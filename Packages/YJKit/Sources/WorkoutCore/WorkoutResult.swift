import Foundation

public struct WorkoutResult: Equatable, Sendable {
    public let durationSeconds: Int
    /// 활동 에너지(activeEnergyBurned)만.
    public let caloriesBurned: Double
    /// 활동 + 휴식(basalEnergyBurned). 소비자가 값을 주지 않으면 0.
    public let totalCaloriesBurned: Double
    public let averageHeartRate: Double?
    /// 워크아웃 구간의 이동 거리(미터). 종목이 distanceWalkingRunning을 수집하지 않으면 0.
    public let distanceMeters: Double
    /// 워크아웃 구간의 걸음수. 종목이 stepCount를 수집하지 않으면 0.
    public let steps: Int

    public init(durationSeconds: Int,
                caloriesBurned: Double,
                averageHeartRate: Double?,
                totalCaloriesBurned: Double = 0,
                distanceMeters: Double = 0,
                steps: Int = 0)
    {
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.totalCaloriesBurned = totalCaloriesBurned
        self.distanceMeters = distanceMeters
        self.steps = steps
    }
}
