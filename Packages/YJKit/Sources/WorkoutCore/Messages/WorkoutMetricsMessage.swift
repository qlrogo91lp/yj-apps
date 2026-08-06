import ConnectivityCore
import Foundation

/// 워치 → 폰 워크아웃 메트릭 브로드캐스트 겸 경과시간 앵커.
/// 와이어 키는 앱에 있던 시절 포맷을 그대로 유지한다 (구버전 앱과 호환).
public struct WorkoutMetricsMessage: ConnectivityMessage {
    public static let messageType = "metrics"

    public let metrics: WorkoutMetrics
    /// 앵커 시점의 일시정지 여부. 구버전 워치는 이 키를 안 보내 false(진행 중)로 떨어진다.
    public let isPaused: Bool
    /// 발신 시각(Unix epoch). ConnectivityService가 스탬프하므로 발신 시엔 nil이고,
    /// 수신 시에만 값이 채워진다. 폰의 경과시간 보간(WorkoutAnchor)에 쓰인다.
    public let sentAt: TimeInterval?

    public init(metrics: WorkoutMetrics, isPaused: Bool = false) {
        self.metrics = metrics
        self.isPaused = isPaused
        sentAt = nil
    }

    public init?(from dictionary: [String: Any]) {
        guard let elapsed = dictionary["elapsed"] as? TimeInterval else { return nil }
        let active = dictionary["calories"] as? Double ?? 0
        // 구버전 워치는 totalCalories를 안 보낸다 — 활동 칼로리로 폴백.
        let total = dictionary["totalCalories"] as? Double ?? active
        metrics = WorkoutMetrics(elapsedSeconds: elapsed,
                                 activeCalories: active,
                                 totalCalories: total,
                                 heartRate: dictionary["heartRate"] as? Double ?? 0)
        isPaused = dictionary["isPaused"] as? Bool ?? false
        sentAt = dictionary["sentAt"] as? Double
    }

    public func toDictionary() -> [String: Any] {
        ["elapsed": metrics.elapsedSeconds,
         "calories": metrics.activeCalories,
         "totalCalories": metrics.totalCalories,
         "heartRate": metrics.heartRate,
         "isPaused": isPaused]
    }
}
