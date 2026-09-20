import SwiftUI

struct SummaryStatsGrid: View {
    let stats: SummaryStats
    let period: SummaryPeriod

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: String(localized: "summary_total_matches"),
                value: stats.totalMatches.formatted()
            )
            StatCard(
                title: String(localized: "summary_win_rate"),
                value: stats.winRate.formatted(.percent.precision(.fractionLength(0)))
            )
            if period == .all {
                StatCard(title: String(localized: "summary_session_count"), value: stats.sessionCount.formatted())
                StatCard(title: String(localized: "summary_average_session_duration"), value: stats.formattedAverageSessionDuration)
            } else {
                StatCard(title: String(localized: "summary_duration"), value: stats.formattedDuration)
                StatCard(title: String(localized: "summary_total_calories"), value: stats.formattedCalories)
            }
        }
    }
}

#Preview {
    SummaryStatsGrid(stats: SummaryStats(
        totalMatches: 12,
        wins: 8,
        winRate: 0.67,
        totalCalories: 3840,
        totalDuration: 67320,
        sessionCount: 8,
        averageSessionSeconds: 8415
    ), period: .all)
        .padding()
        .background(.black)
}
