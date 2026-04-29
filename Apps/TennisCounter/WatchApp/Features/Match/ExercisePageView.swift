import SwiftUI

struct ExercisePageView: View {
    @ObservedObject var healthKit: HealthKitService

    var body: some View {
        VStack(spacing: 16) {
            Text("Exercise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 0) {
                metricView(
                    value: heartRateText,
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )

                Divider()
                    .frame(height: 60)
                    .background(Color.white.opacity(0.2))

                metricView(
                    value: String(format: "%.0f", healthKit.currentCalories),
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange
                )
            }

            metricView(
                value: healthKit.formattedElapsed(),
                unit: "elapsed",
                icon: "timer",
                color: .blue
            )
        }
        .padding()
    }

    private var heartRateText: String {
        healthKit.currentHeartRate > 0
            ? String(format: "%.0f", healthKit.currentHeartRate)
            : "--"
    }

    private func metricView(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
