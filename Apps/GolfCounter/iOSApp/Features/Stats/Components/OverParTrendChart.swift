import Charts
import SwiftUI

/// 최근 라운드의 오버파 추이. 18홀 라운드는 원, 9홀·중단 라운드는 마름모로 구분한다 (spec §5).
struct OverParTrendChart: View {
    let points: [StatsSummary.TrendPoint]

    var body: some View {
        Chart {
            RuleMark(y: .value(String(localized: "chart_axis_even_par"), 0))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(points) { point in
                LineMark(x: .value(String(localized: "chart_axis_date"), point.date),
                         y: .value(String(localized: "chart_axis_over_par"), point.relativeToPar))
                    .foregroundStyle(Color.accentColor)

                PointMark(x: .value(String(localized: "chart_axis_date"), point.date),
                          y: .value(String(localized: "chart_axis_over_par"), point.relativeToPar))
                    .foregroundStyle(Color.accentColor)
                    .symbol(point.isFullRound ? .circle : .diamond)
            }
        }
        .chartXAxis {
            AxisMarks(values: points.map(\.date)) { _ in
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                AxisGridLine()
            }
        }
        .frame(height: 200)
    }
}

#Preview {
    OverParTrendChart(points: (0 ..< 5).map { index in
        StatsSummary.TrendPoint(id: UUID(),
                                date: Date(timeIntervalSince1970: 1_000_000 + Double(index) * 86400),
                                relativeToPar: [12, 9, 15, 7, 10][index],
                                isFullRound: index != 2)
    })
    .padding()
}
