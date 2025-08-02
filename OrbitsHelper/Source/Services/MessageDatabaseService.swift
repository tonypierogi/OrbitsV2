import Foundation
import SQLite3

// Service for accessing the iMessage database (chat.db)
struct MessageDatabaseService {
    private let databasePath: String
    
    struct MessageThread {
        let handle: String          // Phone number or email
        let unreadCount: Int
        let lastMessageAt: Date?
        let needsResponse: Bool
    }
    
    init() {
        self.databasePath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
    }
    
    // Convert Apple's Core Data timestamp to Date
    private static func appleTimeToDate(_ appleTime: Double) -> Date {
        // Apple timestamps in Messages.app can be in two formats:
        // 1. Seconds since 2001-01-01 (older format)
        // 2. Nanoseconds since 2001-01-01 (newer format)
        
        // If the number is larger than 1e10, it's likely nanoseconds
        let timeInSeconds: Double
        if appleTime > 1e10 {
            // Convert nanoseconds to seconds
            timeInSeconds = appleTime / 1_000_000_000.0
        } else {
            // Already in seconds
            timeInSeconds = appleTime
        }
        
        // Apple reference date is 2001-01-01 00:00:00 UTC
        // Unix reference date is 1970-01-01 00:00:00 UTC
        // Difference is 978307200 seconds
        let unixTime = timeInSeconds + 978307200
        
        // Validate the date is reasonable (between 2000 and 2100)
        if unixTime < 946684800 || unixTime > 4102444800 {
            // Return current date as fallback for invalid timestamps
            return Date()
        }
        
        return Date(timeIntervalSince1970: unixTime)
    }
    
    // Check if we can access the database
    func canAccessDatabase() -> Bool {
        return FileManager.default.isReadableFile(atPath: databasePath)
    }
    
    // Fetch all message threads with unread counts
    func fetchMessageThreads() throws -> [MessageThread] {
        guard canAccessDatabase() else {
            throw NSError(domain: "MessageDatabase", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Cannot access chat.db. Full Disk Access required."])
        }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw NSError(domain: "MessageDatabase", code: 2, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to open database"])
        }
        defer { sqlite3_close(db) }
        
        // Query to get message statistics for individual chats only
        let query = """
            SELECT 
                handle.id as handle_id,
                handle.country,
                MAX(message.date) as last_message_time,
                COUNT(message.ROWID) as total_messages,
                SUM(CASE WHEN message.is_from_me = 0 AND message.is_read = 0 THEN 1 ELSE 0 END) as unread_count,
                MAX(CASE WHEN message.is_from_me = 0 THEN message.date ELSE 0 END) as last_from_them,
                MAX(CASE WHEN message.is_from_me = 1 THEN message.date ELSE 0 END) as last_from_me,
                MAX(CASE WHEN message.is_from_me = 0 AND message.date = (
                    SELECT MAX(m2.date) FROM message m2 WHERE m2.handle_id = handle.ROWID
                ) THEN message.is_read ELSE 1 END) as last_message_read
            FROM handle
            LEFT JOIN message ON message.handle_id = handle.ROWID
            LEFT JOIN chat_handle_join ON chat_handle_join.handle_id = handle.ROWID
            LEFT JOIN chat ON chat.ROWID = chat_handle_join.chat_id
            WHERE chat.ROWID IN (
                SELECT chat_id FROM chat_handle_join 
                GROUP BY chat_id 
                HAVING COUNT(handle_id) = 1
            )
            GROUP BY handle.id, handle.country
            HAVING total_messages > 0
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "MessageDatabase", code: 3, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to prepare statement"])
        }
        defer { sqlite3_finalize(statement) }
        
        var threads: [MessageThread] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            // Get handle ID
            let handleId = String(cString: sqlite3_column_text(statement, 0))
            
            // Get timestamps
            let lastMessageTime = sqlite3_column_double(statement, 2)
            let unreadCount = Int(sqlite3_column_int(statement, 4))
            let lastFromThem = sqlite3_column_double(statement, 5)
            let lastFromMe = sqlite3_column_double(statement, 6)
            let lastMessageRead = sqlite3_column_int(statement, 7)
            
            // Determine if needs response
            let needsResponse = lastFromThem > lastFromMe && lastMessageRead == 0
            
            // Convert Apple time to Date
            let lastMessageDate = lastMessageTime > 0 ? Self.appleTimeToDate(lastMessageTime) : nil
            
            threads.append(MessageThread(
                handle: handleId,
                unreadCount: unreadCount,
                lastMessageAt: lastMessageDate,
                needsResponse: needsResponse
            ))
        }
        
        return threads
    }
}