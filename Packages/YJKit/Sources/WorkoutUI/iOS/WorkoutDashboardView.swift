#if os(iOS)
    import SwiftUI
    import WorkoutCore

    /// 폰 워크아웃 대시보드 — 경과시간 링 + 지표 3칸 + 컨트롤.
    public struct WorkoutDashboardView: View {
        private let metrics: WorkoutMetrics
        private let isPaused: Bool
        private let isPauseAvailable: Bool
        private let onPauseResume: () -> Void
        private let onEnd: () -> Void

        public init(metrics: WorkoutMetrics,
                    isPaused: Bool,
                    isPauseAvailable: Bool = true,
                    onPauseResume: @escaping () -> Void,
                    onEnd: @escaping () -> Void)
        {
            self.metrics = metrics
            self.isPaused = isPaused
            self.isPauseAvailable = isPauseAvailable
            self.onPauseResume = onPauseResume
            self.onEnd = onEnd
        }

        public var body: some View {
            VStack {
                WorkoutTimerRing(formattedElapsed: metrics.formattedElapsed, isPaused: isPaused)

                Spacer()

                metricsRow
                    .padding(.horizontal, 20)

                Spacer()

                WorkoutControls(isPaused: isPaused,
                                isPauseAvailable: isPauseAvailable,
                                onPauseResume: onPauseResume,
                                onEnd: onEnd)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }

        private var metricsRow: some View {
            HStack(spacing: 12) {
                MetricCard {
                    HStack(spacing: 4) {
                        HeartRateIcon(heartRate: metrics.heartRate, size: 13)
                        Text(String(localized: "metrics_bpm", bundle: .module))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    MetricValueLabel(
                        value: metrics.heartRate > 0 ? String(format: "%.0f", metrics.heartRate) : "--",
                        unit: "bpm",
                        valueSize: 26
                    )
                }
                MetricCard {
                    Text(String(localized: "metrics_active_kcal", bundle: .module))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    MetricValueLabel(value: String(format: "%.0f", metrics.activeCalories),
                                     unit: "kcal",
                                     valueSize: 26)
                }
                MetricCard {
                    Text(String(localized: "metrics_total_kcal", bundle: .module))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    MetricValueLabel(value: String(format: "%.0f", metrics.totalCalories),
                                     unit: "kcal",
                                     valueSize: 26)
                }
            }
        }
    }

    #Preview {
        WorkoutDashboardView(
            metrics: WorkoutMetrics(elapsedSeconds: 1980, activeCalories: 245, totalCalories: 310, heartRate: 142),
            isPaused: false,
            onPauseResume: {},
            onEnd: {}
        )
        .preferredColorScheme(.dark)
    }
#endif
