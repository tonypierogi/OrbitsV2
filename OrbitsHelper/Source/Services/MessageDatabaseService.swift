import Foundation
import SQLite3

// Service for accessing the iMessage database (chat.db)
struct MessageDatabaseService {
    private let databasePath: String
    
    struct MessageThread {
        let chatId: String           // Chat GUID
        let handles: [String]        // Phone numbers/emails of participants
        let displayName: String?     // Group chat name if applicable
        let isGroup: Bool           // Whether this is a group chat
        let hasUnreadMessages: Bool  // True if has unread messages
        let lastMessageAt: Date?
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
        
        // Query to get all chats with unread status using hybrid approach
        // Checks both is_read flag and last_read_message_timestamp for comprehensive detection
        let query = """
            WITH chat_unread_info AS (
                SELECT 
                    c.ROWID as chat_rowid,
                    c.guid as chat_id,
                    c.display_name,
                    c.last_read_message_timestamp,
                    MAX(m.date) as last_message_date,
                    -- Check for unread using both methods
                    MAX(CASE 
                        WHEN m.is_from_me = 0 AND m.is_read = 0 THEN 1
                        WHEN m.is_from_me = 0 AND c.last_read_message_timestamp > 0 
                             AND m.date > c.last_read_message_timestamp THEN 1
                        ELSE 0
                    END) as has_unread
                FROM chat c
                JOIN chat_message_join cmj ON c.ROWID = cmj.chat_id
                JOIN message m ON m.ROWID = cmj.message_id
                GROUP BY c.ROWID, c.guid, c.display_name, c.last_read_message_timestamp
            )
            SELECT 
                cui.chat_id,
                cui.display_name,
                GROUP_CONCAT(DISTINCT h.id) as participants,
                COUNT(DISTINCT h.id) as participant_count,
                cui.last_message_date,
                cui.has_unread
            FROM chat_unread_info cui
            LEFT JOIN chat_handle_join chj ON cui.chat_rowid = chj.chat_id
            LEFT JOIN handle h ON h.ROWID = chj.handle_id
            GROUP BY cui.chat_rowid, cui.chat_id, cui.display_name, cui.last_message_date, cui.has_unread
            HAVING cui.last_message_date IS NOT NULL
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "MessageDatabase", code: 3, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to prepare statement"])
        }
        defer { sqlite3_finalize(statement) }
        
        var threads: [MessageThread] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            // Get chat ID (column 0)
            let chatId = String(cString: sqlite3_column_text(statement, 0))
            
            // Get display name if exists (column 1)
            let displayName: String? = if sqlite3_column_type(statement, 1) != SQLITE_NULL {
                String(cString: sqlite3_column_text(statement, 1))
            } else {
                nil
            }
            
            // Get participants (column 2)
            let participantsStr = String(cString: sqlite3_column_text(statement, 2))
            let handles = participantsStr.split(separator: ",").map { String($0) }
            
            // Get participant count (column 3)
            let participantCount = Int(sqlite3_column_int(statement, 3))
            let isGroup = participantCount > 1
            
            // Get last message time (column 4)
            let lastMessageTime = sqlite3_column_double(statement, 4)
            
            // Get unread status (column 5)
            let hasUnread = Int(sqlite3_column_int(statement, 5))
            
            // Convert Apple time to Date
            let lastMessageDate = lastMessageTime > 0 ? Self.appleTimeToDate(lastMessageTime) : nil
            
            threads.append(MessageThread(
                chatId: chatId,
                handles: handles,
                displayName: displayName,
                isGroup: isGroup,
                hasUnreadMessages: hasUnread > 0,
                lastMessageAt: lastMessageDate
            ))
        }
        
        return threads
    }
}