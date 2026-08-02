import Foundation

struct WorkoutMetrics {
    var elapsedSeconds: TimeInterval
    var calories: Double
    /// 활동 + 휴식. 구버전 페이로드에는 없어서 calories로 폴백된다.
    var totalCalories: Double
    var heartRate: Double
    var steps: Int

    static let messageKey = "workoutMetrics"
    private static let keysElapsed = "elapsed"
    private static let keysCalories = "calories"
    private static let keysTotalCalories = "totalCalories"
    private static let keysHeartRate = "heartRate"
    private static let keysSteps = "steps"

    func toDictionary() -> [String: Any] {
        ["type": "metrics",
         Self.keysElapsed: elapsedSeconds,
         Self.keysCalories: calories,
         Self.keysTotalCalories: totalCalories,
         Self.keysHeartRate: heartRate,
         Self.keysSteps: steps]
    }

    init(elapsedSeconds: TimeInterval = 0, calories: Double = 0, totalCalories: Double = 0,
         heartRate: Double = 0, steps: Int = 0)
    {
        self.elapsedSeconds = elapsedSeconds
        self.calories = calories
        self.totalCalories = totalCalories
        self.heartRate = heartRate
        self.steps = steps
    }

    init?(from dict: [String: Any]) {
        guard let elapsed = dict[Self.keysElapsed] as? TimeInterval else { return nil }
        elapsedSeconds = elapsed
        calories = dict[Self.keysCalories] as? Double ?? 0
        // 구버전 워치는 totalCalories를 안 보낸다 — 활동 칼로리로 폴백.
        totalCalories = dict[Self.keysTotalCalories] as? Double ?? calories
        heartRate = dict[Self.keysHeartRate] as? Double ?? 0
        steps = dict[Self.keysSteps] as? Int ?? 0
    }

    var formattedElapsed: String {
        WorkoutMetrics.formatSeconds(Int(elapsedSeconds))
    }

    static func formatSeconds(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
