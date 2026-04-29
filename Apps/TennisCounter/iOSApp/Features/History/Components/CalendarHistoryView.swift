import SwiftUI

struct CalendarHistoryView: View {
    let matches: [Match]
    @Binding var selectedMatch: Match?

    @State private var displayedMonth = Date()

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayLabels
            daysGrid
        }
    }

    private var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.headline)
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var weekdayLabels: some View {
        HStack {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }

    private var daysGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    let dayMatches = matchesForDate(date)
                    DayCellView(date: date, matches: dayMatches) {
                        selectedMatch = dayMatches.first
                    }
                } else {
                    Color.clear
                        .frame(height: 36)
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

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

private struct DayCellView: View {
    let date: Date
    let matches: [Match]
    let onTap: () -> Void

    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(date) }
    private var hasMatch: Bool { !matches.isEmpty }
    private var hasWin: Bool { matches.contains { $0.myTotalSets > $0.yourTotalSets } }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .blue : .primary)
                .frame(width: 32, height: 32)
                .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
                .clipShape(Circle())

            if hasMatch {
                Circle()
                    .fill(hasWin ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
            } else {
                Color.clear.frame(width: 5, height: 5)
            }
        }
        .onTapGesture(perform: onTap)
    }
}
