import Charts
import SwiftUI

struct StatisticsFrequencyChart: View {
    let title: String
    let values: [StatisticsDashboard.Frequency]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(HaruchiPalette.text)
            Chart(values) { value in
                BarMark(x: .value("항목", value.id), y: .value("횟수", value.count))
                    .foregroundStyle(value.isHighlighted ? HaruchiPalette.accent : HaruchiPalette.dim)
                    .opacity(value.isFuture ? 0.3 : 1)
                    .accessibilityLabel("\(value.title), \(value.count)회")
            }
            .chartXAxis {
                AxisMarks(values: values.map(\.id)) { item in
                    AxisValueLabel(values.first { $0.id == item.as(Int.self) }?.title ?? "")
                }
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel() } }
            .chartYScale(domain: 0 ... max(1, values.map(\.count).max() ?? 0))
            .frame(height: 180)
            .accessibilityElement(children: .contain)
        }
        .padding()
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
