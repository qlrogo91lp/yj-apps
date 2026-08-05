import Testing
@testable import WorkoutCore

struct WorkoutMetricsTests {
    @Test func formatsUnderOneHourAsMinutesSeconds() {
        #expect(WorkoutMetrics.formatSeconds(0) == "00:00")
        #expect(WorkoutMetrics.formatSeconds(59) == "00:59")
        #expect(WorkoutMetrics.formatSeconds(600) == "10:00")
    }

    @Test func formatsOneHourBoundaryWithHours() {
        #expect(WorkoutMetrics.formatSeconds(3599) == "59:59")
        #expect(WorkoutMetrics.formatSeconds(3600) == "1:00:00")
        #expect(WorkoutMetrics.formatSeconds(3661) == "1:01:01")
    }

    @Test func formattedElapsedUsesElapsedSeconds() {
        let metrics = WorkoutMetrics(elapsedSeconds: 1523)
        #expect(metrics.formattedElapsed == "25:23")
    }

    @Test func defaultsAreZero() {
        let metrics = WorkoutMetrics()
        #expect(metrics.elapsedSeconds == 0)
        #expect(metrics.activeCalories == 0)
        #expect(metrics.totalCalories == 0)
        #expect(metrics.heartRate == 0)
    }
}
