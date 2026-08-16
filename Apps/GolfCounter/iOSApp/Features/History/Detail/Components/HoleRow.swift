import SwiftUI

/// 상세 스코어카드의 한 홀.
/// 워치에서 건너뛴 홀(par == 0)은 오버파를 계산할 수 없으므로 "기록 없음"으로 표시한다 (spec §4).
struct HoleRow: View {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int

    private var isRecorded: Bool {
        par > 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("H\(holeNumber)")
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, alignment: .leading)

            Text(isRecorded ? "Par \(par)" : "Par –")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if isRecorded {
                Text("\(score)타 · \(putts)퍼트")
                    .font(.subheadline)
                Text(ScoreFormat.relativeToPar(score - par))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ScorePalette.color(for: score - par))
                    .frame(width: 34, alignment: .trailing)
            } else {
                Text("기록 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
