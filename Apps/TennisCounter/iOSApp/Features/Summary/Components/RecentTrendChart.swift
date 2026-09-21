import Charts
import SwiftUI

/// 주·월은 최근 세션 운동시간, 전체는 월별 세션 수를 그린다.
struct RecentTrendChart: View {
    /// 오래된 것부터. 비어 있으면 안내 문구를 대신 띄운다.
    var sessions: [MatchSessionGroup] = []
    var monthlyCounts: [(month: Date, count: Int)]?

    var body: some View {
        if let monthlyCounts {
            monthlyChart(monthlyCounts)
        } else if bars.isEmpty {
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
            .chartLegend(.hidden)
            .frame(height: 140)
        }
    }

    private func monthlyChart(_ counts: [(month: Date, count: Int)]) -> some View {
        // 월 오름차순 중 첫 최댓값 하나만 강조한다. 동률에서도 라벨 위치가 흔들리지 않는다.
        let maximum = counts.map(\.count).max()
        let highlightedMonth = counts.first { $0.count == maximum }?.month
        return Chart(counts, id: \.month) { entry in
            BarMark(
                x: .value(String(localized: "summary_period_month"), entry.month, unit: .month),
                y: .value(String(localized: "summary_session_count"), entry.count)
            )
            .foregroundStyle(Color.brand)
            .annotation(position: .top) {
                if entry.month == highlightedMonth {
                    Text(entry.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.year(.twoDigits).month(.abbreviated))
            }
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        .frame(height: 140)
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
