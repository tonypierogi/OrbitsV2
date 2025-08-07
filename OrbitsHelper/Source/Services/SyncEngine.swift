import Foundation
import Contacts
import OrbitsKit
import Supabase
import PostgREST
import CryptoKit

@MainActor
class SyncEngine {
    private let contactsProvider = LocalContactsProvider()
    private let messagesProvider = LocalMessagesProvider()
    private let supabase = SupabaseManager.shared.client
    
    enum SyncError: LocalizedError {
        case noSession
        case permissionDenied(String)
        
        var errorDescription: String? {
            switch self {
            case .noSession:
                return "No active user session"
            case .permissionDenied(let details):
                return "Permission denied: \(details)"
            }
        }
    }
    
    // MARK: - Contact Validation Helpers
    
    private func isValidPhoneNumber(_ identifier: String) -> Bool {
        // Count the number of digits in the identifier
        let digitCount = identifier.filter { $0.isNumber }.count
        return digitCount >= 7
    }
    
    // MARK: - Identifier Normalization for Matching
    
    private func normalizeIdentifierForMatching(_ identifier: String) -> String {
        // Use ContactEnrichmentService for consistent normalization
        return ContactEnrichmentService.normalizeHandle(identifier)
    }
    
    // No longer needed since we use CNContact.identifier which is stable and unique
    // private func generatePossibleIdentifierKeys(_ identifier: String) -> [String] {
    //     // This function is obsolete with CNContact.identifier approach
    // }
    
    private func isRealName(_ displayName: String?) -> Bool {
        guard let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return false
        }
        
        // Check if it's an email
        if name.contains("@") && name.contains(".") {
            return false
        }
        
