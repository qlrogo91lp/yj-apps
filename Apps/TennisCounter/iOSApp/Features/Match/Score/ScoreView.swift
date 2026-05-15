import SwiftUI

struct ScoreView: View {
    let options: MatchOptions
    let onMatchFinished: (Bool, [(my: Int, your: Int)]) -> Void
    let onProgressChanged: (Bool) -> Void

    @StateObject private var viewModel: ScoreViewModel
    @State private var showEditSheet = false

    init(options: MatchOptions,
         onMatchFinished: @escaping (Bool, [(my: Int, your: Int)]) -> Void,
         onProgressChanged: @escaping (Bool) -> Void = { _ in }) {
        self.options = options
        self.onMatchFinished = onMatchFinished
        self.onProgressChanged = onProgressChanged
        _viewModel = StateObject(wrappedValue: ScoreViewModel(options: options))
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

            VStack(spacing: 15) {
                if options.mode == .bestOfThree {
                    SetScores(
                        mySetScore: viewModel.mySetScore,
                        yourSetScore: viewModel.yourSetScore
                    )
                }
                GameScores(
                    myGameScore: viewModel.myGameScore,
                    yourGameScore: viewModel.yourGameScore,
                    isTieBreak: viewModel.isTieBreak
                )
            }
            .padding(.bottom, 300)

            if viewModel.score.lastAction != .none {
                VStack {
                    Spacer()
                    UndoButton(action: { viewModel.undo() })
                        .padding(.bottom, 150)
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: viewModel.isMatchOver) { _, isOver in
            if isOver { onMatchFinished(viewModel.didWin, viewModel.completedSets) }
        }
        .onChange(of: viewModel.hasProgress) { _, hasProgress in
            onProgressChanged(hasProgress)
        }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score)
        }
    }
}

#Preview {
    NavigationStack {
        ScoreView(
            options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
            onMatchFinished: { _, _ in }
        )
    }
}
