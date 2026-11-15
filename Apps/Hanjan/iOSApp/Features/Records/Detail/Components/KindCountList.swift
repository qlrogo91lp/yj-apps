import SwiftUI

/// 술별 잔 수. "소주 3잔 · 맥주 2잔" 을 줄마다 하나씩. 짠만은 들어오지 않는다(`countsByKind` 가 뺀다).
struct KindCountList: View {
    let counts: [KindCount]
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("마신 술")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("편집", action: onEdit)
                    .font(.system(size: 14, weight: .semibold))
                    .tint(BrandColor.amber)
            }
            if counts.isEmpty {
                Text("기록된 잔이 없어요")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(counts, id: \.kindId) { count in
                    HStack {
                        Text(count.name)
                        Spacer()
                        Text("\(count.count)잔")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 16))
                }
            }
        }
    }
}

#Preview {
    KindCountList(
        counts: [
            KindCount(kindId: DrinkPresets.soju.id, name: "소주", count: 3),
            KindCount(kindId: DrinkPresets.beer.id, name: "맥주", count: 2),
        ],
        onEdit: {}
    )
    .padding()
    .background(BrandColor.surface)
    .preferredColorScheme(.dark)
}
