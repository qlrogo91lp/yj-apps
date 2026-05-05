import SwiftUI

struct ScorePadView: View {
    @ObservedObject var viewModel: MatchViewModel

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Me side
                Button(action: { viewModel.addPoint(.me) }) {
                    ZStack {
                        Color.green.opacity(0.15)
                        VStack(spacing: 4) {
                            Text(String(localized: "watch_score_me"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                            Text(viewModel.score.myDisplayScore)
                                .font(.system(size: 46, weight: .bold))
                                .foregroundColor(.green)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(.plain)

                // Opponent side
                Button(action: { viewModel.addPoint(.opponent) }) {
                    ZStack {
                        Color.orange.opacity(0.15)
                        VStack(spacing: 4) {
                            Text(String(localized: "watch_score_opp"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.orange)
                            Text(viewModel.score.yourDisplayScore)
                                .font(.system(size: 46, weight: .bold))
                                .foregroundColor(.orange)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .ignoresSafeArea()
        }
    }
}
