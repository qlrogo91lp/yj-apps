import HealthKit
import Testing
@testable import WorkoutCore

struct WorkoutConfigurationTests {
    @Test func initStoresActivityType() {
        let config = WorkoutConfiguration(activityType: .tennis)
        #expect(config.activityType == .tennis)
    }

    @Test func locationTypeDefaultsToOutdoor() {
        let config = WorkoutConfiguration(activityType: .golf)
        #expect(config.locationType == .outdoor)
    }

    @Test func locationTypeCanBeOverridden() {
        let config = WorkoutConfiguration(
            activityType: .traditionalStrengthTraining,
            locationType: .indoor
        )
        #expect(config.locationType == .indoor)
    }

    @Test func equalWhenAllFieldsMatch() {
        let a = WorkoutConfiguration(activityType: .tennis, locationType: .outdoor)
        let b = WorkoutConfiguration(activityType: .tennis, locationType: .outdoor)
        let c = WorkoutConfiguration(activityType: .tennis, locationType: .indoor)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func resultEqualWhenAllFieldsMatch() {
        let a = WorkoutResult(durationSeconds: 60, caloriesBurned: 100, averageHeartRate: 120)
        let b = WorkoutResult(durationSeconds: 60, caloriesBurned: 100, averageHeartRate: 120)
        let c = WorkoutResult(durationSeconds: 60, caloriesBurned: 100, averageHeartRate: nil)
        #expect(a == b)
        #expect(a != c)
    }

    /// Sendable 컴파일 타임 검증 — conformance가 빠지면 이 함수 호출이 컴파일되지 않는다.
    @Test func typesAreSendable() {
        func requiresSendable(_: some Sendable) {}
        requiresSendable(WorkoutConfiguration(activityType: .tennis))
        requiresSendable(WorkoutResult(durationSeconds: 0, caloriesBurned: 0, averageHeartRate: nil))
    }
}
