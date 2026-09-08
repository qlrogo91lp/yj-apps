@testable import TennisCounter_Watch_App
import Testing
import WatchKit

struct MatchHapticsTests {
    @Test func scoreEventsUseSharedVocabularyWithGolf() {
        #expect(MatchHaptics.type(for: .point) == .click)
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
