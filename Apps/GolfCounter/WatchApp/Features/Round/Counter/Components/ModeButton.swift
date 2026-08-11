import SwiftUI

/// 스윙/퍼팅 전환 버튼 (spec §5).
///
/// 폭이 넉넉하면 알약("스윙 모드"), 좁으면 원형("스윙")으로 떨어진다.
/// 알약 변형에 `maxWidth: .infinity`를 주면 `ViewThatFits`가 언제나 "들어간다"고
/// 판정해 좁은 화면에서 라벨이 잘리므로, 고정 폭을 준다.
///
/// 글자·테두리 색이 링 세그먼트 색과 같다. 색이 "모드"라는 단어 역할을 대신하므로
/// 두 글자로 줄어도 의미가 유지되고, 단일 토글 버튼의 모호함
/// ("현재 상태인가 누르면 갈 곳인가")이 해소된다.
struct ModeButton: View {
    @Binding var mode: StrokeInputMode
    let sizing: CounterSizing

    var body: some View {
        Button(action: toggle) {
            ViewThatFits(in: .horizontal) {
                label(text: wideTitle, width: sizing.modeWideWidth)
                label(text: compactTitle, width: sizing.modeHeight)
            }
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        mode == .swing ? .green : .orange
    }

    private var wideTitle: String {
        mode == .swing ? "스윙 모드" : "퍼팅 모드"
    }

    private var compactTitle: String {
        mode == .swing ? "스윙" : "퍼팅"
    }

    private func toggle() {
        mode = mode == .swing ? .putt : .swing
    }

    /// width == modeHeight이면 Capsule이 정확히 원이 된다.
    private func label(text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: sizing.headerFont, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .frame(width: width, height: sizing.modeHeight)
            .background(tint.opacity(0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.7), lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 12) {
        ModeButton(mode: .constant(.swing), sizing: .regular)
        ModeButton(mode: .constant(.putt), sizing: .tight)
    }
}
