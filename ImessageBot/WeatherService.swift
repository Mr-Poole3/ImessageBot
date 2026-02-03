import Foundation

struct WeatherService {
    struct WeatherResponse: Codable {
        let code: Int
        let msg: String
        let data: WeatherData?
        
        struct WeatherData: Codable {
            let adcode: String?
            let city: String?
            let weather: String?
            let temperature: String? // API returns String for temperature in some cases, or handle as Double/String flexible
            let wind_direction: String?
            let report_time: String?
            
            // Flexible decoding for temperature which might be int, double or string
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                adcode = try container.decodeIfPresent(String.self, forKey: .adcode)
                city = try container.decodeIfPresent(String.self, forKey: .city)
                weather = try container.decodeIfPresent(String.self, forKey: .weather)
                wind_direction = try container.decodeIfPresent(String.self, forKey: .wind_direction)
                report_time = try container.decodeIfPresent(String.self, forKey: .report_time)
                
                if let tempDouble = try? container.decode(Double.self, forKey: .temperature) {
                    temperature = String(tempDouble)
                } else if let tempString = try? container.decode(String.self, forKey: .temperature) {
                    temperature = tempString
                } else {
                    temperature = nil
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case adcode, city, weather, temperature, wind_direction, report_time
            }
        }
    }
    
    static func getWeather(city: String) async -> String {
        guard let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://uapis.cn/api/v1/misc/weather?city=\(encodedCity)") else {
            return "天气查询失败：无效的城市名称"
        }
        
        LogManager.shared.log("正在调用天气 API: \(city)...")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Try to decode generic structure first or just raw JSON parsing for flexibility
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let code = json["code"] as? Int, code != 200 {
                     let msg = json["msg"] as? String ?? "未知错误"
                     return "查询失败: \(msg)"
                }
                
                // Extract fields manually to be safe
                let city = json["city"] as? String ?? city
                let weather = json["weather"] as? String ?? "未知"
                let temp = json["temperature"] as? String ?? "\(json["temperature"] as? Double ?? 0)"
                let wind = json["wind_direction"] as? String ?? ""
                
                return "\(city)当前天气\(weather)，气温\(temp)℃，\(wind)"
            }
            
            return "天气数据解析失败"
            
        } catch {
            LogManager.shared.log("天气 API 请求出错: \(error.localizedDescription)", level: .error)
            return "查询出错: \(error.localizedDescription)"
        }
    }
}
