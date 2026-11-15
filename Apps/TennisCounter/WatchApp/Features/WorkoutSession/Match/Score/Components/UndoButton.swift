import SwiftUI

struct UndoButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        // .disabled() 를 쓰지 않는다 — 꺼진 버튼이 탭을 밑의 득점 버튼으로 흘리지 않게 항상 탭을 받는다.
        Button {
            if isEnabled { action() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .semibold))
                Text(String(localized: "watch_undo"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.3))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.35)
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
