import Combine
import Foundation
import WatchConnectivity

// MARK: - Message Types

private enum WCMessageType: String {
    case sessionStart
    case scoreState
    case matchEnd
    case matchSave
    case matchSaveResult
    case metrics
    case workoutEnd
    case sessionCleared
    case matchReset
}

// MARK: - Service

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isWatchReachable: Bool = false
    @Published var receivedSessionStart: SessionStartMessage?
    @Published var receivedScoreState: ScoreState?
    @Published var receivedMatchEnd: MatchEndMessage?
    @Published var receivedMatchSave: MatchEndMessage?
    @Published var receivedMatchSaveResult: MatchSaveResultMessage?
    @Published var receivedMetrics: WorkoutMetrics?
    @Published var receivedWorkoutEnd: UUID?
    @Published var receivedMatchReset: UUID?

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSessionStart(_ msg: SessionStartMessage) {
        send(msg.toDictionary())
    }

    func sendScoreState(_ state: ScoreState) {
        sendReliably(state.toDictionary())
    }

    func sendMatchEnd(_ msg: MatchEndMessage) {
        sendReliably(msg.toDictionary())
    }

    /// 저장 버튼 전용. iOS가 이 메시지를 받을 때만 히스토리에 persist 한다.
    func sendMatchSave(_ msg: MatchEndMessage) {
        sendReliably(msg.toSaveDictionary())
    }

    /// iOS가 저장 요청을 처리한 뒤 실제 persist 성공/실패를 Watch에 회신한다.
    func sendMatchSaveResult(_ msg: MatchSaveResultMessage) {
        sendReliably(msg.toDictionary())
    }

    static let workoutEndStalenessThreshold: TimeInterval = 60

    /// transferUserInfo로 큐잉돼 앱 재실행 후 뒤늦게 배달된 stale 종료 신호를 거른다.
    /// sentAt이 없으면(구버전 메시지) 기존 동작 보존을 위해 stale로 보지 않는다.
    static func isWorkoutEndStale(sentAt: Double?, now: Double = Date().timeIntervalSince1970) -> Bool {
        guard let sentAt else { return false }
        return now - sentAt > workoutEndStalenessThreshold
    }

    /// applicationContext는 마지막 값을 계속 보관하므로, 운동 종료 시 비우지 못한 채(워치 크래시 등)
    /// 한참 뒤 콜드 런치하면 죽은 세션을 채택할 수 있다. workoutStartDate가 비현실적으로
    /// 오래된 sessionStart는 콜드 런치 채택에서 제외한다. (정상 종료는 clearSessionContext가 비운다)
    static let sessionStartStalenessThreshold: TimeInterval = 6 * 3600

    static func isSessionStartStale(workoutStartDate: Double?, now: Double = Date().timeIntervalSince1970) -> Bool {
        guard let workoutStartDate else { return false }
        return now - workoutStartDate > sessionStartStalenessThreshold
    }

    /// 드라이버가 운동/매치를 끝낼 때 자기 outgoing applicationContext를 비운다.
    /// 그래야 상대가 콜드 런치할 때 끝난 세션의 sessionStart를 읽어 잘못 진입하지 않는다.
    func clearSessionContext() {
        guard WCSession.default.activationState == .activated else { return }
        #if os(iOS)
            guard WCSession.default.isWatchAppInstalled else { return }
        #endif
        try? WCSession.default.updateApplicationContext(["type": WCMessageType.sessionCleared.rawValue])
    }

    private func sendReliably(_ dict: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(dict)
        }
    }

    func sendMetrics(_ metrics: WorkoutMetrics) {
        sendRealtimeOnly(metrics.toDictionary())
    }

    func sendWorkoutEnd(sessionId: UUID) {
        sendReliably([
            "type": WCMessageType.workoutEnd.rawValue,
            "sessionId": sessionId.uuidString,
            "sentAt": Date().timeIntervalSince1970,
        ])
    }

    /// 드라이버가 진행 중 매치를 중간에 버릴 때(뒤로가기) 미러도 모드선택으로 돌아가도록 알린다.
    func sendMatchReset(sessionId: UUID) {
        sendReliably([
            "type": WCMessageType.matchReset.rawValue,
            "sessionId": sessionId.uuidString,
        ])
    }

    private func sendRealtimeOnly(_ dict: [String: Any]) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        #if os(iOS)
            guard WCSession.default.isWatchAppInstalled else { return }
        #endif
        WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
    }

    private func send(_ dict: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        #if os(iOS)
            guard WCSession.default.isWatchAppInstalled else { return }
        #endif
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(dict)
        }
    }

    private func handle(_ message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case WCMessageType.sessionStart.rawValue:
                self.receivedSessionStart = SessionStartMessage(from: message)
            case WCMessageType.scoreState.rawValue:
                self.receivedScoreState = ScoreState(from: message)
            case WCMessageType.matchEnd.rawValue:
                self.receivedMatchEnd = MatchEndMessage(from: message)
            case WCMessageType.matchSave.rawValue:
                self.receivedMatchSave = MatchEndMessage(from: message)
            case WCMessageType.matchSaveResult.rawValue:
                self.receivedMatchSaveResult = MatchSaveResultMessage(from: message)
            case WCMessageType.metrics.rawValue:
                self.receivedMetrics = WorkoutMetrics(from: message)
            case WCMessageType.workoutEnd.rawValue:
                if Self.isWorkoutEndStale(sentAt: message["sentAt"] as? Double) { break }
                if let idStr = message["sessionId"] as? String, let id = UUID(uuidString: idStr) {
                    self.receivedWorkoutEnd = id
                }
            case WCMessageType.matchReset.rawValue:
                if let idStr = message["sessionId"] as? String, let id = UUID(uuidString: idStr) {
                    self.receivedMatchReset = id
                }
            default:
                break
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }

        // 콜드 런치 함정: 앱이 꺼져 있는 동안 updateApplicationContext로 도착한 값은
        // didReceiveApplicationContext 델리게이트가 불리지 않고 receivedApplicationContext에만 남는다.
        // 활성화 직후 직접 읽어 대기 중이던 sessionStart를 채택한다.
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        if context["type"] as? String == WCMessageType.sessionStart.rawValue,
           Self.isSessionStartStale(workoutStartDate: context["workoutStartDate"] as? Double)
        {
            return
        }
        handle(context)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    #if os(iOS)
        func sessionDidBecomeInactive(_: WCSession) {}
        func sessionDidDeactivate(_: WCSession) {
            WCSession.default.activate()
        }
    #endif
}
