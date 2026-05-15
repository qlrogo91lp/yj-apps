import SwiftUI

struct WorkoutTabView: View {
    let metrics: WorkoutMetrics
    let completedMatchCount: Int
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack {
            WorkoutTimerRing(formattedElapsed: metrics.formattedElapsed, isPaused: isPaused)

            Spacer()

            WorkoutMetricsGrid(metrics: metrics, completedMatchCount: completedMatchCount)
                .padding(.horizontal, 20)

            Spacer()

            WorkoutControls(
                isPaused: isPaused,
                onPauseResume: onPauseResume,
                onEnd: onEnd
            )
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    WorkoutTabView(
        metrics: WorkoutMetrics(elapsedSeconds: 1980, calories: 245, heartRate: 142, steps: 1240),
        completedMatchCount: 2,
        isPaused: false,
        onPauseResume: {},
        onEnd: {}
    )
    .preferredColorScheme(.dark)
}
