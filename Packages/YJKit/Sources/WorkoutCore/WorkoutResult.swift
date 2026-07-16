import Foundation

public struct WorkoutResult: Equatable, Sendable {
    public let durationSeconds: Int
    public let caloriesBurned: Double
    public let averageHeartRate: Double?

    public init(durationSeconds: Int, caloriesBurned: Double, averageHeartRate: Double?) {
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
    }
}
