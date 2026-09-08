import SwiftUI

/// 요약 하단의 최근 세션 하나. 패딩·배경·라운드는 여기서 붙인다 — 조각(`SessionHeader`·
/// `MatchRow`)은 자기가 카드에 들어가는지 `List` 에 들어가는지 모른다.
struct RecentSessionCard: View {
    let session: MatchSessionGroup
    let onSelect: (Match) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SessionHeader(session: session)

            ForEach(session.matches) { match in
                MatchRow(match: match)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(match) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
