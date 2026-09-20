import SwiftUI

struct CalendarView: View {
    let matches: [Match]
    /// 현재 월 밖의 경기까지 포함한 소스. 날짜별 목록에서 거짓 빈 세션을 막는 데만 쓴다.
    let sourceMatches: [Match]
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

    private var dayRecords: [WorkoutSessionRecord] {
        guard let selectedDate else { return [] }
        let records = (try? SessionPersistenceService.shared.fetchAll()) ?? []
        return MatchSessionGroup.recordsForGrouping(
            records,
            displayedMatches: dayMatches,
            sourceMatches: sourceMatches
        ) { record in
            Calendar.current.isDate(record.startedAt, inSameDayAs: selectedDate)
        }
    }

    private var daySessions: [MatchSessionGroup] {
        MatchSessionGroup.group(dayMatches, records: dayRecords)
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

            if daySessions.isEmpty {
                Text(String(localized: "history_day_empty"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 32)
            } else {
                SessionList(
                    sessions: daySessions,
                    isLoadingMore: false,
                    onLoadMore: nil,
                    onSelect: onSelect,
                    onDelete: onDelete
                )
            }
        }
    }
}
