import SwiftUI

struct WorkoutSessionView: View {
    @StateObject private var viewModel = WorkoutSessionViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            // Left: controls
            WorkoutControlsView(viewModel: viewModel, dismiss: dismiss)
                .tag(0)

            // Center: match flow
            centerView
                .tag(1)

            // Right: metrics
            WorkoutMetricsView(healthKit: viewModel.healthKit, isPaused: viewModel.isPaused)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear { viewModel.startWorkout() }
    }

    @ViewBuilder
    private var centerView: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView(viewModel: viewModel)
        case let .playing(options):
            MatchView(options: options, flowViewModel: viewModel)
        case let .finished(session):
            MatchResultView(session: session, flowViewModel: viewModel)
        }
    }
}
