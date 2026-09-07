import Foundation

/// 요약 화면의 시간 표기. 1시간을 넘기면 `1:12:24`, 아니면 `54:12`.
enum SummaryFormat {
    static func duration(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }
}
