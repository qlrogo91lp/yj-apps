import SwiftUI

/// 세션 하나를 담는 카드. 기록 목록과 요약이 함께 쓴다.
///
/// 전적을 카드가 직접 보여준다 — 목록에 경기 행이 없어서 세어 볼 수가 없다.
struct SessionCard: View {
    let session: MatchSessionGroup

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.dateText(session.date))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    recordLine
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HStack(spacing: 10) {
                metric(value: durationText, label: String(localized: "session_metric_duration"), color: .brand)
                metric(
                    value: caloriesText,
                    label: String(localized: "session_metric_calories"),
                    color: Color(red: 1, green: 0.702, blue: 0.251)
                )
                metric(
                    value: heartRateText,
                    label: String(localized: "session_metric_heart_rate"),
                    color: Color(red: 1, green: 0.42, blue: 0.341)
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var recordLine: some View {
        if session.matchCount == 0 {
            Text(String(localized: "session_no_match"))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 0) {
                Text(String(format: String(localized: "session_match_count"), session.matchCount))
                Text(verbatim: " · ")
                Text(String(format: String(localized: "session_wins"), session.wins))
                    .foregroundStyle(Color.brand)
                    .fontWeight(.semibold)
                if session.losses > 0 {
                    Text(verbatim: " ")
                    Text(String(format: String(localized: "session_losses"), session.losses))
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
    }

    private func metric(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(value == "–" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationText: String {
        session.elapsedSeconds.map(CumulativeDuration.format) ?? "–"
    }

    private var caloriesText: String {
        guard let calories = session.activeCalories else { return "–" }
        return calories.formatted(.number.precision(.fractionLength(0)))
    }

    private var heartRateText: String {
        guard let rate = session.averageHeartRate else { return "–" }
        return rate.formatted(.number.precision(.fractionLength(0)))
    }

    /// "8월 24일 (일)" / "Sat, Aug 24" — 로케일이 순서를 정한다.
    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: date)
    }
}
