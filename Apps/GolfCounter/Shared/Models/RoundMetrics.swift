import Foundation

/// 라운드 워크아웃 집계값. `GolfRound`의 대응 필드와 1:1이다 (spec §4).
///
/// `WorkoutResult`(WorkoutCore)를 그대로 쓰지 않는 이유: `Shared/`에 `import WorkoutCore`를
/// 두면 iOS 타깃 빌드가 깨진다 — iOS는 WorkoutCore를 링크하지 않는다 (spec §5).
/// 변환은 워치 타깃의 `RoundMetrics+WorkoutResult.swift`에 있다.
struct RoundMetrics: Equatable {
    var calories: Double = 0
    var avgHeartRate: Double = 0
    var distanceMeters: Double = 0
    var steps: Int = 0

    /// 워크아웃 결과를 못 받은 경우 — HealthKit 거부 · 워크아웃 미시작 · 복구된 라운드.
    /// 복구 라운드는 그 구간에 워크아웃 세션이 없었으므로 이게 정상 경로다 (spec §8).
    static let empty = RoundMetrics()
}
