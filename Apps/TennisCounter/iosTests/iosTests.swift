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

    @Test func workoutMetricsFormattedElapsedUnderHour() {
        let metrics = WorkoutMetrics(elapsedSeconds: 754) // 12분 34초
        #expect(metrics.formattedElapsed == "12:34")
    }

    @Test func workoutMetricsFormattedElapsedOverHour() {
        let metrics = WorkoutMetrics(elapsedSeconds: 3724) // 1시간 2분 4초
        #expect(metrics.formattedElapsed == "1:02:04")
    }

    // MARK: - ScoreViewModel addPoint

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

    // MARK: - WorkoutSessionViewModel

    @Test @MainActor func matchSessionStartMatchSetsPlayingPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        guard case .playing(let options) = vm.phase else {
            Issue.record("Expected .playing phase")
            return
        }
        #expect(options.mode == .oneSet)
        #expect(options.noAdRule == true)
    }

    @Test @MainActor func matchSessionFinishMatchSetsFinishedPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
        guard case .finished(let session) = vm.phase else {
            Issue.record("Expected .finished phase")
            return
        }
        #expect(session.result == .win)
        #expect(session.completedSets.count == 1)
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 0)
    }

    @Test @MainActor func matchSessionStartNewMatchResetsToModeSelection() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false))
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after startNewMatch")
            return
        }
    }

    @Test @MainActor func matchSessionEndSessionResetsState() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endSession()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after endSession")
            return
        }
        #expect(vm.elapsedSeconds == 0)
    }

    @Test @MainActor func matchSessionPauseStopsTimer() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.pauseSession()
        #expect(vm.isPaused == true)
        vm.resumeSession()
        #expect(vm.isPaused == false)
    }

    @Test @MainActor func matchSessionRestartMatchUsesSameFormat() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: true))
        vm.finishMatch(didWin: false, completedSets: [(my: 3, your: 6)])
        vm.restartMatch()
        guard case let .playing(newOptions) = vm.phase else {
            Issue.record("Expected .playing after restartMatch")
            return
        }
        #expect(newOptions.mode == .bestOfThree)
    }

    @Test @MainActor func matchSessionRestartWithoutMatchIsNoOp() {
        let vm = WorkoutSessionViewModel()
        vm.restartMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection — restartMatch without prior match should be no-op")
            return
        }
    }

    @Test @MainActor func matchSessionSaveWithNoSessionIsNoOp() {
        let vm = WorkoutSessionViewModel()
        vm.saveCurrentMatch() // _currentSession nil이면 guard에서 리턴
    }

    @Test @MainActor func matchSessionFinishMatchStoresSession() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
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
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after startNewMatch")
            return
        }
    }

    // MARK: - WorkoutSessionViewModel (워크아웃 종료 동기화)

    @Test @MainActor func workoutSessionRemoteWorkoutEndedDefaultsFalse() {
        let vm = WorkoutSessionViewModel()
        #expect(vm.remoteWorkoutEnded == false)
    }

    @Test @MainActor func workoutSessionEndSessionDuringPlayingResetsPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endSession()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after remote workout end triggers endSession")
            return
        }
        #expect(vm.elapsedSeconds == 0)
        #expect(vm.isPaused == false)
    }

    @Test @MainActor func workoutSessionEndSessionAfterFinishedResetsPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
        vm.endSession()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after endSession from .finished state")
            return
        }
    }

    @Test @MainActor func workoutSessionEndSessionResetsMetrics() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endSession()
        #expect(vm.metrics.calories == 0)
        #expect(vm.metrics.heartRate == 0)
    }
}
