import SwiftData
import SwiftUI

struct SummaryView: View {
    @StateObject private var viewModel = SummaryViewModel()
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    statsGrid
                    recentMatchesSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "tab_summary"))
            .sheet(item: $viewModel.selectedMatch) { match in
                MatchDetailSheet(match: match)
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(SummaryPeriod.allCases, id: \.rawValue) { period in
                Text(period.localizedTitle).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let stats = viewModel.stats(from: matches)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: String(localized: "summary_total_matches"),
                value: "\(stats.totalMatches)",
                systemImage: "sportscourt.fill",
                color: .blue
            )

            StatCard(
                title: String(localized: "summary_win_rate"),
                value: String(format: "%.0f%%", stats.winRate * 100),
                systemImage: "trophy.fill",
                color: stats.winRate >= 0.5 ? .green : .orange
            )

            StatCard(
                title: String(localized: "summary_streak"),
                value: "\(stats.streak)",
                systemImage: "flame.fill",
                color: .red
            )

            StatCard(
                title: "Wins",
                value: "\(stats.wins)",
                systemImage: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    // MARK: - Recent Matches

    private var recentMatchesSection: some View {
        let recent = viewModel.recentMatches(from: matches)
        return Group {
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "summary_recent_matches"))
                        .font(.headline)

                    ForEach(recent) { match in
                        RecentMatchCard(match: match)
                            .onTapGesture { viewModel.selectedMatch = match }
                    }
                }
            }
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - RecentMatchCard

private struct RecentMatchCard: View {
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

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView()
    }
}
