import Foundation
@testable import Hanjan
import Testing

@MainActor
struct CalendarMarksTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    /// 소주 환산 `equivalent` 잔을 마신 세션.
    private func record(_ start: Date, equivalent: Double, limit: Double = 8) -> SessionRecord {
        let record = SessionRecord(startedAt: start, endedAt: start.addingTimeInterval(3600), limit: limit)
        record.totalGrams = equivalent * DrinkPresets.soju.alcoholGrams
        return record
    }

    @Test func drankDay_isDrank_otherDaysNone() {
        let marks = CalendarMarks.of([record(date(11, 7, 19), equivalent: 5)], month: date(11, 1), calendar: calendar)
        #expect(marks[date(11, 7)] == CalendarMarks.Mark.drank)
        #expect(marks[date(11, 8)] == CalendarMarks.Mark.none)
        #expect(marks.count == 30)
    }

    @Test func twoSessionsOneExceeded_isExceeded() {
        let first = record(date(11, 7, 18), equivalent: 9)
        let second = record(date(11, 7, 22), equivalent: 2)
        #expect(CalendarMarks.of([first, second], month: date(11, 1), calendar: calendar)[date(11, 7)] == CalendarMarks.Mark.exceeded)
        #expect(CalendarMarks.of([second, first], month: date(11, 1), calendar: calendar)[date(11, 7)] == CalendarMarks.Mark.exceeded)
    }

    @Test func sessionCountsOnStartDay() {
        let lateNight = record(date(10, 31, 23, 50), equivalent: 3)
        #expect(CalendarMarks.of([lateNight], month: date(11, 1), calendar: calendar)[date(11, 1)] == CalendarMarks.Mark.none)
        #expect(CalendarMarks.of([lateNight], month: date(10, 1), calendar: calendar)[date(10, 31)] == CalendarMarks.Mark.drank)
    }

    @Test func sessionWithoutDrinks_isNone() {
        let marks = CalendarMarks.of([record(date(11, 7, 19), equivalent: 0)], month: date(11, 1), calendar: calendar)
        #expect(marks[date(11, 7)] == CalendarMarks.Mark.none)
    }

    @Test func zeroLimit_doesNotCrash() {
        let marks = CalendarMarks.of([record(date(11, 7, 19), equivalent: 2, limit: 0)], month: date(11, 1), calendar: calendar)
        #expect(marks[date(11, 7)] == CalendarMarks.Mark.exceeded)
    }

    @Test func monthTotals_countsOnlyThatMonth() {
        let sessions = [
            record(date(10, 31, 23, 50), equivalent: 3),
            record(date(11, 1, 20), equivalent: 2),
            record(date(11, 7, 19), equivalent: 9),
            record(date(11, 20, 19), equivalent: 8),
        ]
        let totals = CalendarMarks.totals(sessions, month: date(11, 1), calendar: calendar)
        #expect(totals.count == 3)
        #expect(abs(totals.equivalent - 19) < 0.001)
        #expect(totals.exceededCount == 1)
        #expect(totals.line == "3회 · 19잔 · 한도 초과 1회")
    }

    @Test func monthTotals_emptyMonth() {
        let totals = CalendarMarks.totals([], month: date(11, 1), calendar: calendar)
        #expect(totals.line == "0회 · 0잔 · 한도 초과 0회")
    }
}
