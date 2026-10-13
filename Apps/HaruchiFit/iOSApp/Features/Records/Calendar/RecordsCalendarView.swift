import SwiftUI

struct RecordsCalendarView: View {
    let month: RecordCalendarMonth
    let selectedDay: Date
    let canMoveNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSelectDay: (Date) -> Void
    let onSelectRecord: (WorkoutRecord) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RecordMonthHeader(title: month.title, summary: month.summary, canMoveNext: canMoveNext,
                                  onPrevious: onPrevious, onNext: onNext)
                RecordCalendarGrid(calendar: month.calendar, weekdays: month.weekdays, cells: month.cells,
                                   selectedDay: selectedDay, onSelect: onSelectDay)
                selectedRecords
            }
            .padding()
        }
    }

    @ViewBuilder private var selectedRecords: some View {
        if month.selectedRows.isEmpty {
            VStack(spacing: 12) {
                Text(selectedTitle).font(.headline).foregroundStyle(HaruchiPalette.text)
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "calendar")
                } description: {
                    Text(emptyDescription)
                }
                    .foregroundStyle(HaruchiPalette.dim)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedTitle).font(.headline).foregroundStyle(HaruchiPalette.text)
                ForEach(month.selectedRows) { row in
                    Button { onSelectRecord(row.record) } label: { RecordRow(row: row) }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var selectedTitle: String {
        let formatter = DisplayDateFormat.formatter(.monthDayWeekday, calendar: month.calendar, locale: .current)
        return "\(formatter.string(from: selectedDay)) · \(DisplayText.workouts(month.selectedRows.count))"
    }

    private var emptyTitle: LocalizedStringKey {
        switch month.emptyState {
        case .noRecords: "records_empty_title"
        case .emptyMonth: "calendar_empty_month_title"
        case .emptyDay, nil: "calendar_empty_day_title"
        }
    }

    private var emptyDescription: LocalizedStringKey {
        switch month.emptyState {
        case .noRecords: "records_empty_message"
        case .emptyMonth: "calendar_empty_month_message"
        case .emptyDay, nil: "calendar_empty_day_message"
        }
    }
}
