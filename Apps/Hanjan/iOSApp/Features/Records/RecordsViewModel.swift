import Combine
import Foundation

/// 기록 탭의 보기 상태(목록·캘린더, 보고 있는 달, 고른 날짜)와 목록 묶기. 데이터는 화면의 `@Query` 가 넘긴다.
final class RecordsViewModel: ObservableObject {
    enum Mode: Hashable { case list, calendar }

    struct MonthSection: Identifiable {
        let month: Date
        let sessions: [SessionRecord]
        var id: Date {
            month
        }
    }

    @Published var mode: Mode = .list
    @Published private(set) var currentMonth: Date
    @Published private(set) var selectedDate: Date?
    let calendar: Calendar

    init(now: Date = Date(), calendar: Calendar = RecordFormat.calendar) {
        self.calendar = calendar
        currentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        selectedDate = calendar.startOfDay(for: now)
    }

    func changeMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: currentMonth) else { return }
        currentMonth = month
        selectedDate = nil
    }

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    /// 기록 탭은 끝난 술자리만 보인다. 진행 중 세션은 홈이 다룬다 — 여기서 고치면 진행 중 장부와 어긋난다.
    func ended(_ sessions: [SessionRecord]) -> [SessionRecord] {
        sessions.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    /// 최신 달부터, 달 안에서는 최신 술자리부터.
    func sections(_ sessions: [SessionRecord]) -> [MonthSection] {
        var result: [MonthSection] = []
        for session in ended(sessions) {
            let month = calendar.dateInterval(of: .month, for: session.startedAt)?.start ?? session.startedAt
            if let last = result.last, last.month == month {
                result[result.count - 1] = MonthSection(month: month, sessions: last.sessions + [session])
            } else {
                result.append(MonthSection(month: month, sessions: [session]))
            }
        }
        return result
    }

    func sessions(_ sessions: [SessionRecord], on day: Date?) -> [SessionRecord] {
        guard let day else { return [] }
        return ended(sessions).filter { calendar.isDate($0.startedAt, inSameDayAs: day) }.reversed()
    }
}
