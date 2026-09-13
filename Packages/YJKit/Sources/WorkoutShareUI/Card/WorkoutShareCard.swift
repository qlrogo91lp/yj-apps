#if os(iOS)
    import SwiftUI
    import WorkoutCore

    extension WorkoutShareCardModel.Metric {
        var localizedLabel: String {
            switch self {
            case .duration: String(localized: "share_metric_duration", bundle: .module)
            case .calories: String(localized: "share_metric_calories", bundle: .module)
            case .heartRate: String(localized: "share_metric_heart_rate", bundle: .module)
            }
        }
    }

    /// 공유 이미지. 그라디언트가 캔버스 전체를 채우고 지표 카드가 세로 중앙에 놓인다.
    /// 값과 스타일만 받는다 — 서비스나 ViewModel을 모른다.
    struct WorkoutShareCard: View {
        let model: WorkoutShareCardModel
        let style: WorkoutShareStyle

        var body: some View {
            content
                .frame(width: ShareCanvas.width, height: cardHeight)
                .frame(width: ShareCanvas.width, height: ShareCanvas.imageHeight)
                .background(gradient)
        }

        private var cardHeight: CGFloat {
            ShareCanvas.cardSize(rowCount: model.rows.count,
                                 hasLogo: style.logo != nil).height
        }

        private var gradient: LinearGradient {
            let pair = StoryGradient.colors(from: style.accentColor)
            return LinearGradient(colors: [pair.top, pair.bottom],
                                  startPoint: .top,
                                  endPoint: .bottom)
        }

        private var content: some View {
            VStack(spacing: 0) {
                ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                    metricRow(row)
                        .frame(height: ShareCanvas.rowHeight)
                }
                if let logo = style.logo {
                    VStack(spacing: 6) {
                        Rectangle()
                            .fill(.white.opacity(0.25))
                            .frame(height: 1)
                        logo
                            .resizable()
                            .scaledToFit()
                            .frame(height: 16)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(height: ShareCanvas.logoStripHeight)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, ShareCanvas.verticalPadding)
        }

        private func metricRow(_ row: WorkoutShareCardModel.Row) -> some View {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(row.metric.localizedLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 8)
                Text(row.value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let unit = row.unit {
                    Text(unit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private let previewResult = WorkoutResult(durationSeconds: 2538,
                                              caloriesBurned: 312,
                                              averageHeartRate: 148)

    #Preview("3행 + 로고") {
        WorkoutShareCard(model: WorkoutShareCardModel(result: previewResult),
                         style: WorkoutShareStyle(accentColor: .green,
                                                  logo: Image(systemName: "figure.tennis")))
    }

    #Preview("로고 없음") {
        WorkoutShareCard(model: WorkoutShareCardModel(result: previewResult),
                         style: WorkoutShareStyle(accentColor: .green))
    }

    #Preview("1행") {
        WorkoutShareCard(
            model: WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 5400,
                                                               caloriesBurned: 0,
                                                               averageHeartRate: nil)),
            style: WorkoutShareStyle(accentColor: .indigo,
                                     logo: Image(systemName: "figure.golf"))
        )
    }
#endif
