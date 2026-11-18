import Foundation
@testable import Hanjan
import Testing

struct MonthSummaryTests {
    @Test func usesStartDateAndCountsOnlyExceeded() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 50)))
        let record = SessionRecord(startedAt: start, endedAt: start.addingTimeInterval(1200), limit: 1)
        record.totalGrams = DrinkPresets.soju.alcoholGrams * 2
        let result = MonthSummary.of([record], month: start, calendar: calendar)
        #expect(result.count == 1)
        #expect(result.equivalent == 2)
        #expect(result.exceededCount == 1)
        #expect(MonthSummary.of([record], month: start.addingTimeInterval(86400), calendar: calendar).count == 0)
    }
}
