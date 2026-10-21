import Foundation

enum RecordDetailBuilder {
    static let placeholder = "–"

    static func summary(for record: WorkoutRecord, now: Date = Date(), calendar: Calendar = .current,
                        locale: Locale = .current) -> RecordDetailSummary
    {
        let sameYear = calendar.component(.year, from: record.startedAt) == calendar.component(.year, from: now)
        let dateFormatter = DisplayDateFormat.formatter(sameYear ? .monthDayWeekday : .yearMonthDayWeekday, calendar: calendar, locale: locale)
        let end = record.effectiveEndedAt
        return RecordDetailSummary(dateTitle: dateFormatter.string(from: record.startedAt),
                                   timeRangeTitle: DisplayDateFormat.timeRange(from: record.startedAt, to: end, calendar: calendar, locale: locale),
                                   durationText: record.totalSeconds < 60 ? String(localized: "duration_under_minute", table: "Shared") : DisplayText
                                       .minutes(record.totalSeconds / 60),
                                   caloriesText: record.totalCalories.map { "\(Int($0.rounded()))" } ?? placeholder,
                                   heartRateText: record.averageHeartRate.map { "\(Int($0.rounded()))" } ?? placeholder,
                                   spans: spans(for: record),
                                   compositionText: compositionText(for: record))
    }

    /// 운동 구성 막대의 구간 — 기록 순서대로, 0초 구간은 뺀다. 상세와 공유 카드가 같이 쓴다.
    static func spans(for record: WorkoutRecord) -> [RecordDetailSummary.Span] {
        record.orderedSegments.filter { $0.durationSeconds > 0 }.map { .init(kind: $0.kind, seconds: $0.durationSeconds) }
    }

    /// `근력 26분 · 유산소 12분` — 1분 이상인 종류가 없으면 nil. 막대를 보일지도 이 값으로 정한다.
    static func compositionText(for record: WorkoutRecord) -> String? {
        let chips = RecordListBuilder.segmentChips(for: record)
        return chips.isEmpty ? nil : chips.map(\.text).joined(separator: " · ")
    }
}
