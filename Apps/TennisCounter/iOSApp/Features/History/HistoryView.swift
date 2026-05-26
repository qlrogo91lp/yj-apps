import SwiftData
import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @State private var selectedMatch: Match?

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    HistoryEmptyState()
                } else if viewModel.viewMode == .list {
                    MatchList(matches: matches, onSelect: { selectedMatch = $0 })
                } else {
                    ScrollView {
                        CalendarView(matches: matches, selectedMatch: $selectedMatch)
                            .padding()
                    }
                }
            }
            .navigationTitle(String(localized: "history_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.toggleViewMode() }) {
                        Image(systemName: viewModel.viewMode == .list ? "calendar" : "list.bullet")
                    }
                }
            }
            .sheet(item: $selectedMatch) { match in
                MatchDetailSheet(match: match)
            }
        }
    }
}
