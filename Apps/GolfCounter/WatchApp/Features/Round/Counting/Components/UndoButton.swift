import SwiftUI

/// 등장·퇴장 애니메이션은 `.transition`만 선언한다 — 실제 구동은 `canUndo` 변화에
/// `.animation`을 건 호출부(`CountingView`)가 한다.
struct UndoButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        CircleIconButton(systemName: "arrow.uturn.backward",
                         size: size,
                         hitInset: CountingSizing.undoHitInset,
                         action: action)
            .padding(.trailing, CountingSizing.pageIndicatorInset - CountingSizing.ringHorizontalPadding)
            .offset(y: CountingSizing.undoBottomOffset)
            .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    VStack(spacing: 24) {
        UndoButton(size: 36) {}
        UndoButton(size: 30) {}
    }
}
