import Combine
import ConnectivityCore
import Foundation

/// ConnectivityCore 위의 앱 레이어. 코어의 1회성 핸들러 배달을 기존 sticky @Published 시맨틱으로
/// 복원하고(소비자가 nil 대입으로 소비), 테니스 메시지별 send/receive 표면을 제공한다.
/// init에서 모든 onReceive 등록을 마치므로 콜드런치 컨텍스트 배달 제약(같은 main turn 등록)을 만족한다.
final class MatchConnectivity: ObservableObject {
    static let shared = MatchConnectivity(service: ConnectivityService())

    @Published var isWatchReachable: Bool = false
    @Published var receivedSessionStart: SessionStartMessage?
    @Published var receivedScoreState: ScoreState?
    @Published var receivedMatchEnd: MatchEndMessage?
    @Published var receivedMatchSave: MatchEndMessage?
    @Published var receivedMatchSaveResult: MatchSaveResultMessage?
    @Published var receivedMetrics: WorkoutMetrics?
    @Published var receivedWorkoutEnd: UUID?
    @Published var receivedMatchReset: UUID?

    private let service: ConnectivityService

    private init(service: ConnectivityService) {
        self.service = service

        service.$isCounterpartReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWatchReachable)

        service.onReceive(SessionStartMessage.self) { [weak self] msg in
            // 죽은 세션 채택 방지: workoutStartDate가 비현실적으로 오래된 sessionStart는 버린다.
            // (기존에는 콜드런치 컨텍스트 읽기에서만 걸렀으나 모든 수신 경로로 일반화)
            guard !Self.isSessionStartStale(workoutStartDate: msg.workoutStartDate.timeIntervalSince1970) else { return }
            self?.receivedSessionStart = msg
        }
        service.onReceive(ScoreState.self) { [weak self] in self?.receivedScoreState = $0 }
        service.onReceive(MatchEndMessage.self) { [weak self] in self?.receivedMatchEnd = $0 }
        service.onReceive(MatchSaveMessage.self) { [weak self] in self?.receivedMatchSave = $0.base }
        service.onReceive(MatchSaveResultMessage.self) { [weak self] in self?.receivedMatchSaveResult = $0 }
        service.onReceive(WorkoutMetrics.self) { [weak self] in self?.receivedMetrics = $0 }
        service.onReceive(WorkoutEndMessage.self, maxAge: Self.workoutEndStalenessThreshold) { [weak self] in
            self?.receivedWorkoutEnd = $0.sessionId
        }
        service.onReceive(MatchResetMessage.self) { [weak self] in self?.receivedMatchReset = $0.sessionId }
    }

    // MARK: - Send

    func sendSessionStart(_ msg: SessionStartMessage) {
        service.send(msg, via: .context)
    }

    func sendScoreState(_ state: ScoreState) {
        service.send(state, via: .reliable)
    }

    func sendMatchEnd(_ msg: MatchEndMessage) {
        service.send(msg, via: .reliable)
    }

    /// 저장 버튼 전용. iOS가 이 메시지를 받을 때만 히스토리에 persist 한다.
    func sendMatchSave(_ msg: MatchEndMessage) {
        service.send(MatchSaveMessage(base: msg), via: .reliable)
    }

    /// iOS가 저장 요청을 처리한 뒤 실제 persist 성공/실패를 Watch에 회신한다.
    func sendMatchSaveResult(_ msg: MatchSaveResultMessage) {
        service.send(msg, via: .reliable)
    }

    func sendMetrics(_ metrics: WorkoutMetrics) {
        service.send(metrics, via: .realtimeOnly)
    }

    func sendWorkoutEnd(sessionId: UUID) {
        service.send(WorkoutEndMessage(sessionId: sessionId), via: .reliable)
    }

    func sendMatchReset(sessionId: UUID) {
        service.send(MatchResetMessage(sessionId: sessionId), via: .reliable)
    }

    func clearSessionContext() {
        service.clearSessionContext()
    }

    // MARK: - Staleness (구 폰↔워치 통신 서비스에서 이동)

    static let workoutEndStalenessThreshold: TimeInterval = 60

    /// applicationContext는 마지막 값을 계속 보관하므로, 운동 종료 시 비우지 못한 채(워치 크래시 등)
    /// 한참 뒤 수신하면 죽은 세션을 채택할 수 있다. workoutStartDate가 비현실적으로 오래된
    /// sessionStart는 채택에서 제외한다. (정상 종료는 clearSessionContext가 비운다)
    static let sessionStartStalenessThreshold: TimeInterval = 6 * 3600

    static func isSessionStartStale(workoutStartDate: Double?, now: Double = Date().timeIntervalSince1970) -> Bool {
        guard let workoutStartDate else { return false }
        return now - workoutStartDate > sessionStartStalenessThreshold
    }
}
