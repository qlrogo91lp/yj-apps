import SwiftUI

/// 상세 스코어카드의 한 홀.
/// 기록 없는 홀은 오버파를 계산할 수 없으므로 "기록 없음"으로 표시한다 (spec §6).
///
/// 두 종류를 같이 다룬다 — 워치에서 건너뛴 홀(`par == 0`)과, 파만 고르고 한 타도 치지
/// 않은 홀(`par > 0 && score == 0`). 후자는 저장 경계에서 정규화되므로 새 데이터에는
/// 없지만, 이미 저장된 라운드에는 남아 있을 수 있다. 행을 탭하면 편집 시트가 저장된 파를
/// 그대로 보여주므로 이 분기가 수정 경로를 막지는 않는다.
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
