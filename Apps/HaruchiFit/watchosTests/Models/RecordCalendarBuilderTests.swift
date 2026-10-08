import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct RecordCalendarBuilderTests {
    private static let calendar: Calendar = {
        var calendar = GrassFixture.seoul
        calendar.firstWeekday = 1
        return calendar
    }()

    @Test("같은 날 두 기록은 한 칸의 합산 농도와 두 번의 월 요약이 된다")
    func foldsSameDayRecords() throws {
        let context = try GrassFixture.makeContext()
        let first = GrassFixture.record(in: context,
                                        startedAt: GrassFixture.date(2026, 10, 8, 7),
                                        totalSeconds: 1800)
        let second = GrassFixture.record(in: context,
                                         startedAt: GrassFixture.date(2026, 10, 8, 19),
                                         totalSeconds: 3600)
        let month = GrassFixture.date(2026, 10, 1)
        let result = RecordCalendarBuilder.month(from: [first, second], displayedMonth: month,
                                                 selectedDay: first.startedAt,
                                                 now: GrassFixture.date(2026, 10, 9),
                                                 calendar: Self.calendar)

        let day = try #require(result.days.first { Self.calendar.isDate($0.date, inSameDayAs: first.startedAt) })
        #expect(day.sessionCount == 2)
        #expect(day.level == .peak)
        #expect(result.summary == "2회 · 1.5시간")
        #expect(result.selectedRows.map(\.id) == [second.persistentModelID, first.persistentModelID])
    }

    @Test("월은 첫 요일에 맞춰 빈 칸을 넣고 마지막 주를 완성한다")
    func buildsMonthGrid() {
        let result = RecordCalendarBuilder.month(from: [], displayedMonth: GrassFixture.date(2026, 8, 1),
                                                 selectedDay: GrassFixture.date(2026, 8, 1),
                                                 now: GrassFixture.date(2026, 10, 9),
                                                 calendar: Self.calendar)

        #expect(result.cells.count == 42)
        #expect(result.days.count == 31)
        #expect(result.cells.prefix(6).allSatisfy { $0 == nil })
        #expect(result.weekdays.first == "일")
    }

    @Test("미래에 시작한 기록은 현재 월 농도와 요약에서 제외한다")
    func excludesFutureRecord() throws {
        let context = try GrassFixture.makeContext()
        let future = GrassFixture.record(in: context,
                                         startedAt: GrassFixture.date(2026, 10, 10),
                                         totalSeconds: 7200)
        let result = RecordCalendarBuilder.month(from: [future], displayedMonth: GrassFixture.date(2026, 10, 1),
                                                 selectedDay: future.startedAt,
                                                 now: GrassFixture.date(2026, 10, 9),
                                                 calendar: Self.calendar)

        #expect(result.summary == "0회 · 0분")
        #expect(result.selectedRows.isEmpty)
    }

    @Test("전체 기록이 없으면 홈의 수동 기록 안내를 보여 준다")
    func givesGlobalEmptyMessage() {
        let result = RecordCalendarBuilder.month(from: [], displayedMonth: GrassFixture.date(2026, 10, 1),
                                                 selectedDay: GrassFixture.date(2026, 10, 8),
                                                 now: GrassFixture.date(2026, 10, 9),
                                                 calendar: Self.calendar)

        #expect(result.emptyMessage == "아직 기록이 없어요")
    }
}
