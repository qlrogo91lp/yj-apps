@testable import GolfCounter_Watch_App
import Testing
import WorkoutCore

struct RoundMetricsConversionTests {
    @Test func 워크아웃_결과의_네_값이_옮겨진다() {
        let result = WorkoutResult(durationSeconds: 12345,
                                   caloriesBurned: 412,
                                   averageHeartRate: 118,
                                   totalCaloriesBurned: 500,
                                   distanceMeters: 6200,
                                   steps: 9100)

        let metrics = RoundMetrics(result)

        #expect(metrics.calories == 412)
        #expect(metrics.avgHeartRate == 118)
        #expect(metrics.distanceMeters == 6200)
        #expect(metrics.steps == 9100)
    }

    @Test func 심박을_한번도_못받으면_0이_된다() {
        let result = WorkoutResult(durationSeconds: 60,
                                   caloriesBurned: 10,
                                   averageHeartRate: nil)

        let metrics = RoundMetrics(result)

        #expect(metrics.avgHeartRate == 0)
    }

    @Test func empty는_전부_0이다() {
        #expect(RoundMetrics.empty == RoundMetrics(calories: 0, avgHeartRate: 0, distanceMeters: 0, steps: 0))
    }
}
