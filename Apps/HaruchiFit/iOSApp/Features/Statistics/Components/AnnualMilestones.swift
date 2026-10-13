import SwiftUI

struct AnnualMilestones: View {
    let values: [StatisticsDashboard.Milestone]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("stats_milestones").font(.headline).foregroundStyle(HaruchiPalette.text)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(values) { value in
                    VStack(spacing: 4) {
                        Image(systemName: value.isAchieved ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundStyle(value.isAchieved ? HaruchiPalette.accent : HaruchiPalette.dim)
                        Text(DisplayText.workouts(value.target)).foregroundStyle(HaruchiPalette.text)
                        if !value.isAchieved { Text("stats_milestone_remaining \(value.remaining)").font(.caption).foregroundStyle(HaruchiPalette.dim) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 82)
                    .background(HaruchiPalette.surface2, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(value.isAchieved
                        ? String(localized: "stats_milestone_achieved_a11y \(value.target)")
                        : String(localized: "stats_milestone_remaining_a11y \(value.target) \(value.remaining)"))
                }
            }
        }
        .padding()
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
