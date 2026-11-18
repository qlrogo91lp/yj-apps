import Foundation
@testable import Hanjan
import Testing

struct ClockFormatTests {
    @Test func uses24HourClock() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 21, minute: 5)))
        #expect(ClockFormat.string(date) == "21:05")
    }
}
