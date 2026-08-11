import SwiftUI

/// 하단 조작행 — 이전 홀 · 모드 · 다음 홀 (spec §5).
/// 하단 중앙이 엄지가 가장 닿기 쉬운 자리라 가장 자주 쓰는 모드 전환을 거기 둔다.
struct CounterControls: View {
    @Binding var mode: StrokeInputMode
    let canGoToPrevious: Bool
    let sizing: CounterSizing
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: sizing.spacing) {
            arrow(systemName: "chevron.left", action: onPrevious)
                .disabled(!canGoToPrevious)
                .opacity(canGoToPrevious ? 1 : 0.35)

            ModeButton(mode: $mode, sizing: sizing)

            arrow(systemName: "chevron.right", action: onNext)
        }
        .frame(height: sizing.modeHeight)
    }

    private func arrow(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: sizing.arrowSize * 0.4, weight: .semibold))
                .frame(width: sizing.arrowSize, height: sizing.arrowSize)
                .background(Color.gray.opacity(0.25), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CounterControls(mode: .constant(.swing), canGoToPrevious: false,
                    sizing: .regular, onPrevious: {}, onNext: {})
}
