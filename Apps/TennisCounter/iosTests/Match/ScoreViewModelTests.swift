@testable import TennisCounter
import Testing

struct ScoreViewModelTests {
    @Test @MainActor func addPointWinsGame() {
        let vm = ScoreViewModel()
        // 4번 탭하면 게임 승리 (noAdRule=true 기본값: 0→15→30→40→win)
        vm.addPoint(.me)
        vm.addPoint(.me)
        vm.addPoint(.me)
        vm.addPoint(.me)
        #expect(vm.myGameScore == 1)
        #expect(vm.score.myDisplayScore == "0")
    }

    @Test @MainActor func addPointOpponentWinsGame() {
        let vm = ScoreViewModel()
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        #expect(vm.yourGameScore == 1)
        #expect(vm.myGameScore == 0)
    }

    @Test @MainActor func addPointUndoResetsScore() {
        let vm = ScoreViewModel()
        vm.addPoint(.me) // 15-0
        vm.undo()
        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.score.lastAction == .none)
    }

    @Test @MainActor func addPointMatchOver() {
        let vm = ScoreViewModel()
        // oneSet: 6게임 이기면 매치 종료
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        #expect(vm.isMatchOver == true)
        #expect(vm.didWin == true)
        #expect(vm.mySetScore == 1)
        #expect(vm.myGameScore == 0)
    }

    @Test @MainActor func undoAfterGameWinIsNoOp() {
        let vm = ScoreViewModel()
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me) // game won
        let gameScoreBefore = vm.myGameScore
        vm.undo() // undo cannot reverse a game-winning tap
        #expect(vm.myGameScore == gameScoreBefore) // game score unchanged
    }
}
