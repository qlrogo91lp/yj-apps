import SwiftUI

struct ModeView: View {
    @ObservedObject var viewModel: WorkoutSessionViewModel
    @StateObject private var selectionVM = ModeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ModeOptionItem(mode: .oneSet) {
                    selectionVM.selectedMode = .oneSet
                    viewModel.startMatch(options: selectionVM.options)
                }

                ModeOptionItem(mode: .bestOfThree) {
                    selectionVM.selectedMode = .bestOfThree
                    viewModel.startMatch(options: selectionVM.options)
                }

                Divider().background(Color.white.opacity(0.2))

                Picker(String(localized: "mode_game_threshold"), selection: $selectionVM.gameThreshold) {
                    Text("5").tag(5)
                    Text("6").tag(6)
                }

                Toggle(String(localized: "mode_no_ad"), isOn: $selectionVM.noAdRule)
                    .font(.system(size: 14))
                    .toggleStyle(SwitchToggleStyle(tint: .green))

                Toggle(String(localized: "mode_no_tie"), isOn: $selectionVM.noTieRule)
                    .font(.system(size: 14))
                    .toggleStyle(SwitchToggleStyle(tint: .green))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}
