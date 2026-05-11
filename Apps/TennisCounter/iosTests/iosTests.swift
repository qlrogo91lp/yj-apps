//
//  iosTests.swift
//  iosTests
//
//  Created by yj on 4/29/26.
//

import Testing
@testable import TennisCounter

struct iosTests {
    @Test func example() async throws {}

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
}
