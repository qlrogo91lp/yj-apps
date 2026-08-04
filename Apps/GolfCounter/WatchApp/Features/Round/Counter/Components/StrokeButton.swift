import SwiftUI

struct StrokeButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 26, weight: .bold))
                .frame(width: 62, height: 62)
        }
        .buttonStyle(.plain)
        .background(tint.opacity(0.85), in: Circle())
        .foregroundStyle(.white)
    }
}
