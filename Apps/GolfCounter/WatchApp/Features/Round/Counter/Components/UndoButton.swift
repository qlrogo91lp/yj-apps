import SwiftUI

/// 상단 정보행 오른쪽 끝의 취소 버튼 (spec §5).
///
/// tennis-counter는 아이콘 + "취소" 텍스트가 든 캡슐 필을 쓰지만, 골프는 아이콘만 있는
/// 원형이다. 링이 이 화면의 시각적 핵심이라 필의 폭(약 73pt)이 링을 가리기 때문이며,
/// 헤더로 올리면서 모양도 헤더의 다른 원형 버튼(Par)과 맞췄다.
/// 등장·퇴장 트랜지션은 tennis와 같은 것을 쓴다.
struct UndoButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: size, height: size)
                .background(Color.gray.opacity(0.3), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    UndoButton(size: 36) {}
}
