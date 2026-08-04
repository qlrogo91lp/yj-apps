import SwiftUI

struct ParOptionButton: View {
    let par: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Par \(par)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.green.opacity(0.85) : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
    }
}
