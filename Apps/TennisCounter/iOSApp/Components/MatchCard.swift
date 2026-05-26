import SwiftUI

struct MatchCard: View {
    let match: Match

    private var didWin: Bool { match.myTotalSets > match.yourTotalSets }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(didWin ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(didWin ? String(localized: "match_over_win") : String(localized: "match_over_lose"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(didWin ? .green : .orange)
                }
                Spacer()
                if match.matchFormat != .oneSet {
                    Text("\(match.myTotalSets) - \(match.yourTotalSets)")
                        .font(.system(size: 22, weight: .bold))
                }
            }

            HStack(spacing: 6) {
                Text(formattedDate(match.startedAt))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("·")
                    .foregroundColor(.secondary)
                Text(formatName(match.matchFormat.rawValue))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
