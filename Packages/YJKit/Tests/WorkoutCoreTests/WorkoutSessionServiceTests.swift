import HealthKit
import Testing
@testable import WorkoutCore

struct WorkoutSessionServiceTests {
    @Test @MainActor func formattedElapsedStartsAtZero() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.formattedElapsed() == "00:00")
    }

    @Test @MainActor func formattedElapsedFormatsMinutesSeconds() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        service.setLiveMetricsForTesting(elapsedSeconds: 605)
        #expect(service.formattedElapsed() == "10:05")
    }

    @Test @MainActor func formattedElapsedIncludesHoursWhenOverAnHour() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        service.setLiveMetricsForTesting(elapsedSeconds: 3661)
        #expect(service.formattedElapsed() == "1:01:01")
    }

    @Test @MainActor func setLiveMetricsInjectsDisplayValues() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .golf))
        service.setLiveMetricsForTesting(heartRate: 140, calories: 250)
        #expect(service.currentHeartRate == 140)
        #expect(service.currentCalories == 250)
    }

    @Test func workoutResultStoresValues() {
        let result = WorkoutResult(durationSeconds: 90, caloriesBurned: 12.5, averageHeartRate: nil)
        #expect(result.durationSeconds == 90)
        #expect(result.caloriesBurned == 12.5)
        #expect(result.averageHeartRate == nil)
    }
}
