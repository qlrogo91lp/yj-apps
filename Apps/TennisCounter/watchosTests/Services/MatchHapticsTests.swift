@testable import TennisCounter_Watch_App
import Testing
import WatchKit

struct MatchHapticsTests {
    @Test func scoreEventsMapToDistinctHaptics() {
        // .click 은 경기 중 거의 느껴지지 않았다 (실기기). 되돌리기와 짝이 맞는 .directionUp 으로 올린다.
        #expect(MatchHaptics.type(for: .point) == .directionUp)
        #expect(MatchHaptics.type(for: .undo) == .directionDown)
        #expect(MatchHaptics.type(for: .gameWon) == .start)
        #expect(MatchHaptics.type(for: .setWon) == .notification)
    }

    @Test func matchResultMapsToSuccessFailureNotification() {
        #expect(MatchHaptics.type(for: .matchFinished(.win)) == .success)
        #expect(MatchHaptics.type(for: .matchFinished(.loss)) == .failure)
        #expect(MatchHaptics.type(for: .matchFinished(.draw)) == .notification)
    }

    @Test func saveAndPauseEvents() {
        #expect(MatchHaptics.type(for: .saveSucceeded) == .success)
        #expect(MatchHaptics.type(for: .saveFailed) == .failure)
        #expect(MatchHaptics.type(for: .paused) == .stop)
        #expect(MatchHaptics.type(for: .resumed) == .start)
    }
}
