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
}
