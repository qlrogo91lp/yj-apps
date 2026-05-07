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

                ModeOptionItem(mode: .oneSet) {
                    selectionVM.selectedMode = .oneSet
                    viewModel.startMatch(options: selectionVM.options)
                }

                ModeOptionItem(mode: .bestOfThree) {
                    selectionVM.selectedMode = .bestOfThree
                    viewModel.startMatch(options: selectionVM.options)
                }

                Divider().background(Color.white.opacity(0.2))

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
}
