import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// 세션 종료 후 **저장할지 버릴지**를 가르는 지점을 검증한다 (W2).
///
/// 세션 자체(`WorkoutSessionService`)는 HealthKit 을 직접 만져 테스트에서 돌릴 수 없다.
/// 그래서 종료 결과를 받은 뒤의 결정 로직만 다룬다 — 회귀가 나면 사용자가 기록을 잃는
/// 쪽으로 깨지는 부분이 여기다.
@MainActor
struct WorkoutViewModelTests {

    // MARK: - 요약 진입

    @Test("요약 단계에서는 기록을 들고만 있고 아직 보내지 않는다")
    func enterSummaryHoldsRecordWithoutSending() {
        let (viewModel, spy, _) = makeViewModel()

        viewModel.enterSummary(with: RecordFixture.make())

        #expect(viewModel.phase == .summary)
        #expect(viewModel.pendingRecord != nil)
        #expect(spy.sent.isEmpty)
    }

    @Test("보낼 기록이 없으면 요약을 띄우지 않고 대기 상태로 돌아간다")
    func enterSummaryWithoutRecordReturnsToIdle() {
        let (viewModel, spy, _) = makeViewModel()

        viewModel.enterSummary(with: nil)

        #expect(viewModel.phase == .idle)
        #expect(viewModel.pendingRecord == nil)
        #expect(spy.sent.isEmpty)
    }

    // MARK: - 저장

    @Test("저장하면 들고 있던 기록을 한 번만 보낸다")
    func saveTransmitsPendingRecordOnce() {
        let (viewModel, spy, _) = makeViewModel()
        let uuid = UUID()
        viewModel.enterSummary(with: RecordFixture.make(healthKitUUID: uuid, totalSeconds: 4344))

        viewModel.save()

        #expect(spy.sent.count == 1)
        #expect(spy.sent.first?.healthKitUUID == uuid)
        #expect(spy.sent.first?.totalSeconds == 4344)
        #expect(viewModel.phase == .idle)
        #expect(viewModel.pendingRecord == nil)
    }

    @Test("들고 있는 기록이 없으면 저장은 아무것도 보내지 않는다")
    func saveWithoutPendingRecordSendsNothing() {
        let (viewModel, spy, _) = makeViewModel()

        viewModel.save()

        #expect(spy.sent.isEmpty)
        #expect(viewModel.phase == .idle)
    }

    // MARK: - 버리기

    @Test("버리면 아무것도 보내지 않는다")
    func discardTransmitsNothing() {
        let (viewModel, spy, _) = makeViewModel()
        viewModel.enterSummary(with: RecordFixture.make())

        viewModel.discard()

        #expect(spy.sent.isEmpty)
        #expect(viewModel.phase == .idle)
        #expect(viewModel.pendingRecord == nil)
    }

    @Test("버리면 HealthKit 에 저장된 워크아웃도 지워달라고 한다")
    func discardRemovesStoredWorkout() async {
        let uuid = UUID()
        let (viewModel, _, remover) = makeViewModel()
        viewModel.enterSummary(with: RecordFixture.make(healthKitUUID: uuid))

        viewModel.discard()

        // 삭제는 떼어낸 Task 로 돈다 — 도착할 때까지 짧게 기다린다.
        var removed = await remover.removed
        var attempts = 0
        while removed.isEmpty, attempts < 100 {
            await Task.yield()
            removed = await remover.removed
            attempts += 1
        }
        #expect(removed == [uuid])
    }

    @Test("버린 뒤 저장을 눌러도 되살아나지 않는다")
    func saveAfterDiscardSendsNothing() {
        let (viewModel, spy, _) = makeViewModel()
        viewModel.enterSummary(with: RecordFixture.make())
        viewModel.discard()

        viewModel.save()

        #expect(spy.sent.isEmpty)
    }

    // MARK: - Helpers

    private func makeViewModel() -> (WorkoutViewModel, WorkoutRecordSendingSpy, WorkoutRemovingSpy) {
        let spy = WorkoutRecordSendingSpy()
        let remover = WorkoutRemovingSpy()
        return (WorkoutViewModel(connectivity: spy, remover: remover), spy, remover)
    }
}
