import SwiftUI

struct WorkoutSessionView: View {
    let remoteSession: SessionStartMessage?

    @StateObject private var viewModel: WorkoutSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1

    init(remoteSession: SessionStartMessage? = nil) {
        self.remoteSession = remoteSession
        _viewModel = StateObject(wrappedValue: WorkoutSessionViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutControlsView(viewModel: viewModel, dismiss: dismiss)
                .tag(0)
            centerView
                .tag(1)
            WorkoutMetricsView(healthKit: viewModel.healthKit, isPaused: viewModel.isPaused)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear {
            viewModel.startWorkout()
            if let remote = remoteSession {
                viewModel.startMatch(options: remote.options, sessionId: remote.sessionId, isRemote: true)
            }
        }
        .onChange(of: viewModel.remoteWorkoutEnded) {
            if viewModel.remoteWorkoutEnded { dismiss() }
        }
    }

    @ViewBuilder
    private var centerView: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView(viewModel: viewModel)
        case let .playing(options):
            ScoreView(options: options, flowViewModel: viewModel)
        case let .finished(session):
            MatchResultView(session: session, flowViewModel: viewModel)
        }
    }
}
