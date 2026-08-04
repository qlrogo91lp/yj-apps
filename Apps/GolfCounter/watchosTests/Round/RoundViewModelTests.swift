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

    @Test func 스윙모드_감소는_타수를_내린다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke()
        viewModel.incrementStroke()

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 1)
    }

    @Test func 스윙모드_감소는_퍼팅수_아래로_내려가지_않는다() {
        let viewModel = makeViewModel()
        viewModel.inputMode = .putt
        viewModel.incrementStroke()
        viewModel.incrementStroke()
        viewModel.inputMode = .swing

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 2)
        #expect(viewModel.currentPutts == 2)
    }

    @Test func 스윙모드_감소는_0아래로_내려가지_않는다() {
        let viewModel = makeViewModel()

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 0)
    }

    @Test func 퍼팅모드_감소는_타수와_퍼팅을_함께_내린다() {
        let viewModel = makeViewModel()
        viewModel.inputMode = .putt
        viewModel.incrementStroke()
        viewModel.inputMode = .swing
        viewModel.incrementStroke()
        viewModel.inputMode = .putt

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 0)
    }

    @Test func 퍼팅이_0이면_퍼팅모드_감소는_아무것도_바꾸지_않는다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke()
        viewModel.inputMode = .putt

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 0)
    }

    @Test func 타수에_상한이_없다() {
        let viewModel = makeViewModel()

        for _ in 0 ..< 15 { viewModel.incrementStroke() }

        #expect(viewModel.currentScore == 15)
    }
}
