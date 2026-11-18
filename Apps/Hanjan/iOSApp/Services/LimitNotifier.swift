import Foundation
import UserNotifications

struct LimitNotifier {
    func notify(_ level: LimitLevel) {
        let message: String
        switch level {
        case .warning: message = "한도의 80%입니다. 천천히 드세요."
        case .reached: message = "오늘 한도에 도달했습니다."
        default: return
        }
        let content = UNMutableNotificationContent()
        content.body = message
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
