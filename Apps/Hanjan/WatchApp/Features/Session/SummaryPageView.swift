import SwiftUI

struct SummaryPageView: View {
    let session: LiveSession
    let now: Date
    let onEnd: () -> Void
    @State private var confirming = false
    private var elapsed: String {
        let minutes = max(0, Int(now.timeIntervalSince(session.startedAt)) / 60)
        return minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                Text(elapsed).font(.headline)
                Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) 시작").font(.caption2).foregroundStyle(.secondary)
                ForEach(session.ledger.countsByKind(), id: \.kindId) { count in
                    Text("\(count.name) \(count.count)잔").font(.caption)
                }
                Button("종료") { confirming = true }.buttonStyle(.plain).font(.caption.bold())
                    .frame(maxWidth: .infinity).padding(.vertical, 8).foregroundStyle(BrandColor.danger)
                    .overlay(Capsule().stroke(BrandColor.danger))
            }
        }.sheet(isPresented: $confirming) { EndConfirmView(onCancel: { confirming = false }, onEnd: { confirming = false; onEnd() }) }
    }
}

#Preview {
    SummaryPageView(session: LiveSession(id: UUID(), startedAt: Date(), limit: 8, currentKindId: DrinkPresets.soju.id), now: Date(), onEnd: {})
}
