import SwiftUI

struct MatchRowView: View {
    let match: Match
    let didWin: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(didWin ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(didWin ? String(localized: "match_over_win") : String(localized: "match_over_lose"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(didWin ? .green : .orange)

                    Text(formatName(match.matchFormat.rawValue))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text(formattedDate(match.startedAt))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(match.myTotalSets) - \(match.yourTotalSets)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 6)
    }

    private func formatName(_ raw: String) -> String {
        raw == "one_set"
            ? String(localized: "match_format_one_set")
            : String(localized: "match_format_best_of_3")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
