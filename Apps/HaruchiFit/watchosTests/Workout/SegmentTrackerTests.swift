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

    // MARK: - 일시정지

    @Test("정지한 동안은 경과시간이 늘지 않는다")
    func pauseFreezesElapsed() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(600) // 10분 운동
        tracker.pause()
        clock.advance(300) // 5분 정지 — 이 시간은 세지 않는다

        #expect(tracker.elapsedSeconds == 600)
    }

    @Test("재개하면 정지한 만큼을 뺀 채로 다시 흐른다")
    func resumeExcludesPausedSpan() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(1200) // 20분
        tracker.pause()
        clock.advance(600) // 10분 정지
        tracker.resume()
        clock.advance(1200) // 20분

        #expect(tracker.elapsedSeconds == 2400) // 40분. 정지 10분 제외
    }

    @Test("정지를 사이에 낀 구간에도 정지 시간이 빠진다")
    func pausedTimeIsExcludedFromSegments() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(600) // 근력 10분
        tracker.pause()
        clock.advance(300) // 5분 정지
        tracker.resume()
        clock.advance(600) // 근력 10분 더
        tracker.closeOpenSegment(kind: .strength)
        clock.advance(300) // 유산소 5분
        tracker.closeOpenSegment(kind: .cardio)

        #expect(tracker.closed.map(\.durationSeconds) == [1200, 300])
        #expect(tracker.closed.map(\.startOffset) == [0, 1200])

        let total = tracker.closed.reduce(0) { $0 + $1.durationSeconds }
        #expect(total == tracker.elapsedSeconds)
    }

    @Test("정지·재개를 중복으로 불러도 값이 어긋나지 않는다")
    func repeatedPauseResumeIsIdempotent() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        tracker.resume() // 정지 중이 아닌데 재개 — 무시
        clock.advance(600)
        tracker.pause()
        tracker.pause() // 두 번째는 무시
        clock.advance(300)
        tracker.resume()
        tracker.resume() // 두 번째는 무시
        clock.advance(600)

        #expect(tracker.elapsedSeconds == 1200)
    }

    @Test("정지 중에 세션을 끝내도 구간 합계와 총 시간이 어긋나지 않는다")
    func closingWhilePausedKeepsSumConsistent() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(1200) // 20분 운동
        tracker.pause()
        clock.advance(900) // 15분 정지 — 이 상태로 종료 버튼을 누른다
        tracker.closeOpenSegment(kind: .strength)

        let sum = tracker.closed.reduce(0) { $0 + $1.durationSeconds }
        #expect(sum == 1200)
        #expect(tracker.elapsedSeconds == 1200)
        #expect(sum == tracker.elapsedSeconds)
    }

    @Test("새 세션을 열면 정지 누적도 지운다")
    func resetClearsPausedAccumulation() {
        var (tracker, clock) = makeTracker()
        tracker.reset()
        clock.advance(600)
        tracker.pause()
        clock.advance(600)

        tracker.reset() // 정지 중에 새 세션을 연다
        clock.advance(300)

        #expect(tracker.elapsedSeconds == 300)
    }

    @Test("구간을 닫은 직후의 경과시간은 구간 합계와 정확히 같다 — 저장 총시간이 이 값이다")
    func elapsedEqualsSegmentSumRightAfterClosing() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(900) // 근력 15분
        tracker.pause()
        clock.advance(600) // 10분 정지
        tracker.resume()
        clock.advance(300) // 근력 5분 더
        tracker.closeOpenSegment(kind: .strength)
        clock.advance(600) // 유산소 10분
        tracker.closeOpenSegment(kind: .cardio)

        let totalSeconds = tracker.elapsedSeconds // end() 가 붙드는 그 시점
        let sum = tracker.closed.reduce(0) { $0 + $1.durationSeconds }

        #expect(totalSeconds == sum)
        #expect(totalSeconds == 1800) // 30분. 정지 10분 제외

        // 종료 처리(HealthKit 마무리)에 시간이 걸려도 붙든 값은 변하지 않는다
        clock.advance(12)
        #expect(totalSeconds == sum)
    }
}
