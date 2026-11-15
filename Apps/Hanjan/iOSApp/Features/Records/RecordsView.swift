import SwiftData
import SwiftUI

/// 기록 탭. `목록 | 캘린더` 전환, 줄이나 카드를 누르면 상세. T9 가 탭에 건다.
struct RecordsView: View {
    @Query(sort: \SessionRecord.startedAt, order: .reverse) private var records: [SessionRecord]
    @StateObject private var viewModel = RecordsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("보기", selection: $viewModel.mode) {
                    Text("목록").tag(RecordsViewModel.Mode.list)
                    Text("캘린더").tag(RecordsViewModel.Mode.calendar)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                switch viewModel.mode {
                case .list:
                    RecordListView(sections: viewModel.sections(records))
                case .calendar:
                    let ended = viewModel.ended(records)
                    RecordCalendarView(
                        month: viewModel.currentMonth,
                        calendar: viewModel.calendar,
                        marks: CalendarMarks.of(ended, month: viewModel.currentMonth, calendar: viewModel.calendar),
                        totalsLine: CalendarMarks.totals(ended, month: viewModel.currentMonth, calendar: viewModel.calendar).line,
                        selectedDate: viewModel.selectedDate,
                        daySessions: viewModel.sessions(records, on: viewModel.selectedDate),
                        onPrevious: { viewModel.changeMonth(by: -1) },
                        onNext: { viewModel.changeMonth(by: 1) },
                        onSelect: { viewModel.select($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandColor.background)
            .navigationTitle("기록")
            .navigationDestination(for: UUID.self) { id in
                RecordDetailView(sessionId: id)
            }
        }
        .tint(BrandColor.amber)
    }
}

#Preview {
    RecordsView()
        .modelContainer(RecordsPreviewData.container())
        .preferredColorScheme(.dark)
}

#Preview("빈 기록") {
    RecordsView()
        .modelContainer(for: HanjanSchema.models, inMemory: true)
        .preferredColorScheme(.dark)
}
