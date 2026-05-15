import SwiftUI

struct WorkoutTabView: View {
    let metrics: WorkoutMetrics
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metrics.formattedElapsed)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .contentTransition(.numericText())

                HStack(alignment: .bottom, spacing: 6) {
                    Text(String(format: "%.0f", metrics.calories))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("kcal")
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.bottom, 4)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    Text(metrics.heartRate > 0 ? String(format: "%.0f", metrics.heartRate) : "--")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                    Image(systemName: metrics.heartRate > 0 ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .padding(.bottom, 4)
                }
            }

            Spacer()

            WorkoutControls(
                isPaused: isPaused,
                onPauseResume: onPauseResume,
                onEnd: onEnd
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    WorkoutTabView(
        metrics: WorkoutMetrics(elapsedSeconds: 1523, calories: 245, heartRate: 102),
        isPaused: false,
        onPauseResume: {},
        onEnd: {}
    )
}
