import Foundation
import SwiftData

enum HistoryViewMode {
    case list
    case calendar
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var viewMode: HistoryViewMode = .list
    @Published var listMatches: [Match] = []
    @Published var calendarMatches: [Match] = []
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    @Published var currentMonth: Date = Date()

    private var modelContext: ModelContext?
    private var currentPage: Int = 0
    private let pageSize: Int = 20

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
    }

    func loadInitial() {
        currentPage = 0
        listMatches = []
        hasMore = true
        loadNextPage()
        loadCalendarMatches()
    }

    func loadNextPage() {
        guard !isLoadingMore, hasMore, let context = modelContext else { return }
        isLoadingMore = true

        var descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\Match.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = currentPage * pageSize

        let fetched = (try? context.fetch(descriptor)) ?? []
        listMatches.append(contentsOf: fetched)
        hasMore = fetched.count == pageSize
        currentPage += 1
        isLoadingMore = false
    }

    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            loadCalendarMatches()
        }
    }

    func toggleViewMode() {
        viewMode = viewMode == .list ? .calendar : .list
    }

    private func loadCalendarMatches() {
        guard let context = modelContext else { return }
        let start = currentMonth.startOfMonth
        let end = currentMonth.endOfMonth

        let predicate = #Predicate<Match> { $0.startedAt >= start && $0.startedAt < end }
        var descriptor = FetchDescriptor<Match>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Match.startedAt, order: .reverse)]
        )
        calendarMatches = (try? context.fetch(descriptor)) ?? []
    }
}
