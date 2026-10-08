import Foundation

struct RecordsCalendarState {
    private(set) var month: Date
    private(set) var selectedDay: Date

    init(now: Date, calendar: Calendar = .current) {
        month = calendar.dateInterval(of: .month, for: now)?.start ?? now
        selectedDay = calendar.startOfDay(for: now)
    }

    mutating func rebase(from oldCalendar: Calendar, to newCalendar: Calendar) {
        let monthComponents = oldCalendar.dateComponents([.year, .month], from: month)
        let dayComponents = oldCalendar.dateComponents([.year, .month, .day], from: selectedDay)
        month = newCalendar.date(from: monthComponents) ?? month
        selectedDay = newCalendar.startOfDay(for: newCalendar.date(from: dayComponents) ?? selectedDay)
    }

    mutating func moveMonth(by offset: Int,
                            records: [WorkoutRecord],
                            now: Date,
                            calendar: Calendar = .current)
    {
        guard let candidate = calendar.date(byAdding: .month, value: offset, to: month), candidate <= now else { return }
        month = calendar.dateInterval(of: .month, for: candidate)?.start ?? candidate
        let currentMonth = calendar.dateInterval(of: .month, for: now)?.start
        if month == currentMonth {
            selectedDay = calendar.startOfDay(for: now)
            return
        }
        let inMonth = records.filter {
            calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) && $0.startedAt <= now
        }
        selectedDay = inMonth.map(\.startedAt).max().map(calendar.startOfDay(for:)) ?? month
    }

    mutating func select(day: Date,
                         records: [WorkoutRecord],
                         now: Date,
                         calendar: Calendar = .current) -> WorkoutRecord?
    {
        guard day <= now, calendar.isDate(day, equalTo: month, toGranularity: .month) else { return nil }
        selectedDay = calendar.startOfDay(for: day)
        let records = records.filter { $0.startedAt <= now && calendar.isDate($0.startedAt, inSameDayAs: selectedDay) }
        return records.count == 1 ? records[0] : nil
    }
}
