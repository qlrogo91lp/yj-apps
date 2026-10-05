import SwiftUI

struct RematchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.2), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RematchButton {}
        .padding()
        .background(Color.black)
}
