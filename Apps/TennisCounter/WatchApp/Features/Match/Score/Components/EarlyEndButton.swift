import SwiftUI

struct EarlyEndButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(.thickMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }
}
