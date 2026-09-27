import Combine
import Foundation

/// 실패를 한 곳에 모은다. 워치 저장·동기화·삭제가 각자 알림을 띄우면 겹쳐 뜬다.
@MainActor
final class AppAlertCenter: ObservableObject {
    @Published var current: AppAlert?

    /// **떠 있는 알림을 덮지 않는다** — 연달아 실패해도 한 장만 보인다.
    func report(_ alert: AppAlert) {
        guard current == nil else { return }
        current = alert
    }
}
