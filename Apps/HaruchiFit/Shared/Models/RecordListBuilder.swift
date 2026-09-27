import Foundation
import SwiftData

/// 레코드를 **주 단위 섹션**으로 나누고 행 표기를 만든다 (제품 스펙 03b).
///
/// 주의 경계는 `calendar` 의 `.weekOfYear` 를 따른다 — 홈 잔디 그리드와 같은 규칙이다.
/// 레코드가 속하는 주는 **시작 시각** 기준이다 (`GrassAggregator` 의 하루 경계와 같다).
enum RecordListBuilder {
    static func sections(from records: [WorkoutRecord],
                         now: Date = Date(),
                         calendar: Calendar = .current,
                         locale: Locale = Locale(identifier: "ko_KR")) -> [RecordListSection]
    {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)
        let currentYear = calendar.component(.year, from: now)
        let rowFormatter = formatter("M월 d일 (E)", calendar: calendar, locale: locale)
        let sameYearFormatter = formatter("M월 d일", calendar: calendar, locale: locale)
        let otherYearFormatter = formatter("yyyy년 M월 d일", calendar: calendar, locale: locale)

        var buckets: [Date: [WorkoutRecord]] = [:]
        for record in records {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: record.startedAt)?.start else { continue }
            buckets[week, default: []].append(record)
        }

        return buckets.keys.sorted(by: >).map { week in
            let title: String = if week == thisWeek {
                "이번 주"
            } else if week == lastWeek {
                "지난 주"
            } else {
                rangeTitle(week: week, currentYear: currentYear, calendar: calendar,
                           sameYearFormatter: sameYearFormatter, otherYearFormatter: otherYearFormatter)
            }
            let rows = (buckets[week] ?? [])
                .sorted { $0.startedAt > $1.startedAt }
                .map { row(for: $0, formatter: rowFormatter) }
            return RecordListSection(weekStart: week, title: title, rows: rows)
        }
    }

    /// `9월 13일 – 9월 19일`. 시작일이 올해가 아니면 연도를 붙이고, 해를 넘는 주는 끝에도 붙인다.
    private static func rangeTitle(week: Date, currentYear: Int, calendar: Calendar,
                                   sameYearFormatter: DateFormatter, otherYearFormatter: DateFormatter) -> String
    {
        let end = calendar.date(byAdding: .day, value: 6, to: week) ?? week
        let startYear = calendar.component(.year, from: week)
        let endYear = calendar.component(.year, from: end)
        let start = (startYear == currentYear ? sameYearFormatter : otherYearFormatter).string(from: week)
        let finish = (endYear == startYear ? sameYearFormatter : otherYearFormatter).string(from: end)
        return "\(start) – \(finish)"
    }

    private static func row(for record: WorkoutRecord, formatter: DateFormatter) -> RecordListRow {
        var order: [SegmentKind] = []
        var seconds: [SegmentKind: Int] = [:]
        for segment in record.orderedSegments {
            if seconds[segment.kind] == nil { order.append(segment.kind) }
            seconds[segment.kind, default: 0] += segment.durationSeconds
        }
        // 1분 미만은 `유산소 0분` 이 되어 정보가 아니다
        let chips = order.compactMap { kind -> RecordListRow.Chip? in
            let minutes = (seconds[kind] ?? 0) / 60
            return minutes > 0 ? RecordListRow.Chip(kind: kind, minutes: minutes) : nil
        }
        // 잔디 칼로리 기준(GrassAggregator)과 같은 값을 쓴다
        let calories = record.totalCalories.map { "\(Int($0.rounded())) kcal" }
        return RecordListRow(id: record.persistentModelID,
                             record: record,
                             dateTitle: formatter.string(from: record.startedAt),
                             chips: chips,
                             caloriesText: calories)
    }

    private static func formatter(_ format: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }
}
