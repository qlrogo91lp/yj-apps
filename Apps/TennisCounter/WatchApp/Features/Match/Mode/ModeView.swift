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

                HStack {
                    Text(String(localized: "mode_game_threshold"))
                        .font(.system(size: 14))
                    Spacer()
                    Button {
                        let options = [4, 5, 6]
                        let next = ((options.firstIndex(of: selectionVM.gameThreshold) ?? 0) + 1) % options.count
                        selectionVM.gameThreshold = options[next]
                    } label: {
                        Text("\(selectionVM.gameThreshold)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
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
