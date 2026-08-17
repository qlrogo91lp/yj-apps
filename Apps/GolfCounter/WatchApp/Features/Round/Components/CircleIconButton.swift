import SwiftUI

/// 회색 원반 위 아이콘 하나 — 라운드 화면들이 공유하는 보조 조작 버튼이다 (spec §5).
/// 색을 가지는 것은 링과 모드 버튼뿐이라, 색이 곧 "카운트에 관여한다"는 신호가 된다.
struct CircleIconButton: View {
    let systemName: String
    let size: CGFloat
    /// 시각 크기 밖으로 균일하게 넓히는 탭 영역. `.contentShape`만 키우므로 레이아웃에
    /// 보고되는 크기는 그대로다.
    ///
    /// **양옆에 조작 가능한 뷰가 붙어 있으면 쓰지 말 것** — 겹치는 자리에서 어느 쪽이
    /// 탭을 가져갈지 SwiftUI가 보장하지 않는다. 그런 경우는 축 하나만 `.frame`으로
    /// 키우는 별도 방식을 쓴다 (`HoleArrowButton` 참조).
    var hitInset: CGFloat = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: size, height: size)
                .background(Color.gray.opacity(0.25), in: Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle().inset(by: -hitInset))
    }
}

#Preview {
    HStack {
        CircleIconButton(systemName: "chevron.left", size: 30) {}
        CircleIconButton(systemName: "arrow.uturn.backward", size: 30) {}
        CircleIconButton(systemName: "chevron.right", size: 30) {}
    }
}
