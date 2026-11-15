import SwiftUI

struct ActiveSessionCard: View {
    let session: LiveSession
    var body: some View {
        let equivalent = session.ledger.sojuEquivalent()
        let color = LimitLevel.of(equivalent: equivalent, limit: session.limit) == .exceeded ? BrandColor.danger : BrandColor.amber
        VStack(alignment: .leading, spacing: 12) {
            Text("소주 환산").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("\(SojuFormat.string(equivalent)) / \(SojuFormat.string(session.limit))잔").font(.largeTitle.bold()).foregroundStyle(color)
                if let progress = session.toastProgress {
                    HStack(spacing: 4) {
                        ForEach(0 ..< progress.total, id: \.self) { index in
                            Circle().fill(index < progress.filled ? BrandColor.amber : BrandColor.amber.opacity(0.2)).frame(width: 8, height: 8)
                        }
                    }.accessibilityLabel("\(progress.total)번 중 \(progress.filled)번째")
                }
            }
            ProgressView(value: min(equivalent / max(1, session.limit), 1)).tint(color)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(BrandColor.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview { ActiveSessionCard(session: LiveSession(id: UUID(), startedAt: Date(), limit: 8, currentKindId: DrinkPresets.soju.id)) }
