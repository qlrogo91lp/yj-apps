import SwiftUI

struct ScoreRing: View {
    let par: Int
    let strokes: Int
    let putts: Int
    /// 라운드 전체 파 대비 — 이 홀만의 값이 아니다.
    let relativeToPar: Int
    let sizing: CountingSizing
    let onTap: () -> Void

    var body: some View {
        ZStack {
            StrokeRing(segments: segments, sizing: sizing)

            VStack(spacing: 0) {
                Text("\(strokes)")
                    .font(.system(size: sizing.scoreFont, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text(ScoreFormat.relativeToPar(relativeToPar))
                    .font(.system(size: sizing.relativeFont, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button(action: onTap) {
                Circle()
                    .fill(.clear)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: sizing.innerDiameter, height: sizing.innerDiameter)
        }
    }

    private var segments: RingSegments {
        RingSegments(par: par, strokes: strokes, putts: putts)
    }
}

#Preview {
    VStack(spacing: 12) {
        ScoreRing(par: 4, strokes: 3, putts: 0, relativeToPar: -1, sizing: .regular) {}
        ScoreRing(par: 4, strokes: 5, putts: 2, relativeToPar: 2, sizing: .tight) {}
    }
}
