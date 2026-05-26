import SwiftUI

struct MatchList: View {
    let matches: [Match]
    let isLoadingMore: Bool
    let onLoadMore: () -> Void
    let onSelect: (Match) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                    MatchCard(match: match)
                        .onTapGesture { onSelect(match) }
                        .onAppear {
                            if index == matches.count - 5 {
                                onLoadMore()
                            }
                        }
                }

                if isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
