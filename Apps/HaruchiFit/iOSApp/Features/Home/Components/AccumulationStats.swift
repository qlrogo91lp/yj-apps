import SwiftUI

/// 축적 스탯 두 칸 — `이번 달` / `전체 누적`. 횟수가 크고 시간이 작다.
struct AccumulationStats: View {
    let month: HomeDashboard.Stat
    let total: HomeDashboard.Stat

    var body: some View {
        HStack(spacing: 0) {
            stat("home_stat_month", month)
            Rectangle().fill(HaruchiPalette.line).frame(width: 1, height: 44)
            stat("home_stat_total", total)
        }
        .padding(.vertical, 14)
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stat(_ title: LocalizedStringKey, _ stat: HomeDashboard.Stat) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(HaruchiPalette.dim)
            Text(stat.countText).font(.title.bold().monospacedDigit()).foregroundStyle(HaruchiPalette.text)
            Text(stat.durationText).font(.caption.monospacedDigit()).foregroundStyle(HaruchiPalette.dim)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
