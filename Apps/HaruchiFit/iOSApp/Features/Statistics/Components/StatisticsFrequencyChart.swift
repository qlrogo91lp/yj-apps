import Charts
import SwiftUI

struct StatisticsFrequencyChart: View {
    let title: LocalizedStringKey
    let values: [StatisticsDashboard.Frequency]

    private var maximum: Int {
        max(1, values.map(\.count).max() ?? 0)
    }

    private var yAxisValues: [Int] {
        let step = max(1, Int(ceil(Double(maximum) / 4)))
        return Array(stride(from: 0, through: maximum, by: step))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(HaruchiPalette.text)
            Chart(values) { value in
                BarMark(x: .value("chart_item", value.id), y: .value("chart_count", value.count))
                    .foregroundStyle(value.isHighlighted ? HaruchiPalette.accent : HaruchiPalette.dim)
                    .opacity(value.isFuture ? 0.3 : 1)
                    .accessibilityLabel("\(value.title), \(DisplayText.workouts(value.count))")
            }
            .chartXAxis {
                AxisMarks(values: values.map(\.id)) { item in
                    AxisValueLabel(values.first { $0.id == item.as(Int.self) }?.title ?? "")
                }
            }
            .chartYAxis { AxisMarks(values: yAxisValues) { _ in AxisGridLine(); AxisValueLabel() } }
            .chartYScale(domain: 0 ... maximum)
            .frame(height: 180)
            .accessibilityElement(children: .contain)
        }
        .padding()
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
