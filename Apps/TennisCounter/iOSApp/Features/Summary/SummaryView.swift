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

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(SummaryPeriod.allCases, id: \.rawValue) { period in
                Text(period.localizedTitle).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var statsGrid: some View {
        let stats = viewModel.stats(from: matches)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(title: String(localized: "summary_total_matches"), value: "\(stats.totalMatches)", color: .blue)
            StatCard(title: String(localized: "summary_win_rate"), value: String(format: "%.0f%%", stats.winRate * 100), color: stats.winRate >= 0.5 ? .green : .orange)
            StatCard(title: String(localized: "summary_streak"), value: "\(stats.streak)", color: .red)
            StatCard(title: "Wins", value: "\(stats.wins)", color: .green)
        }
    }

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
