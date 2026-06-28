import Foundation
@testable import TennisCounter
import Testing

struct WatchConnectivityStalenessTests {
    @Test func freshWorkoutEndIsNotStale() {
        let now = 1_000_000.0
        #expect(WatchConnectivityService.isWorkoutEndStale(sentAt: now - 1, now: now) == false)
    }

    @Test func oldWorkoutEndIsStale() {
        let now = 1_000_000.0
        #expect(WatchConnectivityService.isWorkoutEndStale(sentAt: now - 120, now: now) == true)
    }

    @Test func missingTimestampIsNotStale() {
        let now = 1_000_000.0
        #expect(WatchConnectivityService.isWorkoutEndStale(sentAt: nil, now: now) == false)
    }

    @Test func recentSessionStartIsNotStale() {
        let now = 1_000_000.0
        #expect(WatchConnectivityService.isSessionStartStale(workoutStartDate: now - 60, now: now) == false)
    }

    @Test func veryOldSessionStartIsStale() {
        let now = 1_000_000.0
        #expect(WatchConnectivityService.isSessionStartStale(workoutStartDate: now - 7 * 3600, now: now) == true)
    }

    @Test func missingSessionStartDateIsNotStale() {
        let now = 1_000_000.0
        #expect(WatchConnectivityService.isSessionStartStale(workoutStartDate: nil, now: now) == false)
    }
}
