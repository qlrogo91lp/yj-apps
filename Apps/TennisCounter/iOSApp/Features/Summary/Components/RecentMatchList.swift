import SwiftUI

struct RecentMatchList: View {
    let matches: [Match]

    var body: some View {
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "summary_recent_matches"))
                    .font(.headline)
                ForEach(matches) { match in
                    MatchCard(match: match)
                }
            }
        }
    }
}
