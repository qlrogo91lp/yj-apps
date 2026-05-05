import SwiftUI

struct ModeSelectionView: View {
    @ObservedObject var viewModel: WorkoutFlowViewModel
    @StateObject private var selectionVM = ModeSelectionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(String(localized: "mode_select_title"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                // Mode cards
                modeCard(mode: .oneSet)
                modeCard(mode: .bestOfThree)

                Divider().background(Color.white.opacity(0.2))

                // Toggles
                Toggle(String(localized: "mode_no_ad"), isOn: $selectionVM.noAdRule)
                    .font(.system(size: 13))
                    .toggleStyle(SwitchToggleStyle(tint: .green))

                Toggle(String(localized: "mode_no_tie"), isOn: $selectionVM.noTieRule)
                    .font(.system(size: 13))
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private func modeCard(mode: MatchMode) -> some View {
        Button(action: {
            selectionVM.selectedMode = mode
            viewModel.startMatch(options: selectionVM.options)
        }) {
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
            .background(Color.green.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func modeTitle(_ mode: MatchMode) -> String {
        switch mode {
        case .oneSet: return String(localized: "mode_one_set")
        case .bestOfThree: return String(localized: "mode_best_of_3")
        }
    }

    private func modeDescription(_ mode: MatchMode) -> String {
        switch mode {
        case .oneSet: return String(localized: "mode_one_set_desc")
        case .bestOfThree: return String(localized: "mode_best_of_3_desc")
        }
    }
}
