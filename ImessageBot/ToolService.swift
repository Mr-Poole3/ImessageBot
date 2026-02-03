import Foundation

// MARK: - Tool Definitions

struct Tool: Codable {
    let type: String
    let function: Function
    
    struct Function: Codable {
        let name: String
        let description: String
        let parameters: Parameters
    }
    
    struct Parameters: Codable {
        let type: String
        let properties: [String: Property]
        let required: [String]
    }
    
    struct Property: Codable {
        let type: String
        let description: String
        let enumValues: [String]?
        
        enum CodingKeys: String, CodingKey {
            case type, description
            case enumValues = "enum"
        }
    }
}

// MARK: - Tool Service

class ToolService {
    static let shared = ToolService()
    
    // Define available tools
    var availableTools: [Tool] {
        return [
            Tool(
                type: "function",
                function: Tool.Function(
                    name: "get_weather",
                    description: "查询指定城市的天气情况。当用户询问天气、气温、下雨吗等问题时使用此工具。",
                    parameters: Tool.Parameters(
                        type: "object",
                        properties: [
                            "city": Tool.Property(
                                type: "string",
                                description: "城市名称，例如：北京、上海、深圳",
                                enumValues: nil
                            )
                        ],
                        required: ["city"]
                    )
                )
            ),
            Tool(
                type: "function",
                function: Tool.Function(
                    name: "web_search",
                    description: "使用搜索引擎查询互联网上的实时信息。当用户询问最新新闻、技术文档、版本号或其他需要实时检索的问题时使用。",
                    parameters: Tool.Parameters(
                        type: "object",
                        properties: [
                            "query": Tool.Property(
                                type: "string",
                                description: "搜索关键词",
                                enumValues: nil
                            )
                        ],
                        required: ["query"]
                    )
                )
            )
        ]
    }
    
    // Execute tool by name
    func executeTool(name: String, arguments: [String: Any]) async -> String {
        switch name {
        case "get_weather":
            if let city = arguments["city"] as? String {
                return await WeatherService.getWeather(city: city)
            }
            return "参数错误: 缺少 city"
        case "web_search":
            if let query = arguments["query"] as? String {
                return await WebSearchService.search(query: query)
            }
            return "参数错误: 缺少 query"
        default:
            return "未知工具: \(name)"
        }
    }
}
