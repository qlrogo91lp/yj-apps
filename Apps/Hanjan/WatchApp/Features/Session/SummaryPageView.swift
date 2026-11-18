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
                Text(elapsed).font(.system(size: 26, weight: .semibold))
                Text("\(ClockFormat.string(session.startedAt)) 시작").font(.caption2).foregroundStyle(.secondary)
                ForEach(session.ledger.countsByKind(), id: \.kindId) { count in
                    HStack {
                        Text(count.name)
                        Spacer()
                        Text("\(count.count)잔")
                    }.font(.caption)
                    Divider()
                }
                Button(role: .destructive) { confirming = true } label: { Label("종료", systemImage: "stop.fill") }
            }
        }.sheet(isPresented: $confirming) { EndConfirmView(onCancel: { confirming = false }, onEnd: { confirming = false; onEnd() }) }
    }
}
