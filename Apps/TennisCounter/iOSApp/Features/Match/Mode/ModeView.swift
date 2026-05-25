import SwiftUI

struct ModeView: View {
    @ObservedObject var viewModel: WorkoutSessionViewModel
    @StateObject private var selectionVM = ModeViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                    ModeOptionItem(format: format) {
                        selectionVM.selectedMode = format
                        viewModel.startMatch(options: selectionVM.options)
                    }
                }

                Divider().background(Color.white.opacity(0.2))

                HStack {
                    Text(String(localized: "mode_game_threshold"))
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $selectionVM.gameThreshold) {
                        Text("4").tag(4)
                        Text("5").tag(5)
                        Text("6").tag(6)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                Toggle(String(localized: "mode_no_ad"), isOn: $selectionVM.noAdRule)
                    .font(.system(size: 15))
                    .tint(.green)

                Toggle(String(localized: "mode_no_tie"), isOn: $selectionVM.noTieRule)
                    .font(.system(size: 15))
                    .tint(.green)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    ModeView(viewModel: WorkoutSessionViewModel())
}
