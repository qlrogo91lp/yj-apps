import SwiftUI

/// 스코어카드 페이지 상단에 라운드 전체 합계를 고정 표시한다 — 어느 페이지에 있든
/// 스크롤 없이 총타수·오버파를 바로 볼 수 있게 한다.
///
/// 총타수만 기본색, 오버파는 `.secondary` — 카운터 링 중앙(`ScoreRing`)과 같은 위계다.
/// `Total:` 라벨은 두 언어 공통으로 쓰므로 번역표에 두지 않는다.
struct ScorecardHeader: View {
    let totalStrokes: Int
    let relativeToPar: Int
    let sizing: ScorecardSizing

    var body: some View {
        HStack(spacing: 6) {
            Text("Total: \(totalStrokes)")
            Text(ScoreFormat.relativeToPar(relativeToPar))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: sizing.headerFont, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ScorecardHeader(totalStrokes: 44, relativeToPar: 8, sizing: .regular)
}
