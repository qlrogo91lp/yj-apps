import SwiftUI

struct CalendarGrid: View {
    let matches: [Match]
    let displayedMonth: Date
    @Binding var selectedMatch: Match?

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        let days = daysInMonth()
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    let dayMatches = matchesForDate(date)
                    DayCell(date: date, matches: dayMatches) {
                        selectedMatch = dayMatches.max(by: { $0.startedAt < $1.startedAt })
                    }
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func daysInMonth() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func matchesForDate(_ date: Date) -> [Match] {
        matches.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }
}
