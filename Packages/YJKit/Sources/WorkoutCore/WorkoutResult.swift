import Foundation

public struct WorkoutResult: Equatable, Sendable {
    public let durationSeconds: Int
    /// 활동 에너지(activeEnergyBurned)만.
    public let caloriesBurned: Double
    /// 활동 + 휴식(basalEnergyBurned). 소비자가 값을 주지 않으면 0.
    public let totalCaloriesBurned: Double
    public let averageHeartRate: Double?

    public init(durationSeconds: Int,
                caloriesBurned: Double,
                averageHeartRate: Double?,
                totalCaloriesBurned: Double = 0)
    {
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.totalCaloriesBurned = totalCaloriesBurned
    }
}
