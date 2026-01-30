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

struct AppConfig: Codable {
    var apiKey: String = ""
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
