import SwiftUI

struct SaveButton: View {
    let saved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                Text(saved ? String(localized: "result_saved") : String(localized: "result_save"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(saved ? .gray : .green)
        .disabled(saved)
    }
}
