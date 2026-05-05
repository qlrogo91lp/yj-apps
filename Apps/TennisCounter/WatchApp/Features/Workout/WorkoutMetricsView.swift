import SwiftUI

struct WorkoutMetricsView: View {
    @ObservedObject var healthKit: HealthKitService
    let isPaused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Elapsed time - large yellow
                VStack(spacing: 2) {
                    Text(healthKit.formattedElapsed())
                        .font(.system(size: 38, weight: .semibold, design: .monospaced))
                        .foregroundColor(isPaused ? Color.yellow.opacity(0.5) : .yellow)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.3), value: healthKit.elapsedSeconds)

                    Text(isPaused ? String(localized: "metrics_paused") : String(localized: "metrics_elapsed"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 10)

                Divider().background(Color.white.opacity(0.15))
                    .padding(.bottom, 8)

                // Metrics row
                HStack(spacing: 0) {
                    metricView(
                        value: String(format: "%.0f", healthKit.currentCalories),
                        label: String(localized: "metrics_kcal"),
                        icon: "flame.fill",
                        color: .orange
                    )

                    Divider()
                        .frame(height: 50)
                        .background(Color.white.opacity(0.15))

                    metricView(
                        value: heartRateText,
                        label: String(localized: "metrics_bpm"),
                        icon: "heart.fill",
                        color: .red
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var heartRateText: String {
        healthKit.currentHeartRate > 0
            ? String(format: "%.0f", healthKit.currentHeartRate)
            : "--"
    }

    private func metricView(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
