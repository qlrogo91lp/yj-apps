import SwiftUI

struct MatchResultView: View {
    let didWin: Bool
    let completedSets: [(my: Int, your: Int)]
    let onNewMatch: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(didWin
                ? String(localized: "match_over_win")
                : String(localized: "match_over_lose"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(didWin ? .green : .orange)

            HStack(spacing: 24) {
                ForEach(completedSets.indices, id: \.self) { idx in
                    let set = completedSets[idx]
                    VStack(spacing: 2) {
                        Text("Set \(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 4) {
                            Text("\(set.my)").foregroundColor(.green)
                            Text("–").foregroundColor(.white.opacity(0.5))
                            Text("\(set.your)").foregroundColor(.orange)
                        }
                        .font(.system(size: 18, weight: .bold))
                    }
                }
            }

            Button(action: onNewMatch) {
                Text(String(localized: "btn_new_match"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Button(action: onExit) {
                Text(String(localized: "btn_end_match"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    MatchResultView(
        didWin: true,
        completedSets: [(my: 6, your: 4), (my: 6, your: 3)],
        onNewMatch: {},
        onExit: {}
    )
}
