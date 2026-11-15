import Foundation
import UserNotifications

struct ReviewReminder {
    static func fireDate(endedAt: Date, calendar: Calendar = .current) -> Date {
        let earliest = endedAt.addingTimeInterval(6 * 3600)
        let day = calendar.startOfDay(for: earliest)
        let ten = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? earliest
        return ten >= earliest ? ten : (calendar.date(byAdding: .day, value: 1, to: ten) ?? ten)
    }

    func schedule(sessionId: UUID, endedAt: Date) {
        let content = UNMutableNotificationContent()
        content.title = "어제 어땠나요?"
        content.userInfo = ["sessionId": sessionId.uuidString]
        let date = Self.fireDate(endedAt: endedAt)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(identifier: "review.\(sessionId)", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}
