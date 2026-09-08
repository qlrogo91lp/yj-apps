import Foundation

/// 누적 통계용 시간 표기. 경기 중 타이머는 `WorkoutMetrics.formatSeconds` 를 계속 쓴다 —
/// 그쪽은 시:분:초라 누적에 쓰면 470:00:00 처럼 카드에서 넘친다.
enum CumulativeDuration {
    static func format(_ seconds: Int) -> String {
        let totalMinutes = max(0, seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return String(format: String(localized: "duration_minutes"), minutes)
        }
        if hours >= 100 {
            return String(format: String(localized: "duration_hours"), hours)
        }
        return String(format: String(localized: "duration_hours_minutes"), hours, minutes)
    }
}
