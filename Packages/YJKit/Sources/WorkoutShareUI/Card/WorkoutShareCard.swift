#if os(iOS)
    import SwiftUI
    import WorkoutCore

    extension WorkoutShareCardModel.Metric {
        var localizedLabel: String {
            switch self {
            case .duration: String(localized: "share_metric_duration", bundle: .module)
            case .activeCalories: String(localized: "share_metric_calories", bundle: .module)
            case .totalCalories: String(localized: "share_metric_total_calories", bundle: .module)
            case .heartRate: String(localized: "share_metric_heart_rate", bundle: .module)
            }
        }

        /// 값 색은 지표마다 고정 — 세 앱 카드가 같은 가족으로 보이게. 앱 색은 원형 로고에만 쓴다.
        var valueColor: Color {
            switch self {
            case .duration: ShareCardPalette.lime
            case .activeCalories, .totalCalories: ShareCardPalette.amber
            case .heartRate: ShareCardPalette.coral
            }
        }
    }

    /// 짙은 회색 카드 위에서 대비를 맞춘 색. 인스타 사진 위에 붙으므로 테마와 무관하게 고정한다.
    enum ShareCardPalette {
        static let background = Color(red: 0x1C / 255, green: 0x1D / 255, blue: 0x1B / 255)
        static let label = Color(red: 0xE4 / 255, green: 0xE6 / 255, blue: 0xDF / 255)
        static let secondary = Color(red: 0x9A / 255, green: 0x9F / 255, blue: 0x92 / 255)
        static let hairline = Color(red: 0x33 / 255, green: 0x35 / 255, blue: 0x2F / 255)
        static let lime = Color(red: 0xAD / 255, green: 0xFF / 255, blue: 0x41 / 255)
        static let amber = Color(red: 0xFF / 255, green: 0xB3 / 255, blue: 0x40 / 255)
        static let coral = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x57 / 255)
    }

    /// 공유 이미지. 짙은 회색 둥근 카드 한 장 — 머리줄(원형 로고 · 제목 · 날짜)과 2×2 지표.
    /// 모서리 바깥은 투명하다. 값과 스타일만 받는다 — 서비스나 ViewModel을 모른다.
    struct WorkoutShareCard: View {
        let model: WorkoutShareCardModel
        let style: WorkoutShareStyle
        var corners: ShareCardCorners = .rounded

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                header
                metrics
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .frame(width: ShareCanvas.cardSize.width, height: ShareCanvas.cardSize.height, alignment: .topLeading)
            .background(ShareCardPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: corners == .rounded ? ShareCanvas.cornerRadius : 0,
                                        style: .continuous))
        }

        private var header: some View {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(style.badgeColor)
                    style.logo
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(BadgeForeground.logoColor(badge: style.badgeColor, explicit: style.logoColor))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(model.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ShareCardPalette.secondary)
                        .monospacedDigit()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }

        private var metrics: some View {
            VStack(alignment: .leading, spacing: 9) {
                row(model.cells[0], model.cells[1])
                Rectangle()
                    .fill(ShareCardPalette.hairline)
                    .frame(height: 1)
                row(model.cells[2], model.cells[3])
            }
        }

        private func row(_ leading: WorkoutShareCardModel.Cell, _ trailing: WorkoutShareCardModel.Cell) -> some View {
            HStack(alignment: .top, spacing: 14) {
                cell(leading)
                cell(trailing)
            }
        }

        private func cell(_ cell: WorkoutShareCardModel.Cell) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(cell.metric.localizedLabel)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ShareCardPalette.label)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(cell.value)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    if let unit = cell.unit {
                        Text(unit)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                }
                .foregroundStyle(cell.metric.valueColor)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private let previewHeader = WorkoutShareHeader(title: "테니스",
                                                   startedAt: Date().addingTimeInterval(-9351),
                                                   endedAt: Date())

    #Preview("네 칸") {
        WorkoutShareCard(
            model: WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 9351, caloriesBurned: 1343,
                                                               averageHeartRate: 136, totalCaloriesBurned: 1584),
                                         header: previewHeader),
            style: WorkoutShareStyle(badgeColor: Color(red: 0.6784, green: 1.0, blue: 0.2549),
                                     logo: Image(systemName: "tennisball"))
        )
        .padding()
        .background(.blue)
    }

    #Preview("심박 없음 · 골프 색") {
        WorkoutShareCard(
            model: WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 4328, caloriesBurned: 612,
                                                               averageHeartRate: nil, totalCaloriesBurned: 734),
                                         header: WorkoutShareHeader(title: "골프", startedAt: Date(), endedAt: nil)),
            style: WorkoutShareStyle(badgeColor: Color(red: 0, green: 0.3216, blue: 0.0392),
                                     logo: Image(systemName: "figure.golf"),
                                     logoColor: Color(red: 0.9686, green: 0.9529, blue: 0.9059))
        )
        .padding()
        .background(.blue)
    }
#endif
