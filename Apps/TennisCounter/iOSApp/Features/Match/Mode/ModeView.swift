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
                        let mode = MatchMode(rawValue: format.rawValue) ?? .oneSet
                        selectionVM.selectedMode = mode
                        viewModel.startMatch(options: selectionVM.options)
                    }
                }

                Divider().background(Color.white.opacity(0.2))

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
