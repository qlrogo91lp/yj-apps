import SwiftUI

/// 스코어카드 한 페이지. 홀 범위 하나를 2열 격자로 그린다.
/// 헤더는 페이지마다 라운드 전체 합계를 고정 표시한다 — 마지막 페이지에만 붙던
/// 이전 방식과 달리 어느 페이지에서도 합계를 바로 볼 수 있다 (spec §4, 2026-08-18 개정).
struct ScorecardView: View {
    let snapshot: RoundSnapshot
    let holeRange: Range<Int>
    let sizing: ScorecardSizing

    var body: some View {
        VStack(spacing: 0) {
            ScorecardHeader(totalStrokes: snapshot.totalStrokes,
                            relativeToPar: snapshot.relativeToPar,
                            sizing: sizing)

            Color.clear.frame(height: sizing.gap)
            Divider()
            Color.clear.frame(height: sizing.gap)

            ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                gridRow(pair)

                if index < pairs.count - 1 {
                    Divider()
                }
            }

            Spacer(minLength: 0)
        }
    }

    /// 높이를 명시한다 — 안의 세로 `Divider`가 늘어나려 해서, 비워 두면 홀이 적은 페이지에서
    /// 행이 벌어진다 (`ScorecardSizing.rowHeight` 주석 참조).
    private func gridRow(_ pair: [ScorecardRow]) -> some View {
        HStack(spacing: 0) {
            cell(pair[0])

            if pair.count > 1 {
                Divider()
                cell(pair[1])
            } else {
                Color.clear.frame(maxWidth: .infinity)
            }
        }
        .frame(height: sizing.rowHeight)
    }

    /// 홀 배지만 왼쪽에 고정하고, 타수·오버파는 한 덩어리로 묶어 오른쪽에 붙인다.
    private func cell(_ row: ScorecardRow) -> some View {
        HStack(spacing: 0) {
            HoleBadge(holeNumber: row.holeNumber, sizing: sizing)

            Spacer(minLength: ScorecardSizing.badgeSpacing)

            Text("\(row.score)")
                .font(.system(size: sizing.valueFont, weight: .semibold, design: .rounded))

            Spacer(minLength: ScorecardSizing.valueSpacing)
                .frame(maxWidth: ScorecardSizing.valueSpacing)

            Text(row.isRecorded ? ScoreFormat.relativeToPar(row.score - row.par) : "–")
                .font(.system(size: sizing.valueFont, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(minWidth: sizing.relativeColumnWidth, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, ScorecardSizing.cellPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 홀을 2개씩 묶어 격자 행으로 만든다. 홀 수가 홀수면 마지막 행은 한 칸만 채운다.
    private var pairs: [[ScorecardRow]] {
        stride(from: 0, to: rows.count, by: 2).map { start in
            Array(rows[start ..< min(start + 2, rows.count)])
        }
    }

    /// 세 배열의 길이가 어긋난 값이 들어와도 인덱스를 벗어나지 않도록 가장 짧은 길이에 맞춘다.
    private var rows: [ScorecardRow] {
        let available = min(snapshot.holeScores.count, snapshot.holePars.count, snapshot.puttCounts.count)
        let safeRange = holeRange.clamped(to: 0 ..< available)
        return safeRange.map { index in
            ScorecardRow(holeNumber: index + 1,
                         par: snapshot.holePars[index],
                         score: snapshot.holeScores[index])
        }
    }
}

private struct ScorecardRow {
    let holeNumber: Int
    let par: Int
    let score: Int

    /// 기록된 홀 = 파와 타수가 모두 있는 홀. `HoleRow`(iOS)와 같은 규칙이다 (invariant spec §6).
    var isRecorded: Bool {
        par > 0 && score > 0
    }
}

#Preview {
    ScorecardView(snapshot: RoundSnapshot(startedAt: Date(),
                                          courseName: "테스트CC",
                                          currentHoleIndex: 8,
                                          holeScores: [4, 3, 6, 5, 4, 3, 5, 4, 6],
                                          holePars: [4, 3, 5, 4, 4, 3, 4, 4, 5],
                                          puttCounts: [2, 1, 2, 2, 2, 1, 2, 2, 2]),
                  holeRange: 0 ..< 9,
                  sizing: .regular)
}
