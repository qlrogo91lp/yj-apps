import SwiftUI

struct HoleNavigation: View {
    let canGoToPrevious: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            navButton(title: "이전", systemName: "chevron.left", action: onPrevious)
                .disabled(!canGoToPrevious)
                .opacity(canGoToPrevious ? 1 : 0.35)
            navButton(title: "다음", systemName: "chevron.right", action: onNext)
        }
    }

    private func navButton(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.25), in: Capsule())
    }
}
