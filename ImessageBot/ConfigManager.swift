import Foundation
import Combine

struct PersonaCard: Codable, Identifiable, Equatable {
    var id: UUID
    var cardName: String
    var personaName: String
    var description: String
    
    init(id: UUID = UUID(), cardName: String, personaName: String, description: String) {
        self.id = id
        self.cardName = cardName
        self.personaName = personaName
        self.description = description
    }
    
    var systemPrompt: String {
        return """
        姓名：\(personaName)
        \(description)
        """
    }
}

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case volcengine = "Volcengine"
    case openai = "OpenAI"
    case ollama = "Ollama"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .volcengine: return "icon_volcengine"
        case .openai: return "icon_openai"
        case .ollama: return "icon_ollama"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .volcengine: return "cloud.fill"
        case .openai: return "sparkles"
        case .ollama: return "cpu.fill"
        }
    }
    
    var description: String {
        switch self {
        case .volcengine: return "火山引擎 (豆包)"
        case .openai: return "OpenAI / 兼容接口"
        case .ollama: return "本地 / 远程 LLM"
        }
    }
}

struct AppConfig: Codable {
    // Legacy support: apiKey was originally used for Volcengine
    var apiKey: String = ""
    
    // AI Provider Selection
    var selectedProvider: AIProvider = .volcengine
    
    // Provider Specific Settings
    // Volcengine
    var volcengineApiKey: String = ""
    var volcengineBaseURL: String = "https://ark.cn-beijing.volces.com/api/v3"
    var volcengineModel: String = "doubao-seed-1-6-flash-250828"
    
    // OpenAI
    var openaiApiKey: String = ""
    var openaiBaseURL: String = "https://api.openai.com/v1"
    var openaiModel: String = "gpt-3.5-turbo"
    
    // Ollama
    var ollamaBaseURL: String = "http://localhost:11434"
    var ollamaModel: String = "llama3"
    
    var triggerPrefix: String = "."
    var personaCards: [PersonaCard] = [
        PersonaCard(
            cardName: "默认角色",
            personaName: "青竹",
            description: "你是一名在校女大学生青竹，就读于四川大学（川大）。性格傲娇，性感，高冷。"
        )
    ]
    var selectedPersonaId: UUID?
    
    var userSystemPrompt: String {
        if let selectedId = selectedPersonaId,
           let card = personaCards.first(where: { $0.id == selectedId }) {
            return card.systemPrompt
        }
        return personaCards.first?.systemPrompt ?? ""
    }
    
    // 程序写死的输出格式提示词，不建议用户修改
    var formatInstruction: String = """
    **注意事项**：
    - 你不能输出任何与动作描述相关的内容，例如：（头转向一旁），（站在一旁），（轻轻撩动头发），（撇你一眼）等文本内容。
    - 你需要站在第一人称角度发送 imessage聊天信息和用户对话。
    - 严禁发送和黄色，赌博，毒品等违法内容。
    - 严禁讨论政治内容，包括但不限于：政治话题，政治人物，政治事件等。

    **输出格式要求**：
    你必须输出一个 JSON 格式的对象，包含以下两个字段：
    - "reply": 你要回复给用户的文本内容。
    - "emoji_keyword": 根据你回复的内容，提供一个用于搜索表情包的关键词（例如：“牛逼”、“委屈”、“亲亲”、“生气”、“你好”、“我操”等）。如果没有合适的关键词，请输出空字符串。
    """
    
    var emojiApiKey: String = ""
    // Number of historical messages to include in context (1-20)
    var contextMemoryLimit: Int = 10
    var isRunning: Bool = false
}

class ConfigManager: ObservableObject {
    @Published var config: AppConfig
    
    private let fileURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".imessagebot")
    }()
    
    init() {
        self.config = AppConfig()
        loadConfig()
        
        // 确保有一个默认选中的角色
        if config.selectedPersonaId == nil {
            config.selectedPersonaId = config.personaCards.first?.id
        }
        
        // Migration: If apiKey exists but volcengineApiKey is empty, migrate it
        if !config.apiKey.isEmpty && config.volcengineApiKey.isEmpty {
            config.volcengineApiKey = config.apiKey
            // We can optionally clear the old apiKey, but keeping it for safety might be okay.
            // Let's not clear it for now to avoid data loss if user downgrades (unlikely but safe).
        }
    }
    
    func loadConfig() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            self.config = decoded
        }
    }
    
    func saveConfig() -> Bool {
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: fileURL)
            LogManager.shared.log("配置已成功保存到本地", level: .success)
            return true
        } catch {
            LogManager.shared.log("保存配置失败: \(error.localizedDescription)", level: .error)
            return false
        }
    }
}
