import Foundation
@testable import TennisCounter
import Testing

struct DurationFormatTests {
    /// 기대값을 로케일 문자열에서 만든다. 시뮬레이터 언어가 무엇이든 깨지지 않는다.
    private func expected(_ key: String.LocalizationValue, _ args: CVarArg...) -> String {
        String(format: String(localized: key), arguments: args)
    }

    @Test func formatsMinutesOnlyBelowOneHour() {
        #expect(CumulativeDuration.format(2520) == expected("duration_minutes", 42))
    }

    @Test func formatsHoursAndMinutes() {
        #expect(CumulativeDuration.format(67320) == expected("duration_hours_minutes", 18, 42))
    }

    @Test func formatsHoursOnlyAboveHundred() {
        #expect(CumulativeDuration.format(1_692_000) == expected("duration_hours", 470))
    }

    @Test func formatsZero() {
        #expect(CumulativeDuration.format(0) == expected("duration_minutes", 0))
    }
}
