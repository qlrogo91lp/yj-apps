import Foundation
@testable import GolfCounter_Watch_App
import Testing

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
        for _ in 0 ..< 5 {
            viewModel.incrementStroke()
        }
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        for _ in 0 ..< 3 {
            viewModel.incrementStroke()
        }

        #expect(viewModel.totalStrokes == 8)
        #expect(viewModel.relativeToPar == 1)
    }

    // MARK: - cancelParEditing (재편집 취소)

    @Test func 파_재편집을_취소하면_홀을_옮기지_않고_카운팅으로_돌아간다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.incrementStroke()
        viewModel.beginParEditing()
        #expect(viewModel.phase == .parSelection)

        viewModel.cancelParEditing()

        #expect(viewModel.phase == .counting)
        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
        #expect(viewModel.currentScore == 2)
    }

    @Test func 파가_없는_홀에서_재편집_취소는_파선택_단계를_벗어나지_않는다() {
        let viewModel = makeViewModel()
        #expect(viewModel.phase == .parSelection)

        viewModel.cancelParEditing()

        #expect(viewModel.phase == .parSelection)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.currentHoleNumber == 1)
    }

    // MARK: - cancelToPreviousHole (phantom hole 정리)

    @Test func 실수로_다음홀에_진입한_뒤_취소하면_phantom_hole이_제거되고_이전홀_데이터가_그대로_남는다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        for _ in 0 ..< 5 {
            viewModel.incrementStroke()
        }
        viewModel.inputMode = .putt
        viewModel.incrementStroke()
        viewModel.inputMode = .swing

        // 실수로 "다음"을 눌러 hole 2(phantom hole, par == 0)가 생성됨.
        viewModel.goToNextHole()
        #expect(viewModel.currentHoleNumber == 2)
        #expect(viewModel.phase == .parSelection)

        // 파 선택 화면의 "이전" 버튼.
        viewModel.cancelToPreviousHole()

        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
        #expect(viewModel.currentScore == 6)
        #expect(viewModel.currentPutts == 1)
        #expect(viewModel.phase == .counting)
        // phantom hole이 배열에서 완전히 제거되어, 총 타수/오버파에 잔여 영향이 없어야 한다.
        #expect(viewModel.totalStrokes == 6)
        #expect(viewModel.relativeToPar == 2)
    }

    @Test func 재편집_중_cancelToPreviousHole은_phantom_hole을_제거하지_않고_이전홀로만_이동한다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.incrementStroke()
        viewModel.incrementStroke()

        // hole 2를 [Par] 버튼으로 재편집하는 중 (phantom hole이 아님).
        viewModel.beginParEditing()
        #expect(viewModel.phase == .parSelection)

        viewModel.cancelToPreviousHole()

        // 백버튼은 이제 cancelParEditing()으로 가므로 이 경로는 방어적 분기다.
        // 불릴 경우 일반 goToPreviousHole()과 동일하게, hole 1로 이동하되 hole 2 데이터는 보존한다.
        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
        #expect(viewModel.currentScore == 1)
        #expect(viewModel.totalStrokes == 3)

        viewModel.goToNextHole()
        #expect(viewModel.currentHoleNumber == 2)
        #expect(viewModel.currentPar == 3)
        #expect(viewModel.currentScore == 2)
    }

    @Test func 첫홀_파선택_화면에서_취소는_아무_효과가_없다() {
        let viewModel = makeViewModel()

        #expect(viewModel.canGoToPreviousHole == false)

        viewModel.cancelToPreviousHole()

        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.phase == .parSelection)
    }
}
