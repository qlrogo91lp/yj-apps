import SwiftUI

/// 세션의 구간 구성을 **길이 비율대로** 보여주는 가로 바.
///
/// `Shared/` 에 두는 이유는 iOS 기록 상세가 같은 바를 쓰기 때문이다 (제품 스펙 04a).
/// 세그먼트는 이 앱의 유일한 차별점이라 어느 화면에서도 생략하지 않는다.
struct SegmentBar: View {
    let segments: [WorkoutRecordMessage.SegmentPayload]
    var height: CGFloat = 8

    var body: some View {
        // 구간이 없으면 바 자체를 그리지 않는다 — 1분 미만 세션.
        if !segments.isEmpty {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(Array(widths(in: proxy.size.width).enumerated()), id: \.offset) { index, width in
                        Rectangle()
                            .fill(color(of: segments[index].kind))
                            .frame(width: width)
                    }
                }
            }
            .frame(height: height)
            .clipShape(Capsule())
        }
    }

    private func color(of kind: SegmentKind) -> Color {
        kind == .strength ? .brandOrange : .blue
    }

    /// **누적 위치를 먼저 반올림하고 그 차이를 폭으로 쓴다.** 칸마다 따로 반올림하면
    /// 합이 전체 폭과 어긋나 워치의 좁은 화면에서 마지막 칸이 눈에 띄게 밀린다.
    private func widths(in totalWidth: CGFloat) -> [CGFloat] {
        let total = segments.reduce(0) { $0 + $1.durationSeconds }
        guard total > 0 else { return [] }

        var widths: [CGFloat] = []
        var elapsed = 0
        var previousEdge: CGFloat = 0
        for segment in segments {
            elapsed += segment.durationSeconds
            let edge = (CGFloat(elapsed) / CGFloat(total) * totalWidth).rounded()
            widths.append(edge - previousEdge)
            previousEdge = edge
        }
        return widths
    }
}

#Preview("구간 3개") {
    SegmentBar(segments: [
        .init(kind: .strength, startOffset: 0, durationSeconds: 3240),
        .init(kind: .cardio, startOffset: 3240, durationSeconds: 1080),
        .init(kind: .strength, startOffset: 4320, durationSeconds: 1024),
    ])
    .padding()
}

#Preview("빈 배열") {
    SegmentBar(segments: [])
        .padding()
}
