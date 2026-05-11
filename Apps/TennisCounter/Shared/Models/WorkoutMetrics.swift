import Foundation

struct WorkoutMetrics {
    var elapsedSeconds: TimeInterval
    var calories: Double
    var heartRate: Double

    static let messageKey = "workoutMetrics"
    private static let keysElapsed = "elapsed"
    private static let keysCalories = "calories"
    private static let keysHeartRate = "heartRate"

    func toDictionary() -> [String: Any] {
        [Self.keysElapsed: elapsedSeconds,
         Self.keysCalories: calories,
         Self.keysHeartRate: heartRate]
    }

    init(elapsedSeconds: TimeInterval = 0, calories: Double = 0, heartRate: Double = 0) {
        self.elapsedSeconds = elapsedSeconds
        self.calories = calories
        self.heartRate = heartRate
    }

    init?(from dict: [String: Any]) {
        guard let elapsed = dict[Self.keysElapsed] as? TimeInterval else { return nil }
        elapsedSeconds = elapsed
        calories = dict[Self.keysCalories] as? Double ?? 0
        heartRate = dict[Self.keysHeartRate] as? Double ?? 0
    }

    var formattedElapsed: String {
        let total = Int(elapsedSeconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
