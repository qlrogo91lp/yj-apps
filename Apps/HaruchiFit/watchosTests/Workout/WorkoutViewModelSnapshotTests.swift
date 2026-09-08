import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// WC — 세션 상태가 바뀔 때 컴플리케이션용 스냅샷이 나가는지.
///
/// **일시정지는 여기서 다루지 않는다.** `isPaused` 는 워치 세션이 단일 소스라 서비스의
/// 스트림으로만 갱신되고(루트 `CLAUDE.md` 워크아웃 계약 — 낙관적 토글 금지), 그 스트림은
/// 실제 `HKWorkoutSession` 없이는 흐르지 않는다. 실기기 검증 항목이다.
@MainActor
struct WorkoutViewModelSnapshotTests {

    @Test("구간을 바꾸면 새 유형으로 발행한다")
    func switchingModePublishesNewKind() {
        let (viewModel, spy) = makeViewModel()

        viewModel.switchMode(to: .cardio)

        #expect(spy.published.count == 1)
        #expect(spy.published.last?.mode == .cardio)
    }

    @Test("같은 유형으로 바꾸면 아무것도 발행하지 않는다")
    func switchingToSameModePublishesNothing() {
        let (viewModel, spy) = makeViewModel()

        viewModel.switchMode(to: .strength)

        #expect(spy.published.isEmpty)
    }

    @Test("발행된 스냅샷은 경과시간과 뜬 시각을 짝으로 담는다")
    func snapshotCarriesElapsedWithCaptureTime() throws {
        let (viewModel, spy) = makeViewModel()

        viewModel.switchMode(to: .cardio)

        // 세션이 없으면 경과시간은 0 이다. 중요한 건 둘이 같은 스냅샷에 함께 실린다는 것 —
        // 컴플리케이션이 `capturedAt - elapsedSeconds` 로 타이머 기준점을 잡는다.
        let snapshot = try #require(spy.published.last)
        #expect(snapshot.elapsedSeconds == 0)
        #expect(snapshot.capturedAt.timeIntervalSinceNow < 1)
    }

    @Test("종료하면 스냅샷을 지운다")
    func endingClearsSnapshot() async {
        let (viewModel, spy) = makeViewModel()

        await viewModel.end()

        #expect(spy.clearCount == 1)
        #expect(spy.published.isEmpty)
    }

    // MARK: - Helpers

    private func makeViewModel() -> (WorkoutViewModel, WorkoutSnapshotPublisherSpy) {
        let snapshots = WorkoutSnapshotPublisherSpy()
        let viewModel = WorkoutViewModel(connectivity: WorkoutRecordSendingSpy(),
                                         remover: WorkoutRemovingSpy(),
                                         defaults: UserDefaults(suiteName: "SnapshotTests-\(UUID().uuidString)")!,
                                         snapshots: snapshots)
        return (viewModel, snapshots)
    }
}
