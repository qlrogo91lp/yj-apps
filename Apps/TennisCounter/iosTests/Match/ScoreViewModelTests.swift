@testable import TennisCounter
import Foundation
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

    // MARK: - ScoreViewModel 버그 재현 + 통일 로직

    @Test @MainActor func noEarlyEndAt_T6_7to6_noTie() {
        // iOS 버그: noTieRule=true에서 7-6이 세트 종료로 오판정되는 것을 방지
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6))
        for _ in 0..<6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        // 6-6에서 noTie → 무승부 처리됨, 7번째 게임 진행 불가 확인은 drawAt_T6_noTie에서
        // 실제로는 6-6에서 멈춰야 함 (draw)
        #expect(vm.isMatchOver == true)
        #expect(vm.matchResult == .draw)
    }

    @Test @MainActor func drawAt_T6_noTie() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6))
        for _ in 0..<6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.matchResult == .draw)
        #expect(vm.isMatchOver == true)
    }

    @Test @MainActor func tiebreakStartsAt_T6() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 6))
        for _ in 0..<6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.isTieBreak == true)
        #expect(vm.isMatchOver == false)
    }

    @Test @MainActor func setWinsAt_T5_5to3() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0..<3 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        #expect(vm.isMatchOver == true)
        #expect(vm.matchResult == .win)
    }

    @Test @MainActor func setWinsAt_T5_6to4() {
        // T=5에서 5-4 이후 6-4 (2게임 차, 임계값 초과)
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0..<4 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        // me 5번째 (5-4)
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        #expect(vm.isMatchOver == false)  // 5-4는 아직 종료 아님
        // me 6번째 (6-4) → 2게임 차, 세트 승리
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        #expect(vm.isMatchOver == true)
        #expect(vm.matchResult == .win)
    }

    @Test @MainActor func tiebreakStartsAt_T5() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0..<5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.isTieBreak == true)
        #expect(vm.isMatchOver == false)
    }

    @Test @MainActor func drawAt_T5_noTie() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 5))
        for _ in 0..<5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.matchResult == .draw)
        #expect(vm.isMatchOver == true)
    }

    @Test @MainActor func resetAllClearsStateAndAppliesNewOptions() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.myGameScore = 3
        vm.mySetScore = 1
        vm.completedSets = [(my: 6, your: 4)]

        let newOptions = MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false)
        vm.resetAll(options: newOptions)

        #expect(vm.myGameScore == 0)
        #expect(vm.yourGameScore == 0)
        #expect(vm.mySetScore == 0)
        #expect(vm.yourSetScore == 0)
        #expect(vm.completedSets.isEmpty)
        #expect(vm.matchResult == nil)
        #expect(vm.options.mode == .bestOfThree)
        #expect(vm.score.noAdRule == false)
    }

    // 누수 진단: 강한 참조를 놓으면 ScoreViewModel이 해제되는지 검증.
    // 통과 → VM 자체엔 retain cycle 없음(앱에서 deinit 안 보이는 건 SwiftUI StateObject 보유 때문).
    // 실패 → VM 내부에 실제 retain cycle 존재.
    @Test @MainActor func scoreViewModelDeallocatesWhenReleased() {
        weak var weakVM: ScoreViewModel?
        autoreleasepool {
            let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
            weakVM = vm
            #expect(weakVM != nil)
        }
        #expect(weakVM == nil)
    }
}
