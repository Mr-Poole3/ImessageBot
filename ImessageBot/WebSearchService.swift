import Foundation

struct WebSearchService {
    struct SearchResponse: Codable {
        let results: [SearchResult]?
        // Error fields
        let code: String?
        let message: String?
        
        struct SearchResult: Codable {
            let title: String
            let url: String
            let snippet: String
            let source: String?
            let publish_time: String?
        }
    }
    
    struct SearchRequest: Codable {
        let query: String
        let site: String?
        let filetype: String?
        let fetch_full: Bool
        let timeout_ms: Int
        let sort: String?
        let time_range: String?
        
        init(query: String, site: String? = nil, filetype: String? = nil, fetch_full: Bool = false, timeout_ms: Int = 5000, sort: String? = nil, time_range: String? = nil) {
            self.query = query
            self.site = site
            self.filetype = filetype
            self.fetch_full = fetch_full
            self.timeout_ms = timeout_ms
            self.sort = sort
            self.time_range = time_range
        }
    }
    
    static func search(query: String) async -> String {
        guard let url = URL(string: "https://uapis.cn/api/v1/search/aggregate") else {
            return "搜索失败：无效的 API 地址"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SearchRequest(query: query)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            LogManager.shared.log("正在调用 Web Search API: \(query)...")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Log raw response for debugging
            if let responseStr = String(data: data, encoding: .utf8) {
                 LogManager.shared.log("API 原始响应: \(responseStr)")
            }
            
            let response = try JSONDecoder().decode(SearchResponse.self, from: data)
            
            // Check for error response
            if let errorCode = response.code {
                let msg = response.message ?? "未知错误"
                return "搜索失败: \(errorCode) - \(msg)"
            }
            
            guard let results = response.results, !results.isEmpty else {
                return "未找到相关搜索结果。"
            }
            
            // Format results
            var output = "找到以下搜索结果：\n"
            for (index, result) in results.prefix(5).enumerated() {
                output += "\(index + 1). [\(result.title)](\(result.url))\n"
                output += "   \(result.snippet.prefix(100))...\n"
                if let time = result.publish_time {
                     output += "   (发布时间: \(time))\n"
                }
            }
            
            return output
            
        } catch {
            LogManager.shared.log("Web Search API 出错: \(error.localizedDescription)", level: .error)
            if let responseStr = String(data: (try? JSONEncoder().encode(requestBody)) ?? Data(), encoding: .utf8) {
                 LogManager.shared.log("Request Body: \(responseStr)", level: .error)
            }
            return "搜索出错: \(error.localizedDescription)"
        }
    }
}
