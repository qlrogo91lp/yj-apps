import SwiftData
import SwiftUI

/// 기록 캘린더. Ralli `History/Calendar/CalendarView` 를 복사해 고쳤다.
/// 달 위에 그 달 요약 한 줄, 아래에 고른 날의 술자리 카드.
struct RecordCalendarView: View {
    let month: Date
    let calendar: Calendar
    let marks: [Date: CalendarMarks.Mark]
    let totalsLine: String
    let selectedDate: Date?
    let daySessions: [SessionRecord]
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("이전 달")
                    Spacer()
                    Text(RecordFormat.month(month))
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("다음 달")
                }
                .tint(BrandColor.amber)

                Text(totalsLine)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                CalendarGrid(month: month, calendar: calendar, marks: marks, selectedDate: selectedDate, onSelect: onSelect)
                    .padding(.bottom, 8)

                if selectedDate != nil {
                    if daySessions.isEmpty {
                        Text("이 날은 기록이 없어요")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)
                    } else {
                        ForEach(daySessions) { session in
                            NavigationLink(value: session.id) {
                                DaySummaryCard(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    let container = RecordsPreviewData.container()
    let sessions = (try? container.mainContext.fetch(FetchDescriptor<SessionRecord>())) ?? []
    let calendar = RecordFormat.calendar
    let selected = sessions.map(\.startedAt).max() ?? .now
    return NavigationStack {
        RecordCalendarView(
            month: selected,
            calendar: calendar,
            marks: CalendarMarks.of(sessions, month: selected, calendar: calendar),
            totalsLine: CalendarMarks.totals(sessions, month: selected, calendar: calendar).line,
            selectedDate: selected,
            daySessions: sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selected) },
            onPrevious: {},
            onNext: {},
            onSelect: { _ in }
        )
        .background(BrandColor.background)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
