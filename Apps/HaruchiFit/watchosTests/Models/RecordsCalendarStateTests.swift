import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct RecordsCalendarStateTests {
    private static let calendar: Calendar = {
        var calendar = GrassFixture.seoul
        calendar.firstWeekday = 1
        return calendar
    }()

    @Test("과거 월로 이동하면 그 달의 가장 최근 기록을 선택한다")
    func selectsLatestRecordWhenMovingToPastMonth() throws {
        let context = try GrassFixture.makeContext()
        let older = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 3), totalSeconds: 600)
        let latest = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 21), totalSeconds: 600)
        var state = RecordsCalendarState(now: GrassFixture.date(2026, 10, 8), calendar: Self.calendar)

        state.moveMonth(by: -1, records: [older, latest], now: GrassFixture.date(2026, 10, 8), calendar: Self.calendar)

        #expect(Self.calendar.isDate(state.month, equalTo: GrassFixture.date(2026, 9, 1), toGranularity: .month))
        #expect(Self.calendar.isDate(state.selectedDay, inSameDayAs: latest.startedAt))
    }

    @Test("한 기록인 날짜만 상세로 넘길 기록을 반환한다")
    func returnsOnlyRecordForExplicitDaySelection() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 8), totalSeconds: 600)
        var state = RecordsCalendarState(now: GrassFixture.date(2026, 10, 8), calendar: Self.calendar)

        let selected = state.select(day: record.startedAt, records: [record], now: GrassFixture.date(2026, 10, 8), calendar: Self.calendar)

        #expect(selected?.persistentModelID == record.persistentModelID)
    }

    @Test("달력과 시간대가 바뀌어도 보고 있던 월과 날짜의 달력상 날짜를 유지한다")
    func rebasesCivilDatesForNewCalendar() throws {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        var state = RecordsCalendarState(now: GrassFixture.date(2026, 10, 8), calendar: GrassFixture.seoul)

        state.rebase(from: GrassFixture.seoul, to: losAngeles)

        #expect(losAngeles.component(.month, from: state.month) == 10)
        #expect(losAngeles.component(.day, from: state.selectedDay) == 8)
    }
}
