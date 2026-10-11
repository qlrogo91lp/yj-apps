import Foundation
import WorkoutCore

enum RecordShareBuilder {
    static func content(for record: WorkoutRecord) -> RecordShareContent {
        let kinds = RecordListBuilder.segmentChips(for: record).map(\.kind.title)
        return RecordShareContent(
            title: kinds.isEmpty ? "운동" : kinds.joined(separator: " · "),
            startedAt: record.startedAt,
            endedAt: record.effectiveEndedAt,
            result: WorkoutResult(
                durationSeconds: record.totalSeconds,
                caloriesBurned: record.activeCalories ?? 0,
                averageHeartRate: record.averageHeartRate,
                totalCaloriesBurned: record.totalCalories ?? 0
            )
        )
    }
}
