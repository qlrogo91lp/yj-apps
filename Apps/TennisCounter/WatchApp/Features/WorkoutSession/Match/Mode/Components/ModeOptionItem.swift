import SwiftUI

struct ModeOptionItem: View {
    let mode: MatchFormat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(modeTitle(mode))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(modeDescription(mode))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func modeTitle(_ mode: MatchFormat) -> String {
        switch mode {
        case .oneSet: String(localized: "mode_one_set")
        case .bestOfThree: String(localized: "mode_best_of_3")
        }
    }

    private func modeDescription(_ mode: MatchFormat) -> String {
        switch mode {
        case .oneSet: String(localized: "mode_one_set_desc")
        case .bestOfThree: String(localized: "mode_best_of_3_desc")
        }
    }
}

#Preview {
    ModeOptionItem(mode: .oneSet, onTap: {})
}
