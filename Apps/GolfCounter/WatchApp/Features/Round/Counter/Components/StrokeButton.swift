import SwiftUI

struct StrokeButton: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 62
    var iconSize: CGFloat = 26
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .background(tint.opacity(0.85), in: Circle())
        .foregroundStyle(.white)
    }
}
