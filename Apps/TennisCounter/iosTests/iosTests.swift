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

    // MARK: - MatchViewModel addPoint

    @Test @MainActor func addPointWinsGame() {
        let vm = MatchViewModel(format: .oneSet)
        // 4번 탭하면 게임 승리 (noAdRule=true 기본값: 0→15→30→40→win)
        vm.addPoint(.me)
        vm.addPoint(.me)
        vm.addPoint(.me)
        vm.addPoint(.me)
        #expect(vm.myGameScore == 1)
        #expect(vm.score.myDisplayScore == "0")
    }

    @Test @MainActor func addPointOpponentWinsGame() {
        let vm = MatchViewModel(format: .oneSet)
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        vm.addPoint(.opponent)
        #expect(vm.yourGameScore == 1)
        #expect(vm.myGameScore == 0)
    }

    @Test @MainActor func addPointUndoResetsScore() {
        let vm = MatchViewModel(format: .oneSet)
        vm.addPoint(.me) // 15-0
        vm.undo()
        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.score.lastAction == .none)
    }

    @Test @MainActor func addPointMatchOver() {
        let vm = MatchViewModel(format: .oneSet)
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
        let vm = MatchViewModel(format: .oneSet)
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me) // game won
        let gameScoreBefore = vm.myGameScore
        vm.undo() // undo cannot reverse a game-winning tap
        #expect(vm.myGameScore == gameScoreBefore) // game score unchanged
    }
}
