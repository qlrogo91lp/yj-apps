import SwiftUI

struct WorkoutSessionView: View {
    let onExit: () -> Void

    @StateObject private var viewModel = WorkoutSessionViewModel()
    @State private var selectedTab: Int = 1
    @State private var showEndMatchConfirm = false
    @State private var showEndWorkoutConfirm = false
    @State private var hasMatchProgress = false

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutTabView(
                metrics: viewModel.metrics,
                isPaused: viewModel.isPaused,
                onPauseResume: {
                    viewModel.isPaused ? viewModel.resumeSession() : viewModel.pauseSession()
                },
                onEnd: { showEndWorkoutConfirm = true }
            )
            .tabItem { Label(String(localized: "tab_workout"), systemImage: "figure.run") }
            .tag(0)

            scoreTabContent
                .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                switch viewModel.phase {
                case .modeSelection:
                    BackButton { selectedTab = 0 }
                case .playing:
                    BackButton {
                        if hasMatchProgress {
                            showEndMatchConfirm = true
                        } else {
                            viewModel.startNewMatch()
                        }
                    }
                case .finished:
                    BackButton { viewModel.startNewMatch() }
                }
            }
            ToolbarItem(placement: .principal) {
                if case .modeSelection = viewModel.phase {
                    Text(String(localized: "new_match"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .alert(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEndMatchConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                hasMatchProgress = false
                viewModel.startNewMatch()
            }
            Button(String(localized: "btn_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .alert(
            String(localized: "end_workout_confirm_title"),
            isPresented: $showEndWorkoutConfirm
        ) {
            Button(String(localized: "workout_end"), role: .destructive) {
                viewModel.endSession()
                onExit()
            }
            Button(String(localized: "btn_cancel"), role: .cancel) {}
        } message: {
            if case .playing = viewModel.phase {
                Text(String(localized: "end_workout_with_match_message"))
            } else {
                Text(String(localized: "end_workout_confirm_message"))
            }
        }
        .onAppear { viewModel.startSession() }
    }

    @ViewBuilder
    private var scoreTabContent: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView(viewModel: viewModel)

        case .playing(let options):
            ScoreView(
                options: options,
                onMatchFinished: { didWin, sets in
                    viewModel.finishMatch(didWin: didWin, completedSets: sets)
                },
                onProgressChanged: { hasMatchProgress = $0 }
            )

        case .finished(let session):
            MatchResultView(session: session, viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutSessionView(onExit: {})
    }
}
