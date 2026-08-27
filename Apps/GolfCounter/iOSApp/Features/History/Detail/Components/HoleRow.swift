import SwiftUI

/// 상세 스코어카드의 한 홀.
/// 기록 없는 홀은 오버파를 계산할 수 없으므로 "기록 없음"으로 표시한다 (invariant spec §6).
///
/// 건너뛴 홀(`par == 0`)과 파만 고른 홀(`par > 0 && score == 0`)을 같이 다룬다 — 후자는
/// 저장 경계에서 정규화되지만 이미 저장된 라운드에는 남아 있을 수 있다.
struct HoleRow: View {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int

    private var isRecorded: Bool {
        par > 0 && score > 0
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
                Text(String(format: String(localized: "hole_row_strokes_putts"), score, putts))
                    .font(.subheadline)
                Text(ScoreFormat.relativeToPar(score - par))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ScorePalette.color(for: score - par))
                    .frame(width: 34, alignment: .trailing)
            } else {
                Text(String(localized: "hole_row_unrecorded"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
