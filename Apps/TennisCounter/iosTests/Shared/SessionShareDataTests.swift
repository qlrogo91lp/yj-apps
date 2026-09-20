import Foundation
@testable import TennisCounter
import Testing
import WorkoutCore

struct SessionShareDataTests {
    @Test func recordUsesFinalMetricsAndActualWorkoutRange() throws {
        let start = Date(timeIntervalSince1970: 100_000)
        let match = Match()
        match.startedAt = start.addingTimeInterval(600)
        match.endedAt = start.addingTimeInterval(1800)
        match.workoutElapsedSeconds = 1800
        match.workoutCaloriesBurned = 200
        match.workoutTotalCaloriesBurned = 250
        match.averageHeartRate = 170
        let record = WorkoutSessionRecord()
        record.startedAt = start
        record.endedAt = start.addingTimeInterval(3600)
        record.elapsedSeconds = 3000 // 일시정지는 헤더의 실제 시간 범위에 포함된다.
        record.activeCalories = 350
        record.totalCalories = 420
        record.averageHeartRate = 142
        let session = MatchSessionGroup(id: UUID(), matches: [match], record: record)

        let share = try #require(SessionShareData(session: session))

        #expect(share.result.durationSeconds == 3000)
        #expect(share.result.caloriesBurned == 350)
        #expect(share.result.totalCaloriesBurned == 420)
        #expect(share.result.averageHeartRate == 142)
        #expect(share.startedAt == start)
        #expect(share.endedAt == start.addingTimeInterval(3600))
    }

    @Test func legacyUsesGroupMaximumAndDoesNotShareMatchHeartRate() throws {
        let first = Match()
        first.startedAt = Date(timeIntervalSince1970: 100_000)
        first.endedAt = Date(timeIntervalSince1970: 100_600)
        first.workoutElapsedSeconds = 600
        first.workoutCaloriesBurned = 500
        first.workoutTotalCaloriesBurned = 620
        first.averageHeartRate = 180
        let last = Match()
        last.startedAt = Date(timeIntervalSince1970: 100_700)
        last.endedAt = Date(timeIntervalSince1970: 101_800)
        last.workoutElapsedSeconds = 1800
        last.workoutCaloriesBurned = 450
        last.workoutTotalCaloriesBurned = 600
        last.averageHeartRate = 130
        let session = MatchSessionGroup(id: UUID(), matches: [first, last], record: nil)

        let share = try #require(SessionShareData(session: session))

        #expect(share.result.durationSeconds == 1800)
        #expect(share.result.caloriesBurned == 500)
        #expect(share.result.totalCaloriesBurned == 620)
        #expect(share.result.averageHeartRate == nil)
        #expect(share.startedAt == Date(timeIntervalSince1970: 100_000))
        #expect(share.endedAt == Date(timeIntervalSince1970: 101_800))
    }

    @Test func recordWithoutMatchesCanBeShared() throws {
        let record = WorkoutSessionRecord()
        record.startedAt = Date(timeIntervalSince1970: 100_000)
        record.elapsedSeconds = 2400
        record.activeCalories = 300
        record.averageHeartRate = 140
        let session = MatchSessionGroup(id: UUID(), matches: [], record: record)

        let share = try #require(SessionShareData(session: session))

        #expect(share.result.durationSeconds == 2400)
        #expect(share.result.caloriesBurned == 300)
        #expect(share.result.totalCaloriesBurned == 0)
        #expect(share.result.averageHeartRate == 140)
        #expect(share.startedAt == record.startedAt)
        #expect(share.endedAt == nil)
    }

    @Test func incompleteRecordDoesNotBorrowLegacyRequiredMetrics() {
        let match = Match()
        match.workoutElapsedSeconds = 1000
        match.workoutCaloriesBurned = 100
        let record = WorkoutSessionRecord()
        record.activeCalories = 150
        let session = MatchSessionGroup(id: UUID(), matches: [match], record: record)

        #expect(SessionShareData(session: session) == nil)
        record.elapsedSeconds = 1500
        record.activeCalories = nil
        #expect(SessionShareData(session: session) == nil)
    }

    @Test func recordMissingOptionalMetricsDoesNotBorrowMatchValues() throws {
        let match = Match()
        match.workoutTotalCaloriesBurned = 500
        match.averageHeartRate = 180
        match.endedAt = Date(timeIntervalSince1970: 101_000)
        let record = WorkoutSessionRecord()
        record.startedAt = Date(timeIntervalSince1970: 100_000)
        record.elapsedSeconds = 1500
        record.activeCalories = 150
        let session = MatchSessionGroup(id: UUID(), matches: [match], record: record)

        let share = try #require(SessionShareData(session: session))

        #expect(share.result.totalCaloriesBurned == 0)
        #expect(share.result.averageHeartRate == nil)
        #expect(share.endedAt == nil)
        #expect(share.startedAt == record.startedAt)
    }

    @Test func legacyRequiresCumulativeDurationAndCalories() throws {
        let match = Match()
        match.startedAt = Date(timeIntervalSince1970: 100_000)
        match.durationSeconds = 600
        match.caloriesBurned = 100
        let session = MatchSessionGroup(id: UUID(), matches: [match], record: nil)

        #expect(SessionShareData(session: session) == nil)
        match.workoutElapsedSeconds = 1200
        #expect(SessionShareData(session: session) == nil)
        match.workoutElapsedSeconds = nil
        match.workoutCaloriesBurned = 200
        #expect(SessionShareData(session: session) == nil)
        match.workoutElapsedSeconds = 1200

        let share = try #require(SessionShareData(session: session))
        #expect(share.result.totalCaloriesBurned == 0)
        #expect(share.result.averageHeartRate == nil)
        #expect(share.startedAt == Date(timeIntervalSince1970: 100_000))
        #expect(share.endedAt == nil)
    }
}
