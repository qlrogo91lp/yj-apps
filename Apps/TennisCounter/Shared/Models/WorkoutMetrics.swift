import Foundation

struct WorkoutMetrics {
    var elapsedSeconds: TimeInterval
    var calories: Double
    var heartRate: Double
    var steps: Int

    static let messageKey = "workoutMetrics"
    private static let keysElapsed = "elapsed"
    private static let keysCalories = "calories"
    private static let keysHeartRate = "heartRate"
    private static let keysSteps = "steps"

    func toDictionary() -> [String: Any] {
        [Self.keysElapsed: elapsedSeconds,
         Self.keysCalories: calories,
         Self.keysHeartRate: heartRate,
         Self.keysSteps: steps]
    }

    init(elapsedSeconds: TimeInterval = 0, calories: Double = 0, heartRate: Double = 0, steps: Int = 0) {
        self.elapsedSeconds = elapsedSeconds
        self.calories = calories
        self.heartRate = heartRate
        self.steps = steps
    }

    init?(from dict: [String: Any]) {
        guard let elapsed = dict[Self.keysElapsed] as? TimeInterval else { return nil }
        elapsedSeconds = elapsed
        calories = dict[Self.keysCalories] as? Double ?? 0
        heartRate = dict[Self.keysHeartRate] as? Double ?? 0
        steps = dict[Self.keysSteps] as? Int ?? 0
    }

    var formattedElapsed: String {
        let total = Int(elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
