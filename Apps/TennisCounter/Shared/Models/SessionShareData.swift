import Foundation
import WorkoutCore

/// 공유 카드에 넘길 세션 최종값과 실제 운동 시간 범위.
/// 레코드가 없는 구버전 세션만 경기 누적 최댓값으로 대신한다.
struct SessionShareData {
    let result: WorkoutResult
    let startedAt: Date
    let endedAt: Date?

    init?(session: MatchSessionGroup) {
        let elapsed: Int?
        let calories: Double?
        let totalCalories: Double?
        if let record = session.record {
            elapsed = record.elapsedSeconds
            calories = record.activeCalories
            totalCalories = record.totalCalories
            startedAt = record.startedAt
            endedAt = record.endedAt
        } else {
            elapsed = session.elapsedSeconds
            calories = session.activeCalories
            totalCalories = session.totalCalories
            endedAt = session.matches.compactMap(\.endedAt).max()
            if let end = endedAt, let elapsed {
                startedAt = end.addingTimeInterval(-TimeInterval(elapsed))
            } else {
                startedAt = session.date
            }
        }

        // 기존 공유 카드와 동일하게 시간·활동 칼로리가 있어야 공유할 수 있다.
        guard let elapsed, let calories else { return nil }
        result = WorkoutResult(
            durationSeconds: elapsed,
            caloriesBurned: calories,
            averageHeartRate: session.averageHeartRate,
            totalCaloriesBurned: totalCalories ?? 0
        )
    }
}
