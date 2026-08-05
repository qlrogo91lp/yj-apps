import SwiftUI
import WorkoutCore

struct ControlsView: View {
    @ObservedObject var healthKit: WorkoutSessionService
    let onEndRound: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            RoundPauseButton(isPaused: healthKit.isPaused) {
                if healthKit.isPaused {
                    healthKit.resumeWorkout()
                } else {
                    healthKit.pauseWorkout()
                }
            }

            RoundEndButton(action: onEndRound)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Color.clear.frame(width: 36, height: 36)
            }
        }
    }
}
