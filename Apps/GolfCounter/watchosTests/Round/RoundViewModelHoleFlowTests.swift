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

    @Test func 이미_점수가_있던_홀의_파_재편집_중_취소는_아무것도_제거하지_않는다() {
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

        // 일반 goToPreviousHole()과 동일하게 동작해, hole 1로 이동하되 hole 2 데이터는 보존되어야 한다.
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

    // MARK: - skipCurrentHole (미타구 홀 건너뛰기)

    @Test func 건너뛰기_파를0으로_되돌리고_다음홀로_간다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)

        viewModel.skipCurrentHole()

        #expect(viewModel.currentHoleNumber == 2)
        // 파가 0으로 돌아갔으므로 건너뛴 홀은 기록 홀 수에 잡히지 않는다.
        #expect(viewModel.recordedHoleCount == 0)
        // 새 홀은 파가 없으므로 다시 파 선택 화면이다.
        #expect(viewModel.phase == .parSelection)
    }

    @Test func 건너뛰기_타수가있으면_아무일도_없다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.skipCurrentHole()

        // 이미 친 홀은 건너뛸 수 없다 — 파가 지워지면 그 타수가 미아가 된다.
        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
        #expect(viewModel.currentScore == 1)
    }

    @Test func 건너뛰기_마지막홀에서는_아무일도_없다() {
        // 이 파일의 makeViewModel()은 holeCount를 받지 않으므로 직접 만든다.
        let viewModel = RoundViewModel(holeCount: 1,
                                       startedAt: Date(timeIntervalSince1970: 1000),
                                       publisher: RoundSnapshotPublisherSpy())
        viewModel.selectPar(4)

        viewModel.skipCurrentHole()

        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
    }

    @Test func 건너뛴홀은_오버파에도_잡히지_않는다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.skipCurrentHole()
        viewModel.selectPar(3)
        for _ in 0 ..< 4 {
            viewModel.incrementStroke()
        }

        // 1번 홀은 건너뛰었으므로 2번 홀의 +1만 남는다.
        #expect(viewModel.relativeToPar == 1)
        #expect(viewModel.recordedHoleCount == 1)
    }
}
