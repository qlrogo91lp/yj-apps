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
    let emptyState: RecordCalendarEmptyState?
}

enum RecordCalendarBuilder {
    static func month(from records: [WorkoutRecord],
                      displayedMonth: Date,
                      selectedDay: Date,
                      now: Date = Date(),
                      calendar: Calendar = .current,
                      locale: Locale = .current) -> RecordCalendarMonth
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
        let title = DisplayDateFormat.formatter(.yearMonth, calendar: calendar, locale: locale).string(from: monthStart)
        let weekdaySymbols = DisplayDateFormat.formatter("E", calendar: calendar, locale: locale).shortWeekdaySymbols
            ?? calendar.shortWeekdaySymbols
        let weekdayOffset = calendar.firstWeekday - 1
        let weekdays = Array(weekdaySymbols[weekdayOffset...]) + Array(weekdaySymbols[..<weekdayOffset])
        let emptyState: RecordCalendarEmptyState? = if records.isEmpty {
            .noRecords
        } else if visible.isEmpty {
            .emptyMonth
        } else if selected.isEmpty {
            .emptyDay
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
                                   emptyState: emptyState)
    }

    private static func summary(for records: [WorkoutRecord]) -> String {
        let seconds = records.reduce(0) { $0 + $1.totalSeconds }
        return "\(DisplayText.workouts(records.count)) · \(DisplayText.duration(seconds: seconds))"
    }
}
