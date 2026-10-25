import SwiftUI

enum SaveButtonState: Equatable {
    case idle, pending, waiting, saved, failed
}

struct SaveButton: View {
    let state: SaveButtonState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(state == .saved || state == .pending || state == .waiting)
    }

    private var icon: String {
        switch state {
        case .idle: "square.and.arrow.down"
        case .pending: "ellipsis.circle"
        case .waiting: "iphone.radiowaves.left.and.right"
        case .saved: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        switch state {
        case .idle: String(localized: "result_save")
        case .pending: String(localized: "result_saving")
        case .waiting: String(localized: "result_save_waiting")
        case .saved: String(localized: "result_saved")
        case .failed: String(localized: "result_save_failed")
        }
    }

    private var tint: Color {
        switch state {
        case .idle: .green
        case .pending: .gray
        case .waiting: .gray
        case .saved: .gray
        case .failed: .orange
        }
    }
}
