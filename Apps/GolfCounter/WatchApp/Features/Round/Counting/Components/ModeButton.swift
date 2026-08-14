import SwiftUI

/// 스윙/퍼팅 전환 버튼 — 헤더 오른쪽 끝의 원형이다 (spec §5).
///
/// Par와 대칭을 이루는 고정 원형이다. "Swing"/"Putt" 텍스트는 32pt대 원 안에서
/// 한 줄로 넣기엔 너무 길어(축약하면 채 이름처럼 보임) 아이콘으로 바꿨다 — 이 화면의
/// 다른 원형 버튼(◁·▷·↩)이 전부 아이콘 전용인 것과도 시각적으로 맞는다.
///
/// 배경·테두리 색이 링 세그먼트 색과 같다. 색이 "모드"라는 단어 역할을 대신하므로
/// 단일 토글 버튼의 모호함("현재 상태인가 누르면 갈 곳인가")이 해소된다.
struct ModeButton: View {
    @Binding var mode: StrokeInputMode
    let sizing: CountingSizing

    var body: some View {
        Button(action: toggle) {
            Image(systemName: iconName)
                .font(.system(size: sizing.headerButtonSize * 0.44, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: sizing.headerButtonSize, height: sizing.headerButtonSize)
                .background(tint.opacity(0.18), in: Circle())
                .overlay(Circle().strokeBorder(tint.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        mode == .swing ? .green : .orange
    }

    /// 골프 전용 SF Symbol은 `figure.golf` 하나뿐이라 퍼팅에 대응하는 채·공 아이콘이
    /// 없다 (실기 확인, 2026-08-14). `flag.circle.fill`(그린의 깃발)로 대체한다.
    private var iconName: String {
        mode == .swing ? "figure.golf" : "flag.circle.fill"
    }

    private func toggle() {
        mode = mode == .swing ? .putt : .swing
    }
}

#Preview {
    HStack(spacing: 12) {
        ModeButton(mode: .constant(.swing), sizing: .regular)
        ModeButton(mode: .constant(.putt), sizing: .tight)
    }
}
