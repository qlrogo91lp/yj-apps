import SwiftUI

enum SaveButtonState: Equatable {
    case idle, saved, failed
}

struct SaveButton: View {
    let state: SaveButtonState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(state == .saved)
    }

    private var icon: String {
        switch state {
        case .idle: "square.and.arrow.down"
        case .saved: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        switch state {
        case .idle: String(localized: "result_save")
        case .saved: String(localized: "result_saved")
        case .failed: String(localized: "result_save_failed")
        }
    }

    private var tint: Color {
        switch state {
        case .idle: .green
        case .saved: .gray
        case .failed: .orange
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SaveButton(state: .idle) {}
        SaveButton(state: .saved) {}
        SaveButton(state: .failed) {}
    }
    .padding()
}
