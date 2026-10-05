import Foundation
@testable import TennisCounter_Watch_App
import Testing

struct ScoreViewModelTests {

    @Test @MainActor func watchNoEarlyEndAt_T6_6to5_noTie() {
        // Watch 버그: noTieRule=true에서 6-5에 세트 종료되는 것 방지
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6)
        let vm = ScoreViewModel(options: options)
        var finishCalled = false
        vm.onMatchFinished = { _, _ in finishCalled = true }
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        #expect(vm.myGameScore == 6)
        #expect(vm.yourGameScore == 5)
        #expect(finishCalled == false)
    }

    @Test @MainActor func watchDrawAt_T6_noTie() {
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6)
        let vm = ScoreViewModel(options: options)
        var finishedResult: MatchResult?
        vm.onMatchFinished = { result, _ in finishedResult = result }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(finishedResult == .draw)
    }

    @Test @MainActor func watchTiebreakStartsAt_T5() {
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5)
        let vm = ScoreViewModel(options: options)
        var finishCalled = false
        vm.onMatchFinished = { _, _ in finishCalled = true }
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.score.gameMode == .tieBreak)
        #expect(finishCalled == false)
    }

    @Test @MainActor func watchDrawAt_T5_noTie() {
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 5)
        let vm = ScoreViewModel(options: options)
        var finishedResult: MatchResult?
        vm.onMatchFinished = { result, _ in finishedResult = result }
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(finishedResult == .draw)
    }

    // MARK: - 경기 전체 멀티 undo

    @Test @MainActor func watchUndoRewindsGamePointsToZero() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.addPoint(.me) // 15-0
        vm.addPoint(.opponent) // 15-15
        vm.addPoint(.me) // 30-15

        vm.undo(); vm.undo(); vm.undo()

        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.score.yourDisplayScore == "0")
        #expect(vm.canUndo == false)
    }

    @Test @MainActor func watchUndoBeyondMatchStartIsNoOp() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.undo() // 스택이 비어 있다
        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.canUndo == false)
    }

    @Test @MainActor func watchUndoReversesGameWin() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me) // 40-0
        vm.addPoint(.opponent) // 40-15
        vm.addPoint(.me) // 게임 획득 → 1-0
        #expect(vm.myGameScore == 1)

        vm.undo()

        #expect(vm.myGameScore == 0)
        #expect(vm.score.myDisplayScore == "40")
        #expect(vm.score.yourDisplayScore == "15")
    }

    @Test @MainActor func watchUndoReversesSetCompletion() {
        // bestOfThree(setsToWin=2)라 세트 1개를 따도 경기는 안 끝난다
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        #expect(vm.mySetScore == 1)
        #expect(vm.completedSets.count == 1)

        vm.undo() // 세트 경계를 넘어 되돌린다

        #expect(vm.mySetScore == 0)
        #expect(vm.completedSets.isEmpty)
        #expect(vm.myGameScore == 4)
        #expect(vm.score.myDisplayScore == "40")
    }

    @Test @MainActor func watchUndoReversesTieBreakEntry() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.score.gameMode == .tieBreak)

        vm.undo()

        #expect(vm.score.gameMode == .normal)
        #expect(vm.myGameScore == 5)
        #expect(vm.yourGameScore == 4)
        #expect(vm.score.yourDisplayScore == "40")
    }

    @Test @MainActor func watchUndoReversesTieBreakWin() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.score.gameMode == .tieBreak)
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me) // wins tie-break 7-0, closes the set
        #expect(vm.mySetScore == 1)
        #expect(vm.completedSets.count == 1)

        vm.undo() // undo the tie-break-winning point

        #expect(vm.mySetScore == 0)
        #expect(vm.completedSets.isEmpty)
        #expect(vm.score.gameMode == .tieBreak)
        #expect(vm.score.myDisplayScore == "6")
        #expect(vm.score.yourDisplayScore == "0")
    }

    @Test @MainActor func watchApplyRemoteStateClearsUndoStack() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.addPoint(.me)
        #expect(vm.canUndo == true)

        vm.applyRemoteState(ScoreState(
            myScore: 30, yourScore: 15,
            myGameScore: 2, yourGameScore: 1,
            mySetScore: 0, yourSetScore: 0,
            completedSets: [], isTieBreak: false
        ))

        #expect(vm.canUndo == false)
    }

    @Test @MainActor func resetAllClearsStateAndAppliesNewOptions() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.myGameScore = 3
        vm.mySetScore = 1
        vm.completedSets = [SetScore(my: 6, your: 4)]

        let newOptions = MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false)
        vm.resetAll(options: newOptions)

        #expect(vm.myGameScore == 0)
        #expect(vm.yourGameScore == 0)
        #expect(vm.mySetScore == 0)
        #expect(vm.yourSetScore == 0)
        #expect(vm.completedSets.isEmpty)
        #expect(vm.options.mode == .bestOfThree)
        #expect(vm.score.noAdRule == false)
        #expect(vm.canUndo == false)
    }

    @Test @MainActor func makeScoreStateIncludesInGamePoints() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.addPoint(.me) // 0 → 15
        let state = vm.makeScoreState()
        #expect(state.myScore == 15)
        #expect(state.myGameScore == 0)
    }

    /// 누수 진단: 강한 참조를 놓으면 ScoreViewModel이 해제되는지 검증.
    /// 통과 → VM 자체엔 retain cycle 없음(앱에서 deinit 안 보이는 건 SwiftUI StateObject 보유 때문).
    @Test @MainActor func scoreViewModelDeallocatesWhenReleased() {
        weak var weakVM: ScoreViewModel?
        autoreleasepool {
            let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
            vm.onMatchFinished = { _, _ in }
            weakVM = vm
            #expect(weakVM != nil)
        }
        #expect(weakVM == nil)
    }

}
