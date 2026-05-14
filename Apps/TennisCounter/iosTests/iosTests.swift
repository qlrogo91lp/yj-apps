//
//  iosTests.swift
//  iosTests
//
//  Created by yj on 4/29/26.
//

@testable import TennisCounter
import Testing

struct iosTests {
    @Test func example() {}

    // MARK: - WorkoutMetrics

    @Test func workoutMetricsParseValidDict() {
        let dict: [String: Any] = ["elapsed": 123.0, "calories": 456.0, "heartRate": 78.0]
        let metrics = WorkoutMetrics(from: dict)
        #expect(metrics != nil)
        #expect(metrics?.elapsedSeconds == 123.0)
        #expect(metrics?.calories == 456.0)
        #expect(metrics?.heartRate == 78.0)
    }

    @Test func workoutMetricsParsePartialDict() {
        let dict: [String: Any] = ["elapsed": 60.0]
        let metrics = WorkoutMetrics(from: dict)
        #expect(metrics != nil)
        #expect(metrics?.calories == 0)
        #expect(metrics?.heartRate == 0)
    }

    @Test func workoutMetricsParseEmptyDict() {
        let metrics = WorkoutMetrics(from: [:])
        #expect(metrics == nil)
    }

    @Test func workoutMetricsFormattedElapsed() {
        let metrics = WorkoutMetrics(elapsedSeconds: 3724)
        #expect(metrics.formattedElapsed == "62:04")
    }

    // MARK: - ScoreViewModel addPoint

    @Test @MainActor func addPointWinsGame() {
        let vm = ScoreViewModel(format: .oneSet)
        // 4번 탭하면 게임 승리 (noAdRule=true 기본값: 0→15→30→40→win)
        vm.addPoint(.me)
        vm.addPoint(.me)
        vm.addPoint(.me)
        vm.addPoint(.me)
        #expect(vm.myGameScore == 1)
        #expect(vm.score.myDisplayScore == "0")
    }

    @Test @MainActor func addPointOpponentWinsGame() {
        let vm = ScoreViewModel(format: .oneSet)
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        #expect(vm.yourGameScore == 1)
        #expect(vm.myGameScore == 0)
    }

    @Test @MainActor func addPointUndoResetsScore() {
        let vm = ScoreViewModel(format: .oneSet)
        vm.addPoint(.me) // 15-0
        vm.undo()
        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.score.lastAction == .none)
    }

    @Test @MainActor func addPointMatchOver() {
        let vm = ScoreViewModel(format: .oneSet)
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
        let vm = ScoreViewModel(format: .oneSet)
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me) // game won
        let gameScoreBefore = vm.myGameScore
        vm.undo() // undo cannot reverse a game-winning tap
        #expect(vm.myGameScore == gameScoreBefore) // game score unchanged
    }

    // MARK: - MatchSessionViewModel

    @Test @MainActor func matchSessionStartMatchSetsPlayingPhase() {
        let vm = MatchSessionViewModel()
        vm.startMatch(format: .oneSet)
        guard case .playing(let options) = vm.phase else {
            Issue.record("Expected .playing phase, got \(vm.phase)")
            return
        }
        #expect(options.mode == .oneSet)
        #expect(options.noAdRule == true)
    }

    @Test @MainActor func matchSessionFinishMatchSetsFinishedPhase() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .oneSet)
        vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
        guard case .finished(let session) = vm.phase else {
            Issue.record("Expected .finished phase, got \(vm.phase)")
            return
        }
        #expect(session.result == .win)
        #expect(session.completedSets.count == 1)
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 0)
    }

    @Test @MainActor func matchSessionStartNewMatchResetsToModeSelection() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .bestOfThree)
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after startNewMatch")
            return
        }
    }

    @Test @MainActor func matchSessionEndSessionResetsState() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .oneSet)
        vm.endSession()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after endSession")
            return
        }
        #expect(vm.elapsedSeconds == 0)
    }

    @Test @MainActor func matchSessionPauseStopsTimer() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.pauseSession()
        #expect(vm.isPaused == true)
        vm.resumeSession()
        #expect(vm.isPaused == false)
    }

    // MARK: - MatchSessionViewModel 확장 테스트

    @Test @MainActor func matchSessionRestartMatchUsesSameFormat() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .bestOfThree)
        vm.finishMatch(didWin: false, completedSets: [(my: 3, your: 6)])
        vm.restartMatch()
        guard case .playing(let options) = vm.phase else {
            Issue.record("Expected .playing after restartMatch, got \(vm.phase)")
            return
        }
        #expect(options.mode == .bestOfThree)
    }

    @Test @MainActor func matchSessionRestartWithoutMatchIsNoOp() {
        let vm = MatchSessionViewModel()
        vm.restartMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection — restartMatch without prior match should be no-op")
            return
        }
    }

    @Test @MainActor func matchSessionSaveWithNoSessionDoesNotThrow() throws {
        let vm = MatchSessionViewModel()
        try vm.saveCurrentMatch()
    }

    @Test @MainActor func matchSessionFinishMatchStoresSession() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .oneSet)
        vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
        guard case .finished(let session) = vm.phase else {
            Issue.record("Expected .finished")
            return
        }
        #expect(session.result == .win)
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 0)
        #expect(session.completedSets.count == 1)
    }

    @Test @MainActor func matchSessionStartNewMatchClearsToModeSelection() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .oneSet)
        vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after startNewMatch")
            return
        }
    }
}
