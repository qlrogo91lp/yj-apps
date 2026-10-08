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
                ContentUnavailableView(month.emptyMessage ?? "이 날에는 기록이 없어요", systemImage: "calendar",
                                       description: Text(emptyDescription))
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
        let formatter = RecordListBuilder.formatter("M월 d일 (E)", calendar: month.calendar, locale: Locale(identifier: "ko_KR"))
        return "\(formatter.string(from: selectedDay)) · \(month.selectedRows.count)회"
    }

    private var emptyDescription: String {
        switch month.emptyMessage {
        case "아직 기록이 없어요": "워치에서 운동하거나 홈의 + 버튼으로 기록해 보세요."
        case "이 달에는 기록이 없어요": "다른 달을 선택해 보세요."
        default: "다른 날짜를 선택해 보세요."
        }
    }
}
