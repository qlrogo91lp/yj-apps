import Foundation
import WorkoutCore

extension RoundMetrics {
    /// `WorkoutResult`는 워치 타깃에만 있으므로 변환도 여기 둔다 (spec §5).
    ///
    /// `durationSeconds`·`totalCaloriesBurned`는 `GolfRound`에 대응 필드가 없어 버린다 —
    /// 소요 시간은 iOS가 `endedAt - startedAt`으로 파생한다.
    init(_ result: WorkoutResult) {
        self.init(calories: result.caloriesBurned,
                  avgHeartRate: result.averageHeartRate ?? 0,
                  distanceMeters: result.distanceMeters,
                  steps: result.steps)
    }
}
