import Charts
import SwiftUI

struct BodyPartFrequencyChart: View {
    let values: [StatisticsDashboard.BodyFrequency]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("운동 부위").font(.headline).foregroundStyle(HaruchiPalette.text)
            Chart(values) { value in
                BarMark(x: .value("횟수", value.count), y: .value("부위", value.part.title))
                    .foregroundStyle(HaruchiPalette.accent)
                    .accessibilityLabel("\(value.part.title), \(value.count)회")
            }
            .chartXScale(domain: 0 ... max(1, values.map(\.count).max() ?? 0))
            .frame(height: CGFloat(values.count) * 34 + 20)
            Text("부위를 태그한 운동 횟수예요. 한 운동은 여러 부위에 포함될 수 있어요.")
                .font(.caption).foregroundStyle(HaruchiPalette.dim)
        }
        .padding()
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
