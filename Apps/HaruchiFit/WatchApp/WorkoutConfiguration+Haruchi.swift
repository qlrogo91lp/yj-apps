import HealthKit
import WorkoutCore

extension WorkoutConfiguration {
    /// 하루치 핏의 기본 프리셋. 실내 근력으로 세션을 열고, 유산소는 세션 안의
    /// 구간(HKWorkoutActivity)으로 다룬다 — 세션 자체를 바꾸지 않는다.
    ///
    /// `nonisolated` 가 필요하다 — 이 타깃은 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
    /// 라서 그냥 두면 이 상수가 MainActor 로 격리되고, 기본 인자는 호출 지점(비격리일 수 있다)에서
    /// 평가되므로 경고가 난다. `WorkoutConfiguration` 은 `Sendable` 이라 격리할 이유가 없다.
    nonisolated static let strength = WorkoutConfiguration(activityType: .traditionalStrengthTraining,
                                                           locationType: .indoor)
}
