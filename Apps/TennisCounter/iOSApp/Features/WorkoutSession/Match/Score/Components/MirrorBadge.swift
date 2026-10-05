import SwiftUI

struct MirrorBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "applewatch")
            Text(String(localized: "mirror_view_only"))
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundColor(.white.opacity(0.9))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MirrorBadge()
    }
}
