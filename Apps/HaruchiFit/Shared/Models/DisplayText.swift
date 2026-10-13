import Foundation

/// 횟수 · 시간 문구. 세 빌더가 같은 표기를 쓰도록 한 곳에 둔다 (`12회` · `72분` · `9.2시간`).
enum DisplayText {
    static func workouts(_ count: Int) -> String {
        String(localized: "count_workouts \(count)", table: "Shared")
    }

    static func minutes(_ minutes: Int) -> String {
        String(localized: "duration_minutes \(minutes)", table: "Shared")
    }

    /// 1시간 미만은 분, 이상은 소수 첫째 자리 시간.
    static func duration(seconds: Int) -> String {
        guard seconds >= 3600 else { return minutes(seconds / 60) }
        let hours = String(format: "%.1f", Double(seconds) / 3600)
        return String(localized: "duration_hours \(hours)", table: "Shared")
    }
}
