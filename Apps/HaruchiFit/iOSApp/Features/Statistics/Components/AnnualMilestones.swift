import SwiftUI

struct AnnualMilestones: View {
    let values: [StatisticsDashboard.Milestone]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("연간 마일스톤").font(.headline).foregroundStyle(HaruchiPalette.text)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(values) { value in
                    VStack(spacing: 4) {
                        Image(systemName: value.isAchieved ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundStyle(value.isAchieved ? HaruchiPalette.accent : HaruchiPalette.dim)
                        Text("\(value.target)회").foregroundStyle(HaruchiPalette.text)
                        if !value.isAchieved { Text("\(value.remaining)회 남음").font(.caption).foregroundStyle(HaruchiPalette.dim) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 82)
                    .background(HaruchiPalette.surface2, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(value.isAchieved ? "\(value.target)회 달성" : "\(value.target)회, \(value.remaining)회 남음")
                }
            }
        }
        .padding()
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
