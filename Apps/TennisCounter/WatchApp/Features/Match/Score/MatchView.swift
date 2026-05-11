import SwiftUI

struct MatchView: View {
    let options: MatchOptions
    @ObservedObject var flowViewModel: WorkoutSessionViewModel
    @StateObject private var viewModel: MatchViewModel
    @State private var showEarlyEndConfirm = false

    init(options: MatchOptions, flowViewModel: WorkoutSessionViewModel) {
        self.options = options
        self.flowViewModel = flowViewModel
        _viewModel = StateObject(wrappedValue: MatchViewModel(options: options))
    }

    var body: some View {
        ZStack {
            // Score pad
            HStack(spacing: 0) {
                PlayerScoreButton(
                    displayScore: viewModel.score.myDisplayScore,
                    player: String(localized: "watch_score_me"),
                    color: .green,
                    action: { viewModel.addPoint(.me) }
                )

                PlayerScoreButton(
                    displayScore: viewModel.score.yourDisplayScore,
                    player: String(localized: "watch_score_opp"),
                    color: .orange,
                    action: { viewModel.addPoint(.opponent) }
                )
            }
            .ignoresSafeArea()

            VStack {
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
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
                .padding(.horizontal, 8)

                Spacer()

                // Deciding point / Deuce label
                if viewModel.score.isDecidingPoint {
                    Text(String(localized: "score_deciding_point"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .transition(.opacity)
                }

                // Undo button
                if viewModel.score.lastAction != .none {
                    UndoButton { viewModel.undo() }
                        .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.score.lastAction)

        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton {
                    if viewModel.myGameScore == 0 && viewModel.yourGameScore == 0 {
                        flowViewModel.startNewMatch()
                    } else {
                        showEarlyEndConfirm = true
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEarlyEndConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                viewModel.triggerEarlyEnd()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .onAppear {
            viewModel.onMatchFinished = { result, sets in
                flowViewModel.finishMatch(result: result, completedSets: sets)
            }
        }
    }
}

#Preview {
    MatchView(
        options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
        flowViewModel: WorkoutSessionViewModel()
    )
}
