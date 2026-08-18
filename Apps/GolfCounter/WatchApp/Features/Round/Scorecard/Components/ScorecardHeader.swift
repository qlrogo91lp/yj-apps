import SwiftUI

/// 스코어카드 페이지 상단에 라운드 전체 합계를 고정 표시한다 — 어느 페이지에 있든
/// 스크롤 없이 총타수·오버파를 바로 볼 수 있게 한다.
///
/// 총타수만 기본색, 오버파는 `.secondary` — 카운터 링 중앙(`ScoreRing`)과 같은 위계다.
/// 구분 기호나 단위 없이 숫자 두 개만 나란히 둔다("44 +8").
struct ScorecardHeader: View {
    let totalStrokes: Int
    let relativeToPar: Int
    let sizing: ScorecardSizing

    var body: some View {
        HStack(spacing: 6) {
            Text("\(totalStrokes)")
            Text(ScoreFormat.relativeToPar(relativeToPar))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: sizing.headerFont, weight: .semibold, design: .rounded))
    }
}

#Preview {
    ScorecardHeader(totalStrokes: 44, relativeToPar: 8, sizing: .regular)
}
