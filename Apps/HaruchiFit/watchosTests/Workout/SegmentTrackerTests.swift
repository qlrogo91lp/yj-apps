import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// 구간 길이가 **벽시계**로 재지는지 본다.
///
/// 실기기에서 40분을 운동해도 "근력 0분" 이 나왔다. `WorkoutSessionService.elapsedSeconds`
/// 는 1초 `Timer` 틱 카운터라 손목을 내리면 멈추고, 다시 켜져도 밀린 만큼 따라잡지 않는다.
/// 시뮬레이터는 앱이 계속 앞에 떠 있어 틱이 정확히 쌓이므로 이 회귀를 못 잡는다.
struct SegmentTrackerTests {
    /// 테스트가 시간을 직접 돌린다.
    private final class Clock {
        var now: Date
        init(_ start: Date = Date(timeIntervalSince1970: 0)) {
            now = start
        }

        func advance(_ seconds: TimeInterval) {
            now.addTimeInterval(seconds)
        }
    }

    private func makeTracker() -> (SegmentTracker, Clock) {
        let clock = Clock()
        return (SegmentTracker(now: { clock.now }), clock)
    }

    @Test("구간 길이는 벽시계로 잰다 — 틱이 안 쌓여도 실제 흐른 시간이 잡힌다")
    func wallClockDrivesSegmentDuration() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(2400) // 40분
        tracker.closeOpenSegment(kind: .strength)

        #expect(tracker.closed.count == 1)
        #expect(tracker.closed.first?.durationSeconds == 2400)
        #expect(tracker.closed.first?.startOffset == 0)
    }

    @Test("전환하면 그 시점에서 구간이 갈린다")
    func switchSplitsAtBoundary() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(600)
        tracker.closeOpenSegment(kind: .strength)
        clock.advance(300)
        tracker.closeOpenSegment(kind: .cardio)

        #expect(tracker.closed.map(\.kind) == [.strength, .cardio])
        #expect(tracker.closed.map(\.startOffset) == [0, 600])
        #expect(tracker.closed.map(\.durationSeconds) == [600, 300])
    }

    @Test("길이가 0인 구간은 버린다 — 전환을 연달아 눌러도 빈 구간이 쌓이지 않는다")
    func zeroLengthSegmentIsDropped() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(600)
        tracker.closeOpenSegment(kind: .strength)
        tracker.closeOpenSegment(kind: .cardio) // 시간이 안 흘렀다
        tracker.closeOpenSegment(kind: .strength)

        #expect(tracker.closed.count == 1)
        #expect(tracker.closed.first?.kind == .strength)
    }

    @Test("구간 합계는 총 경과시간과 같다 — 요약 상단 총 시간과 어긋나면 안 된다")
    func segmentsSumToElapsed() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(900)
        tracker.closeOpenSegment(kind: .strength)
        clock.advance(1200)
        tracker.closeOpenSegment(kind: .cardio)
        clock.advance(300)
        tracker.closeOpenSegment(kind: .strength)

        let total = tracker.closed.reduce(0) { $0 + $1.durationSeconds }
        #expect(total == tracker.elapsedSeconds)
        #expect(total == 2400)
    }

    @Test("새 세션을 열면 이전 구간을 버리고 기준 시각을 다시 잡는다")
    func resetClearsPreviousSession() {
        var (tracker, clock) = makeTracker()
        tracker.reset()
        clock.advance(600)
        tracker.closeOpenSegment(kind: .strength)

        clock.advance(60)
        tracker.reset()
        clock.advance(120)

        #expect(tracker.closed.isEmpty)
        #expect(tracker.elapsedSeconds == 120)
    }
}
