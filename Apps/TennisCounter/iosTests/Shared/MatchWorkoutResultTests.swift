@testable import TennisCounter
import Testing
import WorkoutCore

struct MatchWorkoutResultTests {
    @Test func workoutResultMapsCumulativeFieldsNotMatchSegment() throws {
        let match = Match()
        match.durationSeconds = 1800 // 경기 구간값 — 무시돼야 한다
        match.caloriesBurned = 150
        match.workoutElapsedSeconds = 4800
        match.workoutCaloriesBurned = 500
        match.workoutTotalCaloriesBurned = 620
        match.averageHeartRate = 138

        let result = try #require(match.workoutResult)

        #expect(result.durationSeconds == 4800)
        #expect(result.caloriesBurned == 500)
        #expect(result.totalCaloriesBurned == 620)
        #expect(result.averageHeartRate == 138)
        #expect(result.distanceMeters == 0)
        #expect(result.steps == 0)
        #expect(result.healthKitUUID == nil)
    }

    @Test func workoutResultIsNilWhenElapsedMissing() {
        let match = Match()
        match.workoutCaloriesBurned = 500
        match.averageHeartRate = 138

        #expect(match.workoutResult == nil)
    }

    @Test func workoutResultIsNilWhenCaloriesMissing() {
        let match = Match()
        match.workoutElapsedSeconds = 4800
        match.averageHeartRate = 138

        #expect(match.workoutResult == nil)
    }

    @Test func workoutResultDefaultsTotalCaloriesToZeroAndKeepsNilHeartRate() {
        let match = Match()
        match.workoutElapsedSeconds = 4800
        match.workoutCaloriesBurned = 500
        // workoutTotalCaloriesBurned, averageHeartRate 는 nil

        let result = match.workoutResult

        #expect(result?.totalCaloriesBurned == 0)
        #expect(result?.averageHeartRate == nil)
    }
}
