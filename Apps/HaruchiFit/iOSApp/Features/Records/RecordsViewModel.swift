import Combine
import Foundation

/// 기록 탭의 배선. **표시 규칙은 `RecordListBuilder` 에 있다** — 이 자리는 iOS 테스트 타깃이
/// 없어 유닛 테스트가 닿지 않는다 (`GrassViewModel` 과 같은 이유).
@MainActor
final class RecordsViewModel: ObservableObject {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case calendar
        case list

        var id: Self {
            self
        }

        var title: String {
            self == .calendar ? "달력" : "목록"
        }
    }

    @Published var mode: DisplayMode = .calendar
    @Published private(set) var sections: [RecordListSection] = []
    @Published private(set) var calendarState: RecordsCalendarState
    @Published private(set) var calendarMonth: RecordCalendarMonth

    private var calendar: Calendar
    private let followsSystemCalendar: Bool

    init(calendar: Calendar? = nil) {
        followsSystemCalendar = calendar == nil
        let calendar = calendar ?? .current
        self.calendar = calendar
        let now = Date()
        calendarState = RecordsCalendarState(now: now, calendar: calendar)
        calendarMonth = RecordCalendarBuilder.month(from: [], displayedMonth: now, selectedDay: now,
                                                    now: now, calendar: calendar)
    }

    /// View 가 `@Query` 로 읽은 결과를 밀어넣는다. `이번 주` 는 부른 시각 기준이다.
    func rebuild(from records: [WorkoutRecord]) {
        rebuild(from: records, now: Date())
    }

    func rebuild(from records: [WorkoutRecord], now: Date) {
        refreshCalendarIfNeeded()
        sections = RecordListBuilder.sections(from: records, now: now, calendar: calendar)
        calendarMonth = RecordCalendarBuilder.month(from: records, displayedMonth: calendarState.month,
                                                    selectedDay: calendarState.selectedDay, now: now, calendar: calendar)
    }

    func moveMonth(by offset: Int, from records: [WorkoutRecord]) {
        let now = Date()
        calendarState.moveMonth(by: offset, records: records, now: now, calendar: calendar)
        rebuild(from: records, now: now)
    }

    func select(day: Date, from records: [WorkoutRecord]) -> WorkoutRecord? {
        let now = Date()
        let record = calendarState.select(day: day, records: records, now: now, calendar: calendar)
        rebuild(from: records, now: now)
        return record
    }

    var canMoveNext: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: calendarState.month) else { return false }
        return next <= Date()
    }

    private func refreshCalendarIfNeeded() {
        guard followsSystemCalendar else { return }
        let updated = Calendar.current
        guard updated.timeZone != calendar.timeZone || updated.firstWeekday != calendar.firstWeekday else { return }
        calendarState.rebase(from: calendar, to: updated)
        calendar = updated
    }
}
