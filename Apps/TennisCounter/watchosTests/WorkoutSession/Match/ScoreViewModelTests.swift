import Foundation
@testable import TennisCounter_Watch_App
import Testing

struct ScoreViewModelTests {
    @Test(arguments: [
        (0, 0, 0, 0, false),
        (0, 0, 1, 1, true),
        (0, 0, 5, 5, true),
        (0, 0, 5, 4, false),
        (0, 0, 4, 5, false),
        (1, 0, 5, 5, false),
        (0, 1, 5, 5, false),
        (1, 1, 0, 0, true),
    ])
    @MainActor func manualDrawRequiresTiedSetsAndGames(
        mySets: Int, yourSets: Int, myGames: Int, yourGames: Int, allowed: Bool
    ) {
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false))
        vm.mySetScore = mySets
        vm.yourSetScore = yourSets
        vm.myGameScore = myGames
        vm.yourGameScore = yourGames
        vm.completedSets = Array(repeating: SetScore(my: 6, your: 4), count: mySets)
            + Array(repeating: SetScore(my: 4, your: 6), count: yourSets)
        var result: MatchResult?
        vm.onMatchFinished = { value, _ in result = value }

        #expect(vm.canFinishAsDraw == allowed)
        vm.finishAsDraw()

        #expect(result == (allowed ? .draw : nil))
    }

    @Test @MainActor func manualDrawPreservesFiveAllAndFinishesOnce() {
        let haptics = HapticsSpy()
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), haptics: haptics)
        var results: [MatchResult] = []
        var sets: [SetScore] = []
        vm.onMatchFinished = { result, scores in
            results.append(result)
            sets = scores
        }
        for _ in 0 ..< 5 {
            for side in [PlayerSide.me, .opponent] {
                for _ in 0 ..< 4 {
                    vm.addPoint(side)
                }
            }
        }

        vm.finishAsDraw()
        vm.finishAsDraw()

        #expect(results == [.draw])
        #expect(sets.count == 1)
        #expect(sets.first?.my == 5)
        #expect(sets.first?.your == 5)
        #expect(vm.mySetScore == 0)
        #expect(vm.yourSetScore == 0)
        #expect(!vm.canFinishAsDraw)
        #expect(haptics.played.count(where: { $0 == .matchFinished(.draw) }) == 1)
    }

    @Test @MainActor func manualDrawRequiresTiedPoints() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.myGameScore = 5
        vm.yourGameScore = 5
        vm.addPoint(.me)
        var result: MatchResult?
        vm.onMatchFinished = { value, _ in result = value }

        #expect(!vm.canFinishAsDraw)
        vm.finishAsDraw()
        #expect(result == nil)
        #expect(vm.completedSets.isEmpty)

        vm.addPoint(.opponent)
        #expect(vm.canFinishAsDraw)
    }

    @Test @MainActor func manualDrawRejectsUnequalTieBreakPoints() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.myGameScore = 6
        vm.yourGameScore = 6
        vm.score.setTieBreakMode()
        vm.addPoint(.me)
        var result: MatchResult?
        vm.onMatchFinished = { value, _ in result = value }

        vm.finishAsDraw()
        #expect(result == nil)

        vm.addPoint(.opponent)
        vm.finishAsDraw()
        #expect(result == .draw)
        #expect(vm.completedSets.first?.my == 6)
        #expect(vm.completedSets.first?.your == 6)
    }

    @Test @MainActor func manualDrawBetweenTiedSetsDoesNotAppendAnEmptySet() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false))
        vm.mySetScore = 1
        vm.yourSetScore = 1
        vm.completedSets = [SetScore(my: 6, your: 4), SetScore(my: 4, your: 6)]
        var result: MatchResult?
        vm.onMatchFinished = { value, _ in result = value }

        vm.finishAsDraw()

        #expect(result == .draw)
        #expect(vm.completedSets.count == 2)
        #expect(vm.completedSets.last?.my == 4)
        #expect(vm.completedSets.last?.your == 6)
    }

    @Test @MainActor func resetAfterManualDrawAllowsAnotherTiedMatch() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.myGameScore = 5
        vm.yourGameScore = 5
        vm.finishAsDraw()

        vm.resetAll(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        #expect(!vm.canFinishAsDraw)
        vm.myGameScore = 1
        vm.yourGameScore = 1
        var result: MatchResult?
        vm.onMatchFinished = { value, _ in result = value }

        #expect(vm.canFinishAsDraw)
        vm.finishAsDraw()
        #expect(result == .draw)
        #expect(vm.completedSets.count == 1)
        #expect(vm.completedSets.first?.my == 1)
    }

    @Test @MainActor func manualDrawDoesNotFinishAnAutomaticDrawTwice() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true))
        var results: [MatchResult] = []
        vm.onMatchFinished = { result, _ in results.append(result) }
        for _ in 0 ..< 6 {
            for side in [PlayerSide.me, .opponent] {
                for _ in 0 ..< 4 {
                    vm.addPoint(side)
                }
            }
        }

        #expect(!vm.canFinishAsDraw)
        vm.finishAsDraw()

        #expect(results == [.draw])
        #expect(vm.completedSets.count == 1)
    }

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

    // MARK: - 매치 타이브레이크 (3세트 대체 10점)

    @Test @MainActor func watchMatchTieBreak_startsAtOneAllInBestOfThree() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: true))
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        } // Set 1: 6-0 me
        for _ in 0 ..< 6 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        } // Set 2: 0-6 opponent

        #expect(vm.score.gameMode == .tieBreak)
        #expect(vm.myGameScore == 0)
        #expect(vm.yourGameScore == 0)
        #expect(vm.mySetScore == 1)
        #expect(vm.yourSetScore == 1)
    }

    @Test @MainActor func watchMatchTieBreak_notStartedWhenOptionOff() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: false))
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }

        #expect(vm.score.gameMode == .normal)
    }

    @Test @MainActor func watchMatchTieBreak_notStartedWhenMatchAlreadyDecided() {
        var result: MatchResult?
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: true))
        vm.onMatchFinished = { value, _ in result = value }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }

        #expect(result == .win)
        #expect(vm.score.gameMode == .normal)
    }

    @Test @MainActor func watchMatchTieBreak_startsEvenWithNoTieRuleOn() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: true, matchTieBreak: true))
        for _ in 0 ..< 4 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        } // Set 1: 6-4 me
        for _ in 0 ..< 4 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        } // Set 2: 4-6 opponent

        #expect(vm.score.gameMode == .tieBreak)
        #expect(vm.mySetScore == 1)
        #expect(vm.yourSetScore == 1)
    }

    @Test @MainActor func watchMatchTieBreak_winEndsMatchAndRecordsPoints() {
        var result: MatchResult?
        var sets: [SetScore] = []
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: true))
        vm.onMatchFinished = { value, scores in result = value; sets = scores }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.score.gameMode == .tieBreak)

        for _ in 0 ..< 7 {
            vm.addPoint(.opponent)
        }
        for _ in 0 ..< 10 {
            vm.addPoint(.me)
        } // 10-7 me

        #expect(result == .win)
        #expect(sets.last?.my == 10)
        #expect(sets.last?.your == 7)
        #expect(vm.mySetScore == 2)
        #expect(vm.myGameScore == 0)
        #expect(vm.yourGameScore == 0)
    }

    @Test @MainActor func watchMatchTieBreak_lossRecordsLoss() {
        var result: MatchResult?
        var sets: [SetScore] = []
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: true))
        vm.onMatchFinished = { value, scores in result = value; sets = scores }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }

        for _ in 0 ..< 8 {
            vm.addPoint(.me)
        }
        for _ in 0 ..< 10 {
            vm.addPoint(.opponent)
        } // 8-10 opponent

        #expect(result == .loss)
        #expect(sets.last?.my == 8)
        #expect(sets.last?.your == 10)
    }

    @Test @MainActor func watchMatchTieBreak_continuesPastNineAll() {
        var result: MatchResult?
        var sets: [SetScore] = []
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: true))
        vm.onMatchFinished = { value, scores in result = value; sets = scores }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }

        for _ in 0 ..< 9 {
            vm.addPoint(.me); vm.addPoint(.opponent)
        } // 9-9
        #expect(result == nil)

        vm.addPoint(.me) // 10-9
        #expect(result == nil)
        vm.addPoint(.me) // 11-9

        #expect(result == .win)
        #expect(sets.last?.my == 11)
        #expect(sets.last?.your == 9)
    }

    @Test @MainActor func watchMatchTieBreak_undoOfWinningPointRestoresTarget() {
        var result: MatchResult?
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: true))
        vm.onMatchFinished = { value, _ in result = value }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }

        for _ in 0 ..< 7 {
            vm.addPoint(.opponent)
        }
        for _ in 0 ..< 10 {
            vm.addPoint(.me)
        } // 10-7 me, match over
        #expect(result == .win)

        vm.undo() // 9-7
        vm.undo() // 8-7

        #expect(vm.score.gameMode == .tieBreak)
        #expect(vm.score.myDisplayScore == "8")
        #expect(vm.score.yourDisplayScore == "7")

        result = nil
        vm.addPoint(.me) // 9-7 — 목표가 7로 되돌아갔다면 diff 2로 여기서 끝나야 하지만, 10이 유지되므로 계속된다

        #expect(result == nil)

        vm.addPoint(.me) // 10-7 — 목표 10 유지 확인

        #expect(result == .win)
    }

    @Test @MainActor func watchMatchTieBreak_undoOfFirstPointReturnsToSetTwoEnd() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: true))
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        } // Set 1: 6-0 me

        for _ in 0 ..< 5 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        } // 5 games
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent) // 40-0 in the 6th game
        vm.addPoint(.opponent) // wins the 6th game 6-0, finishes Set 2 → 1-1, enters match tiebreak

        #expect(vm.score.gameMode == .tieBreak)
        #expect(vm.mySetScore == 1)
        #expect(vm.yourSetScore == 1)

        vm.undo()

        #expect(vm.score.gameMode == .normal)
        #expect(vm.mySetScore == 1)
        #expect(vm.yourSetScore == 0)
        #expect(vm.yourGameScore == 5)
        #expect(vm.score.yourDisplayScore == "40")
    }

    @Test @MainActor func watchNoTieDrawAtSixAll_endsMatchBeforeMatchTieBreak() {
        var result: MatchResult?
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: true, matchTieBreak: true))
        vm.onMatchFinished = { value, _ in result = value }
        for _ in 0 ..< 4 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        } // Set 1: 6-4 me

        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        } // Set 2: 6-6, noTieRule → draw

        #expect(result == .draw)
        #expect(vm.score.gameMode == .normal)
    }

    @Test @MainActor func watchMatchTieBreak_finishesOnceThroughCallback() {
        var results: [MatchResult] = []
        var sets: [SetScore] = []
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, matchTieBreak: true))
        vm.onMatchFinished = { value, scores in results.append(value); sets = scores }
        for _ in 0 ..< 6 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        for _ in 0 ..< 6 {
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }

        for _ in 0 ..< 7 {
            vm.addPoint(.opponent)
        }
        for _ in 0 ..< 10 {
            vm.addPoint(.me)
        } // 10-7 me

        #expect(results == [.win])
        #expect(sets.last?.my == 10)
        #expect(sets.last?.your == 7)
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
