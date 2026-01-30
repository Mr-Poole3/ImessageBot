import Foundation
import SQLite3
import Combine

class MessageEngine: ObservableObject {
    private var db: OpaquePointer?
    private let dbPath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
    private var lastProcessedRowID: Int64 = 0
    private var timer: Timer?
    
    @Published var isRunning = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    var config: AppConfig
    
    init(config: AppConfig) {
        self.config = config
    }
    
    func toggle(with config: AppConfig) {
        if isRunning {
            stop()
            alertMessage = "机器人服务已停止"
            showAlert = true
        } else {
            self.config = config
            start()
            
            if isRunning {
                alertMessage = "机器人服务启动成功！"
            } else {
                alertMessage = "服务启动失败：请确保已在“系统设置 -> 隐私与安全性 -> 完全磁盘访问权限”中添加并勾选了本应用。"
            }
            showAlert = true
        }
    }
    
    func start() {
        guard !isRunning else { return }
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errorMsg = "数据库打开失败，请确保已授予“完全磁盘访问权限”"
            LogManager.shared.log(errorMsg, level: .error)
            // 保持 isRunning 为 false，这样 UI 上的按钮状态就不会变
            isRunning = false
            return
        }
        
        // 成功打开数据库后，再设置运行状态
        lastProcessedRowID = getLastRowID()
        isRunning = true
        LogManager.shared.log("iMessage 机器人服务已启动，唤醒词：'\(config.triggerPrefix)'", level: .success)
        
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
        LogManager.shared.log("服务已停止", level: .warning)
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
                        LogManager.shared.log("检测到指令: \(text) (来自: \(sender))")
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
                
                LogManager.shared.log("AI 回复: \(reply)")
                
                // Send text segments
                let segments = splitText(reply)
                LogManager.shared.log("回复将分 \(segments.count) 段发送")
                
                for segment in segments {
                    // 发送前检查是否有新动态中断 (同步 Python 逻辑)
                    if let latestID = await getLatestIDAsync(), latestID != lastProcessedRowID {
                        LogManager.shared.log("检测到新消息，中断当前回复流程", level: .warning)
                        return
                    }

                    sendIMessage(to: sender, text: segment)
                    LogManager.shared.log("已发送: \(segment)")
                    
                    // 发送后立即更新 ID，防止循环触发 (同步 Python 逻辑)
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s wait for DB write
                    if let sentID = await getLatestIDAsync() {
                        lastProcessedRowID = sentID
                    }
                    
                    try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.0...3.0) * 1_000_000_000))
                }
                
                // Handle Emoji
                if !emojiKeyword.isEmpty {
                    // 随机决定是否发送表情包 (例如 50% 概率)
                    if Double.random(in: 0...1) < 0.3 {
                        LogManager.shared.log("正在准备表情包: \(emojiKeyword)...")
                        if let url = await EmojiService.getEmojiURL(keyword: emojiKeyword, apiKey: config.emojiApiKey),
                           let fileURL = await EmojiService.downloadEmoji(url: url) {
                            LogManager.shared.log("表情包下载成功，正在发送...", level: .success)
                            sendIMessageAttachment(to: sender, fileURL: fileURL)
                            
                            // 发送后更新 ID
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            if let sentID = await getLatestIDAsync() {
                                lastProcessedRowID = sentID
                            }
                            
                            // 延长等待时间，确保 iMessage 已读取并处理文件
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            try? FileManager.default.removeItem(at: fileURL)
                        } else {
                            LogManager.shared.log("未能获取或下载表情包", level: .warning)
                        }
                    } else {
                        LogManager.shared.log("随机决定本次不发送表情包 (\(emojiKeyword))")
                    }
                }
            } catch {
                LogManager.shared.log("处理指令时出错: \(error.localizedDescription)", level: .error)
            }
        }
    }

    private func getLatestIDAsync() async -> Int64? {
        return getLastRowID()
    }
    
    private func splitText(_ text: String) -> [String] {
        // 修正后的正则：匹配非分隔符序列，后跟可选的分隔符序列
        // 分隔符包括：中英文句号、感叹号、问号、省略号、换行、波浪号
        let pattern = "([^。！？…!?.\\n~～]+[。！？…!?.\\n~～]*)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [text]
        }
        
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        return results.map { nsString.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
