import SwiftUI

struct ParBackButton: View {
    let canGoToPrevious: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("이전", systemImage: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.25), in: Capsule())
        .disabled(!canGoToPrevious)
        .opacity(canGoToPrevious ? 1 : 0.35)
    }
}
