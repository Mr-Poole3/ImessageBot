import Foundation
import EventKit

class CalendarService {
    static let shared = CalendarService()
    private let eventStore = EKEventStore()
    
    // Check and request permission
    private func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
    }
    
    func createEvent(title: String, startDate: Date, endDate: Date? = nil, notes: String? = nil) async -> String {
        do {
            let granted = try await requestAccess()
            guard granted else {
                return "创建失败：未获得日历访问权限。请在系统设置中允许应用访问日历。"
            }
            
            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.startDate = startDate
            event.endDate = endDate ?? startDate.addingTimeInterval(3600) // Default to 1 hour
            event.notes = notes
            event.calendar = eventStore.defaultCalendarForNewEvents
            
            try eventStore.save(event, span: .thisEvent)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let timeStr = formatter.string(from: startDate)
            
            return "成功创建日历事项：\(title) 于 \(timeStr)"
            
        } catch {
            LogManager.shared.log("Calendar Error: \(error.localizedDescription)", level: .error)
            return "创建日历出错: \(error.localizedDescription)"
        }
    }
}
