import SwiftUI

/// 가로 스코어보드 — 행 2개(나 / 상대) × 열 = 세트.
///
/// 워치 점수 화면과 같이 나=초록, 상대=주황. 승패와 관계없이 행의 굵기는 같다.
struct Scoreboard: View {
    let match: Match

    private var sets: [SetRecord] {
        (match.sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    var body: some View {
        if sets.isEmpty {
            Text(String(localized: "match_detail_no_sets"))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            VStack(spacing: 10) {
                row(
                    name: String(localized: "match_detail_me"),
                    games: sets.map(\.myGames),
                    color: .green
                )
                row(
                    name: match.opponentName ?? String(localized: "match_detail_opponent"),
                    games: sets.map(\.yourGames),
                    color: .orange
                )
            }
        }
    }

    private func row(name: String, games: [Int], color: Color) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            Spacer(minLength: 8)
            ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                Text(verbatim: "\(game)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
                    .frame(width: 24)
            }
        }
    }
}
