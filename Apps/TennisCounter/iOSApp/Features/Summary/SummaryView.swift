import SwiftData
import SwiftUI

struct SummaryView: View {
    var onShowHistory: () -> Void = {}
    @StateObject private var viewModel = SummaryViewModel()
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @Query private var records: [WorkoutSessionRecord]

    private var sessions: [MatchSessionGroup] {
        viewModel.selectedPeriodSessions(from: matches, records: records)
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

                    if sessions.isEmpty {
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
        let stats = viewModel.stats(from: matches, records: records)
        SummaryStatsGrid(stats: stats, period: viewModel.selectedPeriod)
        Text(String(
            format: String(localized: "summary_record_line"),
            stats.wins,
            stats.totalMatches - stats.wins,
            stats.roundedWinRatePercentage
        ))
        .font(.system(size: 15))
        .foregroundColor(.secondary)
    }

    private var trendSection: some View {
        section(title: viewModel.selectedPeriod == .all
            ? String(localized: "summary_monthly_sessions") : String(localized: "summary_section_trend"))
        {
            if viewModel.selectedPeriod == .all {
                RecentTrendChart(monthlyCounts: viewModel.monthlySessionCounts(from: matches, records: records))
            } else {
                RecentTrendChart(sessions: viewModel.trendSessions(from: matches, records: records))
            }
        }
    }

    @ViewBuilder
    private var recentSessionSection: some View {
        if let session = sessions.first {
            section(title: String(localized: "summary_recent_session")) {
                Button(action: onShowHistory) {
                    SessionCard(session: session)
                }
                .buttonStyle(.plain)
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
