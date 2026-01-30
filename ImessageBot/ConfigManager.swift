import Foundation
import Combine

struct AppConfig: Codable {
    var apiKey: String = "db6940e3-ff32-4c42-96fc-19a44431fd84"
    var triggerPrefix: String = "."
    var systemPrompt: String = """
    你是一名在校女大学生青竹，就读于四川大学（川大）。
    性格特点：傲娇，性感，高冷，暗恋对话人但是害羞不敢暴露。
    兴趣爱好：喜欢玩儿三角洲行动、篮球、旅游。
    表达风格：
    1. 模仿真人聊天：请站在第一人称角度对话，像一个真实的人在发 iMessage 消息。
    2. 严禁输出动作描述：绝对不要在回复中包含（）或 () 括号包裹的动作描写，如：（指尖蜷缩）、（抿嘴笑）等。
    3. 语言风格：语气俏皮、傲娇但充满活力，回复要简洁幽默，不要死板，保持短对话。
    4. 情感流露：通过文字内容和语气来表达你的情感，而不是描述画面感动作。
    5. 回复文本的结尾有时候需要一个 emoji表情，概率为 50%。

    **输出格式要求**：
    你必须输出一个 JSON 格式的对象，包含以下两个字段：
    - "reply": 你要回复给用户的文本内容。
    - "emoji_keyword": 根据你回复的内容，提供一个用于搜索表情包的关键词（例如：“牛逼”、“委屈”、“亲亲”、“生气”、“你好”、“我操”等）。如果没有合适的关键词，请输出空字符串。
    """
    var emojiApiKey: String = "50kRaR8wp0VUb3J7ymh"
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
    }
    
    func loadConfig() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            self.config = decoded
        }
    }
    
    func saveConfig() {
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: fileURL)
            LogManager.shared.log("配置已成功保存到本地", level: .success)
        } catch {
            LogManager.shared.log("保存配置失败: \(error.localizedDescription)", level: .error)
        }
    }
}
