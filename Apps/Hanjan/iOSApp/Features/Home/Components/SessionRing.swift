import SwiftUI

struct SessionRing: View {
    let session: LiveSession

    var body: some View {
        let equivalent = session.ledger.sojuEquivalent()
        let exceeded = LimitLevel.of(equivalent: equivalent, limit: session.limit) == .exceeded
        VStack(spacing: 24) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: exceeded ? 1 : min(equivalent / max(session.limit, 0.01), 1))
                    .stroke(exceeded ? BrandColor.danger : BrandColor.amber, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(SojuFormat.string(equivalent)).font(.system(size: 64, weight: .bold))
                    Text("/ \(SojuFormat.string(session.limit))잔").font(.system(size: 22)).foregroundStyle(.secondary)
                }
            }.frame(width: 220, height: 220)
            if let progress = session.toastProgress {
                HStack(spacing: 12) {
                    ForEach(0 ..< progress.total, id: \.self) { index in
                        Circle()
                            .fill(index < progress.filled ? BrandColor.amber : .clear)
                            .overlay(Circle().strokeBorder(BrandColor.amber, lineWidth: 2))
                            .frame(width: 16, height: 16)
                    }
                }.accessibilityLabel("\(progress.total)번 중 \(progress.filled)번째")
            }
        }
    }
}
