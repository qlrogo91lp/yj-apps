import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// 로케일을 인자로 넘기므로 실행 언어와 무관하다.
@MainActor
struct DisplayDateFormatTests {
    private let calendar = GrassFixture.seoul
    private let ko = Locale(identifier: "ko_KR")
    private let en = Locale(identifier: "en_US")
    private let evening = GrassFixture.date(2026, 8, 22, 19, 12)

    private func format(_ template: DisplayDateFormat.Template, _ locale: Locale) -> String {
        DisplayDateFormat.formatter(template, calendar: calendar, locale: locale).string(from: evening)
    }

    /// ICU 가 끼우는 좁은 공백을 일반 공백으로 맞춘다.
    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{2009}", with: " ")
    }

    @Test("한국어 템플릿 출력은 전환 전 패턴과 같다")
    func koreanMatchesLegacyPatterns() {
        #expect(format(.monthDayWeekday, ko) == "8월 22일 (토)")
        #expect(format(.monthDay, ko) == "8월 22일")
        #expect(format(.yearMonthDay, ko) == "2026년 8월 22일")
        #expect(format(.yearMonthDayWeekday, ko) == "2026년 8월 22일 (토)")
        #expect(format(.yearMonth, ko) == "2026년 8월")
        #expect(normalized(format(.time, ko)) == "오후 7:12")
    }

    @Test("영어 템플릿 출력")
    func englishTemplates() {
        #expect(format(.monthDayWeekday, en) == "Sat, Aug 22")
        #expect(format(.monthDay, en) == "Aug 22")
        #expect(format(.yearMonthDay, en) == "Aug 22, 2026")
        #expect(format(.yearMonth, en) == "August 2026")
        #expect(normalized(format(.time, en)) == "7:12 PM")
    }

    @Test("날짜와 시각은 가운뎃점으로 잇는다")
    func dateAndTimeJoinedWithMiddleDot() {
        let ko = DisplayDateFormat.dateAndTime(evening, dateTemplate: .monthDayWeekday, calendar: calendar, locale: ko)
        let en = DisplayDateFormat.dateAndTime(evening, dateTemplate: .monthDayWeekday, calendar: calendar, locale: en)
        #expect(normalized(ko) == "8월 22일 (토) · 오후 7:12")
        #expect(normalized(en) == "Sat, Aug 22 · 7:12 PM")
    }

    @Test("홈 월 제목은 한국어만 월이 앞이다")
    func homeMonthTitle() {
        #expect(DisplayDateFormat.homeMonthTitle(for: evening, calendar: calendar, locale: ko) == "8월 2026")
        #expect(DisplayDateFormat.homeMonthTitle(for: evening, calendar: calendar, locale: en) == "August 2026")
    }

    @Test("시간 범위 — 한국어는 시간대 이름, 영어는 구간 표기")
    func timeRange() {
        let end = GrassFixture.date(2026, 8, 22, 20, 24)
        #expect(DisplayDateFormat.timeRange(from: evening, to: end, calendar: calendar, locale: ko) == "저녁 7:12 – 8:24")
        #expect(normalized(DisplayDateFormat.timeRange(from: evening, to: end, calendar: calendar, locale: en)) == "7:12 – 8:24 PM")
    }

    @Test("한국어 시간 범위는 시간대가 바뀌면 끝에도 이름을 붙인다")
    func koreanTimeRangeKeepsChangedPeriod() {
        let start = GrassFixture.date(2026, 8, 22, 20, 30)
        let end = GrassFixture.date(2026, 8, 22, 21, 40)
        #expect(DisplayDateFormat.timeRange(from: start, to: end, calendar: calendar, locale: ko) == "저녁 8:30 – 밤 9:40")
    }
}
