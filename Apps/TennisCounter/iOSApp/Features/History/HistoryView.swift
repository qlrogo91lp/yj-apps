import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedMatch: Match?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.viewMode == .list {
                    if viewModel.listMatches.isEmpty, !viewModel.isLoadingMore {
                        HistoryEmptyState()
                    } else {
                        MatchList(
                            matches: viewModel.listMatches,
                            isLoadingMore: viewModel.isLoadingMore,
                            onLoadMore: { viewModel.loadNextPage() },
                            onSelect: { selectedMatch = $0 }
                        )
                    }
                } else {
                    ScrollView {
                        CalendarView(
                            matches: viewModel.calendarMatches,
                            currentMonth: viewModel.currentMonth,
                            onPrevious: { viewModel.changeMonth(by: -1) },
                            onNext: { viewModel.changeMonth(by: 1) },
                            selectedMatch: $selectedMatch
                        )
                        .padding()
                    }
                }
            }
            .navigationTitle(String(localized: "history_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.toggleViewMode() }, label: {
                        Image(systemName: viewModel.viewMode == .list ? "calendar" : "list.bullet")
                    })
                }
            }
            .sheet(item: $selectedMatch) { match in
                MatchDetailSheet(match: match)
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadInitial()
            }
        }
    }
}
