import SwiftUI
import WorkoutCore

struct MetricsView: View {
    @ObservedObject var healthKit: WorkoutSessionService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(healthKit.formattedElapsed())
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(healthKit.isPaused ? Color.yellow.opacity(0.5) : .yellow)
                .contentTransition(.numericText())

            metricRow(value: heartRateText, unit: "bpm", color: .red)
            metricRow(value: String(format: "%.0f", healthKit.currentCalories), unit: "kcal", color: .orange)
            metricRow(value: distanceText, unit: "km", color: .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    private func metricRow(value: String, unit: String, color: Color) -> some View {
        HStack(alignment: .bottom, spacing: 5) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 3)
        }
    }

    private var heartRateText: String {
        healthKit.currentHeartRate > 0 ? String(format: "%.0f", healthKit.currentHeartRate) : "--"
    }

    private var distanceText: String {
        String(format: "%.2f", healthKit.currentDistanceMeters / 1000)
    }
}

#if DEBUG
    #Preview {
        let service = WorkoutSessionService(configuration: .golf)
        service.setLiveMetricsForTesting(heartRate: 98, calories: 320, elapsedSeconds: 5430, distanceMeters: 6240)
        return MetricsView(healthKit: service)
    }
#endif
