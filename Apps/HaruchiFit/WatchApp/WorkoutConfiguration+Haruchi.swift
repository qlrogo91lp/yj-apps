import HealthKit
import WorkoutCore

extension WorkoutConfiguration {
    /// 하루치 핏의 기본 프리셋. **세션은 실내 근력 하나로 열고 끝까지 바꾸지 않는다** (D-M8).
    ///
    /// HealthKit 은 근력↔유산소처럼 카테고리가 다른 activityType 으로의 구간 전환을
    /// 거부한다 (`Code=3 "Cannot add subactivity"`, 2026-09-03 실기기 실측). 따라서
    /// 유산소 구간은 `HKWorkoutActivity` 가 아니라 SwiftData 세그먼트가 갖는다 —
    /// 근거는 아키텍처 문서 2절.
    ///
    /// `nonisolated` 가 필요하다 — 이 타깃은 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
    /// 라서 그냥 두면 이 상수가 MainActor 로 격리되고, 기본 인자는 호출 지점(비격리일 수 있다)에서
    /// 평가되므로 경고가 난다. `WorkoutConfiguration` 은 `Sendable` 이라 격리할 이유가 없다.
    nonisolated static let strength = WorkoutConfiguration(activityType: .traditionalStrengthTraining,
                                                           locationType: .indoor)
}
