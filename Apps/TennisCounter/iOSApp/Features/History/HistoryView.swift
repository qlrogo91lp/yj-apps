import SwiftData
import SwiftUI
import WorkoutCore

struct HistoryView: View {
    let activationID: Int
    let showListOnActivation: Bool
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedSession: MatchSessionGroup?
    @State private var pendingDelete: MatchSessionGroup?

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
                            onSelect: { selectedSession = viewModel.sessionForDetail($0) },
                            onDelete: { pendingDelete = $0 }
                        )
                    }
                } else {
                    CalendarView(
                        matches: viewModel.calendarMatches,
                        sourceMatches: viewModel.calendarSourceMatches,
                        currentMonth: viewModel.currentMonth,
                        onPrevious: { viewModel.changeMonth(by: -1) },
                        onNext: { viewModel.changeMonth(by: 1) },
                        selectedDate: $viewModel.selectedDate,
                        onSelect: { selectedSession = viewModel.sessionForDetail($0) },
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
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedSession != nil },
                    set: { if !$0 { selectedSession = nil } }
                )
            ) {
                if let selectedSession {
                    SessionDetailView(session: selectedSession)
                }
            }
            .confirmationDialog(
                String(localized: "history_delete_confirm_title"),
                isPresented: .init(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button(String(localized: "btn_delete"), role: .destructive) {
                    if let session = pendingDelete { viewModel.delete(session) }
                    pendingDelete = nil
                }
                Button(String(localized: "btn_cancel"), role: .cancel) { pendingDelete = nil }
            } message: {
                Text(String(localized: "history_delete_confirm_message"))
            }
            .alert(
                healthDeletionFailureMessage,
                isPresented: .init(
                    get: { viewModel.deletionFailure != nil },
                    set: { if !$0 { viewModel.deletionFailure = nil } }
                )
            ) {
                Button(String(localized: "btn_confirm")) {
                    viewModel.deletionFailure = nil
                }
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                activate(activationID)
            }
            .onChange(of: activationID) { _, value in
                activate(value)
            }
        }
    }

    private func activate(_ id: Int) {
        if viewModel.activate(id, showList: showListOnActivation), showListOnActivation {
            selectedSession = nil
        }
    }

    private var healthDeletionFailureMessage: String {
        switch viewModel.deletionFailure {
        case .notAuthorized:
            String(localized: "history_delete_health_denied")
        case .failed, .none, .nothingToDelete, .deleted:
            String(localized: "history_delete_health_failed")
        }
    }
}
