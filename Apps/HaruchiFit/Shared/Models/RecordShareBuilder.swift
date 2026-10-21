import Foundation
import WorkoutCore

enum RecordShareBuilder {
    static func content(for record: WorkoutRecord) -> RecordShareContent {
        // 제목은 브랜드 고정 — 구성은 머리줄 아래 막대가 보여준다. 번역하지 않는다.
        let chips = RecordListBuilder.segmentChips(for: record)
        let composition = chips.isEmpty ? nil : RecordShareContent.Composition(spans: RecordDetailBuilder.spans(for: record), chips: chips)
        return RecordShareContent(
            title: "Haruchi Fit",
            startedAt: record.startedAt,
            endedAt: record.effectiveEndedAt,
            result: WorkoutResult(
                durationSeconds: record.totalSeconds,
                caloriesBurned: record.activeCalories ?? 0,
                averageHeartRate: record.averageHeartRate,
                totalCaloriesBurned: record.totalCalories ?? 0
            ),
            composition: composition
        )
    }
}
