import Foundation

/// 날짜·시각 표기 한 곳. 패턴을 번역하지 않고 로케일 템플릿에 맡긴다.
/// 한국어 출력은 전환 전과 같다 (`8월 22일 (토)` · `오후 7:12`).
///
/// 템플릿으로 안 되는 두 곳(홈 월 제목, 상세 시간 범위)만 한국어가 지금 표기를 지킨다 — 제품 스펙이 못박았다.
enum DisplayDateFormat {
    enum Template: String {
        case monthDayWeekday = "MMMdEEE"
        case monthDay = "MMMd"
        case yearMonthDay = "yMMMd"
        case yearMonthDayWeekday = "yMMMdEEE"
        case yearMonth = "yMMMM"
        case time = "jmm"
    }

    static func formatter(_ template: Template, calendar: Calendar, locale: Locale) -> DateFormatter {
        formatter(template.rawValue, calendar: calendar, locale: locale)
    }

    static func formatter(_ template: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// 날짜 + 시각. 템플릿 하나로 만들면 한국어에서 가운뎃점이 빠지고 영어에 `at` 이 낀다.
    static func dateAndTime(_ date: Date, dateTemplate: Template, calendar: Calendar, locale: Locale) -> String {
        let day = formatter(dateTemplate, calendar: calendar, locale: locale).string(from: date)
        let time = formatter(.time, calendar: calendar, locale: locale).string(from: date)
        return "\(day) · \(time)"
    }

    /// 홈 상단 월 제목. 한국어 `8월 2026` (스펙 02), 그 밖은 `August 2026`.
    static func homeMonthTitle(for date: Date, calendar: Calendar, locale: Locale) -> String {
        if isKorean(locale) {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = locale
            formatter.dateFormat = "M월 yyyy"
            return formatter.string(from: date)
        }
        return formatter(.yearMonth, calendar: calendar, locale: locale).string(from: date)
    }

    /// 기록 상세 시간 범위. 한국어 `저녁 7:12 – 8:24` (스펙 04, 같은 시간대면 끝의 이름 생략), 그 밖은 `7:12 – 8:24 PM`.
    static func timeRange(from start: Date, to end: Date, calendar: Calendar, locale: Locale) -> String {
        if isKorean(locale) {
            let withPeriod = patternFormatter("B h:mm", calendar: calendar, locale: locale)
            let withoutPeriod = patternFormatter("h:mm", calendar: calendar, locale: locale)
            let period = patternFormatter("B", calendar: calendar, locale: locale)
            let endFormatter = period.string(from: start) == period.string(from: end) ? withoutPeriod : withPeriod
            return "\(withPeriod.string(from: start)) – \(endFormatter.string(from: end))"
        }
        let interval = DateIntervalFormatter()
        interval.calendar = calendar
        interval.timeZone = calendar.timeZone
        interval.locale = locale
        interval.dateStyle = .none
        interval.timeStyle = .short
        return interval.string(from: start, to: end)
    }

    private static func isKorean(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ko"
    }

    private static func patternFormatter(_ pattern: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter
    }
}
