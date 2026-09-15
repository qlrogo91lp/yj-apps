import Foundation
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

    /// 카드의 숫자는 "이 경기가 끝난 시점까지의 누적값"이라, 시간 범위도 워크아웃 시작 ~ 이 경기 끝이다.
    /// 같은 세션의 다른 경기를 조회하지 않고 누적 시간을 거꾸로 빼서 시작을 구한다.
    @Test func shareRangeEndsAtThisMatchAndStartsAtWorkoutStart() {
        let match = Match()
        let end = Date(timeIntervalSince1970: 100_000)
        match.startedAt = end.addingTimeInterval(-1800) // 이 경기의 시작 — 쓰지 않는다
        match.endedAt = end
        match.workoutElapsedSeconds = 9351

        #expect(match.shareEndedAt == end)
        #expect(match.shareStartedAt == end.addingTimeInterval(-9351))
    }

    @Test func shareRangeFallsBackToMatchStartWhenEndMissing() {
        let match = Match()
        let start = Date(timeIntervalSince1970: 100_000)
        match.startedAt = start
        match.workoutElapsedSeconds = 9351

        #expect(match.shareEndedAt == nil)
        #expect(match.shareStartedAt == start)
    }
}
