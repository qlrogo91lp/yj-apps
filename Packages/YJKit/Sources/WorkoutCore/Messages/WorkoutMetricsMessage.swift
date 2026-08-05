import ConnectivityCore
import Foundation

/// 워치 → 폰 워크아웃 메트릭 브로드캐스트.
/// 와이어 키는 앱에 있던 시절 포맷을 그대로 유지한다 (구버전 앱과 호환).
public struct WorkoutMetricsMessage: ConnectivityMessage {
    public static let messageType = "metrics"

    public let metrics: WorkoutMetrics

    public init(metrics: WorkoutMetrics) {
        self.metrics = metrics
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
    }

    public func toDictionary() -> [String: Any] {
        ["elapsed": metrics.elapsedSeconds,
         "calories": metrics.activeCalories,
         "totalCalories": metrics.totalCalories,
         "heartRate": metrics.heartRate]
    }
}
