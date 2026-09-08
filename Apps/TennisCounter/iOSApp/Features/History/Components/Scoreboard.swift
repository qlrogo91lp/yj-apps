import SwiftUI

/// 가로 스코어보드 — 행 2개(나 / 상대) × 열 = 세트.
///
/// 승/패 표기를 행 안에 흡수한다. 이긴 행을 굵게 하면 결과가 스코어에서 바로 읽히므로,
/// "승" 을 스코어보다 크게 띄울 이유가 없다.
struct Scoreboard: View {
    let match: Match

    private var sets: [SetRecord] {
        (match.sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    private var didWin: Bool {
        match.myTotalSets > match.yourTotalSets
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
                    isWinner: didWin
                )
                row(
                    name: match.opponentName ?? String(localized: "match_detail_opponent"),
                    games: sets.map(\.yourGames),
                    isWinner: !didWin
                )
            }
        }
    }

    private func row(name: String, games: [Int], isWinner: Bool) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.system(size: 16, weight: isWinner ? .bold : .regular))
                .foregroundColor(isWinner ? .primary : .secondary)
            Spacer(minLength: 8)
            ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                Text(verbatim: "\(game)")
                    .font(.system(size: 20, weight: isWinner ? .bold : .regular, design: .rounded))
                    .foregroundColor(isWinner ? .primary : .secondary)
                    .frame(width: 24)
            }
        }
    }
}
