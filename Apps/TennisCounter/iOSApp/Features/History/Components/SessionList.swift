import SwiftUI

/// 기록 목록과 캘린더 하단이 함께 쓰는 세션 목록. 세션 하나가 카드 하나다.
struct SessionList: View {
    let sessions: [MatchSessionGroup]
    let isLoadingMore: Bool
    /// 캘린더 하단은 페이징하지 않으므로 nil.
    let onLoadMore: (() -> Void)?
    let onSelect: (MatchSessionGroup) -> Void
    let onDelete: (MatchSessionGroup) -> Void

    var body: some View {
        List {
            ForEach(sessions) { session in
                SessionCard(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(session) }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .swipeActions(edge: .trailing) {
                        Button(String(localized: "btn_delete"), role: .destructive) { onDelete(session) }
                    }
                    .onAppear { loadMoreIfNeeded(reaching: session) }
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

    private func loadMoreIfNeeded(reaching session: MatchSessionGroup) {
        guard let onLoadMore else { return }
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        if index >= max(0, sessions.count - 3) { onLoadMore() }
    }
}