        // Check if it's purely numeric (with optional formatting)
        let strippedName = name.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "+", with: "")
        
        if !strippedName.isEmpty && strippedName.allSatisfy({ $0.isNumber }) {
            return false
        }
        
        // Check if it contains at least one letter (real names should have letters)
        let hasLetter = name.contains { $0.isLetter }
        if !hasLetter {
            return false
        }
        
        // Additional check: if the name is too short (less than 2 characters), it's probably not a real name
        if name.count < 2 {
            return false
        }
        
        return true
    }
    
    private func shouldSyncContact(identifier: String, displayName: String?) -> Bool {
        // Only validate phone numbers - emails are always valid
        if !identifier.contains("@") {
            // It's a phone number, check if it has enough digits
            if !isValidPhoneNumber(identifier) {
                print("Skipping contact '\(displayName ?? identifier)': Invalid phone number (less than 7 digits)")
                return false
            }
        }
        
        // Skip if display name isn't a real name
        if !isRealName(displayName) {
            print("Skipping contact '\(displayName ?? identifier)': Display name appears to be email/number/invalid")
            return false
        }
        
        return true
    }

    func runFullSync() async throws {
        print("Starting full sync...")
        
        // 1. Ensure we have a logged-in user.
        guard let session = supabase.auth.currentSession else {
            throw SyncError.noSession
        }
        
        print("Syncing for user ID: \(session.user.id)")
        print("User email: \(session.user.email ?? "No email")")
        
        // 2. Check permissions
        let permissionStatus = await PermissionsManager.getPermissionStatus()
        guard permissionStatus.contactsAccess else {
            throw SyncError.permissionDenied("Contacts access required. \(permissionStatus.instructions ?? "")")
        }
        
        // 3. Create handle mapping from contacts
        let handleToContactMap = try await contactsProvider.createHandleToContactMapping()
        print("Created handle mapping with \(handleToContactMap.count) entries")
        
        // 4. Fetch message threads if we have access
        var messageThreads: [MessageDatabaseService.MessageThread] = []
        if permissionStatus.fullDiskAccess {
            do {
                messageThreads = try messagesProvider.fetchMessageThreads()
                print("Found \(messageThreads.count) message threads")
            } catch {
                print("Warning: Could not fetch messages: \(error.localizedDescription)")
            }
        } else {
            print("Skipping message sync - Full Disk Access not granted")
        }
        
        // 5. Create a map of handles to message data from chat threads
        struct MessageData {
            let hasUnreadMessages: Bool
            let lastMessageAt: Date?
            let chatGuid: String
        }
        var messageDataByHandle: [String: MessageData] = [:]
        
        for thread in messageThreads {
            // For individual chats, map to the single participant
            if !thread.isGroup && thread.handles.count == 1 {
                let handle = thread.handles[0]
                let normalizedHandle = ContactEnrichmentService.normalizeHandle(handle)
                
                // Aggregate data if this handle appears in multiple chats
                if let existing = messageDataByHandle[normalizedHandle] {
                    // If either chat has unread messages, mark as unread
                    let hasUnread = existing.hasUnreadMessages || thread.hasUnreadMessages
                    let latestDate: Date? = {
                        if let e = existing.lastMessageAt, let t = thread.lastMessageAt {
                            return e > t ? e : t
                        }
                        return existing.lastMessageAt ?? thread.lastMessageAt
                    }()
                    // Keep the chat GUID from the chat with unread messages, or the most recent
                    let chatGuid = thread.hasUnreadMessages ? thread.chatId : existing.chatGuid
                    messageDataByHandle[normalizedHandle] = MessageData(hasUnreadMessages: hasUnread, lastMessageAt: latestDate, chatGuid: chatGuid)
                } else {
                    messageDataByHandle[normalizedHandle] = MessageData(hasUnreadMessages: thread.hasUnreadMessages, lastMessageAt: thread.lastMessageAt, chatGuid: thread.chatId)
                }
            }
            // Group chats will be handled separately if needed
        }
        
        // 6. Process all contacts and enrich with message data
        var personsToSync: [Person] = []
        var processedHandles = Set<String>()
        var skippedContactsCount = 0
        
        // Process contacts from Contacts app
        for (handle, contact) in handleToContactMap {
            _ = ContactEnrichmentService.normalizeHandle(handle)
            
            // Skip if we've already processed this contact (by CNContact.identifier)
            if processedHandles.contains(contact.identifier) {
                continue
            }
            processedHandles.insert(contact.identifier)
            
            // Build display name for filtering check
            let displayName = ContactEnrichmentService.buildDisplayName(from: contact)
            
            // Get phone and email for display/communication
            let phoneNumber = ContactEnrichmentService.getPrimaryPhoneNumber(from: contact)
            let emailAddress = ContactEnrichmentService.getPrimaryEmailAddress(from: contact)
            
            // Apply filtering criteria (use phone or email for validation)
            let identifierForValidation = phoneNumber ?? emailAddress ?? contact.identifier
            if !shouldSyncContact(identifier: identifierForValidation, displayName: displayName) {
                skippedContactsCount += 1
                continue
            }
            
            // Get message data if available (match by phone/email)
            var messageData: MessageData? = nil
            if let phone = phoneNumber {
                let normalizedPhone = ContactEnrichmentService.normalizeHandle(phone)
                messageData = messageDataByHandle[normalizedPhone]
            }
            if messageData == nil, let email = emailAddress {
                let normalizedEmail = ContactEnrichmentService.normalizeHandle(email)
                messageData = messageDataByHandle[normalizedEmail]
            }
            
            // Generate photo hash if available
            let photoHash = ContactEnrichmentService.generatePhotoHash(from: contact.imageData)
            
            let person = Person(
                userId: session.user.id,
                contactIdentifier: contact.identifier,  // Use CNContact.identifier
                phoneNumber: phoneNumber,
                emailAddress: emailAddress,
                displayName: displayName,
                photoHash: photoHash,
                photoAvailable: contact.imageDataAvailable,
                orbitId: nil,
                unreadCount: (messageData?.hasUnreadMessages ?? false) ? 1 : 0,
                lastMessageAt: messageData?.lastMessageAt,
                orbit: nil,
                chatGuid: messageData?.chatGuid,
                needsResponse: false,  // Will be fetched from Supabase
                needsResponseMarkedAt: nil
            )
            
            personsToSync.append(person)
        }
        
        // Skip message-only contacts - we only sync contacts that exist in Contacts app with proper names
        
        // 8. No need for complex deduplication since CNContact.identifier is guaranteed unique
        // But keep this logic as a safety check
        var uniquePersons: [String: Person] = [:]
        var duplicateCount = 0
        for person in personsToSync {
            // Keep the first occurrence of each contactIdentifier (CNContact.identifier)
            if uniquePersons[person.contactIdentifier] == nil {
                uniquePersons[person.contactIdentifier] = person
            } else {
                duplicateCount += 1
                print("Unexpected duplicate CNContact.identifier found: \(person.contactIdentifier) - \(person.displayName ?? "No name")")
            }
        }
        let dedupedPersons = Array(uniquePersons.values)
        if duplicateCount > 0 {
            print("Removed \(duplicateCount) duplicate contact identifiers (this should not happen with CNContact.identifier)")
        }
        
        // 9. Sync to Supabase
        print("Syncing \(dedupedPersons.count) persons to Supabase (deduped from \(personsToSync.count))...")
        
        var totalUpdated = 0
        var totalInserted = 0
        
        if !dedupedPersons.isEmpty {
            // First, fetch all existing persons for this user to preserve IDs and relationships
            print("Fetching existing persons to preserve relationships...")
            
            // Fetch existing persons using the Person model which handles the database schema correctly
            var existingPersons: [Person] = []
            do {
                existingPersons = try await supabase
                    .from("person")
                    .select("*, orbit(*)")  // Include orbit relation like in fetchPersons
                    .eq("user_id", value: session.user.id.uuidString)
                    .execute()
                    .value
                print("Successfully fetched \(existingPersons.count) existing persons")
            } catch {
                print("Error fetching existing persons: \(error)")
                print("Error details: \(error.localizedDescription)")
                // Continue with empty list - all will be treated as new inserts
                existingPersons = []
            }
            
            // Create a simple mapping using CNContact.identifier (no complex key generation needed)
            var existingPersonsMap: [String: Person] = [:]
            for person in existingPersons {
                existingPersonsMap[person.contactIdentifier] = person
            }
            print("Created mapping for \(existingPersons.count) existing persons")
            
            // Separate persons into those that need updates vs new inserts
            var personsToUpdate: [Person] = []
            var personsToInsert: [Person] = []
            
            // Debug: Log some existing contact identifiers
            if !existingPersonsMap.isEmpty {
                let sampleIdentifiers = Array(existingPersonsMap.keys.prefix(5))
                print("Sample existing identifiers: \(sampleIdentifiers)")
            }
            
            for person in dedupedPersons {
                // Simple lookup using CNContact.identifier
                let existingPerson = existingPersonsMap[person.contactIdentifier]
                
                // Debug: Log identifier matching for better troubleshooting
                if dedupedPersons.count <= 10 || personsToInsert.count < 5 {
                    print("Checking CNContact.identifier: '\(person.contactIdentifier)' - Found: \(existingPerson != nil)")
                }
                
                if let existingPerson = existingPerson {
                    // This person exists, prepare for update with existing ID and created_at
                    let updatedPerson = Person(
                        id: existingPerson.id,
                        userId: person.userId,
                        contactIdentifier: person.contactIdentifier,
                        phoneNumber: person.phoneNumber,
                        emailAddress: person.emailAddress,
                        displayName: person.displayName,
                        photoHash: person.photoHash,
                        photoAvailable: person.photoAvailable,
                        orbitId: existingPerson.orbitId, // Preserve orbit relationship
                        unreadCount: person.unreadCount,
                        lastMessageAt: person.lastMessageAt,
                        createdAt: existingPerson.createdAt, // PRESERVE the original created_at
                        updatedAt: Date(), // Update the timestamp
                        orbit: existingPerson.orbit, // Preserve orbit object
                        chatGuid: person.chatGuid,
                        needsResponse: existingPerson.needsResponse, // Preserve needs response flag
                        needsResponseMarkedAt: existingPerson.needsResponseMarkedAt // Preserve needs response marked at
                    )
                    personsToUpdate.append(updatedPerson)
                } else {
                    // This is a new person - log why it's being treated as new
                    if personsToInsert.count < 5 {
                        print("Treating as NEW: CNContact.identifier '\(person.contactIdentifier)' (display: \(person.displayName ?? "nil"))")
                    }
                    personsToInsert.append(person)
                }
            }
            
            print("Persons to update: \(personsToUpdate.count)")
            print("Persons to insert (before final check): \(personsToInsert.count)")
            
            // Final safety check: Query database for any personsToInsert that might already exist
            // This handles edge cases where the initial fetch might have missed some contacts
            if !personsToInsert.isEmpty {
                let identifiersToCheck = personsToInsert.map { $0.contactIdentifier }
                
                do {
                    let existingCheck: [Person] = try await supabase
                        .from("person")
                        .select("id, contact_identifier, created_at")
                        .eq("user_id", value: session.user.id.uuidString)
                        .in("contact_identifier", values: identifiersToCheck)
                        .execute()
                        .value
                    
                    if !existingCheck.isEmpty {
                        print("Found \(existingCheck.count) contacts that already exist in database during final check")
                        
                        // Create a set of existing identifiers for quick lookup
                        let existingIdentifiers = Set(existingCheck.map { $0.contactIdentifier })
                        
                        // Filter out any contacts that already exist
                        let originalCount = personsToInsert.count
                        personsToInsert = personsToInsert.filter { person in
                            !existingIdentifiers.contains(person.contactIdentifier)
                        }
                        
                        print("Filtered out \(originalCount - personsToInsert.count) existing contacts from insert list")
                    }
                } catch {
                    print("Warning: Could not perform final existence check: \(error)")
                    // Continue with original personsToInsert - worst case the insert will fail
                }
            }
            
            print("Persons to insert (after final check): \(personsToInsert.count)")
            
            totalUpdated = personsToUpdate.count
            totalInserted = personsToInsert.count
            
            // Process updates in batches
            if !personsToUpdate.isEmpty {
                let batchSize = 50
                for i in stride(from: 0, to: personsToUpdate.count, by: batchSize) {
                    let endIndex = min(i + batchSize, personsToUpdate.count)
                    let batch = Array(personsToUpdate[i..<endIndex])
                    
                    print("Updating batch \(i/batchSize + 1) of \((personsToUpdate.count + batchSize - 1)/batchSize) (\(batch.count) records)")
                    
                    // Create partial update structs with only the fields we want to update
                    struct PersonUpdate: Encodable {
                        let id: UUID
                        let phoneNumber: String?
                        let emailAddress: String?
                        let displayName: String?
                        let photoHash: String?
                        let photoAvailable: Bool
                        let unreadCount: Int
                        let lastMessageAt: Date?
                        let chatGuid: String?
                        let updatedAt: Date
                    }
                    
                    let updates = batch.map { person in
                        PersonUpdate(
                            id: person.id,
                            phoneNumber: person.phoneNumber,
                            emailAddress: person.emailAddress,
                            displayName: person.displayName,
                            photoHash: person.photoHash,
                            photoAvailable: person.photoAvailable,
                            unreadCount: person.unreadCount,
                            lastMessageAt: person.lastMessageAt,
                            chatGuid: person.chatGuid,
                            updatedAt: Date()
                        )
                    }
                    
                    do {
                        for update in updates {
                            _ = try await supabase
                                .from("person")
                                .update(update)
                                .eq("id", value: update.id.uuidString)
                                .execute()
                        }
                        print("✓ Update batch \(i/batchSize + 1) completed successfully")
                    } catch {
                        print("✗ Error in update batch \(i/batchSize + 1): \(error)")
                        throw error
                    }
                }
            }
            
            // Process inserts in batches - using regular insert since we've already filtered existing
            if !personsToInsert.isEmpty {
                let batchSize = 50
                for i in stride(from: 0, to: personsToInsert.count, by: batchSize) {
                    let endIndex = min(i + batchSize, personsToInsert.count)
                    let batch = Array(personsToInsert[i..<endIndex])
                    
                    print("Inserting batch \(i/batchSize + 1) of \((personsToInsert.count + batchSize - 1)/batchSize) (\(batch.count) records)")
                    
                    // Debug: Log first few identifiers in batch
                    if i == 0 {
                        let sampleBatch = batch.prefix(3)
                        for person in sampleBatch {
                            print("  Inserting: '\(person.contactIdentifier)' - \(person.displayName ?? "no name")")
                        }
                    }
                    
                    do {
                        // Use regular insert since we've already verified these don't exist
                        _ = try await supabase
                            .from("person")
                            .insert(batch)
                            .execute()
                        print("✓ Insert batch \(i/batchSize + 1) completed successfully")
                    } catch {
                        print("✗ Error in insert batch \(i/batchSize + 1): \(error)")
                        
                        // If insert fails due to duplicate (race condition), try to insert individually
                        print("Attempting individual inserts for failed batch...")
                        var individualSuccesses = 0
                        var individualFailures = 0
                        
                        for person in batch {
                            do {
                                _ = try await supabase
                                    .from("person")
                                    .insert(person)
                                    .execute()
                                individualSuccesses += 1
                            } catch {
                                individualFailures += 1
                                print("  Failed to insert '\(person.contactIdentifier)': \(error.localizedDescription)")
                            }
                        }
                        
                        print("Individual insert results: \(individualSuccesses) succeeded, \(individualFailures) failed")
                        
                        // Don't throw the error if some succeeded
                        if individualSuccesses == 0 {
                            throw error
                        }
                    }
                }
            }
        }
        
        print("Sync complete!")
        print("- Contacts found: \(handleToContactMap.count)")
        print("- Contacts skipped (invalid): \(skippedContactsCount)")
        print("- Message threads processed: \(messageThreads.count)")
        print("- Total persons synced: \(dedupedPersons.count)")
        print("- Persons updated: \(totalUpdated)")
        print("- Persons inserted: \(totalInserted)")
    }
}