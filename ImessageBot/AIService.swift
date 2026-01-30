import Foundation

class AIService {
    struct AIResponse: Codable {
        let reply: String
        let emoji_keyword: String
    }
    
    static func getResponse(input: String, config: AppConfig) async throws -> (String, String) {
        let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let fullSystemPrompt = config.userSystemPrompt + config.formatInstruction
        
        let body: [String: Any] = [
            "model": "doubao-seed-1-6-flash-250828",
            "messages": [
                ["role": "system", "content": fullSystemPrompt],
                ["role": "user", "content": input]
            ],
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        LogManager.shared.log("正在请求 AI 响应...")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct ChatCompletion: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let completion = try JSONDecoder().decode(ChatCompletion.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw NSError(domain: "AIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
        }
        
        let aiData = try JSONDecoder().decode(AIResponse.self, from: content.data(using: .utf8)!)
        return (aiData.reply, aiData.emoji_keyword)
    }
}
