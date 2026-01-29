import Foundation
import Combine

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    private let maxLogs = 500
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let message: String
        let level: LogLevel
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: timestamp)
        }
    }
    
    enum LogLevel {
        case info, warning, error, success
        
        var colorName: String {
            switch self {
            case .info: return "secondary"
            case .warning: return "orange"
            case .error: return "red"
            case .success: return "green"
            }
        }
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        DispatchQueue.main.async {
            let entry = LogEntry(message: message, level: level)
            self.logs.insert(entry, at: 0)
            if self.logs.count > self.maxLogs {
                self.logs.removeLast()
            }
            print("[\(entry.formattedTime)] \(message)")
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}
