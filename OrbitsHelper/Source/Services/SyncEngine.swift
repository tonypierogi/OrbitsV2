import Foundation
import Contacts
import OrbitsKit // Use our shared package
import Supabase

@MainActor
class SyncEngine {
    private let contactsProvider = LocalContactsProvider()
    private let messagesProvider = LocalMessagesProvider()
    private let supabase = SupabaseManager.shared.client

    func runFullSync() async throws {
        print("Starting full sync...")
        
        // 1. Ensure we have a logged-in user.
        guard let session = supabase.auth.currentSession else {
            print("Sync failed: No active user session.")
            throw URLError(.userAuthenticationRequired)
        }
        
        // 2. Fetch all local contacts.
        let localContacts = try contactsProvider.fetchAllContacts()
        print("Found \(localContacts.count) contacts locally.")

        // 3. Transform CNContacts into our 'Person' model from OrbitsKit.
        let orbitPersons = localContacts.map { contact -> Person in
            // This is a simplified transformation.
            // A real implementation would handle hashing the photo data.
            return Person(
                id: UUID(), // Supabase will assign an ID on insert if not specified
                userId: session.user.id,
                contactIdentifier: contact.identifier,
                displayName: "\(contact.givenName) \(contact.familyName)",
                photoHash: nil, // Placeholder for photo hash logic
                photoAvailable: contact.imageDataAvailable,
                orbitId: nil, // Default orbit can be assigned later
                unreadCount: 0,
                lastMessageAt: nil
            )
        }
        
        // 4. Upsert the contacts to Supabase.
        // 'Upsert' will insert new contacts and update existing ones
        // based on the unique constraint (user_id, contact_identifier).
        print("Syncing \(orbitPersons.count) contacts to Supabase...")
        try await supabase
            .from("person")
            .upsert(orbitPersons)
            .execute()

        print("Contact sync complete!")
        // TODO: Implement unread message sync logic here.
    }
}