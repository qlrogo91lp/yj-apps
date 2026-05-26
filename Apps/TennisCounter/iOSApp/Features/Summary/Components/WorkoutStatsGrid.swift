import SwiftUI

#Preview {
    WorkoutStatsGrid(stats: SummaryStats(
        totalMatches: 12,
        wins: 8,
        winRate: 0.67,
        totalCalories: 1240,
        totalDuration: 4980,
        avgHeartRate: 138
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}

struct WorkoutStatsGrid: View {
    let stats: SummaryStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "summary_section_workout"))
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                StatCard(
                    title: String(localized: "summary_total_calories"),
                    value: stats.formattedCalories,
                    color: .green
                )
                StatCard(
                    title: String(localized: "summary_duration"),
                    value: stats.formattedDuration,
                    color: .green
                )
                StatCard(
                    title: String(localized: "summary_avg_heartrate"),
                    value: stats.formattedHeartRate,
                    color: .green
                )
            }
        }
    }
}
