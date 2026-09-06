import Combine
import ConnectivityCore
import Foundation

/// `ConnectivityService` 위의 얇은 SwiftUI 래퍼. 코어는 콜백만 주므로 `@Published` 로 되살린다
/// (YJKit README — 테니스 `MatchConnectivity` 와 같은 패턴).
///
/// **`init` 안에서 모든 `onReceive` 등록을 마친다.** 서비스를 만든 main-queue turn 을 넘기면
/// 콜드런치 시 먼저 도착한 배달을 놓친다.
@MainActor
final class HaruchiFitConnectivity: ObservableObject {
    @Published private(set) var receivedRecord: WorkoutRecordMessage?

    private let service: ConnectivityService

    init(service: ConnectivityService) {
        self.service = service
        service.onReceive(WorkoutRecordMessage.self) { [weak self] message in
            self?.receivedRecord = message
        }
    }
}
