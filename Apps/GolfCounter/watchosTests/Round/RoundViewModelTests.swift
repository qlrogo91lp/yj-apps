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

@MainActor
struct RoundViewModelHoleFlowTests {
    private func makeViewModel() -> RoundViewModel {
        RoundViewModel(startedAt: Date(timeIntervalSince1970: 1000),
                       publisher: RoundSnapshotPublisherSpy())
    }

    @Test func 파가_없으면_파선택_단계다() {
        let viewModel = makeViewModel()

        #expect(viewModel.phase == .parSelection)
    }

    @Test func 파를_고르면_카운팅_단계로_넘어간다() {
        let viewModel = makeViewModel()

        viewModel.selectPar(4)

        #expect(viewModel.currentPar == 4)
        #expect(viewModel.phase == .counting)
    }

    @Test func 파편집을_시작하면_파선택_단계로_되돌아간다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)

        viewModel.beginParEditing()

        #expect(viewModel.phase == .parSelection)
    }

    @Test func 파를_다시_고르면_편집이_끝난다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.beginParEditing()

        viewModel.selectPar(5)

        #expect(viewModel.currentPar == 5)
        #expect(viewModel.phase == .counting)
    }

    @Test func 다음홀로_가면_새_홀은_값이_0이고_파선택_단계다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.goToNextHole()

        #expect(viewModel.currentHoleNumber == 2)
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.phase == .parSelection)
    }

    @Test func 홀_이동은_입력모드를_스윙으로_되돌린다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.inputMode = .putt

        viewModel.goToNextHole()

        #expect(viewModel.inputMode == .swing)
    }

    @Test func 파가_이미_있는_홀로_돌아가면_바로_카운팅_단계다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.goToNextHole()
        viewModel.selectPar(3)

        viewModel.goToPreviousHole()

        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
        #expect(viewModel.currentScore == 1)
        #expect(viewModel.phase == .counting)
    }

    @Test func 첫홀에서는_이전홀로_갈_수_없다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)

        #expect(viewModel.canGoToPreviousHole == false)
        viewModel.goToPreviousHole()
        #expect(viewModel.currentHoleNumber == 1)
    }

    @Test func 이전홀로_이동_중이던_파편집은_취소된다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.beginParEditing()

        viewModel.goToPreviousHole()

        #expect(viewModel.phase == .counting)
    }

    @Test func 누적_타수와_오버파를_홀에_걸쳐_합산한다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        for _ in 0 ..< 5 { viewModel.incrementStroke() }
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        for _ in 0 ..< 3 { viewModel.incrementStroke() }

        #expect(viewModel.totalStrokes == 8)
        #expect(viewModel.relativeToPar == 1)
    }
}
