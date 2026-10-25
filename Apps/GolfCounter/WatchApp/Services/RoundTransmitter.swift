import ConnectivityCore
import Foundation

/// 완료 라운드 발신. ViewModel이 WatchConnectivity를 직접 모르게 프로토콜 뒤에 둔다
/// (`RoundSnapshotPublishing`과 같은 방식, spec §7).
protocol RoundTransmitting {
    func send(_ message: RoundCompletedMessage)
}

struct RoundTransmitter: RoundTransmitting {
    private let service: ConnectivityService

    init(service: ConnectivityService = ConnectivityService()) {
        self.service = service
    }

    /// `.queued`는 항상 transferUserInfo로 보내 시스템이 배달을 보장한다 — 워치 쪽 재시도
    /// 로직은 만들지 않는다 (spec §7). `.reliable`은 폰이 근처에 있으면 sendMessage를 쓰는데
    /// 실패해도 다시 보내지 않아 기록이 사라진다.
    func send(_ message: RoundCompletedMessage) {
        service.send(message, via: .queued)
    }
}
