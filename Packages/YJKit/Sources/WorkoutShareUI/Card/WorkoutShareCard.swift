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

    /// 스토리에 올릴 지표 카드. 값과 스타일만 받는다 — 서비스나 ViewModel을 모른다.
    struct WorkoutShareCard: View {
        enum Mode {
            /// 카드 모서리 바깥이 투명하다. 인스타그램 스티커로 넘긴다.
            case sticker
            /// 그라디언트가 캔버스 전체를 채우고 카드가 세로 중앙에 놓인다. 공유 시트 폴백용.
            case standalone
        }

        let model: WorkoutShareCardModel
        let style: WorkoutShareStyle
        let mode: Mode

        var body: some View {
            switch mode {
            case .sticker:
                card
                    .frame(width: ShareCanvas.width, height: stickerHeight)
            case .standalone:
                card
                    .frame(width: ShareCanvas.width, height: ShareCanvas.standaloneHeight)
                    .background(gradient)
            }
        }

        private var stickerHeight: CGFloat {
            ShareCanvas.stickerSize(rowCount: model.rows.count,
                                    hasLogo: style.logo != nil).height
        }

        private var card: some View {
            content
                .frame(width: ShareCanvas.width, height: stickerHeight)
                .background(cardBackground)
        }

        /// 스티커 모드에서 이 라운드 사각형의 모서리 바깥이 투명해진다 — PNG와 알파 채널이 필요한 이유다.
        @ViewBuilder private var cardBackground: some View {
            switch mode {
            case .sticker:
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(gradient)
            case .standalone:
                Color.clear
            }
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

    #Preview("스티커 · 3행 + 로고") {
        WorkoutShareCard(model: WorkoutShareCardModel(result: previewResult),
                         style: WorkoutShareStyle(accentColor: .green,
                                                  logo: Image(systemName: "figure.tennis")),
                         mode: .sticker)
    }

    #Preview("스티커 · 로고 없음") {
        WorkoutShareCard(model: WorkoutShareCardModel(result: previewResult),
                         style: WorkoutShareStyle(accentColor: .green),
                         mode: .sticker)
    }

    #Preview("스티커 · 1행") {
        WorkoutShareCard(
            model: WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 5400,
                                                               caloriesBurned: 0,
                                                               averageHeartRate: nil)),
            style: WorkoutShareStyle(accentColor: .indigo,
                                     logo: Image(systemName: "figure.golf")),
            mode: .sticker
        )
    }

    #Preview("전체 이미지") {
        WorkoutShareCard(model: WorkoutShareCardModel(result: previewResult),
                         style: WorkoutShareStyle(accentColor: .green,
                                                  logo: Image(systemName: "figure.tennis")),
                         mode: .standalone)
    }
#endif
