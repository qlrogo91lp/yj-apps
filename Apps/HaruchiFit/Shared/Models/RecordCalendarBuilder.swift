import Foundation
import SwiftData

struct RecordCalendarDay: Identifiable {
    let date: Date
    let level: GrassLevel
    let sessionCount: Int
    let totalSeconds: Int
    let isFuture: Bool

    var id: Date {
        date
    }
}

struct RecordCalendarMonth {
    let calendar: Calendar
    let monthStart: Date
    let title: String
    let summary: String
    let weekdays: [String]
    let cells: [RecordCalendarDay?]
    let days: [RecordCalendarDay]
    let selectedRows: [RecordListRow]
    let emptyMessage: String?
}

enum RecordCalendarBuilder {
    static func month(from records: [WorkoutRecord],
                      displayedMonth: Date,
                      selectedDay: Date,
                      now: Date = Date(),
                      calendar: Calendar = .current,
                      locale: Locale = Locale(identifier: "ko_KR")) -> RecordCalendarMonth
    {
        let monthStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? displayedMonth
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let visible = records.filter { $0.startedAt >= monthStart && $0.startedAt < monthEnd && $0.startedAt <= now }
        let aggregates = Dictionary(uniqueKeysWithValues: GrassAggregator.fold(visible, calendar: calendar).map { ($0.day, $0) })
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1 ..< 1
        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { day -> RecordCalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
            let aggregate = aggregates[calendar.startOfDay(for: date)]
            return RecordCalendarDay(date: date,
                                     level: aggregate.map(GrassIntensity.byTime.level) ?? .none,
                                     sessionCount: aggregate?.sessionCount ?? 0,
                                     totalSeconds: aggregate?.totalSeconds ?? 0,
                                     isFuture: date > now)
        }
        var cells: [RecordCalendarDay?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: days)
        while !cells.isEmpty, cells.count % 7 != 0 {
            cells.append(nil)
        }

        let selected = visible.filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDay) }.sorted { $0.startedAt > $1.startedAt }
        let title = RecordListBuilder.formatter("yyyy년 M월", calendar: calendar, locale: locale).string(from: monthStart)
        let weekdaySymbols = RecordListBuilder.formatter("", calendar: calendar, locale: locale).shortWeekdaySymbols
            ?? calendar.shortWeekdaySymbols
        let weekdayOffset = calendar.firstWeekday - 1
        let weekdays = Array(weekdaySymbols[weekdayOffset...]) + Array(weekdaySymbols[..<weekdayOffset])
        let emptyMessage: String? = if records.isEmpty {
            "아직 기록이 없어요"
        } else if visible.isEmpty {
            "이 달에는 기록이 없어요"
        } else if selected.isEmpty {
            "이 날에는 기록이 없어요"
        } else {
            nil
        }
        return RecordCalendarMonth(calendar: calendar,
                                   monthStart: monthStart,
                                   title: title,
                                   summary: summary(for: visible),
                                   weekdays: weekdays,
                                   cells: cells,
                                   days: days,
                                   selectedRows: RecordListBuilder.rows(for: selected, calendar: calendar, locale: locale,
                                                                        includeStartTime: true),
                                   emptyMessage: emptyMessage)
    }

    private static func summary(for records: [WorkoutRecord]) -> String {
        let seconds = records.reduce(0) { $0 + $1.totalSeconds }
        let duration = if seconds < 3600 {
            "\(seconds / 60)분"
        } else {
            String(format: "%.1f시간", Double(seconds) / 3600)
        }
        return "\(records.count)회 · \(duration)"
    }
}
