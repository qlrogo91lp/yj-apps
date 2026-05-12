import SwiftUI

struct RecentMatchCard: View {
    let match: Match

    private var didWin: Bool { match.myTotalSets > match.yourTotalSets }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(didWin ? String(localized: "match_over_win") : String(localized: "match_over_lose"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(didWin ? .green : .orange)
                    Text(match.matchFormat == .oneSet
                        ? String(localized: "match_format_one_set")
                        : String(localized: "match_format_best_of_3"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(match.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(match.myTotalSets) – \(match.yourTotalSets)")
                .font(.system(size: 22, weight: .bold))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
