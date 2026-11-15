import Foundation

/// 기록 화면의 날짜·요약 문구. 이번 버전은 한국어만 내므로 기기 언어와 무관하게 ko_KR 로 적는다.
enum RecordFormat {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.firstWeekday = 1
        return calendar
    }()

    private static let locale = Locale(identifier: "ko_KR")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = format
        return formatter
    }

    private static let monthFormatter = formatter("yyyy년 M월")
    private static let dayFormatter = formatter("M월 d일 EEEE")
    private static let shortDayFormatter = formatter("M월 d일")
    private static let timeFormatter = formatter("a h:mm")

    /// "2026년 11월"
    static func month(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    /// "11월 7일 토요일"
    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// "11월 7일"
    static func shortDay(_ date: Date) -> String {
        shortDayFormatter.string(from: date)
    }

    /// "오후 7:20 – 오후 10:04". 종료 전이면 시작 시각만.
    static func timeRange(_ start: Date, _ end: Date?) -> String {
        guard let end else { return timeFormatter.string(from: start) }
        return "\(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))"
    }

    /// "5잔" — 소주 환산, 0.5 단위.
    static func glasses(_ equivalent: Double) -> String {
        "\(SojuFormat.string(equivalent))잔"
    }

    /// 목록 한 줄의 보조 문구. "성수동 · 지민, 민수". 둘 다 없으면 nil.
    static func subtitle(placeName: String?, companions: [String]) -> String? {
        let parts = [placeName?.isEmpty == false ? placeName : nil, companions.isEmpty ? nil : companions.joined(separator: ", ")]
            .compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
