import SwiftUI

/// 이번 주 운동 구성 — 홈에서 유일하게 허용하는 차트다 (제품 스펙 3절).
/// 구성을 낼 수 없을 때는 같은 자리에 마일스톤 또는 빈 주 문구를 한 줄로 보인다.
struct WeekCompositionBar: View {
    let week: HomeDashboard.WeekComposition?
    let milestone: String?
    let emptyText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("이번 주").font(.subheadline.weight(.semibold)).foregroundStyle(HaruchiPalette.text)
                Spacer()
                if let week {
                    Text(week.totalText).font(.subheadline.monospacedDigit()).foregroundStyle(HaruchiPalette.dim)
                }
            }
            if let week {
                bar(week)
                HStack(spacing: 14) {
                    ForEach(week.legend, id: \.kind) { item in
                        HStack(spacing: 6) {
                            Circle().fill(color(item.kind)).frame(width: 8, height: 8)
                            Text(item.text).font(.caption).foregroundStyle(HaruchiPalette.dim)
                        }
                    }
                }
            } else if let line = milestone ?? emptyText {
                Text(line).font(.footnote).foregroundStyle(HaruchiPalette.dim)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func bar(_ week: HomeDashboard.WeekComposition) -> some View {
        let sum = max(week.strengthSeconds + week.cardioSeconds, 1)
        return GeometryReader { proxy in
            HStack(spacing: 2) {
                if week.strengthSeconds > 0 {
                    Rectangle().fill(HaruchiPalette.accent)
                        .frame(width: proxy.size.width * CGFloat(week.strengthSeconds) / CGFloat(sum))
                }
                if week.cardioSeconds > 0 {
                    Rectangle().fill(HaruchiPalette.cardio)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HaruchiPalette.surface2)
            .clipShape(Capsule())
        }
        .frame(height: 10)
    }

    private func color(_ kind: SegmentKind) -> Color {
        kind == .strength ? HaruchiPalette.accent : HaruchiPalette.cardio
    }
}
