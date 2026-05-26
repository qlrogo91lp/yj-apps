import SwiftData
import SwiftUI

struct SummaryView: View {
    @StateObject private var viewModel = SummaryViewModel()
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]

    private var stats: SummaryStats { viewModel.stats(from: matches) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(SummaryPeriod.allCases, id: \.rawValue) { period in
                            Text(period.localizedTitle).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    MatchStatsGrid(stats: stats)

                    WorkoutStatsGrid(stats: stats)

                    RecentMatchList(matches: viewModel.recentMatches(from: matches))
                }
                .padding()
            }
            .navigationTitle(String(localized: "tab_summary"))
        }
    }
}
