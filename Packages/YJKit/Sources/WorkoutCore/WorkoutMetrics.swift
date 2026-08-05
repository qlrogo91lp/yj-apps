import Foundation

/// 워크아웃 진행 중 스냅샷. 종료 시 요약인 `WorkoutResult`의 진행 중 버전이다.
public struct WorkoutMetrics: Equatable, Sendable {
    public let elapsedSeconds: TimeInterval
    /// 활동 에너지(activeEnergyBurned)만.
    public let activeCalories: Double
    /// 활동 + 휴식(basalEnergyBurned).
    public let totalCalories: Double
    public let heartRate: Double

    public init(elapsedSeconds: TimeInterval = 0,
                activeCalories: Double = 0,
                totalCalories: Double = 0,
                heartRate: Double = 0)
    {
        self.elapsedSeconds = elapsedSeconds
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.heartRate = heartRate
    }

    public var formattedElapsed: String {
        Self.formatSeconds(Int(elapsedSeconds))
    }

    public static func formatSeconds(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
