import SwiftUI

struct WorkoutControlsView: View {
    @ObservedObject var viewModel: WorkoutFlowViewModel
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 12) {
            // Pause / Resume button
            WorkoutPauseButton(isPaused: viewModel.isPaused) {
                if viewModel.isPaused { viewModel.resumeWorkout() }
                else { viewModel.pauseWorkout() }
            }

            // End Workout button
            WorkoutEndButton {
                viewModel.endWorkout()
                dismiss()
            }
        }
        .padding()
    }
}
