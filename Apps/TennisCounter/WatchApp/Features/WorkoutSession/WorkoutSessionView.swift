import SwiftUI
import WorkoutCore
import WorkoutUI

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
            controlsTab
                .tag(0)
            centerView
                .tag(1)
            metricsTab
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

    private var controlsTab: some View {
        WorkoutControlsView(
            isPaused: viewModel.isPaused,
            onPauseResume: {
                if viewModel.isPaused {
                    viewModel.resumeWorkout()
                } else {
                    viewModel.pauseWorkout()
                }
            },
            onEnd: {
                viewModel.endWorkout()
                dismiss()
            }
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Color.clear.frame(width: 36, height: 36)
            }
        }
    }

    private var metricsTab: some View {
        WorkoutMetricsView(metrics: viewModel.currentMetrics, isPaused: viewModel.isPaused)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
    }

    @ViewBuilder
    private var centerView: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView(viewModel: viewModel)
        case .playing:
            ScoreView(viewModel: viewModel.scoreVM, flowViewModel: viewModel)
        case let .finished(session):
            MatchResultView(session: session, flowViewModel: viewModel)
        }
    }
}
