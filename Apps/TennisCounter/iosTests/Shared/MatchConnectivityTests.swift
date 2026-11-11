import Foundation
@testable import TennisCounter
import Testing
import WorkoutCore

struct MatchConnectivityTests {
    @Test func recentSessionStartIsNotStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: now - 60, now: now) == false)
    }

    @Test func veryOldSessionStartIsStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: now - 7 * 3600, now: now) == true)
    }

    @Test func missingSessionStartDateIsNotStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: nil, now: now) == false)
    }

    @Test func workoutEndMessageUsesResultEndDate() {
        let endedAt = Date(timeIntervalSince1970: 1_000_900)
        let result = WorkoutResult(durationSeconds: 900,
                                   caloriesBurned: 120,
                                   averageHeartRate: 135,
                                   endedAt: endedAt)

        let message = MatchConnectivity.workoutEndMessage(
            sessionId: UUID(),
            result: result,
            startedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        #expect(message.endedAt == endedAt)
    }

    @Test func workoutEndMessageFallsBackToResultDurationWhenTotalElapsedSecondsIsNil() {
        let result = WorkoutResult(durationSeconds: 900, caloriesBurned: 120, averageHeartRate: 135)

        let message = MatchConnectivity.workoutEndMessage(
            sessionId: UUID(),
            result: result,
            startedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        #expect(message.elapsedSeconds == 900)
    }

    /// Task 4b — 정지 제외 표시 기준 총시간이 있으면 그걸 쓴다. 정지를 포함한 `result.durationSeconds`(벽시계)는 덮인다.
    @Test func workoutEndMessageUsesTotalElapsedSecondsWhenProvided() {
        let result = WorkoutResult(durationSeconds: 900, caloriesBurned: 120, averageHeartRate: 135)

        let message = MatchConnectivity.workoutEndMessage(
            sessionId: UUID(),
            result: result,
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            totalElapsedSeconds: 600
        )

        #expect(message.elapsedSeconds == 600)
    }
}
