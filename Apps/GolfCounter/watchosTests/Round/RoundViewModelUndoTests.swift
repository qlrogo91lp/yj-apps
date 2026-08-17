import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelUndoTests {
    private func makeViewModel(spy: RoundSnapshotPublisherSpy = RoundSnapshotPublisherSpy()) -> RoundViewModel {
        RoundViewModel(startedAt: Date(timeIntervalSince1970: 1000), publisher: spy)
    }

    @Test func 시작하면_되돌릴게_없다() {
        let viewModel = makeViewModel()

        #expect(viewModel.canUndo == false)
    }

    @Test func 타수를_입력하면_되돌릴게_생긴다() {
        let viewModel = makeViewModel()

        viewModel.incrementStroke()

        #expect(viewModel.canUndo)
    }

    @Test func 스윙_입력을_되돌리면_타수만_내려간다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke()
        viewModel.incrementStroke()

        viewModel.undo()

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 0)
    }

    @Test func 퍼팅_입력을_되돌리면_타수와_퍼팅이_함께_내려간다() {
        let viewModel = makeViewModel()
        viewModel.inputMode = .putt
        viewModel.incrementStroke()

        viewModel.undo()

        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
    }

    /// 되돌리기는 입력의 정확한 역연산이다 — 모드가 바뀌어도 그때 친 종류대로 되돌린다.
    @Test func 연속_되돌리기는_입력의_역순으로_돌아간다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke() // 스윙
        viewModel.inputMode = .putt
        viewModel.incrementStroke() // 퍼팅
        viewModel.inputMode = .swing

        viewModel.undo() // 퍼팅이 되돌아가야 한다

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 0)

        viewModel.undo() // 스윙이 되돌아가야 한다

        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
        #expect(viewModel.canUndo == false)
    }

    @Test func 되돌릴게_없으면_되돌리기는_아무것도_바꾸지_않는다() {
        let viewModel = makeViewModel()

        viewModel.undo()

        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
    }

    /// 홀을 넘긴 뒤 되돌리면 화면이 통째로 이전 홀로 돌아가 예측이 안 된다.
    /// "지금 보고 있는 홀의 마지막 입력을 되돌린다"가 유일하게 예측 가능한 의미다 (spec §7).
    @Test func 다음홀로_이동하면_되돌릴게_없다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.goToNextHole()

        #expect(viewModel.canUndo == false)
    }

    @Test func 이전홀로_이동하면_되돌릴게_없다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.incrementStroke()

        viewModel.goToPreviousHole()

        #expect(viewModel.canUndo == false)
    }

    /// 복구 시점에는 되돌릴 대상을 모른다. 모르는 상태에서 되돌리는 것보다 안 뜨는 게 안전하다.
    @Test func 복구로_시작하면_되돌릴게_없다() {
        let snapshot = RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                                     courseName: nil,
                                     currentHoleIndex: 0,
                                     holeScores: [3],
                                     holePars: [4],
                                     puttCounts: [1])
        let viewModel = RoundViewModel(resuming: snapshot, publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.canUndo == false)
    }

    /// 파는 Par 버튼으로 언제든 고칠 수 있으므로 되돌리기 대상이 아니고,
    /// 파를 바꿔도 이미 친 타는 유효하므로 스택을 비우지도 않는다.
    @Test func 파를_고르는것은_되돌리기에_영향이_없다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke()

        viewModel.selectPar(5)

        #expect(viewModel.canUndo)
    }

    /// 이 파일의 핵심 회귀 테스트 — 2026-08-17 실기 검토에서 발견된 버그.
    /// 홀 1에서 친 뒤 홀 2로 넘어갔다가 홀 1로 돌아오면, 홀 1의 되돌리기가 살아있어야 한다.
    @Test func 홀을_옮겼다_돌아오면_그_홀의_되돌리기_기록이_남아있다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.incrementStroke()
        viewModel.goToNextHole()
        viewModel.selectPar(3)

        viewModel.goToPreviousHole()

        #expect(viewModel.canUndo)

        viewModel.undo()

        #expect(viewModel.currentScore == 1)
    }

    /// 퍼팅으로 친 것까지 정확히 기억한다 — 종류 정보가 홀을 넘나들며 유실되지 않는다.
    @Test func 홀을_옮겼다_돌아와도_입력_종류를_정확히_기억한다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.inputMode = .putt
        viewModel.incrementStroke()
        viewModel.inputMode = .swing
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.incrementStroke()

        viewModel.goToPreviousHole()
        viewModel.undo()

        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
    }

    /// 두 홀을 오가며 각각 되돌리기를 확인해도 서로 섞이지 않는다.
    @Test func 여러_홀_사이를_오가도_각_홀의_되돌리기가_독립적으로_유지된다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.incrementStroke()
        viewModel.incrementStroke()

        viewModel.goToPreviousHole()
        #expect(viewModel.canUndo)
        viewModel.goToNextHole()
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.currentScore == 1)
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.canUndo == false)
    }

    @Test func 되돌리면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.undo()

        #expect(spy.published.last?.holeScores == [0])
    }
}
