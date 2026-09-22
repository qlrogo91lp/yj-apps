import Foundation

extension WorkoutRecord {
    /// 외부 워크아웃을 레코드로 옮긴다. **세그먼트를 정확히 하나 만든다** — 매핑된 kind 로
    /// 전체 길이를 덮는다 (스펙 5절). 외부 워크아웃은 전환이 0 회인 세션이라 의미도 맞고,
    /// 잔디 집계가 워치 기록과 **같은 경로**로 읽게 된다.
    ///
    /// `totalCalories` 에 active 를 그대로 넣는다 — 다른 앱 워크아웃에는 basal 샘플이
    /// 붙어 있지 않아 따로 구해도 대개 nil 이다.
    static func make(from workout: ImportedWorkout) -> WorkoutRecord {
        let record = WorkoutRecord(healthKitUUID: workout.uuid,
                                   startedAt: workout.startedAt,
                                   endedAt: workout.endedAt,
                                   totalSeconds: workout.totalSeconds,
                                   activeCalories: workout.activeCalories,
                                   totalCalories: workout.activeCalories,
                                   averageHeartRate: workout.averageHeartRate,
                                   source: .healthKitImport)
        record.segments = [Segment(kind: workout.kind,
                                   startOffset: 0,
                                   durationSeconds: workout.totalSeconds)]
        return record
    }
}
