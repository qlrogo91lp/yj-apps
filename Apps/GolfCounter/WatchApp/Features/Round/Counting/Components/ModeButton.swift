import SwiftUI

/// 스윙/퍼팅 전환 버튼 — 헤더 오른쪽 끝의 원형이다 (spec §5).
/// 배경·테두리 색이 링 세그먼트 색과 같아, 색이 "모드"라는 단어 역할을 대신한다.
struct ModeButton: View {
    @Binding var mode: StrokeInputMode
    let sizing: CountingSizing

    var body: some View {
        Button(action: toggle) {
            // `figure.*` 계열은 같은 폰트 크기에서도 다른 심볼보다 크게 그려진다.
            // 0.4를 넘기면 원 테두리에 닿을 듯 답답해진다 (42mm 실측).
            Image(systemName: iconName)
                .font(.system(size: sizing.headerButtonSize * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: sizing.headerButtonSize, height: sizing.headerButtonSize)
                .background(tint.opacity(0.18), in: Circle())
                .overlay(Circle().strokeBorder(tint.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contentShape(Circle().inset(by: -CountingSizing.headerButtonHitInset))
    }

    private var tint: Color {
        mode == .swing ? .green : .orange
    }

    /// 골프 전용 SF Symbol은 `figure.golf` 하나뿐이라 퍼팅에 대응하는 채·공 아이콘이
    /// 없다 (실기 확인, 2026-08-14). `flag.circle.fill`(그린의 깃발)로 대체한다.
    private var iconName: String {
        mode == .swing ? "figure.golf" : "flag.fill"
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
