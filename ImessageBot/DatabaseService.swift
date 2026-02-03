import Foundation
import SQLite3

actor DatabaseService {
    private var db: OpaquePointer?
    private let dbPath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
    
    enum DatabaseError: Error {
        case openFailed
    }
    
    struct MessageResult {
        let rowID: Int64
        let text: String
        let sender: String
    }
    
    struct ChatMessage {
        let text: String
        let isFromMe: Bool
    }
    
    func open() throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw DatabaseError.openFailed
        }
    }
    
    func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    func getLastRowID() -> Int64 {
        guard let db = db else { return 0 }
        let query = "SELECT MAX(ROWID) FROM message"
        var statement: OpaquePointer?
        var rowID: Int64 = 0
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                rowID = sqlite3_column_int64(statement, 0)
            }
        }
        sqlite3_finalize(statement)
        return rowID
    }
    
    func getLatestMessage() -> MessageResult? {
        guard let db = db else { return nil }
        
        let query = """
        SELECT message.ROWID, message.text, handle.id 
        FROM message 
        JOIN handle ON message.handle_id = handle.rowid 
        ORDER BY message.date DESC 
        LIMIT 1
        """
        
        var statement: OpaquePointer?
        var result: MessageResult?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let rowID = sqlite3_column_int64(statement, 0)
                let textPtr = sqlite3_column_text(statement, 1)
                let senderPtr = sqlite3_column_text(statement, 2)
                
                let text = textPtr != nil ? String(cString: textPtr!) : ""
                let sender = senderPtr != nil ? String(cString: senderPtr!) : ""
                
                result = MessageResult(rowID: rowID, text: text, sender: sender)
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    func getRecentMessages(handleId: String, limit: Int) -> [ChatMessage] {
        guard let db = db else { return [] }
        
        let query = """
        SELECT message.text, message.is_from_me
        FROM message
        JOIN handle ON message.handle_id = handle.rowid
        WHERE handle.id = ? AND message.text IS NOT NULL
        ORDER BY message.date DESC
        LIMIT ?
        """
        
        var statement: OpaquePointer?
        var messages: [ChatMessage] = []
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            // Bind parameters
            sqlite3_bind_text(statement, 1, (handleId as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let textPtr = sqlite3_column_text(statement, 0)
                let isFromMe = sqlite3_column_int(statement, 1) != 0
                
                if let textPtr = textPtr {
                    let text = String(cString: textPtr)
                    // Simple filtering to avoid empty messages or just whitespace
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        messages.append(ChatMessage(text: text, isFromMe: isFromMe))
                    }
                }
            }
        }
        sqlite3_finalize(statement)
        
        // Return reversed to be in chronological order (oldest -> newest)
        return messages.reversed()
    }
}
