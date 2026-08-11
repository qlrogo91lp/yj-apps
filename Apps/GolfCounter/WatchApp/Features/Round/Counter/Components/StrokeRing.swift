import SwiftUI

/// 파 칸수만큼 나뉜 링 (spec §6).
///
/// 회색 트랙 위에 채워진 칸을 덧그린다. 채워진 칸은 `trim`의 끝값을 시작값에서
/// 끝값으로 움직여 호가 그려지듯 차오른다 — 애니메이션은 호출부가 건다.
/// 파를 넘긴 타수는 바깥에 얇은 링으로 덧그린다.
struct StrokeRing: View {
    let segments: RingSegments
    let sizing: CounterSizing

    var body: some View {
        ZStack {
            arcs(kinds: segments.slots,
                 diameter: sizing.ringDiameter,
                 lineWidth: sizing.ringStroke,
                 drawsTrack: true)

            if !segments.overflow.isEmpty {
                arcs(kinds: paddedOverflow,
                     diameter: overflowDiameter,
                     lineWidth: sizing.overflowStroke,
                     drawsTrack: false)
            }
        }
        .frame(width: sizing.outerRadius * 2, height: sizing.outerRadius * 2)
    }

    private var overflowDiameter: CGFloat {
        sizing.ringDiameter + sizing.ringStroke + sizing.overflowGap * 2 + sizing.overflowStroke
    }

    /// 바깥 링도 주 링과 같은 칸수로 나눈다 — 채워지지 않은 칸은 그리지 않는다.
    private var paddedOverflow: [RingSegments.Kind] {
        let slotCount = segments.slots.count
        guard slotCount > 0 else { return [] }
        return (0 ..< slotCount).map { index in
            index < segments.overflow.count ? segments.overflow[index] : .empty
        }
    }

    private func arcs(kinds: [RingSegments.Kind],
                      diameter: CGFloat,
                      lineWidth: CGFloat,
                      drawsTrack: Bool) -> some View
    {
        let count = max(kinds.count, 1)
        // 칸 사이 간격. 둘레 대비 비율이라 칸이 많아져도 비례해서 줄어든다.
        let gap = 0.5 / CGFloat(count) * 0.16

        return ZStack {
            ForEach(Array(kinds.enumerated()), id: \.offset) { index, kind in
                let start = CGFloat(index) / CGFloat(count) + gap
                let end = CGFloat(index + 1) / CGFloat(count) - gap

                if drawsTrack {
                    arc(from: start, to: end, color: .gray.opacity(0.25), lineWidth: lineWidth)
                }

                // 빈 칸은 길이 0으로 그려둔다. 채워질 때 끝값이 움직이므로 애니메이션이 붙는다.
                arc(from: start,
                    to: kind == .empty ? start : end,
                    color: color(for: kind),
                    lineWidth: lineWidth)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func arc(from start: CGFloat, to end: CGFloat, color: Color, lineWidth: CGFloat) -> some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            // Circle().trim은 3시 방향에서 시작한다. 12시로 옮긴다.
            .rotationEffect(.degrees(-90))
    }

    private func color(for kind: RingSegments.Kind) -> Color {
        switch kind {
        case .swing: .green
        case .putt: .orange
        case .empty: .clear
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StrokeRing(segments: RingSegments(par: 4, strokes: 3, putts: 0), sizing: .regular)
        StrokeRing(segments: RingSegments(par: 4, strokes: 5, putts: 2), sizing: .tight)
    }
}
