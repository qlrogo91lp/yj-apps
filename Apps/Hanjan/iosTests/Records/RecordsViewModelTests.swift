import Foundation
@testable import Hanjan
import Testing

@MainActor
struct RecordsViewModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func record(_ start: Date, ended: Bool = true) -> SessionRecord {
        SessionRecord(startedAt: start, endedAt: ended ? start.addingTimeInterval(3600) : nil)
    }

    @Test func sections_groupByStartMonth_newestFirst_excludingActive() {
        let viewModel = RecordsViewModel(now: date(11, 15), calendar: calendar)
        let oct = record(date(10, 31, 23))
        let nov1 = record(date(11, 1, 20))
        let nov7 = record(date(11, 7, 19))
        let active = record(date(11, 15, 19), ended: false)
        let sections = viewModel.sections([oct, active, nov1, nov7])
        #expect(sections.map(\.month) == [date(11, 1), date(10, 1)])
        #expect(sections.first?.sessions.map(\.id) == [nov7.id, nov1.id])
        #expect(sections.last?.sessions.map(\.id) == [oct.id])
    }

    @Test func sessionsOnDay_oldestFirst() {
        let viewModel = RecordsViewModel(now: date(11, 15), calendar: calendar)
        let early = record(date(11, 7, 18))
        let late = record(date(11, 7, 22))
        let other = record(date(11, 8, 1))
        #expect(viewModel.sessions([late, other, early], on: date(11, 7)).map(\.id) == [early.id, late.id])
        #expect(viewModel.sessions([late], on: nil).isEmpty)
    }

    @Test func changeMonth_movesMonthAndClearsSelection() {
        let viewModel = RecordsViewModel(now: date(11, 15, 12), calendar: calendar)
        #expect(viewModel.currentMonth == date(11, 1))
        #expect(viewModel.selectedDate == date(11, 15))
        viewModel.changeMonth(by: -1)
        #expect(viewModel.currentMonth == date(10, 1))
        #expect(viewModel.selectedDate == nil)
        viewModel.select(date(10, 31, 23))
        #expect(viewModel.selectedDate == date(10, 31))
    }
}
