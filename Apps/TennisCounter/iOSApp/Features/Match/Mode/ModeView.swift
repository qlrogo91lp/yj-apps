import SwiftUI

struct ModeView: View {
    let onFormatSelected: (MatchOptions) -> Void

    @StateObject private var viewModel = ModeViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                    Button { onFormatSelected(viewModel.options(for: format)) } label: {
                        ModeListItem(format: format)
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(Color.white.opacity(0.2))

                Toggle(String(localized: "mode_no_ad"), isOn: $viewModel.noAdRule)
                    .font(.system(size: 15))
                    .tint(.green)

                Toggle(String(localized: "mode_no_tie"), isOn: $viewModel.noTieRule)
                    .font(.system(size: 15))
                    .tint(.green)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    NavigationStack {
        ModeView(onFormatSelected: { _ in })
    }
}
