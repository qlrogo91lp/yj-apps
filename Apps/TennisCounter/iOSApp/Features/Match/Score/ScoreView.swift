import SwiftData
import SwiftUI

struct ScoreView: View {
    let format: MatchFormat
    let onMatchFinished: (Bool, [(my: Int, your: Int)]) -> Void
    let onEnd: () -> Void

    @StateObject private var viewModel: MatchViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false

    init(format: MatchFormat,
         onMatchFinished: @escaping (Bool, [(my: Int, your: Int)]) -> Void,
         onEnd: @escaping () -> Void) {
        self.format = format
        self.onMatchFinished = onMatchFinished
        self.onEnd = onEnd
        _viewModel = StateObject(wrappedValue: MatchViewModel(format: format))
    }

    var body: some View {
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

            VStack {
                ScoreInfo(
                    myGameScore: viewModel.myGameScore,
                    yourGameScore: viewModel.yourGameScore,
                    mySetScore: viewModel.mySetScore,
                    yourSetScore: viewModel.yourSetScore,
                    format: format
                )
                .padding(.top, 12)
                .allowsHitTesting(false)
                Spacer()
                if viewModel.score.lastAction != .none {
                    UndoButton(action: { viewModel.undo() })
                        .padding(.bottom, 20)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "early_end_button"), action: onEnd)
                    .font(.system(size: 14))
            }
        }
        .onAppear {
            viewModel.injectContext(modelContext)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: viewModel.isMatchOver) { _, isOver in
            if isOver {
                onMatchFinished(viewModel.didWin, viewModel.completedSets)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score)
        }
    }
}

#Preview {
    NavigationStack {
        ScoreView(
            format: .oneSet,
            onMatchFinished: { _, _ in },
            onEnd: {}
        )
    }
}
