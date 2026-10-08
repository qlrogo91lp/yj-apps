import SwiftUI

struct RecordCalendarGrid: View {
    let calendar: Calendar
    let weekdays: [String]
    let cells: [RecordCalendarDay?]
    let selectedDay: Date
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(weekdays, id: \.self) { weekday in
                Text(weekday).font(.caption2).foregroundStyle(HaruchiPalette.dim)
                    .frame(maxWidth: .infinity)
            }
            ForEach(cells.indices, id: \.self) { index in
                if let day = cells[index] {
                    RecordDayCell(day: day, isSelected: calendar.isDate(day.date, inSameDayAs: selectedDay), calendar: calendar) {
                        onSelect(day.date)
                    }
                } else {
                    Color.clear.frame(minHeight: 44).accessibilityHidden(true)
                }
            }
        }
    }
}
