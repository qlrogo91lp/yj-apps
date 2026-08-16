import SwiftUI

/// `CircleIconButton`과 달리 히트 영역을 세로로만 넓힌다 — 옆이 링(가장 자주 쓰는
/// 탭 타깃)이라 가로로 넓히면 스트로크 탭을 가로챌 수 있다.
struct HoleArrowButton: View {
    let systemName: String
    let size: CGFloat
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        CircleIconButton(systemName: systemName, size: size, action: action)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.35)
            .frame(width: size, height: CountingSizing.arrowHitHeight)
            .contentShape(Rectangle())
    }
}

#Preview {
    HStack(spacing: 24) {
        HoleArrowButton(systemName: "chevron.left", size: 36, isEnabled: false) {}
        HoleArrowButton(systemName: "chevron.right", size: 36) {}
    }
}
