import Charts
import SwiftUI

struct BodyPartFrequencyChart: View {
    let values: [StatisticsDashboard.BodyFrequency]

    private var maximum: Int {
        max(1, values.map(\.count).max() ?? 0)
    }

    private var xAxisValues: [Int] {
        let step = max(1, Int(ceil(Double(maximum) / 4)))
        return Array(stride(from: 0, through: maximum, by: step))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("stats_body_parts").font(.headline).foregroundStyle(HaruchiPalette.text)
            Chart(values) { value in
                BarMark(x: .value("chart_count", value.count), y: .value("chart_body_part", value.part.title))
                    .foregroundStyle(HaruchiPalette.accent)
                    .accessibilityLabel("\(value.part.title), \(DisplayText.workouts(value.count))")
            }
            .chartXAxis { AxisMarks(values: xAxisValues) { _ in AxisGridLine(); AxisValueLabel() } }
            .chartXScale(domain: 0 ... maximum)
            .frame(height: CGFloat(values.count) * 34 + 20)
            Text("stats_body_parts_note")
                .font(.caption).foregroundStyle(HaruchiPalette.dim)
        }
        .padding()
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
