@testable import TennisCounter_Watch_App
import Testing

struct watchosTests {

    @Test func example() {}

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

    // MARK: - 워크아웃 종료 동기화

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

    @Test @MainActor func remoteWorkoutEndedDefaultsFalse() {
        let vm = WorkoutSessionViewModel()
        #expect(vm.remoteWorkoutEnded == false)
    }
}
