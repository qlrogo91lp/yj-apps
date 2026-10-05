import SwiftUI

struct UndoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(String(localized: "btn_undo"), systemImage: "arrow.uturn.backward")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(.white.opacity(0.1), in: Capsule())
        }
    }
}
