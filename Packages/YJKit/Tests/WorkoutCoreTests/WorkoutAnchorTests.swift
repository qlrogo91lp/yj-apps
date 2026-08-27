import Testing
@testable import WorkoutCore

struct WorkoutAnchorTests {
    @Test func addsElapsedSinceSentWhenRunning() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: false, sentAt: 1000, now: 1007
        )
        #expect(result == 107)
    }

    @Test func freezesWhenPaused() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: true, sentAt: 1000, now: 1007
        )
        #expect(result == 100)
    }

    /// 구버전 발신자는 sentAt 스탬프가 없다 — 보간 없이 앵커 값을 그대로 쓴다.
    @Test func returnsAnchorWhenSentAtMissing() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: false, sentAt: nil, now: 1007
        )
        #expect(result == 100)
    }

    /// 두 기기 시계가 어긋나 now < sentAt이면 시간이 거꾸로 가지 않도록 앵커 값을 유지한다.
    @Test func clampsNegativeDrift() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: false, sentAt: 1000, now: 995
        )
        #expect(result == 100)
    }

    @Test func returnsAnchorExactlyAtSentAt() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: false, sentAt: 1000, now: 1000
        )
        #expect(result == 100)
    }
}
