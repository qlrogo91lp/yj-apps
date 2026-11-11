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

    @Test func workoutResultCarriesEndDate() {
        let endedAt = Date(timeIntervalSince1970: 1_000_900)
        let result = WorkoutResult(durationSeconds: 900,
                                   caloriesBurned: 120,
                                   averageHeartRate: 135,
                                   endedAt: endedAt)

        #expect(result.endedAt == endedAt)
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
        #expect(service.typesToRead.count == 3)
        #expect(!service.typesToRead.contains(HKObjectType.workoutType()))
        #expect(!service.typesToRead.contains(HKQuantityType(.stepCount)))
        #expect(!service.typesToRead.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func typesToShareIsWorkoutOnly() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.typesToShare.count == 1)
        #expect(service.typesToShare.contains(HKObjectType.workoutType()))
        #expect(!service.typesToShare.contains(HKQuantityType(.stepCount)))
        #expect(!service.typesToShare.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func typesToShareExcludesAdditionalTypes() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(
            activityType: .golf,
            locationType: .indoor,
            additionalReadTypes: [.distanceWalkingRunning, .stepCount]
        ))
        #expect(service.typesToShare.count == 1)
        #expect(service.typesToShare.contains(HKObjectType.workoutType()))
        #expect(!service.typesToShare.contains(HKQuantityType(.stepCount)))
        #expect(!service.typesToShare.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func typesToReadIncludesAdditionalTypes() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(
            activityType: .golf,
            locationType: .indoor,
            additionalReadTypes: [.distanceWalkingRunning, .stepCount]
        ))
        #expect(service.typesToRead.count == 5)
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

    // MARK: - elapsedDisplay

    @Test @MainActor func elapsedDisplayStartsNilBeforeSessionBegins() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.elapsedDisplay == nil)
    }

    @Test @MainActor func beginElapsedDisplaySession_createsFreshRunningReference() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        let start = Date(timeIntervalSince1970: 1000)

        service.beginElapsedDisplaySession(at: start)

        #expect(service.elapsedDisplay?.referenceDate == start)
        #expect(service.elapsedDisplay?.pausedAt == nil)
    }

    @Test @MainActor func applyElapsedDisplayState_pausedThenRunning_preservesFraction() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        let start = Date(timeIntervalSince1970: 1000)
        service.beginElapsedDisplaySession(at: start)
        let generation = service.currentElapsedDisplayGeneration

        service.applyElapsedDisplayState(.paused, at: Date(timeIntervalSince1970: 1010.25), generation: generation)
        #expect(service.elapsedDisplay?.elapsed(at: Date(timeIntervalSince1970: 9999)) == 10.25)

        service.applyElapsedDisplayState(.running, at: Date(timeIntervalSince1970: 1030.75), generation: generation)
        #expect(service.elapsedDisplay?.elapsed(at: Date(timeIntervalSince1970: 1031.5)) == 11)
    }

    @Test @MainActor func stop_freezesAtRequestDate_laterTimeDoesNotGrowIt() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        let start = Date(timeIntervalSince1970: 1000)
        service.beginElapsedDisplaySession(at: start)

        let endDate = Date(timeIntervalSince1970: 1040)
        service.endElapsedDisplaySession(at: endDate)

        // 종료 저장(HealthKit 마무리)에 3초가 걸려도 고정된 값은 그대로다.
        #expect(service.elapsedDisplay?.elapsed(at: endDate.addingTimeInterval(3)) == 40)
    }

    @Test @MainActor func resetAfterStop_beginElapsedDisplaySession_startsNewReference() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        service.beginElapsedDisplaySession(at: Date(timeIntervalSince1970: 1000))
        service.endElapsedDisplaySession(at: Date(timeIntervalSince1970: 1040))

        let newStart = Date(timeIntervalSince1970: 2000)
        service.beginElapsedDisplaySession(at: newStart)

        #expect(service.elapsedDisplay?.referenceDate == newStart)
        #expect(service.elapsedDisplay?.pausedAt == nil)
    }

    @Test @MainActor func staleDelegate_doesNotUnfreezeOrOverwriteNewSession() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        service.beginElapsedDisplaySession(at: Date(timeIntervalSince1970: 1000))
        let staleGeneration = service.currentElapsedDisplayGeneration

        let endDate = Date(timeIntervalSince1970: 1040)
        service.endElapsedDisplaySession(at: endDate)

        // 이미 끝난(다른 세대의) 세션에서 지연 도착한 .running 이벤트 — 고정을 풀면 안 된다.
        service.applyElapsedDisplayState(.running, at: Date(timeIntervalSince1970: 1200), generation: staleGeneration)
        #expect(service.elapsedDisplay?.elapsed(at: Date(timeIntervalSince1970: 9999)) == 40)

        // 새 운동이 시작된 뒤에도 옛 세대의 지연 이벤트가 새 모델을 덮어쓰면 안 된다.
        let newStart = Date(timeIntervalSince1970: 2000)
        service.beginElapsedDisplaySession(at: newStart)
        service.applyElapsedDisplayState(.paused, at: Date(timeIntervalSince1970: 2500), generation: staleGeneration)

        #expect(service.elapsedDisplay?.referenceDate == newStart)
        #expect(service.elapsedDisplay?.pausedAt == nil)
    }
}
