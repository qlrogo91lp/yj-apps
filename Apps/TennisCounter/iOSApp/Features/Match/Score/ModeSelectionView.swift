import SwiftUI

struct ModeSelectionView: View {
    @StateObject private var viewModel = ModeSelectionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(String(localized: "new_match"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                        NavigationLink(value: format) {
                            ModeCardView(format: format)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationDestination(for: MatchFormat.self) { format in
                MatchView(format: format)
            }
            .navigationBarHidden(true)
        }
    }
}

private struct ModeCardView: View {
    let format: MatchFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(format == .oneSet ? "🎾" : "🏆")
                    .font(.system(size: 28))
                Text(format.localizedTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(format.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ModeSelectionView()
    }
}
