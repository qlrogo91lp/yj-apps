import SwiftUI

/// 세션 상세의 경기 카드. 결과(승리/패배 + 스코어)를 크게, 세트별 스코어와 경기 구간 지표를 작게 보인다.
///
/// 3세트 매치는 세트 스코어(2–1)가, 한 세트 경기는 그 세트의 게임 스코어(4–6)가 결과 자리에 온다.
/// 나=초록, 상대=주황은 워치 점수 화면과 같다.
struct MatchCard: View {
    let match: Match
    let order: Int

    private static let calorieColor = Color(red: 1, green: 0.702, blue: 0.251)
    private static let heartRateColor = Color(red: 1, green: 0.42, blue: 0.341)

    private var sets: [SetRecord] {
        (match.sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    private var result: MatchResult {
        MatchResult(rawValue: match.resultRaw) ?? .draw
    }

    private var showsSetTotals: Bool {
        match.matchFormat == .bestOfThree
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headline
            resultRow.padding(.top, 6)
            if showsSetTotals, !sets.isEmpty {
                setChips.padding(.top, 12)
            }
            Divider().padding(.vertical, 12)
            metrics
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 머리줄

    private var headline: some View {
        Text(headlineText)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private var headlineText: String {
        var parts = [
            String(format: String(localized: "session_match_order"), order),
            match.matchFormat.localizedTitle,
        ]
        if match.noAdRule { parts.append(String(localized: "mode_no_ad")) }
        return parts.joined(separator: " · ")
    }

    // MARK: - 결과

    private var resultRow: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(resultTitle)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(result == .win ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.secondary))
            Spacer(minLength: 8)
            score
        }
    }

    @ViewBuilder
    private var score: some View {
        if let pair = scorePair {
            HStack(spacing: 6) {
                Text(verbatim: "\(pair.my)").foregroundStyle(.green)
                Text(verbatim: "–").foregroundStyle(.tertiary)
                Text(verbatim: "\(pair.your)").foregroundStyle(.orange)
            }
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .monospacedDigit()
        } else {
            Text(String(localized: "match_detail_no_sets"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var scorePair: (my: Int, your: Int)? {
        guard !sets.isEmpty else { return nil }
        if showsSetTotals { return (match.myTotalSets, match.yourTotalSets) }
        guard let first = sets.first else { return nil }
        return (first.myGames, first.yourGames)
    }

    private var resultTitle: String {
        switch result {
        case .win: String(localized: "match_card_win")
        case .loss: String(localized: "match_card_loss")
        case .draw: String(localized: "result_draw")
        }
    }

    // MARK: - 세트 칩

    private var setChips: some View {
        HStack(spacing: 8) {
            ForEach(sets, id: \.setNumber) { set in
                Text(verbatim: "\(set.myGames)–\(set.yourGames)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(set.myGames > set.yourGames ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 지표

    private var metrics: some View {
        HStack(spacing: 10) {
            metric("timer", durationText, .brand)
            metric("flame.fill", caloriesText, Self.calorieColor)
            metric("heart.fill", heartRateText, Self.heartRateColor)
        }
    }

    private func metric(_ symbol: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(value == "–" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(value == "–" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationText: String {
        match.durationSeconds.map(CumulativeDuration.format) ?? "–"
    }

    private var caloriesText: String {
        format(match.caloriesBurned)
    }

    private var heartRateText: String {
        format(match.averageHeartRate)
    }

    private func format(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(0))) ?? "–"
    }
}
