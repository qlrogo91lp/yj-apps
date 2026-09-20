import SwiftUI

/// 요약 하단의 최근 세션 하나. 탭하면 그 세션의 가장 최근 경기를 연다.
struct RecentSessionCard: View {
    let session: MatchSessionGroup
    let onSelect: (Match) -> Void

    var body: some View {
        SessionCard(session: session)
            .contentShape(Rectangle())
            .onTapGesture {
                if let match = session.matches.last { onSelect(match) }
            }
    }
}
