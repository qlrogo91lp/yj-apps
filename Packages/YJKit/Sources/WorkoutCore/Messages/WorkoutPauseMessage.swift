import ConnectivityCore
import Foundation

/// 폰 → 워치 일시정지/재개 명령.
///
/// 폰에는 실제 워크아웃 세션이 없다 — 워치만 HKWorkoutSession을 소유한다. 따라서 폰의
/// pause 버튼은 상태를 직접 바꾸는 대신 이 명령을 보내고, 워치가 세션을 제어한 결과가
/// 다음 WorkoutMetricsMessage의 isPaused로 되돌아온다(ack).
public struct WorkoutPauseMessage: ConnectivityMessage {
    public static let messageType = "workoutPause"

    public let sessionId: UUID
    /// true면 일시정지, false면 재개.
    public let shouldPause: Bool

    public init(sessionId: UUID, shouldPause: Bool) {
        self.sessionId = sessionId
        self.shouldPause = shouldPause
    }

    public init?(from dictionary: [String: Any]) {
        guard let idString = dictionary["sessionId"] as? String,
              let id = UUID(uuidString: idString),
              let shouldPause = dictionary["shouldPause"] as? Bool else { return nil }
        sessionId = id
        self.shouldPause = shouldPause
    }

    public func toDictionary() -> [String: Any] {
        ["sessionId": sessionId.uuidString, "shouldPause": shouldPause]
    }
}
