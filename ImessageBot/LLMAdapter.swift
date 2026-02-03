import Foundation

protocol LLMAdapter {
    /// Prepare HTTP headers
    func headers(apiKey: String) -> [String: String]
    
    /// Prepare request body
    func prepareRequestBody(model: String, messages: [[String: Any]], tools: [Tool], useTools: Bool) -> [String: Any]
    
    /// Format tool arguments for sending back to the API in the message history
    /// OpenAI expects JSON String; Ollama expects Dictionary (Object)
    func formatToolArgumentsForHistory(_ arguments: String) -> Any
}

class OpenAIAdapter: LLMAdapter {
    func headers(apiKey: String) -> [String: String] {
        return [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
    }
    
    func prepareRequestBody(model: String, messages: [[String: Any]], tools: [Tool], useTools: Bool) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        
        if useTools {
            body["tools"] = tools.map { tool in
                [
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
        } else {
            body["response_format"] = ["type": "json_object"]
        }
        
        return body
    }
    
    func formatToolArgumentsForHistory(_ arguments: String) -> Any {
        // OpenAI expects the arguments as a JSON string
        return arguments
    }
}

class OllamaAdapter: LLMAdapter {
    func headers(apiKey: String) -> [String: String] {
        // Ollama usually doesn't need a key, but we pass "ollama" or user provided key
        return [
            "Authorization": "Bearer \(apiKey.isEmpty ? "ollama" : apiKey)",
            "Content-Type": "application/json"
        ]
    }
    
    func prepareRequestBody(model: String, messages: [[String: Any]], tools: [Tool], useTools: Bool) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false
        ]
        
        if useTools {
            body["tools"] = tools.map { tool in
                [
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
            // Ollama compatibility: remove 'format' when using tools if necessary
            // or keep it if model supports it. Based on previous logic, we removed it.
        } else {
            body["format"] = "json"
        }
        
        return body
    }
    
    func formatToolArgumentsForHistory(_ arguments: String) -> Any {
        // Ollama expects the arguments as a Dictionary (Object)
        if let data = arguments.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        return arguments // Fallback
    }
}

class AdapterFactory {
    static func getAdapter(for provider: AIProvider) -> LLMAdapter {
        switch provider {
        case .openai, .volcengine:
            return OpenAIAdapter()
        case .ollama:
            return OllamaAdapter()
        }
    }
}
