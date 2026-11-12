import Foundation
import Testing
@testable import WorkoutCore

struct WorkoutElapsedDisplayTests {
    @Test func running_withoutTicks_usesDateDifference() {
        let start = Date(timeIntervalSince1970: 100)
        let display = WorkoutElapsedDisplay(referenceDate: start)

        let now = Date(timeIntervalSince1970: 140.75)
        #expect(display.elapsed(at: now) == 40.75)
    }

    @Test func pauseResume_preservesFraction() {
        let start = Date(timeIntervalSince1970: 100)
        var display = WorkoutElapsedDisplay(referenceDate: start)

        display = display.pausing(at: Date(timeIntervalSince1970: 110.25))
        #expect(display.elapsed(at: Date(timeIntervalSince1970: 500)) == 10.25)

        display = display.resuming(at: Date(timeIntervalSince1970: 130.75))
        #expect(display.elapsed(at: Date(timeIntervalSince1970: 131.5)) == 11)
    }

    @Test func pausing_whenAlreadyPaused_keepsFirstBoundary() {
        let start = Date(timeIntervalSince1970: 100)
        var display = WorkoutElapsedDisplay(referenceDate: start)

        display = display.pausing(at: Date(timeIntervalSince1970: 110))
        display = display.pausing(at: Date(timeIntervalSince1970: 200)) // 무시되어야 한다

        #expect(display.elapsed(at: Date(timeIntervalSince1970: 999)) == 10)
    }

    @Test func resuming_whenNotPaused_isNoOp() {
        let start = Date(timeIntervalSince1970: 100)
        var display = WorkoutElapsedDisplay(referenceDate: start)

        display = display.resuming(at: Date(timeIntervalSince1970: 200)) // 정지 중이 아니므로 무시

        #expect(display.elapsed(at: Date(timeIntervalSince1970: 150)) == 50)
    }

    @Test func negativeDate_clampsToZero() {
        let start = Date(timeIntervalSince1970: 100)
        let display = WorkoutElapsedDisplay(referenceDate: start)

        #expect(display.elapsed(at: Date(timeIntervalSince1970: 50)) == 0)
    }
}
