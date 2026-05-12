import SwiftData
import SwiftUI

struct ScoreTabView: View {
    let format: MatchFormat

    @StateObject private var viewModel: MatchViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showEarlyEndConfirm = false

    init(format: MatchFormat) {
        self.format = format
        _viewModel = StateObject(wrappedValue: MatchViewModel(format: format))
    }

    var body: some View {
        Group {
            if viewModel.isMatchOver {
                matchOverView
            } else {
                scoreView
            }
        }
        .onAppear { viewModel.injectContext(modelContext) }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score)
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEarlyEndConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                dismiss()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
    }

    // MARK: - Score view

    private var scoreView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 0) {
                PlayerScoreZone(
                    displayScore: viewModel.score.myDisplayScore,
                    playerLabel: String(localized: "watch_score_me"),
                    color: .green,
                    onTap: { withAnimation { viewModel.addPoint(.me) } },
                    onLongPress: { showEditSheet = true }
                )
                PlayerScoreZone(
                    displayScore: viewModel.score.yourDisplayScore,
                    playerLabel: String(localized: "watch_score_opp"),
                    color: .orange,
                    onTap: { withAnimation { viewModel.addPoint(.opponent) } },
                    onLongPress: { showEditSheet = true }
                )
            }
            .ignoresSafeArea()

            ScoreOverlay(
                myGameScore: viewModel.myGameScore,
                yourGameScore: viewModel.yourGameScore,
                mySetScore: viewModel.mySetScore,
                yourSetScore: viewModel.yourSetScore,
                format: format,
                showUndo: viewModel.score.lastAction != .none,
                onUndo: { viewModel.undo() }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "early_end_button")) {
                    showEarlyEndConfirm = true
                }
                .font(.system(size: 14))
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Match over view

    private var matchOverView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(viewModel.didWin
                ? String(localized: "match_over_win")
                : String(localized: "match_over_lose"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(viewModel.didWin ? .green : .orange)

            HStack(spacing: 24) {
                ForEach(viewModel.completedSets.indices, id: \.self) { idx in
                    let set = viewModel.completedSets[idx]
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

            Button(action: {
                viewModel.resetAll()
                dismiss()
            }) {
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

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
