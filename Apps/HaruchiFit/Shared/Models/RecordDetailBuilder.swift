import Foundation

enum RecordDetailBuilder {
    static let placeholder = "–"

    static func summary(for record: WorkoutRecord, now: Date = Date(), calendar: Calendar = .current,
                        locale: Locale = .current) -> RecordDetailSummary
    {
        let sameYear = calendar.component(.year, from: record.startedAt) == calendar.component(.year, from: now)
        let dateFormatter = DisplayDateFormat.formatter(sameYear ? .monthDayWeekday : .yearMonthDayWeekday, calendar: calendar, locale: locale)
        let end = record.effectiveEndedAt
        let chips = RecordListBuilder.segmentChips(for: record)
        return RecordDetailSummary(dateTitle: dateFormatter.string(from: record.startedAt),
                                   timeRangeTitle: DisplayDateFormat.timeRange(from: record.startedAt, to: end, calendar: calendar, locale: locale),
                                   durationText: record.totalSeconds < 60 ? String(localized: "duration_under_minute", table: "Shared") : DisplayText
                                       .minutes(record.totalSeconds / 60),
                                   caloriesText: record.totalCalories.map { "\(Int($0.rounded()))" } ?? placeholder,
                                   heartRateText: record.averageHeartRate.map { "\(Int($0.rounded()))" } ?? placeholder,
                                   spans: record.orderedSegments.filter { $0.durationSeconds > 0 }.map { .init(
                                       kind: $0.kind,
                                       seconds: $0.durationSeconds
                                   ) },
                                   compositionText: chips.isEmpty ? nil : chips.map(\.text).joined(separator: " · "))
    }
}
