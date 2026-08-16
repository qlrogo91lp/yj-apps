import SwiftUI

/// 기록 리스트의 한 행. 오버파를 가장 크게 두고 총타수는 보조로 둔다 (spec §4).
struct RoundCard: View {
    let round: GolfRound

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // 골프장명이 없으면 행 자체를 생략한다 — "미입력" placeholder를 두지 않는다.
                if let courseName = round.courseName, !courseName.isEmpty {
                    Text(courseName)
                        .font(.headline)
                }

                Text("\(round.recordedHoleCount)홀")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ScoreFormat.relativeToPar(round.relativeToPar))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ScorePalette.color(for: round.relativeToPar))
                Text("\(round.totalStrokes)타")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let round = GolfRound()
    round.courseName = "레이크사이드"
    round.holeScores = [4, 5, 3]
    round.holePars = [4, 4, 3]
    round.puttCounts = [2, 2, 1]
    return List {
        RoundCard(round: round)
    }
}
