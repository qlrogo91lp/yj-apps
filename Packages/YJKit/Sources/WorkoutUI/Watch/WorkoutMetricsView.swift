#if os(watchOS)
    import SwiftUI
    import WorkoutCore

    /// 워치 워크아웃 메트릭 화면 — 경과시간·활동 kcal·총 kcal·BPM을 세로로 나열한다.
    ///
    /// `statusText` 를 주면 맨 위에 한 줄이 더 붙는다. 문구는 앱이 소유한다 —
    /// 패키지는 그것이 무엇을 뜻하는지 모른다. 주지 않으면 기존 4개 지표 그대로다.
    public struct WorkoutMetricsView: View {
        private let metrics: WorkoutMetrics
        private let isPaused: Bool
        private let statusText: String?
        private let elapsedDisplay: WorkoutElapsedDisplay?

        public init(metrics: WorkoutMetrics, isPaused: Bool, statusText: String? = nil, elapsedDisplay: WorkoutElapsedDisplay? = nil) {
            self.metrics = metrics
            self.isPaused = isPaused
            self.statusText = statusText
            self.elapsedDisplay = elapsedDisplay
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                if let statusText {
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                elapsedView
                    .font(.system(size: 45, weight: .semibold, design: .rounded))
                    .foregroundColor(isPaused ? Color.yellow.opacity(0.5) : .yellow)
                    .monospacedDigit()

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
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    StackedLabel(text: String(localized: "metrics_total_kcal", bundle: .module),
                                 font: .system(size: 12, weight: .semibold),
                                 color: .white)
                        .padding(.bottom, 5)
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

        @ViewBuilder
        private var elapsedView: some View {
            if let elapsedDisplay {
                WorkoutElapsedText(display: elapsedDisplay)
            } else {
                Text(metrics.formattedElapsed)
            }
        }
    }

    #Preview("기본") {
        WorkoutMetricsView(
            metrics: WorkoutMetrics(elapsedSeconds: 1523, activeCalories: 245, totalCalories: 303, heartRate: 102),
            isPaused: false
        )
    }

    #Preview("상태 줄") {
        WorkoutMetricsView(
            metrics: WorkoutMetrics(elapsedSeconds: 1523, activeCalories: 245, totalCalories: 303, heartRate: 102),
            isPaused: false,
            statusText: "진행 중 · 근력"
        )
    }

    #Preview("elapsedDisplay — 실행 중") {
        WorkoutMetricsView(
            metrics: WorkoutMetrics(elapsedSeconds: 1523, activeCalories: 245, totalCalories: 303, heartRate: 102),
            isPaused: false,
            elapsedDisplay: WorkoutElapsedDisplay(referenceDate: Date().addingTimeInterval(-1523))
        )
    }

    #Preview("elapsedDisplay — 정지 중") {
        WorkoutMetricsView(
            metrics: WorkoutMetrics(elapsedSeconds: 1523, activeCalories: 245, totalCalories: 303, heartRate: 102),
            isPaused: true,
            elapsedDisplay: WorkoutElapsedDisplay(
                referenceDate: Date().addingTimeInterval(-1523),
                pausedAt: Date()
            )
        )
    }
#endif
