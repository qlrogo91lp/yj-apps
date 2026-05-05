import SwiftUI

struct WorkoutFlowView: View {
    @StateObject private var viewModel = WorkoutFlowViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
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
        .onAppear { viewModel.startWorkout() }
    }

    @ViewBuilder
    private var centerView: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeSelectionView(viewModel: viewModel)
        case .playing(let options):
            MatchView(options: options, flowViewModel: viewModel)
        case .finished(let session):
            MatchResultView(session: session, flowViewModel: viewModel)
        }
    }
}
