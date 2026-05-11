//
//  watchosTests.swift
//  watchosTests
//
//  Created by yj on 4/29/26.
//

@testable import TennisCounter_Watch_App
import Testing

struct watchosTests {

    @Test func example() {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    @Test @MainActor func finishMatchSetsPhaseImmediately() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .draw, completedSets: [])

        guard case .finished = vm.phase else {
            Issue.record("Expected .finished phase immediately after finishMatch, got \(vm.phase)")
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
            Issue.record("Expected .playing phase after restartMatch, got \(vm.phase)")
            return
        }
        #expect(newOptions.mode == .bestOfThree)
        #expect(newOptions.noAdRule == false)
        #expect(newOptions.noTieRule == true)
    }
}
