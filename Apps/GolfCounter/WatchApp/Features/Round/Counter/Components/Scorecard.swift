import SwiftUI

struct Scorecard: View {
    let snapshot: RoundSnapshot

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows, id: \.holeNumber) { row in
                HStack(spacing: 4) {
                    Text("H\(row.holeNumber)")
                        .frame(width: 26, alignment: .leading)
                    Text(row.par > 0 ? "Par\(row.par)" : "—")
                        .frame(width: 38, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text("\(row.score)타(\(row.putts)p)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.par > 0 ? ScoreFormat.relativeToPar(row.score - row.par) : "")
                        .frame(width: 26, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }

            Divider()

            Text("합계 \(snapshot.totalStrokes)타 · \(totalPutts)퍼트 · \(ScoreFormat.relativeToPar(snapshot.relativeToPar))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var totalPutts: Int {
        snapshot.puttCounts.reduce(0, +)
    }

    /// 세 배열의 길이가 어긋난 값이 들어와도 인덱스를 벗어나지 않도록 가장 짧은 길이에 맞춘다.
    private var rows: [ScorecardRow] {
        let count = min(snapshot.holeScores.count, snapshot.holePars.count, snapshot.puttCounts.count)
        return (0 ..< count).map { index in
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
}

#Preview {
    Scorecard(snapshot: RoundSnapshot(startedAt: Date(),
                                      courseName: "테스트CC",
                                      currentHoleIndex: 2,
                                      holeScores: [4, 3, 6],
                                      holePars: [4, 3, 5],
                                      puttCounts: [2, 1, 2]))
}
