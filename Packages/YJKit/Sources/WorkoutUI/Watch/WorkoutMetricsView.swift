#if os(watchOS)
    import SwiftUI
    import WorkoutCore

    /// 워치 워크아웃 메트릭 화면 — 경과시간·활동 kcal·총 kcal·BPM을 세로로 나열한다.
    public struct WorkoutMetricsView: View {
        private let metrics: WorkoutMetrics
        private let isPaused: Bool

        public init(metrics: WorkoutMetrics, isPaused: Bool) {
            self.metrics = metrics
            self.isPaused = isPaused
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(metrics.formattedElapsed)
                    .font(.system(size: 45, weight: .semibold, design: .rounded))
                    .foregroundColor(isPaused ? Color.yellow.opacity(0.5) : .yellow)
                    .contentTransition(.numericText())

                HStack(alignment: .bottom, spacing: 6) {
                    Text(String(format: "%.0f", metrics.activeCalories))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    StackedLabel(text: String(localized: "metrics_active_kcal", bundle: .module),
                                 font: .system(size: 12, weight: .semibold),
                                 color: .white)
                        .padding(.bottom, 5)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    Text(String(format: "%.0f", metrics.totalCalories))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    StackedLabel(text: String(localized: "metrics_total_kcal", bundle: .module),
                                 font: .system(size: 11, weight: .medium),
                                 color: .white.opacity(0.5))
                        .padding(.bottom, 2)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    Text(heartRateText)
                        .font(.system(size: 35, weight: .bold, design: .rounded))
                    HeartRateIcon(heartRate: metrics.heartRate)
                        .padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .background(Color.black.ignoresSafeArea())
        }

        private var heartRateText: String {
            metrics.heartRate > 0 ? String(format: "%.0f", metrics.heartRate) : "--"
        }
    }

    #Preview {
        WorkoutMetricsView(
            metrics: WorkoutMetrics(elapsedSeconds: 1523, activeCalories: 245, totalCalories: 303, heartRate: 102),
            isPaused: false
        )
    }
#endif
