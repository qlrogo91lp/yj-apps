import SwiftUI

struct SaveButton: View {
    let saved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                Text(saved
                     ? String(localized: "result_saved")
                     : String(localized: "result_save"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(saved ? .gray : .green)
        .disabled(saved)
    }
}

#Preview {
    VStack(spacing: 16) {
        SaveButton(saved: false) {}
        SaveButton(saved: true) {}
    }
    .padding()
    .background(Color.black)
}
