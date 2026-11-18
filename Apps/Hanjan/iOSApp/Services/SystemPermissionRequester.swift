import CoreLocation
import Foundation
import UserNotifications

/// 알림·위치(사용 중) 권한을 시스템 창으로 묻는다.
/// 시스템 API 래퍼라 원래 `Shared/Services/` 자리지만 T5 소유 폴더 밖이라 기능 안에 둔다 (T9 에서 옮길 수 있다).
final class SystemPermissionRequester: NSObject, PermissionRequesting, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Bool, Never>?

    func requestNotifications() async -> Bool {
        await (try? UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 이미 정해진 권한이면 시스템 창 없이 바로 결과를 돌려준다.
    func requestLocation() async -> Bool {
        let status = manager.authorizationStatus
        guard status == .notDetermined else { return Self.isGranted(status) }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        // delegate 를 붙이는 순간에도 현재 상태(.notDetermined)로 한 번 불린다. 사용자가 답할 때까지 기다린다.
        guard status != .notDetermined else { return }
        Task { @MainActor in
            self.continuation?.resume(returning: Self.isGranted(status))
            self.continuation = nil
        }
    }

    nonisolated static func isGranted(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }
}
