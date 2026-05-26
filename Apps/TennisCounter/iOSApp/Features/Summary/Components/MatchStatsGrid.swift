import SwiftUI

#Preview {
    MatchStatsGrid(stats: SummaryStats(
        totalMatches: 12,
        wins: 8,
        winRate: 0.67,
        totalCalories: nil,
        totalDuration: nil,
        avgHeartRate: nil
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}

struct MatchStatsGrid: View {
    let stats: SummaryStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: String(localized: "summary_total_matches"),
                value: "\(stats.totalMatches)",
                color: .green
            )
            StatCard(
                title: String(localized: "summary_win_rate"),
                value: String(format: "%.0f%%", stats.winRate * 100),
                color: .green
            )
            StatCard(
                title: String(localized: "summary_wins"),
                value: "\(stats.wins)",
                color: .green
            )
        }
    }
}
