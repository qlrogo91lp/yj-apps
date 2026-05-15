import SwiftUI

struct WorkoutMetricsGrid: View {
    let metrics: WorkoutMetrics
    let completedMatchCount: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard {
                HStack(spacing: 4) {
                    HeartRateIcon(heartRate: metrics.heartRate)
                        .font(.system(size: 13))
                    Text(String(localized: "workout_metric_heartrate"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                metricValue(
                    text: metrics.heartRate > 0 ? String(format: "%.0f", metrics.heartRate) : "--",
                    unit: "bpm"
                )
            }
            MetricCard {
                Text(String(localized: "workout_metric_calories"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                metricValue(text: String(format: "%.0f", metrics.calories), unit: "kcal")
            }
            MetricCard {
                Text(String(localized: "workout_metric_steps"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                metricValue(text: "\(metrics.steps)", unit: String(localized: "workout_metric_steps_unit"))
            }
            MetricCard {
                Text(String(localized: "workout_metric_matches"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                metricValue(text: "\(completedMatchCount)", unit: String(localized: "workout_metric_matches_unit"))
            }
        }
    }

    private func metricValue(text: String, unit: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(text)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
