import Foundation

enum RecordDetailBuilder {
    static let placeholder = "–"

    static func summary(for record: WorkoutRecord, now: Date = Date(), calendar: Calendar = .current,
                        locale: Locale = Locale(identifier: "ko_KR")) -> RecordDetailSummary
    {
        let sameYear = calendar.component(.year, from: record.startedAt) == calendar.component(.year, from: now)
        let dateFormatter = RecordListBuilder.formatter(sameYear ? "M월 d일 (E)" : "yyyy년 M월 d일 (E)", calendar: calendar, locale: locale)
        let end = record.endedAt ?? record.startedAt.addingTimeInterval(TimeInterval(record.totalSeconds))
        let chips = RecordListBuilder.segmentChips(for: record)
        return RecordDetailSummary(dateTitle: dateFormatter.string(from: record.startedAt),
                                   timeRangeTitle: timeRange(from: record.startedAt, to: end, calendar: calendar, locale: locale),
                                   durationText: record.totalSeconds < 60 ? "1분 미만" : "\(record.totalSeconds / 60)분",
                                   caloriesText: record.totalCalories.map { "\(Int($0.rounded()))" } ?? placeholder,
                                   heartRateText: record.averageHeartRate.map { "\(Int($0.rounded()))" } ?? placeholder,
                                   spans: record.orderedSegments.filter { $0.durationSeconds > 0 }.map { .init(kind: $0.kind, seconds: $0.durationSeconds) },
                                   compositionText: chips.isEmpty ? nil : chips.map(\.text).joined(separator: " · "))
    }

    private static func timeRange(from start: Date, to end: Date, calendar: Calendar, locale: Locale) -> String {
        let withPeriod = RecordListBuilder.formatter("B h:mm", calendar: calendar, locale: locale)
        let withoutPeriod = RecordListBuilder.formatter("h:mm", calendar: calendar, locale: locale)
        let period = RecordListBuilder.formatter("B", calendar: calendar, locale: locale)
        return "\(withPeriod.string(from: start)) – \((period.string(from: start) == period.string(from: end) ? withoutPeriod : withPeriod).string(from: end))"
    }
}
