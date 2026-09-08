import SwiftUI

struct SummaryStatsGrid: View {
    let stats: SummaryStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: String(localized: "summary_total_matches"),
                value: "\(stats.totalMatches)"
            )
            StatCard(
                title: String(localized: "summary_duration"),
                value: stats.formattedDuration
            )
            StatCard(
                title: String(localized: "summary_total_calories"),
                value: stats.formattedCalories
            )
        }
    }
}

#Preview {
    SummaryStatsGrid(stats: SummaryStats(
        totalMatches: 12,
        wins: 8,
        winRate: 0.67,
        totalCalories: 3840,
        totalDuration: 67320
    ))
    .padding()
    .background(.black)
}
