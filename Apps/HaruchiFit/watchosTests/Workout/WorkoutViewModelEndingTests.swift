import Combine
import Foundation
@testable import HaruchiFit_Watch_App
import Testing
import WorkoutCore

@MainActor
struct WorkoutViewModelEndingTests {
    @Test("마무리 중 중복 종료가 단계와 기록을 변경하지 않는다")
    func duplicateEndDoesNotInterruptPendingEnd() async {
        let fixture = Fixture()
        let viewModel = fixture.viewModel
        var phases: [SessionPhase] = []
        let subscription = viewModel.$phase.dropFirst().sink { phases.append($0) }
        defer { subscription.cancel() }

        let first = Task { await viewModel.end() }
        await fixture.stopper.waitUntilPending()
        let duplicate = await viewModel.end()

        #expect(duplicate == nil)
        #expect(fixture.stopper.callCount == 1)
        #expect(viewModel.isEnding)
        #expect(viewModel.pendingRecord == nil)
        #expect(phases.isEmpty)
        #expect(fixture.snapshots.clearCount == 0)

        let result = fixture.result()
        fixture.stopper.complete(with: result)
        #expect(await first.value == result)
        #expect(phases == [.summary])
        #expect(!viewModel.isEnding)
        #expect(fixture.snapshots.clearCount == 1)
        #expect(viewModel.pendingRecord?.healthKitUUID == result.healthKitUUID)
    }

    @Test("종료 대기와 중복 요청이 구간 및 총 시간을 늘리지 않는다")
    func endingCapturesDurationAndSegmentsOnce() async throws {
        let fixture = Fixture()
        fixture.clock.now.addTimeInterval(60)
        let first = Task { await fixture.viewModel.end() }
        await fixture.stopper.waitUntilPending()
        fixture.clock.now.addTimeInterval(30)
        await fixture.viewModel.end()
        fixture.stopper.complete(with: fixture.result())
        await first.value

        let record = try #require(fixture.viewModel.pendingRecord)
        #expect(record.totalSeconds == 60)
        #expect(record.segments.count == 1)
        #expect(record.segments.reduce(0) { $0 + $1.durationSeconds } == 60)
    }

    @Test("요약 뒤 늦게 도착한 종료가 보관 기록을 변경하지 않는다")
    func lateEndPreservesSummary() async {
        let fixture = Fixture()
        let first = Task { await fixture.viewModel.end() }
        await fixture.stopper.waitUntilPending()
        let result = fixture.result()
        fixture.stopper.complete(with: result)
        await first.value

        await fixture.viewModel.end()

        #expect(fixture.stopper.callCount == 1)
        #expect(fixture.viewModel.phase == .summary)
        #expect(fixture.viewModel.pendingRecord?.healthKitUUID == result.healthKitUUID)
        #expect(fixture.snapshots.clearCount == 1)
    }

    @Test("결과가 없으면 종료 잠금이 풀리고 다시 종료할 수 있다")
    func nilResultClearsEnding() async {
        let fixture = Fixture()
        for _ in 0 ..< 2 {
            let task = Task { await fixture.viewModel.end() }
            await fixture.stopper.waitUntilPending()
            #expect(fixture.viewModel.isEnding)
            fixture.stopper.complete(with: nil)
            await task.value
            #expect(fixture.viewModel.phase == .idle)
            #expect(fixture.viewModel.pendingRecord == nil)
            #expect(!fixture.viewModel.isEnding)
        }
        #expect(fixture.stopper.callCount == 2)
    }

    @Test("종료 중 시작과 유형 변경 및 정지 조작을 무시한다")
    func actionsAreIgnoredWhileEnding() async {
        let fixture = Fixture()
        let task = Task { await fixture.viewModel.end() }
        await fixture.stopper.waitUntilPending()

        await fixture.viewModel.start()
        fixture.viewModel.toggleStartKind()
        fixture.viewModel.switchMode(to: .cardio)
        fixture.viewModel.togglePause()

        #expect(fixture.viewModel.phase == .idle)
        #expect(!fixture.viewModel.isStarting)
        #expect(fixture.viewModel.mode == .strength)
        #expect(fixture.defaults.string(forKey: "startSegmentKind") == nil)
        #expect(fixture.snapshots.published.isEmpty)
        #expect(!fixture.viewModel.isPaused)
        fixture.stopper.complete(with: fixture.result())
        await task.value
    }

    @Test("종료 중 정지 신호는 시계에 반영하고 스냅샷을 발행하지 않는다")
    func pauseChangeDoesNotPublishWhileEnding() async {
        let fixture = Fixture()
        fixture.clock.now.addTimeInterval(60)
        let task = Task { await fixture.viewModel.end() }
        await fixture.stopper.waitUntilPending()
        fixture.viewModel.handlePauseChange(true)
        fixture.clock.now.addTimeInterval(30)
        fixture.viewModel.handlePauseChange(false)
        #expect(fixture.snapshots.published.isEmpty)
        fixture.stopper.complete(with: nil)
        await task.value

        fixture.viewModel.switchMode(to: .cardio)
        #expect(fixture.snapshots.published.last?.elapsedSeconds == 60)
    }

    private final class Clock {
        var now = Date(timeIntervalSince1970: 0)
    }

    @MainActor
    private final class Fixture {
        let clock = Clock()
        let stopper = WorkoutStopperSpy()
        let snapshots = WorkoutSnapshotPublisherSpy()
        let defaults = UserDefaults(suiteName: "EndingTests-\(UUID().uuidString)")!
        let viewModel: WorkoutViewModel

        init() {
            let clock = clock
            let stopper = stopper
            viewModel = WorkoutViewModel(connectivity: WorkoutRecordSendingSpy(),
                                         remover: WorkoutRemovingSpy(),
                                         defaults: defaults,
                                         snapshots: snapshots,
                                         now: { clock.now },
                                         stopWorkout: { await stopper.stop() })
        }

        func result() -> WorkoutResult {
            WorkoutResult(durationSeconds: 90, caloriesBurned: 12, averageHeartRate: 100,
                          healthKitUUID: UUID(), endedAt: clock.now)
        }
    }
}
