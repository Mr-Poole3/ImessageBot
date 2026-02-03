import Foundation

class AIService {
    struct AIResponse: Codable {
        let reply: String
        let emoji_keyword: String
    }
    
    // Define a common structure for API response since many providers use OpenAI-compatible format
    struct ChatCompletion: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }
    
    // Define structure for Ollama native API response
    struct OllamaAPIResponse: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let model: String
        let created_at: String
        let message: Message
        let done: Bool
    }
    
    static func getResponse(input: String, config: AppConfig) async throws -> (String, String) {
        switch config.selectedProvider {
        case .volcengine:
            return try await getVolcengineResponse(input: input, config: config)
        case .openai:
            return try await getOpenAIResponse(input: input, config: config)
        case .ollama:
            return try await getOllamaResponse(input: input, config: config)
        }
    }
    
    private static func getVolcengineResponse(input: String, config: AppConfig) async throws -> (String, String) {
        // Ensure Base URL ends with /chat/completions, handle user input flexibility
        var baseUrlString = config.volcengineBaseURL
        if baseUrlString.hasSuffix("/") {
            baseUrlString.removeLast()
        }
        if !baseUrlString.hasSuffix("/chat/completions") {
            baseUrlString += "/chat/completions"
        }
        
        guard let url = URL(string: baseUrlString) else {
            throw NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Volcengine Base URL"])
        }
        
        return try await makeRequest(
            url: url,
            apiKey: config.volcengineApiKey,
            model: config.volcengineModel,
            input: input,
            config: config
        )
    }
    
    private static func getOpenAIResponse(input: String, config: AppConfig) async throws -> (String, String) {
        // Ensure Base URL ends with /chat/completions, handle user input flexibility
        var baseUrlString = config.openaiBaseURL
        if baseUrlString.hasSuffix("/") {
            baseUrlString.removeLast()
        }
        if !baseUrlString.hasSuffix("/chat/completions") {
            baseUrlString += "/chat/completions"
        }
        
        guard let url = URL(string: baseUrlString) else {
            throw NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI Base URL"])
        }
        
        return try await makeRequest(
            url: url,
            apiKey: config.openaiApiKey,
            model: config.openaiModel,
            input: input,
            config: config
        )
    }
    
    private static func getOllamaResponse(input: String, config: AppConfig) async throws -> (String, String) {
        // Ollama usually runs on http://localhost:11434/api/chat or /v1/chat/completions
        // We will use the native /api/chat endpoint for Ollama provider
        var baseUrlString = config.ollamaBaseURL
        if baseUrlString.hasSuffix("/") {
            baseUrlString.removeLast()
        }
        
        // Check if user provided the full path or just the host
        // We prefer /api/chat for native Ollama handling
        if !baseUrlString.contains("/api") && !baseUrlString.contains("/v1") {
            baseUrlString += "/api/chat"
        }
        
        guard let url = URL(string: baseUrlString) else {
            throw NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama Base URL"])
        }
        
        return try await makeOllamaRequest(
            url: url,
            model: config.ollamaModel,
            input: input,
            config: config
        )
    }
    
    private static func makeOllamaRequest(url: URL, model: String, input: String, config: AppConfig) async throws -> (String, String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Some setups might require auth even for Ollama, though usually not default
        request.setValue("Bearer ollama", forHTTPHeaderField: "Authorization")
        
        let fullSystemPrompt = config.userSystemPrompt + config.formatInstruction
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": fullSystemPrompt],
                ["role": "user", "content": input]
            ],
            "stream": false,
            "format": "json"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        LogManager.shared.log("正在请求 Ollama Native API...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                LogManager.shared.log("Ollama API 请求失败: HTTP \(httpResponse.statusCode) - \(errorBody)", level: .error)
                throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
            }
            
            let completion = try JSONDecoder().decode(OllamaAPIResponse.self, from: data)
            let content = completion.message.content
            
            // Try to parse the JSON content from the AI response
            var cleanContent = content
            if cleanContent.contains("```json") {
                cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
            }
            
            guard let jsonData = cleanContent.data(using: .utf8) else {
                throw NSError(domain: "AIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert content to data"])
            }
            
            let aiData = try JSONDecoder().decode(AIResponse.self, from: jsonData)
            return (aiData.reply, aiData.emoji_keyword)
            
        } catch {
            LogManager.shared.log("Ollama 请求或解析出错: \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    private static func makeRequest(url: URL, apiKey: String, model: String, input: String, config: AppConfig) async throws -> (String, String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let fullSystemPrompt = config.userSystemPrompt + config.formatInstruction
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": fullSystemPrompt],
                ["role": "user", "content": input]
            ],
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        LogManager.shared.log("正在请求 AI 响应 (\(config.selectedProvider.rawValue))...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                LogManager.shared.log("API 请求失败: HTTP \(httpResponse.statusCode) - \(errorBody)", level: .error)
                throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
            }
            
            let completion = try JSONDecoder().decode(ChatCompletion.self, from: data)
            guard let content = completion.choices.first?.message.content else {
                throw NSError(domain: "AIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
            }
            
            // Try to parse the JSON content from the AI response
            // Sometimes AI might wrap it in markdown code blocks ```json ... ```
            var cleanContent = content
            if cleanContent.contains("```json") {
                cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
            }
            
            guard let jsonData = cleanContent.data(using: .utf8) else {
                throw NSError(domain: "AIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert content to data"])
            }
            
            let aiData = try JSONDecoder().decode(AIResponse.self, from: jsonData)
            return (aiData.reply, aiData.emoji_keyword)
            
        } catch {
            LogManager.shared.log("AI 请求或解析出错: \(error.localizedDescription)", level: .error)
            throw error
        }
    }
}
