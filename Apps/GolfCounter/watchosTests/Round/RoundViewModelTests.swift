import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelTests {
    private func makeViewModel() -> RoundViewModel {
        RoundViewModel(startedAt: Date(timeIntervalSince1970: 1000),
                       publisher: RoundSnapshotPublisherSpy())
    }

    @Test func 시작하면_첫홀의_값이_모두_0이다() {
        let viewModel = makeViewModel()

        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.inputMode == .swing)
    }

    @Test func 스윙모드_증가는_타수만_올린다() {
        let viewModel = makeViewModel()

        viewModel.incrementStroke()
        viewModel.incrementStroke()

        #expect(viewModel.currentScore == 2)
        #expect(viewModel.currentPutts == 0)
    }

    @Test func 퍼팅모드_증가는_타수와_퍼팅을_함께_올린다() {
        let viewModel = makeViewModel()
        viewModel.inputMode = .putt

        viewModel.incrementStroke()

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 1)
    }

    @Test func 타수에_상한이_없다() {
        let viewModel = makeViewModel()

        for _ in 0 ..< 15 {
            viewModel.incrementStroke()
        }

        #expect(viewModel.currentScore == 15)
    }
}
