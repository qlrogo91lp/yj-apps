import SwiftUI

struct MatchList: View {
    let matches: [Match]
    let onSelect: (Match) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(matches) { match in
                    MatchCard(match: match)
                        .onTapGesture { onSelect(match) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
