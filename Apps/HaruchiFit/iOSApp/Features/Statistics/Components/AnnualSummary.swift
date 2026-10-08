import SwiftUI

struct AnnualSummary: View {
    let dashboard: StatisticsDashboard
    @State private var showsWeeklyAverageExplanation = false

    var body: some View {
        ViewThatFits {
            HStack(spacing: 0) { stats }
            VStack(spacing: 12) { stats }
        }
        .padding()
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var stats: some View {
        value(title: dashboard.isCurrentYear ? "올해 운동" : "연간 운동", value: dashboard.countText)
        Divider().overlay(HaruchiPalette.line)
        value(title: dashboard.isCurrentYear ? "올해 누적" : "연간 누적", value: dashboard.durationText)
        Divider().overlay(HaruchiPalette.line)
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Text("주 평균")
                Button {
                    showsWeeklyAverageExplanation = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showsWeeklyAverageExplanation) {
                    Text(dashboard.weeklyAverageExplanation)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            .foregroundStyle(HaruchiPalette.dim)
            Text(dashboard.weeklyAverageText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(HaruchiPalette.text)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHint(dashboard.weeklyAverageExplanation)
    }

    private func value(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).foregroundStyle(HaruchiPalette.dim)
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(HaruchiPalette.text)
        }
        .frame(maxWidth: .infinity)
    }
}
