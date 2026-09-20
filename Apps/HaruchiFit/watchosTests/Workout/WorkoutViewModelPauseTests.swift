import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// 정지 신호가 **시계**에 닿는지 본다.
///
/// `session.$isPaused` 스트림은 실제 `HKWorkoutSession` 없이는 흐르지 않으므로
/// (`WorkoutViewModelSnapshotTests` 주석 참고) 스트림이 부르는 지점을 직접 호출한다.
/// 스트림 자체의 연결은 실기기 검증 항목이다.
@MainActor
struct WorkoutViewModelPauseTests {
    private final class Clock {
        var now: Date
        init(_ start: Date = Date(timeIntervalSince1970: 0)) {
            now = start
        }

        func advance(_ seconds: TimeInterval) {
            now.addTimeInterval(seconds)
        }
    }

    private func makeViewModel() -> (WorkoutViewModel, WorkoutSnapshotPublisherSpy, Clock) {
        let clock = Clock()
        let snapshots = WorkoutSnapshotPublisherSpy()
        let viewModel = WorkoutViewModel(connectivity: WorkoutRecordSendingSpy(),
                                         remover: WorkoutRemovingSpy(),
                                         defaults: UserDefaults(suiteName: "PauseTests-\(UUID().uuidString)")!,
                                         snapshots: snapshots,
                                         now: { clock.now })
        return (viewModel, snapshots, clock)
    }

    @Test("정지한 시간은 컴플리케이션 스냅샷의 경과시간에서 빠진다")
    func pausedTimeIsExcludedFromSnapshot() throws {
        let (viewModel, spy, clock) = makeViewModel()

        clock.advance(600) // 10분 운동
        viewModel.handlePauseChange(true)
        clock.advance(300) // 5분 정지
        viewModel.handlePauseChange(false)
        clock.advance(600) // 10분 더

        viewModel.switchMode(to: .cardio) // 스냅샷 발행

        let snapshot = try #require(spy.published.last)
        #expect(snapshot.elapsedSeconds == 1200) // 20분. 정지 5분 제외
    }

    @Test("정지 중에 발행된 스냅샷은 멈춘 시각을 담는다")
    func snapshotDuringPauseHoldsFrozenElapsed() throws {
        let (viewModel, spy, clock) = makeViewModel()

        clock.advance(900) // 15분
        viewModel.handlePauseChange(true)
        clock.advance(1800) // 30분을 멈춰 있었다

        viewModel.switchMode(to: .cardio)

        let snapshot = try #require(spy.published.last)
        #expect(snapshot.elapsedSeconds == 900)
    }

    @Test("정지 신호가 중복으로 와도 경과시간이 어긋나지 않는다")
    func duplicatePauseSignalsDoNotDrift() throws {
        let (viewModel, spy, clock) = makeViewModel()

        clock.advance(600)
        viewModel.handlePauseChange(true)
        viewModel.handlePauseChange(true)
        clock.advance(300)
        viewModel.handlePauseChange(false)
        viewModel.handlePauseChange(false)
        clock.advance(600)

        viewModel.switchMode(to: .cardio)

        let snapshot = try #require(spy.published.last)
        #expect(snapshot.elapsedSeconds == 1200)
    }
}
