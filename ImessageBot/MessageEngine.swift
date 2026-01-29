import Foundation
import SQLite3
import Combine

class MessageEngine: ObservableObject {
    private var db: OpaquePointer?
    private let dbPath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
    private var lastProcessedRowID: Int64 = 0
    private var timer: Timer?
    
    @Published var isRunning = false
    var config: AppConfig
    
    init(config: AppConfig) {
        self.config = config
    }
    
    func start() {
        guard !isRunning else { return }
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Failed to open database. Ensure Full Disk Access is granted.")
            return
        }
        
        // Get initial last row ID
        lastProcessedRowID = getLastRowID()
        isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        sqlite3_close(db)
        db = nil
        isRunning = false
    }
    
    private func getLastRowID() -> Int64 {
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
    
    private func poll() {
        let query = """
        SELECT message.ROWID, message.text, handle.id 
        FROM message 
        JOIN handle ON message.handle_id = handle.rowid 
        ORDER BY message.date DESC 
        LIMIT 1
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let rowID = sqlite3_column_int64(statement, 0)
                
                // 只有当 ID 变化时才处理
                if rowID != lastProcessedRowID {
                    let textPtr = sqlite3_column_text(statement, 1)
                    let senderPtr = sqlite3_column_text(statement, 2)
                    
                    let text = textPtr != nil ? String(cString: textPtr!) : ""
                    let sender = senderPtr != nil ? String(cString: senderPtr!) : ""
                    
                    lastProcessedRowID = rowID
                    
                    if !text.isEmpty && text.hasPrefix(config.triggerPrefix) {
                        handleTrigger(text: text, sender: sender)
                    }
                }
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func handleTrigger(text: String, sender: String) {
        Task {
            do {
                let cleanInput = text.replacingOccurrences(of: config.triggerPrefix, with: "").trimmingCharacters(in: .whitespaces)
                let (reply, emojiKeyword) = try await AIService.getResponse(input: cleanInput, config: config)
                
                // Send text segments
                let segments = splitText(reply)
                for segment in segments {
                    // 发送前检查是否有新动态中断 (同步 Python 逻辑)
                    if let latestID = await getLatestIDAsync(), latestID != lastProcessedRowID {
                        print("检测到新动态, 中断当前回复")
                        return
                    }

                    sendIMessage(to: sender, text: segment)
                    
                    // 发送后立即更新 ID，防止循环触发 (同步 Python 逻辑)
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s wait for DB write
                    if let sentID = await getLatestIDAsync() {
                        lastProcessedRowID = sentID
                    }
                    
                    try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.0...3.0) * 1_000_000_000))
                }
                
                // Handle Emoji
                if !emojiKeyword.isEmpty {
                    if let url = await EmojiService.getEmojiURL(keyword: emojiKeyword, apiKey: config.emojiApiKey),
                       let fileURL = await EmojiService.downloadEmoji(url: url) {
                        sendIMessageAttachment(to: sender, fileURL: fileURL)
                        
                        // 发送后更新 ID
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if let sentID = await getLatestIDAsync() {
                            lastProcessedRowID = sentID
                        }
                        
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                }
            } catch {
                print("Error handling trigger: \(error)")
            }
        }
    }

    private func getLatestIDAsync() async -> Int64? {
        return getLastRowID()
    }
    
    private func splitText(_ text: String) -> [String] {
        let pattern = "([^。！？…\\u{1F600}-\\u{1F64F}\\u{1F300}-\\u{1F5FF}\\u{1F680}-\\u{1F6FF}\\u{1F1E0}-\\u{1F1FF}]+[。！？…\\u{1F600}-\\u{1F64F}\\u{1F300}-\\u{1F5FF}\\u{1F680}-\\u{1F6FF}\\u{1F1E0}-\\u{1F1FF}]+[））」』”\"]*|[^。！？…\\u{1F600}-\\u{1F64F}\\u{1F300}-\\u{1F5FF}\\u{1F680}-\\u{1F6FF}\\u{1F1E0}-\\u{1F1FF}]+$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [text] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        return matches.map { match in
            let range = Range(match.range, in: text)!
            return String(text[range]).trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
    }
    
    private func sendIMessage(to handle: String, text: String) {
        let safeText = text.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
        let scriptSource = "tell application \"Messages\" to send \"\(safeText)\" to buddy \"\(handle)\""
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let err = error { print("AppleScript Error: \(err)") }
        }
    }
    
    private func sendIMessageAttachment(to handle: String, fileURL: URL) {
        let scriptSource = "tell application \"Messages\" to send POSIX file \"\(fileURL.path)\" to buddy \"\(handle)\""
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let err = error { print("AppleScript Attachment Error: \(err)") }
        }
    }
}
