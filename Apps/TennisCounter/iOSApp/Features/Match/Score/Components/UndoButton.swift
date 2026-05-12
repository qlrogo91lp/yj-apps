import SwiftUI

struct UndoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(String(localized: "btn_undo"), systemImage: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.white.opacity(0.1), in: Capsule())
        }
        .allowsHitTesting(true)
    }
}
