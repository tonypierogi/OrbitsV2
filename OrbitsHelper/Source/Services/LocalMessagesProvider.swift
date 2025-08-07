import Foundation

// This service is responsible for querying the local chat.db SQLite database.
// This requires Full Disk Access permission on macOS.
struct LocalMessagesProvider {
    private let messageDatabaseService = MessageDatabaseService()
    
    // Fetch all message threads with their unread counts and last message info
    func fetchMessageThreads() throws -> [MessageDatabaseService.MessageThread] {
        return try messageDatabaseService.fetchMessageThreads()
    }
    
    // Fetch unread message threads (contacts with unread messages)
    func fetchUnreadMessageThreads() -> [String] {
        do {
            let threads = try messageDatabaseService.fetchMessageThreads()
            // Return all handles from threads with unread messages
            return threads
                .filter { $0.hasUnreadMessages }
                .flatMap { $0.handles }
        } catch {
            print("Error fetching unread messages: \(error.localizedDescription)")
            return []
        }
    }
    
    // Check if we have access to the messages database
    func hasMessageAccess() -> Bool {
        return messageDatabaseService.canAccessDatabase()
    }
    
    // Get a summary of message access status
    func getAccessStatus() -> String {
        if hasMessageAccess() {
            return "Message access granted"
        } else {
            return "Full Disk Access required to sync messages"
        }
    }
}