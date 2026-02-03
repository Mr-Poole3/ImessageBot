import Foundation
import SQLite3
import Combine

@MainActor
class MessageEngine: ObservableObject {
    private let databaseService = DatabaseService()
    private var lastProcessedRowID: Int64 = 0
    private var pollingTask: Task<Void, Never>?
    
    @Published var isRunning = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private var configManager: ConfigManager
    
    init(configManager: ConfigManager) {
        self.configManager = configManager
    }
    
    var config: AppConfig {
        configManager.config
    }
    
    func toggle(with config: AppConfig) {
        if isRunning {
            stop()
        } else {
            // 启动前先更新配置
            self.configManager.config = config
            
            // 校验 API Key
            if config.selectedProvider == .volcengine && config.volcengineApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                alertMessage = "服务启动失败：请先在设置中填写火山引擎 API Key。"
                showAlert = true
                return
            } else if config.selectedProvider == .openai && config.openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                alertMessage = "服务启动失败：请先在设置中填写 OpenAI API Key。"
                showAlert = true
                return
            }
            // Ollama usually doesn't need an API Key, so we skip check or check Base URL reachability later
            
            start()
        }
    }
    
    func start() {
        guard !isRunning else { return }
        
        Task {
            do {
                try await databaseService.open()
                self.lastProcessedRowID = await databaseService.getLastRowID()
                self.isRunning = true
                
                LogManager.shared.log("iMessage 机器人服务已启动，唤醒词：'\(self.config.triggerPrefix)'", level: .success)
                self.alertMessage = "机器人服务启动成功！"
                self.showAlert = true
                
                self.startPollingLoop()
                
            } catch {
                let errorMsg = "数据库打开失败，请确保已授予“完全磁盘访问权限”"
                LogManager.shared.log(errorMsg, level: .error)
                self.alertMessage = "服务启动失败：\(errorMsg)"
                self.showAlert = true
                self.isRunning = false
            }
        }
    }
    
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        self.isRunning = false
        
        Task {
            await databaseService.close()
            LogManager.shared.log("服务已停止", level: .warning)
        }
        
        alertMessage = "机器人服务已停止"
        showAlert = true
    }
    
    private func startPollingLoop() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                // 2秒轮询间隔
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self.poll()
            }
        }
    }
    
    private func poll() async {
        guard let result = await databaseService.getLatestMessage() else { return }
        
        // 只有当 ID 变化时才处理
        if result.rowID != lastProcessedRowID {
            let rowID = result.rowID
            let text = result.text
            let sender = result.sender
            
            lastProcessedRowID = rowID
            
            if !text.isEmpty && text.hasPrefix(config.triggerPrefix) {
                LogManager.shared.log("检测到指令: \(text) (来自: \(sender))")
                await handleTrigger(text: text, sender: sender)
            }
        }
    }
    
    private func handleTrigger(text: String, sender: String) async {
        // 使用 Task.detached 或直接在当前 Task 执行都可以，
        // 但为了避免阻塞 polling loop 太久（虽然 loop 是串行的），
        // 这里的处理包含 sleep，所以最好还是让它在单独的 Task 中跑，
        // 不过 pollingTask 本身就是为了处理这个。
        // 如果处理时间很长，会阻塞下一次 poll。
        // 考虑到这里包含多次 sleep (模拟打字)，如果不希望阻塞轮询（比如检测新消息打断），
        // 可以在当前 Task 中执行，但要注意 handleTrigger 内部的逻辑。
        
        // 原有逻辑是 Task { ... } 也就是 fire-and-forget，不阻塞 timer。
        // 这里我们也应该用 Task 包装，以免阻塞 polling loop。
        
        Task {
            do {
                let cleanInput = text.replacingOccurrences(of: config.triggerPrefix, with: "").trimmingCharacters(in: .whitespaces)
                
                // Fetch context history
                // We fetch limit + 1 to account for the potential presence of the current trigger message
                var history = await databaseService.getRecentMessages(handleId: sender, limit: config.contextMemoryLimit + 1)
                
                // Filter out the current message if it appears at the end of the history
                // This prevents the AI from seeing the current prompt as part of the history (which would be redundant)
                if let last = history.last, last.text == text && !last.isFromMe {
                    history.removeLast()
                }
                
                // Ensure we respect the user's configured limit
                if history.count > config.contextMemoryLimit {
                    history = Array(history.suffix(config.contextMemoryLimit))
                }
                
                let (reply, emojiKeyword) = try await AIService.getResponse(input: cleanInput, history: history, config: config)
                
                LogManager.shared.log("AI 回复: \(reply)")
                
                // Send text segments
                let segments = splitText(reply)
                LogManager.shared.log("回复将分 \(segments.count) 段发送")
                
                for segment in segments {
                    // 发送前检查是否有新动态中断
                    if let latestID = await getLatestIDAsync(), latestID != lastProcessedRowID {
                        LogManager.shared.log("检测到新消息，中断当前回复流程", level: .warning)
                        return
                    }

                    sendIMessage(to: sender, text: segment)
                    LogManager.shared.log("已发送: \(segment)")
                    
                    // 发送后立即更新 ID，防止循环触发
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if let sentID = await getLatestIDAsync() {
                        // 注意：这里更新 lastProcessedRowID 需要在 MainActor
                        await MainActor.run {
                            lastProcessedRowID = sentID
                        }
                    }
                    
                    try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.0...3.0) * 1_000_000_000))
                }
                
                // Handle Emoji
                if !emojiKeyword.isEmpty {
                    if Double.random(in: 0...1) < 0.3 {
                        LogManager.shared.log("正在准备表情包: \(emojiKeyword)...")
                        
                        if let latestID = await getLatestIDAsync(), latestID != lastProcessedRowID {
                            LogManager.shared.log("检测到新消息，取消发送表情包", level: .warning)
                            return
                        }
                        
                        if let url = await EmojiService.getEmojiURL(keyword: emojiKeyword, apiKey: config.emojiApiKey) {
                            
                            if let latestID = await getLatestIDAsync(), latestID != lastProcessedRowID {
                                LogManager.shared.log("检测到新消息，取消下载表情包", level: .warning)
                                return
                            }
                            
                            if let fileURL = await EmojiService.downloadEmoji(url: url) {
                                
                                if let latestID = await getLatestIDAsync(), latestID != lastProcessedRowID {
                                    LogManager.shared.log("检测到新消息，取消发送表情包文件", level: .warning)
                                    try? FileManager.default.removeItem(at: fileURL)
                                    return
                                }
                                
                                LogManager.shared.log("表情包下载成功，正在发送...", level: .success)
                                sendIMessageAttachment(to: sender, fileURL: fileURL)
                                
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                if let sentID = await getLatestIDAsync() {
                                    await MainActor.run {
                                        lastProcessedRowID = sentID
                                    }
                                }
                                
                                try? await Task.sleep(nanoseconds: 5_000_000_000)
                                try? FileManager.default.removeItem(at: fileURL)
                            } else {
                                LogManager.shared.log("未能下载表情包", level: .warning)
                            }
                        } else {
                            LogManager.shared.log("未能获取表情包 URL", level: .warning)
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
        return await databaseService.getLastRowID()
    }
    
    private func splitText(_ text: String) -> [String] {
        // 修正后的正则：匹配非分隔符序列，后跟可选的分隔符序列
        // 分隔符包括：中英文句号、感叹号、问号、省略号、换行、波浪号
        // 特殊处理：点号(.)只有在后面不跟数字时才视为分隔符，以避免切分小数（如 -6.0）
        let pattern = "((?:[^。！？…!?.\\n~～]|\\.(?=\\d))+(?:[。！？…!?\\n~～]|\\.(?!\\d))*)"
        
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
