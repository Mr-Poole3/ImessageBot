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
            ),
            Tool(
                type: "function",
                function: Tool.Function(
                    name: "create_calendar_event",
                    description: "创建系统日历日程。当用户需要设置提醒、安排会议或记录日程时使用。请解析出具体的日期时间。",
                    parameters: Tool.Parameters(
                        type: "object",
                        properties: [
                            "title": Tool.Property(
                                type: "string",
                                description: "日程标题/内容",
                                enumValues: nil
                            ),
                            "start_time": Tool.Property(
                                type: "string",
                                description: "开始时间，格式必须为 yyyy-MM-dd HH:mm:ss，例如 2024-02-01 14:00:00",
                                enumValues: nil
                            ),
                            "end_time": Tool.Property(
                                type: "string",
                                description: "结束时间，格式同上（可选，默认1小时）",
                                enumValues: nil
                            ),
                            "notes": Tool.Property(
                                type: "string",
                                description: "备注信息（可选）",
                                enumValues: nil
                            )
                        ],
                        required: ["title", "start_time"]
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
        case "create_calendar_event":
            if let title = arguments["title"] as? String,
               let startTimeStr = arguments["start_time"] as? String {
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX") // Ensure fixed format
                
                guard let startDate = formatter.date(from: startTimeStr) else {
                    return "日期解析失败，请确保格式为 yyyy-MM-dd HH:mm:ss"
                }
                
                var endDate: Date? = nil
                if let endTimeStr = arguments["end_time"] as? String {
                    endDate = formatter.date(from: endTimeStr)
                }
                
                let notes = arguments["notes"] as? String
                
                return await CalendarService.shared.createEvent(title: title, startDate: startDate, endDate: endDate, notes: notes)
            }
            return "参数错误: 缺少 title 或 start_time"
        default:
            return "未知工具: \(name)"
        }
    }
}
