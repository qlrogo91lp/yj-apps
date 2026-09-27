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
}
