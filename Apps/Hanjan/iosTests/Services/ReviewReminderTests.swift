import Foundation
@testable import Hanjan
import Testing

struct ReviewReminderTests {
    @Test(arguments: [(23, 1), (2, 0), (5, 1)]) func fireDate(hour: Int, dayOffset: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let ended = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: hour)))
        let expected = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15 + dayOffset, hour: 10))!
        #expect(ReviewReminder.fireDate(endedAt: ended, calendar: calendar) == expected)
    }
}
