import ConnectivityCore
import Foundation

/// `ConnectivityService` 위의 얇은 수신 래퍼. 받은 기록을 **화면과 무관하게 즉시** 앱 루트로 넘긴다
/// (골프 `RoundReceiveService` 와 같은 구조). `@Published` 로 들고 있다가 뷰가 저장하게 하면
/// 백그라운드로 깨어난 앱에서 저장이 돌지 않고, 연달아 도착한 기록은 앞의 것이 덮여 사라진다.
///
/// **`init` 안에서 모든 `onReceive` 등록을 마친다.** 서비스를 만든 main-queue turn 을 넘기면
/// 콜드런치 시 먼저 도착한 배달을 놓친다.
@MainActor
final class HaruchiFitConnectivity {
    private let service: ConnectivityService

    init(service: ConnectivityService, onRecord: @escaping @MainActor (WorkoutRecordMessage) -> Void) {
        self.service = service
        service.onReceive(WorkoutRecordMessage.self) { message in
            onRecord(message)
        }
    }
}
