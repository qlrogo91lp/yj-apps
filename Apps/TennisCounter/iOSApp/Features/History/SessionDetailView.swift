import SwiftUI

/// 세션 하나의 상세. 기록 목록에서 push로 열고 모든 경기 카드를 함께 보여준다.
struct SessionDetailView: View {
    let session: MatchSessionGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                SessionMetricsGrid(session: session)
                if !session.matches.isEmpty { matchSection }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SessionShareButton(session: session)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.dateText(session.date))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            if let range = timeRangeText {
                Text(range)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: String(localized: "session_match_count"), session.matchCount))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            ForEach(Array(session.matches.enumerated()), id: \.element.id) { index, match in
                SessionMatchCard(match: match, order: index + 1)
            }
        }
    }

    private var timeRangeText: String? {
        guard let record = session.record, let end = record.endedAt else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: record.startedAt)) – \(formatter.string(from: end))"
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: date)
    }
}

private struct SessionMetricsGrid: View {
    let session: MatchSessionGroup

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                cell(String(localized: "session_metric_duration"), durationText, .brand)
                cell(String(localized: "share_metric_active"), caloriesText, Color(red: 1, green: 0.702, blue: 0.251))
            }
            Divider()
            HStack(spacing: 14) {
                cell(String(localized: "share_metric_total"), totalCaloriesText, Color(red: 1, green: 0.702, blue: 0.251))
                cell(String(localized: "session_metric_heart_rate"), heartRateText, Color(red: 1, green: 0.42, blue: 0.341))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func cell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(value == "–" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationText: String {
        session.elapsedSeconds.map(CumulativeDuration.format) ?? "–"
    }

    private var caloriesText: String {
        format(session.activeCalories)
    }

    private var totalCaloriesText: String {
        format(session.totalCalories)
    }

    private var heartRateText: String {
        format(session.averageHeartRate)
    }

    private func format(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(0))) ?? "–"
    }
}

private struct SessionMatchCard: View {
    let match: Match
    let order: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(format: String(localized: "session_match_order"), order))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let seconds = match.durationSeconds {
                    Text(String(format: String(localized: "session_match_duration"), seconds / 60))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Scoreboard(match: match)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
