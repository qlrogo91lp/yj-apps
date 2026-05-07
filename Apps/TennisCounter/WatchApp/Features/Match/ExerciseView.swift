import SwiftUI

struct ExerciseView: View {
    @ObservedObject var healthKit: HealthKitService

    var body: some View {
        VStack(spacing: 16) {
            Text("Exercise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 0) {
                ExerciseMetric(
                    value: heartRateText,
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )

                Divider()
                    .frame(height: 60)
                    .background(Color.white.opacity(0.2))

                ExerciseMetric(
                    value: String(format: "%.0f", healthKit.currentCalories),
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange
                )
            }

            ExerciseMetric(
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
}
