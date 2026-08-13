import HealthKit
import WorkoutCore

extension WorkoutConfiguration {
    /// spec §8 — GPS를 쓰지 않아(.indoor) 배터리를 아끼고, 거리·걸음수는 가속도계 기반 값을 읽는다.
    static let golf = WorkoutConfiguration(activityType: .golf,
                                           locationType: .indoor,
                                           additionalReadTypes: [.distanceWalkingRunning, .stepCount])
}
