import SwiftUI

/// 운동 구성 막대 아래 캡션 — `근력 26분 · 유산소 12분`. 종류 덩어리를 막대와 같은 색으로 칠한다.
/// 폰트는 호출부가 정한다. 상세와 공유 카드가 같이 쓴다.
struct CompositionCaption: View {
    let chips: [RecordListRow.Chip]

    var body: some View {
        Text(caption)
    }

    private var caption: AttributedString {
        var result = AttributedString()
        for (index, chip) in chips.enumerated() {
            if index > 0 {
                var separator = AttributedString(" · ")
                separator.foregroundColor = HaruchiPalette.dim
                result += separator
            }
            var text = AttributedString(chip.text)
            text.foregroundColor = chip.kind == .strength ? HaruchiPalette.accent : HaruchiPalette.cardio
            result += text
        }
        return result
    }
}

#Preview {
    CompositionCaption(chips: [.init(kind: .strength, minutes: 54), .init(kind: .cardio, minutes: 18)])
        .font(.system(size: 11, weight: .medium))
        .padding()
        .background(Color(white: 0.11))
}
