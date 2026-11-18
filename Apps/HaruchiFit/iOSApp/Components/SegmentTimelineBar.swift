import SwiftUI

struct SegmentTimelineBar: View {
    let spans: [RecordDetailSummary.Span]

    var body: some View {
        GeometryReader { proxy in
            let total = spans.reduce(0) { $0 + $1.seconds }
            HStack(spacing: 0) {
                ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
                    Rectangle()
                        .fill(span.kind == .strength ? HaruchiPalette.accent : HaruchiPalette.cardio)
                        .frame(width: total > 0 ? proxy.size.width * CGFloat(span.seconds) / CGFloat(total) : 0)
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
    }
}
