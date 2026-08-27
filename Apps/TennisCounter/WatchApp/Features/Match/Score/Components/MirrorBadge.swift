import SwiftUI

struct MirrorBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "iphone")
            Text(String(localized: "mirror_view_only_short"))
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundColor(.white.opacity(0.9))
    }
}

#Preview {
    MirrorBadge()
}
