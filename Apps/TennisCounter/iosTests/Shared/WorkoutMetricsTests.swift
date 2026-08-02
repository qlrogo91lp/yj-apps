@testable import TennisCounter
import Testing

struct WorkoutMetricsTests {
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

    @Test func formatSecondsUnderOneHour() {
        #expect(WorkoutMetrics.formatSeconds(150) == "02:30")
    }

    @Test func formatSecondsOverOneHour() {
        #expect(WorkoutMetrics.formatSeconds(3661) == "1:01:01")
    }

    @Test func workoutMetricsParsesTotalCalories() {
        let dict: [String: Any] = ["elapsed": 100.0, "calories": 200.0, "totalCalories": 260.0]
        let metrics = WorkoutMetrics(from: dict)
        #expect(metrics?.calories == 200.0)
        #expect(metrics?.totalCalories == 260.0)
    }

    /// 구버전 워치가 보낸 딕셔너리에는 totalCalories 키가 없다 — 활동 칼로리로 폴백해야
    /// 화면에 0이 뜨지 않는다.
    @Test func workoutMetricsFallsBackToActiveWhenTotalMissing() {
        let dict: [String: Any] = ["elapsed": 100.0, "calories": 200.0]
        let metrics = WorkoutMetrics(from: dict)
        #expect(metrics?.totalCalories == 200.0)
    }

    @Test func workoutMetricsRoundTripsTotalCalories() {
        let original = WorkoutMetrics(elapsedSeconds: 90, calories: 210, totalCalories: 275, heartRate: 130)
        let restored = WorkoutMetrics(from: original.toDictionary())
        #expect(restored?.totalCalories == 275)
        #expect(restored?.calories == 210)
        #expect(restored?.heartRate == 130)
    }

    @Test func workoutMetricsTotalDefaultsToZero() {
        let metrics = WorkoutMetrics(elapsedSeconds: 10)
        #expect(metrics.totalCalories == 0)
    }
}
