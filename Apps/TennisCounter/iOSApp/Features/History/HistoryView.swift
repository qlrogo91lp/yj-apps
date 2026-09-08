import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedMatch: Match?
    @State private var pendingDelete: Match?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.viewMode == .list {
                    if viewModel.listSessions.isEmpty, !viewModel.isLoadingMore {
                        HistoryEmptyState()
                    } else {
                        SessionList(
                            sessions: viewModel.listSessions,
                            isLoadingMore: viewModel.isLoadingMore,
                            onLoadMore: { viewModel.loadNextPage() },
                            onSelect: { selectedMatch = $0 },
                            onDelete: { pendingDelete = $0 }
                        )
                    }
                } else {
                    CalendarView(
                        matches: viewModel.calendarMatches,
                        currentMonth: viewModel.currentMonth,
                        onPrevious: { viewModel.changeMonth(by: -1) },
                        onNext: { viewModel.changeMonth(by: 1) },
                        selectedDate: $viewModel.selectedDate,
                        onSelect: { selectedMatch = $0 },
                        onDelete: { pendingDelete = $0 }
                    )
                    .padding(.horizontal)
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
            .confirmationDialog(
                String(localized: "history_delete_confirm_title"),
                isPresented: .init(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button(String(localized: "btn_delete"), role: .destructive) {
                    if let match = pendingDelete { viewModel.delete(match) }
                    pendingDelete = nil
                }
                Button(String(localized: "btn_cancel"), role: .cancel) { pendingDelete = nil }
            } message: {
                Text(String(localized: "history_delete_confirm_message"))
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadInitial()
            }
        }
    }
}
