@testable import TennisCounter
import Testing

struct WorkoutSessionViewModelTests {
    @Test @MainActor func matchSessionStartMatchSetsPlayingPhase() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        guard case let .playing(options) = vm.phase else {
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
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        guard case let .finished(session) = vm.phase else {
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
        vm.finishMatch(result: .loss, completedSets: [(my: 3, your: 6)])
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
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        guard case let .finished(session) = vm.phase else {
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
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after startNewMatch")
            return
        }
    }

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
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
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

    @Test @MainActor func startOwnMatchClearsStaleRemoteScoreState() {
        let service = WatchConnectivityService.shared
        service.receivedScoreState = ScoreState(
            myScore: 15, yourScore: 0,
            myGameScore: 3, yourGameScore: 2,
            mySetScore: 1, yourSetScore: 0,
            completedSets: [], isTieBreak: false
        )
        defer { service.receivedScoreState = nil }

        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: false)

        #expect(service.receivedScoreState == nil)
    }

    @Test @MainActor func remoteMatchStartDoesNotClearScoreState() {
        let service = WatchConnectivityService.shared
        let existing = ScoreState(
            myScore: 15, yourScore: 0,
            myGameScore: 3, yourGameScore: 2,
            mySetScore: 1, yourSetScore: 0,
            completedSets: [], isTieBreak: false
        )
        service.receivedScoreState = existing
        defer { service.receivedScoreState = nil }

        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true)

        #expect(service.receivedScoreState != nil)
    }

    @Test @MainActor func restartMatchResetsScoreVM() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.scoreVM.myGameScore = 3
        vm.scoreVM.mySetScore = 1
        vm.scoreVM.completedSets = [(my: 6, your: 4)]

        vm.restartMatch()

        #expect(vm.scoreVM.myGameScore == 0)
        #expect(vm.scoreVM.mySetScore == 0)
        #expect(vm.scoreVM.completedSets.isEmpty)
    }

    @Test @MainActor func startMatchAppliesOptionsToScoreVM() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false))
        #expect(vm.scoreVM.options.mode == .bestOfThree)
        #expect(vm.scoreVM.score.noAdRule == false)
    }

    @Test @MainActor func driverIgnoresRemoteScoreState() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // isDriver = true
        vm.scoreVM.myGameScore = 2
        vm.applyIncomingScoreStateForTest(ScoreState(
            myScore: 0, yourScore: 0, myGameScore: 5, yourGameScore: 5,
            mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false
        ))
        #expect(vm.scoreVM.myGameScore == 2) // driver는 덮어쓰지 않음
    }

    @Test @MainActor func mirrorAppliesRemoteScoreState() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.applyIncomingScoreStateForTest(ScoreState(
            myScore: 30, yourScore: 15, myGameScore: 3, yourGameScore: 2,
            mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false
        ))
        #expect(vm.scoreVM.myGameScore == 3)
        #expect(vm.scoreVM.score.myScore == 30)
    }
}
