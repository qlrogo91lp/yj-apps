import SwiftUI

/// 스탯 두 칸 — `이번 달`(횟수 · 시간) / `연속`(주 · 최장 기록). 위 숫자가 크고 아래 줄이 작다.
struct AccumulationStats: View {
    let month: HomeDashboard.Stat
    let streak: HomeDashboard.Streak

    var body: some View {
        HStack(spacing: 0) {
            stat("home_stat_month", count: month.countText, detail: month.durationText)
            Rectangle().fill(HaruchiPalette.line).frame(width: 1, height: 44)
            stat("home_stat_streak", count: streak.countText, detail: streak.detailText)
        }
        .padding(.vertical, 14)
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stat(_ title: LocalizedStringKey, count: String, detail: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(HaruchiPalette.dim)
            countText(count)
                .foregroundStyle(HaruchiPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail).font(.caption.monospacedDigit()).foregroundStyle(HaruchiPalette.dim)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// 숫자만 크게, 단위는 한 단계 작게 — `12 weeks` · `12주`. 영어 단위가 길어 통째로 크게 그리면 칸을 넘는다.
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
