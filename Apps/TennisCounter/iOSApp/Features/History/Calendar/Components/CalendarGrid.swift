import SwiftUI

struct CalendarGrid: View {
    let matches: [Match]
    let displayedMonth: Date
    @Binding var selectedDate: Date?

    private var calendar: Calendar {
        Calendar.current
    }

    var body: some View {
        let days = daysInMonth()
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    // 캘린더는 날짜만 고른다. 상세는 하단 목록의 경기 행에서 연다 —
                    // 그날 마지막 경기 하나만 시트로 띄우면 나머지에 닿을 방법이 없다.
                    DayCell(
                        date: date,
                        matches: matchesForDate(date),
                        isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                    ) {
                        selectedDate = date
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
