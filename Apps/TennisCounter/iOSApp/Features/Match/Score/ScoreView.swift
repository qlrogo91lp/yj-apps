import SwiftUI

struct ScoreView: View {
    let isDriver: Bool
    let onMatchFinished: (MatchResult, [(my: Int, your: Int)]) -> Void
    let onProgressChanged: (Bool) -> Void

    @ObservedObject var viewModel: ScoreViewModel
    @State private var showEditSheet = false

    init(viewModel: ScoreViewModel,
         isDriver: Bool,
         onMatchFinished: @escaping (MatchResult, [(my: Int, your: Int)]) -> Void,
         onProgressChanged: @escaping (Bool) -> Void = { _ in })
    {
        self.viewModel = viewModel
        self.isDriver = isDriver
        self.onMatchFinished = onMatchFinished
        self.onProgressChanged = onProgressChanged
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 0) {
                PlayerPointZone(
                    displayScore: viewModel.score.myDisplayScore,
                    playerLabel: String(localized: "watch_score_me"),
                    color: .green,
                    onTap: { guard isDriver else { return }; withAnimation { viewModel.addPoint(.me) } },
                    onLongPress: { guard isDriver else { return }; showEditSheet = true }
                )
                PlayerPointZone(
                    displayScore: viewModel.score.yourDisplayScore,
                    playerLabel: String(localized: "watch_score_opp"),
                    color: .orange,
                    onTap: { guard isDriver else { return }; withAnimation { viewModel.addPoint(.opponent) } },
                    onLongPress: { guard isDriver else { return }; showEditSheet = true }
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 15) {
                if viewModel.options.mode == .bestOfThree {
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

            if !isDriver {
                VStack {
                    MirrorBadge().padding(.top, 8)
                    Spacer()
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: viewModel.matchResult) { _, result in
            if let result { onMatchFinished(result, viewModel.completedSets) }
        }
        .onChange(of: viewModel.hasProgress) { _, hasProgress in
            onProgressChanged(hasProgress)
        }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score, onChange: { viewModel.onStateChanged?() })
        }
    }
}

#Preview {
    NavigationStack {
        ScoreView(
            viewModel: ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false)),
            isDriver: true,
            onMatchFinished: { _, _ in }
        )
    }
}
