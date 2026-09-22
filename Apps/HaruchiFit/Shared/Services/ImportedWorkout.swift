import Foundation

/// HealthKit 을 떠난 워크아웃 하나. **`HKWorkout` 이 `Shared/` 위로 올라오지 않게 하는
/// 경계다** — 순수 값이라야 워치 테스트 타깃에서 규칙을 검증할 수 있다.
///
/// `kind` 는 이미 매핑을 통과한 결과다. 여기까지 온 워크아웃은 전부 잔디에 반영된다.
nonisolated struct ImportedWorkout: Equatable, Identifiable {
    let uuid: UUID
    let kind: SegmentKind
    let startedAt: Date
    let endedAt: Date
    /// `HKWorkout.duration` — **일시정지를 뺀 값**이라 워치 기록(PR #26)과 의미가 같다.
    let totalSeconds: Int
    let activeCalories: Double?
    let averageHeartRate: Double?

    var id: UUID {
        uuid
    }
}
