import SwiftUI

struct MatchSessionView: View {
    @StateObject private var viewModel = MatchSessionViewModel()
    @State private var selectedTab: Int = 1
    @State private var showEndConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutTabView(
                metrics: viewModel.metrics,
                onPauseResume: {
                    viewModel.isPaused ? viewModel.resumeSession() : viewModel.pauseSession()
                },
                onEnd: { showEndConfirm = true }
            )
            .tabItem { Label(String(localized: "tab_workout"), systemImage: "figure.run") }
            .tag(0)

            scoreTabContent
                .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(!isBackAllowed)
        .toolbar {
            if case .playing = viewModel.phase {
                ToolbarItem(placement: .topBarLeading) {
                    BackButton { selectedTab = 0 }
                }
            }
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEndConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                viewModel.endSession()
                dismiss()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .onAppear { viewModel.startSession() }
    }

    private var isBackAllowed: Bool {
        if case .modeSelection = viewModel.phase { return true }
        return false
    }

    @ViewBuilder
    private var scoreTabContent: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView { format in
                viewModel.startMatch(format: format)
            }

        case .playing(let options):
            let format = MatchFormat(rawValue: options.mode.rawValue) ?? .oneSet
            ScoreView(
                format: format,
                onMatchFinished: { didWin, sets in
                    viewModel.finishMatch(didWin: didWin, completedSets: sets)
                },
                onEnd: { showEndConfirm = true }
            )

        case .finished(let session):
            MatchResultView(
                didWin: session.result == .win,
                completedSets: session.completedSets.map { ($0.my, $0.your) },
                onNewMatch: { viewModel.startNewMatch() },
                onExit: { dismiss() }
            )
            .navigationBarBackButtonHidden()
        }
    }
}

#Preview {
    NavigationStack {
        MatchSessionView()
            .toolbar(.hidden, for: .tabBar)
    }
}
