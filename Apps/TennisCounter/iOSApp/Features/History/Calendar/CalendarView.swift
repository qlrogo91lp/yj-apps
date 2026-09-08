import SwiftUI

struct CalendarView: View {
    let matches: [Match]
    let currentMonth: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    @Binding var selectedDate: Date?
    let onSelect: (Match) -> Void
    let onDelete: (Match) -> Void

    private var dayMatches: [Match] {
        guard let selectedDate else { return [] }
        return matches.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: selectedDate) }
    }

    var body: some View {
        // 캘린더는 고정, 스크롤은 아래 SessionList 가 갖는다 — 바깥을 ScrollView 로
        // 감싸면 List 와 중첩돼 높이가 무너진다.
        VStack(spacing: 0) {
            MonthHeader(
                displayedMonth: currentMonth,
                onPrevious: onPrevious,
                onNext: onNext
            )
            WeekdayLabels()
            CalendarGrid(
                matches: matches,
                displayedMonth: currentMonth,
                selectedDate: $selectedDate
            )
            .padding(.bottom, 8)

            if dayMatches.isEmpty {
                Text(String(localized: "history_day_empty"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 32)
            } else {
                SessionList(
                    sessions: MatchSessionGroup.group(dayMatches),
                    isLoadingMore: false,
                    onLoadMore: nil,
                    onSelect: onSelect,
                    onDelete: onDelete
                )
            }
        }
    }
}
