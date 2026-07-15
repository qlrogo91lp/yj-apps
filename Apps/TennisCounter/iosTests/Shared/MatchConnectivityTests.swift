import Foundation
@testable import TennisCounter
import Testing

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
}
