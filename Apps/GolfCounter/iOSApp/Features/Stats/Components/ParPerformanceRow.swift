import SwiftUI

/// Par 3 / 4 / 5 각각의 홀당 평균 오버파. 어느 파에서 타수를 잃는지 보여준다 (spec §5).
struct ParPerformanceRow: View {
    let items: [StatsSummary.ParPerformance]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(items) { item in
                StatCard(title: "Par \(item.par)",
                         value: item.averageOverPar.map(ScoreFormat.averageRelativeToPar) ?? "–")
            }
        }
    }
}

#Preview {
    ParPerformanceRow(items: [
        StatsSummary.ParPerformance(par: 3, averageOverPar: 0.8),
        StatsSummary.ParPerformance(par: 4, averageOverPar: 1.2),
        StatsSummary.ParPerformance(par: 5, averageOverPar: nil),
    ])
    .padding()
}
