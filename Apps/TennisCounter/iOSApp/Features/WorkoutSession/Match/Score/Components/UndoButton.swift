import SwiftUI

struct UndoButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        // .disabled() 를 쓰지 않는다 — 꺼진 버튼이 탭을 밑의 득점 영역으로 흘리지 않게 항상 탭을 받는다.
        Button {
            if isEnabled { action() }
        } label: {
            Label(String(localized: "btn_undo"), systemImage: "arrow.uturn.backward")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(.white.opacity(0.1), in: Capsule())
                .opacity(isEnabled ? 1 : 0.35)
                .padding(10)
                .contentShape(Rectangle())
        }
    }
}
