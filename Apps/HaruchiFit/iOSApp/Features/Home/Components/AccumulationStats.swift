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
            countText(stat.countText)
                .foregroundStyle(HaruchiPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(stat.durationText).font(.caption.monospacedDigit()).foregroundStyle(HaruchiPalette.dim)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// 숫자만 크게, 단위는 한 단계 작게 — `398 workouts` · `398회`. 영어 단위가 길어 통째로 크게 그리면 칸을 넘는다.
    /// 문구는 공유 카탈로그가 만든 그대로 쓰고, 화면에서 숫자 구간만 찾아 키운다.
    private func countText(_ text: String) -> Text {
        var attributed = AttributedString(text)
        attributed.font = .headline
        if let range = text.range(of: #"[0-9][0-9,.]*"#, options: .regularExpression),
           let lower = AttributedString.Index(range.lowerBound, within: attributed),
           let upper = AttributedString.Index(range.upperBound, within: attributed)
        {
            attributed[lower ..< upper].font = .title.bold().monospacedDigit()
        }
        return Text(attributed)
    }
}
