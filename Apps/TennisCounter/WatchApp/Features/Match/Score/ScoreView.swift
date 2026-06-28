import SwiftUI

struct ScoreView: View {
    @ObservedObject var flowViewModel: WorkoutSessionViewModel
    @ObservedObject var viewModel: ScoreViewModel
    @State private var showExitConfirm = false

    init(viewModel: ScoreViewModel, flowViewModel: WorkoutSessionViewModel) {
        self.viewModel = viewModel
        self.flowViewModel = flowViewModel
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                PlayerPointButton(
                    displayScore: viewModel.score.myDisplayScore,
                    player: String(localized: "watch_score_me"),
                    color: .green,
                    hasSetScore: viewModel.mySetScore > 0 || viewModel.yourSetScore > 0,
                    action: { guard flowViewModel.isDriver else { return }; viewModel.addPoint(.me) }
                )

                PlayerPointButton(
                    displayScore: viewModel.score.yourDisplayScore,
                    player: String(localized: "watch_score_opp"),
                    color: .orange,
                    hasSetScore: viewModel.mySetScore > 0 || viewModel.yourSetScore > 0,
                    action: { guard flowViewModel.isDriver else { return }; viewModel.addPoint(.opponent) }
                )
            }
            .ignoresSafeArea(.container)

            GeometryReader { geo in
                let isSmall = geo.size.width <= 162
                VStack(spacing: 4) {
                    SetScores(
                        mySetScore: viewModel.mySetScore,
                        yourSetScore: viewModel.yourSetScore
                    )
                    GameScores(
                        myGameScore: viewModel.myGameScore,
                        yourGameScore: viewModel.yourGameScore,
                        isTieBreak: viewModel.score.gameMode == .tieBreak
                    )
                }
                .padding(.top, isSmall ? 24 : 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .bottom) {
                    if !flowViewModel.isDriver {
                        MirrorBadge()
                            .padding(.bottom, isSmall ? 20 : 25)
                    } else if viewModel.score.lastAction != .none {
                        UndoButton { viewModel.undo() }
                            .padding(.bottom, isSmall ? 20 : 25)
                    }
                }
                .ignoresSafeArea(.container)
                .animation(.easeInOut(duration: 0.2), value: viewModel.score.lastAction)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton {
                    if viewModel.mySetScore == 0, viewModel.yourSetScore == 0,
                       viewModel.myGameScore == 0, viewModel.yourGameScore == 0
                    {
                        flowViewModel.startNewMatch()
                    } else {
                        showExitConfirm = true
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showExitConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                flowViewModel.startNewMatch()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
    }
}

#Preview {
    ScoreView(
        viewModel: ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false)),
        flowViewModel: WorkoutSessionViewModel()
    )
}
