import SwiftUI

/// 기록 목록과 캘린더 하단이 함께 쓰는 세션 목록. 세션 하나가 `Section`, 경기 하나가 행이다.
struct SessionList: View {
    let sessions: [MatchSessionGroup]
    let isLoadingMore: Bool
    /// 캘린더 하단은 페이징하지 않으므로 nil.
    let onLoadMore: (() -> Void)?
    let onSelect: (Match) -> Void
    let onDelete: (Match) -> Void

    /// 무한 스크롤은 세션이 아니라 경기 기준으로 센다 — 세션당 경기 수가 들쭉날쭉해서
    /// 세션으로 세면 남은 분량을 가늠할 수 없다.
    private var matchCount: Int {
        sessions.reduce(0) { $0 + $1.matches.count }
    }

    var body: some View {
        List {
            ForEach(sessions) { session in
                Section(header: SessionHeader(session: session)) {
                    ForEach(session.matches) { match in
                        MatchRow(match: match)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(match) }
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(String(localized: "btn_delete"), role: .destructive) { onDelete(match) }
                            }
                            .onAppear { loadMoreIfNeeded(reaching: match) }
                    }
                }
            }

            if isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        // 셋을 다 걸어야 다크 배경이 유지된다 — 하나라도 빠지면 흰 배경이 비친다.
        .scrollContentBackground(.hidden)
    }

    private func loadMoreIfNeeded(reaching match: Match) {
        guard let onLoadMore else { return }
        let flattened = sessions.flatMap(\.matches)
        guard let index = flattened.firstIndex(where: { $0.id == match.id }) else { return }
        if index == max(0, matchCount - 5) { onLoadMore() }
    }
}
