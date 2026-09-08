import Charts
import SwiftUI

/// 최근 10회 세션의 운동시간 막대. "얼마나 오래 쳤나"만 맡는 독립 블록이라 기간 필터를 타지 않는다.
struct RecentTrendChart: View {
    /// 오래된 것부터. 비어 있으면 안내 문구를 대신 띄운다.
    let sessions: [MatchSessionGroup]

    var body: some View {
        if bars.isEmpty {
            Text(String(localized: "summary_trend_insufficient"))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Chart(bars, id: \.id) { bar in
                BarMark(
                    x: .value(String(localized: "summary_section_trend"), bar.label),
                    y: .value(String(localized: "summary_duration"), bar.minutes)
                )
                .foregroundStyle(Color.brand)
            }
            .frame(height: 140)
        }
    }

    /// 누적값이 없는 세션은 건너뛴다 — 0 막대는 "그날 안 뛰었다"로 읽힌다.
    private var bars: [Bar] {
        sessions.compactMap { session in
            guard let seconds = session.elapsedSeconds else { return nil }
            return Bar(id: session.id, label: Self.axisLabel(session.date), minutes: seconds / 60)
        }
    }

    private struct Bar {
        let id: UUID
        let label: String
        let minutes: Int
    }

    /// "8/24" — 로케일이 월·일 순서를 정한다.
    private static func axisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }
}
