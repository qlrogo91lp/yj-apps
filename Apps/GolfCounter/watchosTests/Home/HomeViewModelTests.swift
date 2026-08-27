import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct HomeViewModelTests {
    private func snapshot() -> RoundSnapshot {
        RoundSnapshot(holeCount: 9,
                      startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: nil,
                      currentHoleIndex: 1,
                      holeScores: [4, 0],
                      holePars: [4, 0],
                      puttCounts: [2, 0])
    }

    @Test func 스냅샷이_있으면_그_라운드로_복구한다() {
        let publisher = RoundSnapshotPublisherSpy()
        publisher.stored = snapshot()
        let viewModel = HomeViewModel(publisher: publisher)

        viewModel.resumeIfNeeded()

        #expect(viewModel.isRoundActive)
        #expect(viewModel.resumingSnapshot?.holeCount == 9)
    }

    @Test func 스냅샷이_없으면_아무것도_하지_않는다() {
        let viewModel = HomeViewModel(publisher: RoundSnapshotPublisherSpy())

        viewModel.resumeIfNeeded()

        #expect(viewModel.isRoundActive == false)
        #expect(viewModel.resumingSnapshot == nil)
    }

    @Test func 복구_시도는_앱_실행당_한_번뿐이다() {
        // 요약에서 전송 없이 나오면 스냅샷이 남는다. 가드가 없으면 홈에 도착하자마자
        // 다시 라운드로 끌려 들어가 빠져나올 수 없다.
        let publisher = RoundSnapshotPublisherSpy()
        publisher.stored = snapshot()
        let viewModel = HomeViewModel(publisher: publisher)
        viewModel.resumeIfNeeded()
        viewModel.isRoundActive = false

        viewModel.resumeIfNeeded()

        #expect(viewModel.isRoundActive == false)
    }

    @Test func 홀수_토글은_18과_9를_오간다() {
        let viewModel = HomeViewModel(publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.holeCount == 18)

        viewModel.toggleHoleCount()
        #expect(viewModel.holeCount == 9)

        viewModel.toggleHoleCount()
        #expect(viewModel.holeCount == 18)
    }

    @Test func 새_라운드를_시작하면_복구_스냅샷을_비운다() {
        let publisher = RoundSnapshotPublisherSpy()
        publisher.stored = snapshot()
        let viewModel = HomeViewModel(publisher: publisher)
        viewModel.resumeIfNeeded()

        viewModel.startNewRound()

        #expect(viewModel.resumingSnapshot == nil)
        #expect(viewModel.isRoundActive)
    }

    @Test func 진행중_라운드가_남아있는지_알려준다() {
        let publisher = RoundSnapshotPublisherSpy()
        let viewModel = HomeViewModel(publisher: publisher)

        #expect(viewModel.hasPendingRound == false)

        publisher.stored = snapshot()
        #expect(viewModel.hasPendingRound)
    }
}
