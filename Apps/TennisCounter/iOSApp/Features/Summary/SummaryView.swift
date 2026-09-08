import SwiftData
import SwiftUI

struct SummaryView: View {
    @StateObject private var viewModel = SummaryViewModel()
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @State private var selectedMatch: Match?

    private var filtered: [Match] {
        viewModel.filteredMatches(from: matches)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker(String(localized: "summary_period_label"), selection: $viewModel.selectedPeriod) {
                        ForEach(SummaryPeriod.allCases, id: \.rawValue) { period in
                            Text(period.localizedTitle).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        statsSection
                        trendSection
                        recentSessionSection
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "tab_summary"))
            .sheet(item: $selectedMatch) { match in
                MatchDetailSheet(match: match)
            }
        }
    }

    private var emptyState: some View {
        Text(String(localized: "summary_no_matches"))
            .font(.system(size: 15))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 60)
    }

    @ViewBuilder
    private var statsSection: some View {
        let stats = viewModel.stats(from: matches)
        SummaryStatsGrid(stats: stats)
        Text(String(
            format: String(localized: "summary_record_line"),
            stats.wins,
            stats.totalMatches - stats.wins,
            Int(stats.winRate * 100)
        ))
        .font(.system(size: 15))
        .foregroundColor(.secondary)
    }

    private var trendSection: some View {
        section(title: String(localized: "summary_section_trend")) {
            RecentTrendChart(sessions: viewModel.trendSessions(from: matches))
        }
    }

    @ViewBuilder
    private var recentSessionSection: some View {
        if let session = viewModel.recentSession(from: matches) {
            section(title: String(localized: "summary_recent_session")) {
                RecentSessionCard(session: session) { selectedMatch = $0 }
            }
        }
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
            content()
        }
    }
}
