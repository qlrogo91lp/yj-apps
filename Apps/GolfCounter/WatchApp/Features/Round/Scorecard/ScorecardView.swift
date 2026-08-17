import SwiftUI

/// 스코어카드 한 페이지. 홀 범위 하나만 그린다 (spec §4).
/// 합계 줄은 마지막 청크에만 붙이고, 값은 라운드 전체 합계다.
struct ScorecardView: View {
    let snapshot: RoundSnapshot
    let holeRange: Range<Int>
    let showsTotal: Bool

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows, id: \.holeNumber) { row in
                HStack(spacing: 4) {
                    Text("H\(row.holeNumber)")
                        .frame(width: 26, alignment: .leading)
                    Text(row.isRecorded ? "Par\(row.par)" : "—")
                        .frame(width: 38, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text("\(row.score)타(\(row.putts)p)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.isRecorded ? ScoreFormat.relativeToPar(row.score - row.par) : "")
                        .frame(width: 26, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }

            if showsTotal {
                Divider()

                Text("합계 \(snapshot.totalStrokes)타 · \(totalPutts)퍼트 · \(ScoreFormat.relativeToPar(snapshot.relativeToPar))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
    }

    private var totalPutts: Int {
        snapshot.puttCounts.reduce(0, +)
    }

    /// 세 배열의 길이가 어긋난 값이 들어와도 인덱스를 벗어나지 않도록 가장 짧은 길이에 맞춘다.
    private var rows: [ScorecardRow] {
        let available = min(snapshot.holeScores.count, snapshot.holePars.count, snapshot.puttCounts.count)
        let safeRange = holeRange.clamped(to: 0 ..< available)
        return safeRange.map { index in
            ScorecardRow(holeNumber: index + 1,
                         par: snapshot.holePars[index],
                         score: snapshot.holeScores[index],
                         putts: snapshot.puttCounts[index])
        }
    }
}

private struct ScorecardRow {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int

    /// 기록된 홀 = 파와 타수가 모두 있는 홀. `HoleRow`(iOS)와 같은 규칙이다 (invariant spec §6).
    var isRecorded: Bool {
        par > 0 && score > 0
    }
}

#Preview {
    ScorecardView(snapshot: RoundSnapshot(startedAt: Date(),
                                          courseName: "테스트CC",
                                          currentHoleIndex: 2,
                                          holeScores: [4, 3, 6],
                                          holePars: [4, 3, 5],
                                          puttCounts: [2, 1, 2]),
                  holeRange: 0 ..< 3,
                  showsTotal: true)
}
