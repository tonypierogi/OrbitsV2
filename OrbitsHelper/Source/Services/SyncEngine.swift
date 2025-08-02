import Foundation
import Contacts
import OrbitsKit
import Supabase
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
        
        // 5. Create a map of handles to message data, combining multiple threads if needed
        var messageDataByHandle: [String: MessageDatabaseService.MessageThread] = [:]
        for thread in messageThreads {
            let normalizedHandle = ContactEnrichmentService.normalizeHandle(thread.handle)
            
            if let existingThread = messageDataByHandle[normalizedHandle] {
                // Combine data from multiple threads for the same handle
                let combinedUnreadCount = existingThread.unreadCount + thread.unreadCount
                let latestMessageDate: Date? = {
                    if let existingDate = existingThread.lastMessageAt,
                       let threadDate = thread.lastMessageAt {
                        return existingDate > threadDate ? existingDate : threadDate
                    }
                    return existingThread.lastMessageAt ?? thread.lastMessageAt
                }()
                let needsResponse = existingThread.needsResponse || thread.needsResponse
                
                messageDataByHandle[normalizedHandle] = MessageDatabaseService.MessageThread(
                    handle: normalizedHandle,
                    unreadCount: combinedUnreadCount,
                    lastMessageAt: latestMessageDate,
                    needsResponse: needsResponse
                )
            } else {
                // First thread for this handle
                messageDataByHandle[normalizedHandle] = thread
            }
        }
        
        // 6. Process all contacts and enrich with message data
        var personsToSync: [Person] = []
        var processedHandles = Set<String>()
        
        // Process contacts from Contacts app
        for (handle, contact) in handleToContactMap {
            let normalizedHandle = ContactEnrichmentService.normalizeHandle(handle)
            
            // Skip if we've already processed this contact
            if processedHandles.contains(normalizedHandle) {
                continue
            }
            processedHandles.insert(normalizedHandle)
            
            // Find the best identifier for this contact
            guard let contactIdentifier = ContactEnrichmentService.findBestContactIdentifier(from: contact) else {
                continue
            }
            
            // Get message data if available
            let messageData = messageDataByHandle[normalizedHandle]
            
            // Generate photo hash if available
            let photoHash = ContactEnrichmentService.generatePhotoHash(from: contact.imageData)
            
            let person = Person(
                userId: session.user.id,
                contactIdentifier: contactIdentifier,
                displayName: ContactEnrichmentService.buildDisplayName(from: contact),
                photoHash: photoHash,
                photoAvailable: contact.imageDataAvailable,
                orbitId: nil,
                unreadCount: messageData?.unreadCount ?? 0,
                lastMessageAt: messageData?.lastMessageAt
            )
            
            personsToSync.append(person)
        }
        
        // 7. Process message threads that don't have matching contacts
        for thread in messageThreads {
            let normalizedHandle = ContactEnrichmentService.normalizeHandle(thread.handle)
            
            if !processedHandles.contains(normalizedHandle) {
                processedHandles.insert(normalizedHandle)
                
                // Create a Person entry for this message thread without contact info
                let person = Person(
                    userId: session.user.id,
                    contactIdentifier: normalizedHandle,
                    displayName: thread.handle, // Use handle as display name
                    photoHash: nil,
                    photoAvailable: false,
                    orbitId: nil,
                    unreadCount: thread.unreadCount,
                    lastMessageAt: thread.lastMessageAt
                )
                
                personsToSync.append(person)
            }
        }
        
        // 8. Remove any duplicates based on contact_identifier
        var uniquePersons: [String: Person] = [:]
        var duplicateCount = 0
        for person in personsToSync {
            // Keep the first occurrence of each contact_identifier
            if uniquePersons[person.contactIdentifier] == nil {
                uniquePersons[person.contactIdentifier] = person
            } else {
                duplicateCount += 1
                print("Duplicate found: \(person.contactIdentifier) - \(person.displayName ?? "No name")")
            }
        }
        let dedupedPersons = Array(uniquePersons.values)
        if duplicateCount > 0 {
            print("Removed \(duplicateCount) duplicate contact identifiers")
        }
        
        // 9. Sync to Supabase
        print("Syncing \(dedupedPersons.count) persons to Supabase (deduped from \(personsToSync.count))...")
        
        if !dedupedPersons.isEmpty {
            // Upsert with onConflict to handle existing records
            // The unique constraint is on (user_id, contact_identifier)
            // Process in smaller batches to avoid conflicts
            let batchSize = 50
            for i in stride(from: 0, to: dedupedPersons.count, by: batchSize) {
                let endIndex = min(i + batchSize, dedupedPersons.count)
                let batch = Array(dedupedPersons[i..<endIndex])
                
                print("Processing batch \(i/batchSize + 1) of \((dedupedPersons.count + batchSize - 1)/batchSize) (\(batch.count) records)")
                
                do {
                    let response = try await supabase
                        .from("person")
                        .upsert(batch, onConflict: "user_id,contact_identifier", ignoreDuplicates: false)
                        .execute()
                    print("✓ Batch \(i/batchSize + 1) completed successfully")
                } catch {
                    print("✗ Error in batch \(i/batchSize + 1): \(error)")
                    throw error
                }
            }
        }
        
        print("Sync complete!")
        print("- Contacts synced: \(handleToContactMap.count)")
        print("- Message threads processed: \(messageThreads.count)")
        print("- Total persons synced: \(personsToSync.count)")
    }
}