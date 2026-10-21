import SwiftUI

/// 공유 카드 머리줄 아래 자리에 들어가는 운동 구성 — 막대와 종류별 시간 한 줄.
/// 카드는 이미지로 구워지므로 값만 받는다.
struct ShareComposition: View {
    let composition: RecordShareContent.Composition

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SegmentTimelineBar(spans: composition.spans)
            CompositionCaption(chips: composition.chips)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview("한 줄") {
    ShareComposition(composition: .init(
        spans: [.init(kind: .strength, seconds: 3240), .init(kind: .cardio, seconds: 1080), .init(kind: .strength, seconds: 300)],
        chips: [.init(kind: .strength, minutes: 59), .init(kind: .cardio, minutes: 18)]
    ))
    .frame(width: 234, height: 30, alignment: .topLeading)
    .padding()
    .background(Color(white: 0.11))
}
