import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelSnapshotTests {
    private let startedAt = Date(timeIntervalSince1970: 1000)

    private func makeViewModel(spy: RoundSnapshotPublisherSpy) -> RoundViewModel {
        RoundViewModel(startedAt: startedAt, courseName: "테스트CC", publisher: spy)
    }

    @Test func start하면_최초_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)

        viewModel.start()

        #expect(spy.published.count == 1)
        #expect(spy.published.last?.startedAt == startedAt)
        #expect(spy.published.last?.courseName == "테스트CC")
    }

    @Test func 타수를_올리면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.selectPar(4)

        viewModel.incrementStroke()

        #expect(spy.published.last?.holeScores == [1])
    }

    @Test func 파를_고르면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)

        viewModel.selectPar(3)

        #expect(spy.published.last?.holePars == [3])
    }

    @Test func 홀을_옮기면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.selectPar(4)

        viewModel.goToNextHole()

        #expect(spy.published.last?.currentHoleIndex == 1)
        #expect(spy.published.last?.holeScores == [0, 0])
    }

    @Test func 홀을_건너뛰면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.selectPar(4)

        viewModel.skipCurrentHole()

        // 컴플리케이션과 크래시 복구가 이 값을 그대로 읽으므로, 파가 실제로 0으로
        // 되돌아간 스냅샷이 발행되어야 한다.
        #expect(spy.published.last?.currentHoleIndex == 1)
        #expect(spy.published.last?.holePars == [0, 0])
    }

    @Test func 이동할_수_없는_이전홀은_스냅샷을_발행하지_않는다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.start()
        let countAfterStart = spy.published.count

        viewModel.goToPreviousHole()

        #expect(spy.published.count == countAfterStart)
    }

    /// 종료 확인만으로는 스냅샷을 지우지 않는다 — 실제로 지우는 시점은 `saveAndTransmit()`이다
    /// (전송 성공 또는 0홀 폐기, Task 6).
    @Test func finishRound하면_요약으로_전환되고_스냅샷은_아직_남는다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.start()

        viewModel.finishRound()

        #expect(viewModel.phase == .summary)
        #expect(spy.clearCallCount == 0)
    }

    @Test func 스냅샷으로_라운드를_복구한다() {
        let snapshot = RoundSnapshot(startedAt: startedAt,
                                     courseName: "복구CC",
                                     currentHoleIndex: 2,
                                     holeScores: [4, 3, 2],
                                     holePars: [4, 3, 5],
                                     puttCounts: [2, 1, 1])

        let viewModel = RoundViewModel(resuming: snapshot, publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.startedAt == startedAt)
        #expect(viewModel.courseName == "복구CC")
        #expect(viewModel.currentHoleNumber == 3)
        #expect(viewModel.currentScore == 2)
        #expect(viewModel.currentPar == 5)
        #expect(viewModel.currentPutts == 1)
        #expect(viewModel.totalStrokes == 9)
        #expect(viewModel.phase == .counting)
        #expect(viewModel.inputMode == .swing)
    }

    @Test func 복구한_라운드에서_이어서_카운트할_수_있다() {
        let snapshot = RoundSnapshot(startedAt: startedAt,
                                     courseName: nil,
                                     currentHoleIndex: 1,
                                     holeScores: [4, 3],
                                     holePars: [4, 3],
                                     puttCounts: [2, 1])
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = RoundViewModel(resuming: snapshot, publisher: spy)

        viewModel.incrementStroke()

        #expect(viewModel.currentScore == 4)
        #expect(spy.published.last?.holeScores == [4, 4])
    }

    /// 배열 길이가 어긋난 스냅샷(외부 저장소에서 온 값)이 인덱스 크래시를 내지 않아야 한다.
    @Test func 길이가_어긋난_스냅샷도_안전하게_복구한다() {
        let snapshot = RoundSnapshot(startedAt: startedAt,
                                     courseName: nil,
                                     currentHoleIndex: 3,
                                     holeScores: [4],
                                     holePars: [],
                                     puttCounts: [])

        let viewModel = RoundViewModel(resuming: snapshot, publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.currentHoleNumber == 4)
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.currentPutts == 0)
        #expect(viewModel.phase == .parSelection)
    }
}
