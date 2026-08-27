import SwiftUI

struct UndoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}
