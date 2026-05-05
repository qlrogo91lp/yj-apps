import SwiftUI

struct EarlyEndButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }
}
