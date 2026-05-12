import SwiftUI

struct ModeView: View {
    let onFormatSelected: (MatchFormat) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(String(localized: "new_match"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                    Button { onFormatSelected(format) } label: {
                        ModeListItem(format: format)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
    }
}

#Preview {
    ModeView(onFormatSelected: { _ in })
}
