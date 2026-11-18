import Foundation
import WorkoutCore

/// 공유 카드에 넘길 세션 최종값과 실제 운동 시간 범위.
/// 레코드가 없는 구버전 세션만 경기 누적 최댓값으로 대신한다.
struct SessionShareData {
    let result: WorkoutResult
    let startedAt: Date
    let endedAt: Date?

    init?(record: WorkoutSessionRecord) {
        guard let elapsed = record.elapsedSeconds, let calories = record.activeCalories else { return nil }
        startedAt = record.startedAt
        endedAt = record.endedAt
        result = WorkoutResult(durationSeconds: elapsed, caloriesBurned: calories,
                               averageHeartRate: record.averageHeartRate, totalCaloriesBurned: record.totalCalories ?? 0)
    }

    init?(session: MatchSessionGroup) {
        if let record = session.record {
            self.init(record: record)
            return
        }
        guard let elapsed = session.elapsedSeconds, let calories = session.activeCalories else { return nil }
        let end = session.matches.compactMap(\.endedAt).max()
        let start = end.map { $0.addingTimeInterval(-TimeInterval(elapsed)) } ?? session.date
        self.init(result: WorkoutResult(durationSeconds: elapsed, caloriesBurned: calories,
                                        averageHeartRate: session.averageHeartRate, totalCaloriesBurned: session.totalCalories ?? 0),
                  startedAt: start, endedAt: end)
    }

    private init(result: WorkoutResult, startedAt: Date, endedAt: Date?) {
        self.result = result
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
