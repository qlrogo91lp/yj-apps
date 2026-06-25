@testable import TennisCounter_Watch_App
import Testing

struct WorkoutSessionViewModelTests {
    @Test @MainActor func finishMatchSetsPhaseImmediately() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .draw, completedSets: [])

        guard case .finished = vm.phase else {
            Issue.record("Expected .finished phase immediately after finishMatch")
            return
        }
    }

    @Test @MainActor func finishMatchPopulatesSetScores() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false))

        let sets = [
            SetScore(my: 6, your: 3),
            SetScore(my: 2, your: 6),
        ]
        vm.finishMatch(result: .draw, completedSets: sets)

        guard case let .finished(session) = vm.phase else {
            Issue.record("Expected .finished phase")
            return
        }
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 1)
    }

    @Test @MainActor func restartMatchReusesOptions() {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: true)
        vm.startMatch(options: options)
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 3)])

        vm.restartMatch()

        guard case let .playing(newOptions) = vm.phase else {
            Issue.record("Expected .playing phase after restartMatch")
            return
        }
        #expect(newOptions.mode == .bestOfThree)
        #expect(newOptions.noAdRule == false)
        #expect(newOptions.noTieRule == true)
    }

    @Test @MainActor func endWorkoutClearsCurrentSession() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        #expect(vm.currentSession() != nil)
        vm.endWorkout()
        #expect(vm.currentSession() == nil)
    }

    @Test @MainActor func endWorkoutDuringMatchInProgressClearsSession() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: true))
        vm.endWorkout()
        #expect(vm.currentSession() == nil)
    }

    @Test @MainActor func endWorkoutTwiceIsIdempotent() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endWorkout()
        vm.endWorkout()
        #expect(vm.currentSession() == nil)
        #expect(vm.isPaused == false)
    }

    @Test @MainActor func endWorkoutDoesNotResetPhase() {
        // Watch의 endWorkout은 HealthKit 세션만 종료하고 phase는 변경하지 않음
        // startNewMatch()가 phase를 .modeSelection으로 리셋하는 역할
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.endWorkout()
        guard case .playing = vm.phase else {
            Issue.record("endWorkout should not reset phase — phase should remain .playing")
            return
        }
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

    @Test @MainActor func remoteWorkoutEndedDefaultsFalse() {
        let vm = WorkoutSessionViewModel()
        #expect(vm.remoteWorkoutEnded == false)
    }

    // MARK: - Metrics Broadcast

    @Test @MainActor func metricsNotBroadcastWhenNotPlaying() {
        let vm = WorkoutSessionViewModel()
        vm.broadcastMetrics()
        #expect(vm.lastMetrics == nil)
    }

    @Test @MainActor func metricsBroadcastWhenPlaying() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.broadcastMetrics()
        #expect(vm.lastMetrics != nil)
    }

    @Test @MainActor func metricsHeartRateReflectsHealthKit() {
        HealthKitService.shared.currentHeartRate = 140
        defer { HealthKitService.shared.currentHeartRate = 0 }
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.broadcastMetrics()
        #expect(vm.lastMetrics?.heartRate == 140)
    }

    @Test @MainActor func metricsCaloriesAreNetOfStart() {
        HealthKitService.shared.currentCalories = 100
        defer { HealthKitService.shared.currentCalories = 0 }
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        HealthKitService.shared.currentCalories = 150
        vm.broadcastMetrics()
        #expect(vm.lastMetrics?.calories == 50)
    }

    @Test @MainActor func restartMatchResetsScoreVM() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.scoreVM.myGameScore = 3
        vm.scoreVM.mySetScore = 1
        vm.scoreVM.completedSets = [SetScore(my: 6, your: 4)]

        vm.restartMatch()

        #expect(vm.scoreVM.myGameScore == 0)
        #expect(vm.scoreVM.mySetScore == 0)
        #expect(vm.scoreVM.completedSets.isEmpty)
    }

    @Test @MainActor func metricsNotBroadcastAfterMatchFinished() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 3)])
        vm.broadcastMetrics()
        #expect(vm.lastMetrics == nil)
    }
}
