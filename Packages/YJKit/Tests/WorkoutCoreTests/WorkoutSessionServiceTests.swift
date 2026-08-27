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

    @Test @MainActor func basalCaloriesStartAtZero() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.currentBasalCalories == 0)
    }

    @Test @MainActor func basalCaloriesReflectInjectedValue() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        service.setLiveMetricsForTesting(calories: 120, basalCalories: 45)
        #expect(service.currentCalories == 120)
        #expect(service.currentBasalCalories == 45)
    }

    @Test @MainActor func typesToReadOmitsAdditionalTypesByDefault() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.typesToRead.count == 4)
        #expect(!service.typesToRead.contains(HKQuantityType(.stepCount)))
        #expect(!service.typesToRead.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func typesToShareOmitsAdditionalTypesByDefault() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.typesToShare.count == 4)
        #expect(!service.typesToShare.contains(HKQuantityType(.stepCount)))
        #expect(!service.typesToShare.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func typesToShareIncludesAdditionalTypes() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(
            activityType: .golf,
            locationType: .indoor,
            additionalReadTypes: [.distanceWalkingRunning, .stepCount]
        ))
        #expect(service.typesToShare.count == 6)
        #expect(service.typesToShare.contains(HKQuantityType(.stepCount)))
        #expect(service.typesToShare.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func typesToReadIncludesAdditionalTypes() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(
            activityType: .golf,
            locationType: .indoor,
            additionalReadTypes: [.distanceWalkingRunning, .stepCount]
        ))
        #expect(service.typesToRead.count == 6)
        #expect(service.typesToRead.contains(HKQuantityType(.stepCount)))
        #expect(service.typesToRead.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func distanceAndStepsStartAtZero() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .golf))
        #expect(service.currentDistanceMeters == 0)
        #expect(service.currentSteps == 0)
    }

    @Test @MainActor func setLiveMetricsInjectsDistanceAndSteps() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .golf))
        service.setLiveMetricsForTesting(distanceMeters: 4820.5, steps: 7100)
        #expect(service.currentDistanceMeters == 4820.5)
        #expect(service.currentSteps == 7100)
    }

    @Test func resultDistanceAndStepsDefaultToZero() {
        let result = WorkoutResult(durationSeconds: 60, caloriesBurned: 100, averageHeartRate: 120)
        #expect(result.distanceMeters == 0)
        #expect(result.steps == 0)
    }

    @Test func resultCarriesDistanceAndSteps() {
        let result = WorkoutResult(durationSeconds: 60,
                                   caloriesBurned: 100,
                                   averageHeartRate: 120,
                                   totalCaloriesBurned: 145,
                                   distanceMeters: 4820.5,
                                   steps: 7100)
        #expect(result.distanceMeters == 4820.5)
        #expect(result.steps == 7100)
    }
}
