import Foundation

class EmojiService {
    static func getEmojiURL(keyword: String, apiKey: String) async -> URL? {
        guard !keyword.isEmpty else { return nil }
        
        var components = URLComponents(string: "https://api.yaohud.cn/api/v5/bqzhizuo")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "msg", value: keyword)
        ]
        
        guard let url = components.url else { return nil }
        
        do {
            LogManager.shared.log("搜索表情包关键词: \(keyword)")
            let (data, _) = try await URLSession.shared.data(from: url)
            struct EmojiResponse: Codable {
                struct Data: Codable {
                    let url: String
                }
                let code: Int
                let data: Data?
            }
            
            let result = try JSONDecoder().decode(EmojiResponse.self, from: data)
            if result.code == 200, let urlString = result.data?.url {
                return URL(string: urlString)
            }
        } catch {
            print("Emoji error: \(error)")
        }
        return nil
    }
    
    static func downloadEmoji(url: URL) async -> URL? {
        do {
            LogManager.shared.log("正在从 URL 下载表情包...")
            let (data, _) = try await URLSession.shared.data(from: url)
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension.isEmpty ? "jpg" : url.pathExtension)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Download error: \(error)")
            return nil
        }
    }
}
