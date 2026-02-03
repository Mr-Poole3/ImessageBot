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
                let content: String?
                let tool_calls: [ToolCall]?
                let role: String
            }
            let message: Message
            let finish_reason: String?
        }
        let choices: [Choice]
    }
    
    // Define structure for Ollama native API response
    struct OllamaAPIResponse: Codable {
        struct Message: Codable {
            let role: String
            let content: String?
            let tool_calls: [ToolCall]?
        }
        let model: String
        let created_at: String
        let message: Message
        let done: Bool
    }
    
    // Common structure for tool calls (OpenAI & Ollama compatible)
    struct ToolCall: Codable {
        let id: String? // Ollama might skip ID, OpenAI has it
        let type: String? // Ollama might skip type, OpenAI has it
        let function: FunctionCall
        
        // Custom decoding to handle missing type
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            function = try container.decode(FunctionCall.self, forKey: .function)
            
            // Try to decode type, default to "function" if missing
            if let typeStr = try? container.decode(String.self, forKey: .type) {
                type = typeStr
            } else {
                type = "function"
            }
        }
        
        // Manual encoding to ensure structure is preserved
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(type ?? "function", forKey: .type)
            try container.encode(function, forKey: .function)
        }
        
        enum CodingKeys: String, CodingKey {
            case id, type, function
        }
        
        struct FunctionCall: Codable {
            let name: String
            let arguments: String // JSON string or Dictionary
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decode(String.self, forKey: .name)
                
                // Try to decode arguments as String (OpenAI style)
                if let argsString = try? container.decode(String.self, forKey: .arguments) {
                    arguments = argsString
                } 
                // Try to decode arguments as Dictionary and convert to JSON String (Ollama style)
                else if let argsDict = try? container.decode([String: AnyCodable].self, forKey: .arguments) {
                    let jsonData = try JSONEncoder().encode(argsDict)
                    arguments = String(data: jsonData, encoding: .utf8) ?? "{}"
                } else {
                    arguments = "{}"
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case name, arguments
            }
        }
    }
    
    // Helper struct for decoding Any in Codable
    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intVal = try? container.decode(Int.self) {
                value = intVal
            } else if let doubleVal = try? container.decode(Double.self) {
                value = doubleVal
            } else if let stringVal = try? container.decode(String.self) {
                value = stringVal
            } else if let boolVal = try? container.decode(Bool.self) {
                value = boolVal
            } else if let arrayVal = try? container.decode([AnyCodable].self) {
                value = arrayVal.map { $0.value }
            } else if let dictVal = try? container.decode([String: AnyCodable].self) {
                value = dictVal.mapValues { $0.value }
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let intVal = value as? Int {
                try container.encode(intVal)
            } else if let doubleVal = value as? Double {
                try container.encode(doubleVal)
            } else if let stringVal = value as? String {
                try container.encode(stringVal)
            } else if let boolVal = value as? Bool {
                try container.encode(boolVal)
            } else if let arrayVal = value as? [Any] {
                try container.encode(arrayVal.map { AnyCodable($0) })
            } else if let dictVal = value as? [String: Any] {
                try container.encode(dictVal.mapValues { AnyCodable($0) })
            } else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
            }
        }
    }

    // Define a common structure for API response since many providers use OpenAI-compatible format
    // Removed duplicate ChatCompletion definition
    
    static func getResponse(input: String, history: [DatabaseService.ChatMessage] = [], config: AppConfig) async throws -> (String, String) {
        // Initial request
        let (responseContent, toolCalls) = try await getRawResponse(input: input, history: history, config: config)
        
        // If there are tool calls, execute them and recursively call AI
        if let toolCalls = toolCalls, !toolCalls.isEmpty {
            LogManager.shared.log("AI 请求调用工具: \(toolCalls.count) 个")
            
            // Add the assistant's tool call message to history
            // Note: We need a way to represent tool calls in our simple ChatMessage struct or manage a separate conversation context for this turn
            // For simplicity in this recursion, we will rebuild the messages array in the next request
            
            var conversationMessages = buildMessages(history: history, input: input, systemPrompt: config.userSystemPrompt + config.formatInstruction)
            
            // Append assistant's message with tool_calls
            var assistantMsg: [String: Any] = ["role": "assistant"]
            if let content = responseContent {
                assistantMsg["content"] = content
            }
            let toolCallsWithId = toolCalls.map { toolCall -> (ToolCall, String) in
                let toolCallId = toolCall.id ?? "call_\(UUID().uuidString)"
                return (toolCall, toolCallId)
            }
            let toolCallsDict = toolCallsWithId.map { pair -> [String: Any] in
                let toolCall = pair.0
                let toolCallId = pair.1
                
                let adapter = AdapterFactory.getAdapter(for: config.selectedProvider)
                let arguments = adapter.formatToolArgumentsForHistory(toolCall.function.arguments)
                
                return [
                    "id": toolCallId,
                    "type": "function",
                    "function": [
                        "name": toolCall.function.name,
                        "arguments": arguments
                    ]
                ]
            }
            assistantMsg["tool_calls"] = toolCallsDict
            conversationMessages.append(assistantMsg)
            
            // Execute tools
            for pair in toolCallsWithId {
                let toolCall = pair.0
                let toolCallId = pair.1
                let functionName = toolCall.function.name
                let argsString = toolCall.function.arguments
                
                LogManager.shared.log("执行工具: \(functionName)")
                
                var toolResult = "工具执行失败"
                if let data = argsString.data(using: .utf8),
                   let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    toolResult = await ToolService.shared.executeTool(name: functionName, arguments: args)
                } else {
                    LogManager.shared.log("工具参数解析失败: \(argsString)", level: .error)
                }
                
                LogManager.shared.log("工具结果: \(toolResult)")
                
                // Append tool result message
                conversationMessages.append([
                    "role": "tool",
                    "tool_call_id": toolCallId,
                    "name": functionName,
                    "content": toolResult
                ])
            }
            
            // Second request with tool results
            return try await makeFollowUpRequest(messages: conversationMessages, config: config)
        }
        
        // No tool calls, standard response
        return try parseAIResponse(content: responseContent ?? "")
    }
    
    private static func getRawResponse(input: String, history: [DatabaseService.ChatMessage], config: AppConfig) async throws -> (String?, [ToolCall]?) {
        // Unified request handling using Adapter
        var baseUrl: String
        switch config.selectedProvider {
        case .volcengine:
            baseUrl = formatBaseURL(config.volcengineBaseURL)
        case .openai:
            baseUrl = formatBaseURL(config.openaiBaseURL)
        case .ollama:
            baseUrl = formatOllamaURL(config.ollamaBaseURL)
        }
        
        // Get model and API key
        let model: String
        let apiKey: String
        switch config.selectedProvider {
        case .volcengine:
            model = config.volcengineModel
            apiKey = config.volcengineApiKey
        case .openai:
            model = config.openaiModel
            apiKey = config.openaiApiKey
        case .ollama:
            model = config.ollamaModel
            apiKey = "ollama" // Or user provided key if any
        }
        
        let fullSystemPrompt = config.userSystemPrompt + config.formatInstruction
        let messages = buildMessages(history: history, input: input, systemPrompt: fullSystemPrompt)
        let anyMessages = messages.map { $0 as [String: Any] }
        
        return try await makeGenericRequestRaw(
            url: URL(string: baseUrl)!,
            apiKey: apiKey,
            model: model,
            messages: anyMessages,
            config: config,
            useTools: true
        )
    }
    
    // Helper to format Base URL
    private static func formatBaseURL(_ url: String) -> String {
        var u = url
        if u.hasSuffix("/") { u.removeLast() }
        if !u.hasSuffix("/chat/completions") { u += "/chat/completions" }
        return u
    }
    
    private static func formatOllamaURL(_ url: String) -> String {
        var u = url
        if u.hasSuffix("/") { u.removeLast() }
        if !u.contains("/api") && !u.contains("/v1") { u += "/api/chat" }
        return u
    }

    // ... (Existing helper methods like buildMessages) ...

    
    private static func getVolcengineResponse(input: String, history: [DatabaseService.ChatMessage], config: AppConfig) async throws -> (String, String) {
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
        
        return try await makeGenericRequest(
            url: url,
            apiKey: config.volcengineApiKey,
            model: config.volcengineModel,
            messages: buildMessages(history: history, input: input, systemPrompt: config.userSystemPrompt + config.formatInstruction),
            config: config,
            useTools: false
        )
    }
    
    private static func getOpenAIResponse(input: String, history: [DatabaseService.ChatMessage], config: AppConfig) async throws -> (String, String) {
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
        
        return try await makeGenericRequest(
            url: url,
            apiKey: config.openaiApiKey,
            model: config.openaiModel,
            messages: buildMessages(history: history, input: input, systemPrompt: config.userSystemPrompt + config.formatInstruction),
            config: config,
            useTools: false
        )
    }
    
    private static func getOllamaResponse(input: String, history: [DatabaseService.ChatMessage], config: AppConfig) async throws -> (String, String) {
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
        
        return try await makeOllamaGenericRequest(
            url: url,
            model: config.ollamaModel,
            messages: buildMessages(history: history, input: input, systemPrompt: config.userSystemPrompt + config.formatInstruction),
            config: config,
            useTools: false
        )
    }
    
    private static func buildMessages(history: [DatabaseService.ChatMessage], input: String, systemPrompt: String) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        
        // Inject current time into system prompt
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let currentTime = formatter.string(from: Date())
        let systemPromptWithTime = "\(systemPrompt)\n\nCurrent Time: \(currentTime)"
        
        messages.append(["role": "system", "content": systemPromptWithTime])
        
        for msg in history {
            messages.append([
                "role": msg.isFromMe ? "assistant" : "user",
                "content": msg.text
            ])
        }
        
        messages.append(["role": "user", "content": input])
        return messages
    }
    
    // Helper to extract JSON AIResponse from content string
    private static func parseAIResponse(content: String) throws -> (String, String) {
        var cleanContent = content
        if cleanContent.contains("```json") {
            cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        }
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw NSError(domain: "AIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert content to data"])
        }
        
        do {
            let aiData = try JSONDecoder().decode(AIResponse.self, from: jsonData)
            return (aiData.reply, aiData.emoji_keyword)
        } catch {
            LogManager.shared.log("AI 响应 JSON 解析失败，原文: \(content)", level: .error)
            throw error
        }
    }
    
    private static func makeFollowUpRequest(messages: [[String: Any]], config: AppConfig) async throws -> (String, String) {
        // This method handles the second call to the LLM after tools have been executed.
        // It needs to handle provider-specific logic similar to makeRequest/makeOllamaRequest
        // For simplicity, we'll route to the correct provider handler again but with pre-built messages
        
        switch config.selectedProvider {
        case .volcengine:
            return try await makeGenericRequest(
                url: URL(string: formatBaseURL(config.volcengineBaseURL))!,
                apiKey: config.volcengineApiKey,
                model: config.volcengineModel,
                messages: messages,
                config: config,
                useTools: false // Prevent infinite tool loops for now
            )
        case .openai:
            return try await makeGenericRequest(
                url: URL(string: formatBaseURL(config.openaiBaseURL))!,
                apiKey: config.openaiApiKey,
                model: config.openaiModel,
                messages: messages,
                config: config,
                useTools: false
            )
        case .ollama:
            return try await makeOllamaGenericRequest(
                url: URL(string: formatOllamaURL(config.ollamaBaseURL))!,
                model: config.ollamaModel,
                messages: messages,
                config: config,
                useTools: false
            )
        }
    }
    
    private static func makeOllamaRequest(url: URL, model: String, input: String, history: [DatabaseService.ChatMessage], config: AppConfig, useTools: Bool) async throws -> (String?, [ToolCall]?) {
        let fullSystemPrompt = config.userSystemPrompt + config.formatInstruction
        let messages = buildMessages(history: history, input: input, systemPrompt: fullSystemPrompt)
        
        // Convert [[String:String]] to [[String:Any]] for compatibility
        let anyMessages = messages.map { $0 as [String: Any] }
        
        return try await makeOllamaGenericRequestRaw(url: url, model: model, messages: anyMessages, config: config, useTools: useTools)
    }
    
    private static func makeOllamaGenericRequest(url: URL, model: String, messages: [[String: Any]], config: AppConfig, useTools: Bool) async throws -> (String, String) {
        let (content, _) = try await makeOllamaGenericRequestRaw(url: url, model: model, messages: messages, config: config, useTools: useTools)
        return try parseAIResponse(content: content ?? "")
    }
    
    private static func makeOllamaGenericRequestRaw(url: URL, model: String, messages: [[String: Any]], config: AppConfig, useTools: Bool) async throws -> (String?, [ToolCall]?) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600 // 10 minutes timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer ollama", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "format": "json" // Ollama native format
        ]
        
        if useTools {
            // Ollama tools format
            let tools = ToolService.shared.availableTools.map { tool -> [String: Any] in
                return [
                    "type": "function",
                    "function": [
                        "name": tool.function.name,
                        "description": tool.function.description,
                        "parameters": [
                            "type": tool.function.parameters.type,
                            "properties": tool.function.parameters.properties.mapValues { prop in
                                var dict: [String: Any] = [
                                    "type": prop.type,
                                    "description": prop.description
                                ]
                                if let enums = prop.enumValues {
                                    dict["enum"] = enums
                                }
                                return dict
                            },
                            "required": tool.function.parameters.required
                        ]
                    ]
                ]
            }
            body["tools"] = tools
            // Ollama might not support "format": "json" AND "tools" simultaneously in some versions, check compatibility
            // For safety, when using tools, we might need to remove "format": "json" and rely on prompt engineering for JSON output in the final turn
            // But let's try keeping it for now or removing it if it causes issues.
            body.removeValue(forKey: "format") 
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                LogManager.shared.log("Ollama API Error: \(httpResponse.statusCode) - \(errorBody)", level: .error)
                throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
            }
            
            // Log raw response for debugging
            if let responseStr = String(data: data, encoding: .utf8) {
                 // LogManager.shared.log("Ollama Raw Response: \(responseStr)")
            }
            
            do {
                let completion = try JSONDecoder().decode(OllamaAPIResponse.self, from: data)
                return (completion.message.content, completion.message.tool_calls)
            } catch {
                 LogManager.shared.log("Ollama Decoding Error: \(error). Data: \(String(data: data, encoding: .utf8) ?? "nil")", level: .error)
                 throw error
            }
            
        } catch {
            LogManager.shared.log("Ollama Request Error: \(error.localizedDescription)", level: .error)
            throw error
        }
    }

    private static func makeRequest(url: URL, apiKey: String, model: String, input: String, history: [DatabaseService.ChatMessage], config: AppConfig, useTools: Bool) async throws -> (String?, [ToolCall]?) {
        let fullSystemPrompt = config.userSystemPrompt + config.formatInstruction
        let messages = buildMessages(history: history, input: input, systemPrompt: fullSystemPrompt)
        
        // Convert to [String: Any]
        let anyMessages = messages.map { $0 as [String: Any] }
        
        return try await makeGenericRequestRaw(url: url, apiKey: apiKey, model: model, messages: anyMessages, config: config, useTools: useTools)
    }
    
    private static func makeGenericRequest(url: URL, apiKey: String, model: String, messages: [[String: Any]], config: AppConfig, useTools: Bool) async throws -> (String, String) {
        let (content, _) = try await makeGenericRequestRaw(url: url, apiKey: apiKey, model: model, messages: messages, config: config, useTools: useTools)
        return try parseAIResponse(content: content ?? "")
    }
    
    private static func makeGenericRequestRaw(url: URL, apiKey: String, model: String, messages: [[String: Any]], config: AppConfig, useTools: Bool) async throws -> (String?, [ToolCall]?) {
        let adapter = AdapterFactory.getAdapter(for: config.selectedProvider)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let headers = adapter.headers(apiKey: apiKey)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let body = adapter.prepareRequestBody(model: model, messages: messages, tools: ToolService.shared.availableTools, useTools: useTools)
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                LogManager.shared.log("API Error: \(httpResponse.statusCode) - \(errorBody)", level: .error)
                throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
            }
            
            // Log raw response for debugging
            // if let responseStr = String(data: data, encoding: .utf8) {
                 // LogManager.shared.log("Raw Response: \(responseStr)")
            // }
            
            // Try to decode with standard structure first (most providers)
            // Or use provider specific decoding if needed (currently Ollama response structure is slightly different but we handle it via optional fields in ToolCall or separate struct)
            
            // Note: Ollama native response has 'message' field instead of 'choices'. 
            // We might need to abstract response parsing in Adapter too if they differ significantly.
            // For now, let's keep the existing logic of trying ChatCompletion then OllamaAPIResponse
            
            if config.selectedProvider == .ollama {
                 do {
                    let completion = try JSONDecoder().decode(OllamaAPIResponse.self, from: data)
                    return (completion.message.content, completion.message.tool_calls)
                 } catch {
                     // Fallback or log
                     LogManager.shared.log("Ollama Decoding Error: \(error)", level: .error)
                     throw error
                 }
            } else {
                let completion = try JSONDecoder().decode(ChatCompletion.self, from: data)
                let choice = completion.choices.first
                return (choice?.message.content, choice?.message.tool_calls)
            }
            
        } catch {
            LogManager.shared.log("Request Error: \(error.localizedDescription)", level: .error)
            throw error
        }
    }
}
