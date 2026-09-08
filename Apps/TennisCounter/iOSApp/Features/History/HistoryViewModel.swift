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
    @Published var currentMonth: Date = .init()
    @Published private(set) var listSessions: [MatchSessionGroup] = []

    private var modelContext: ModelContext?
    private let pageSize: Int = 20

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
    }

    func loadInitial() {
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
        // 페이지 번호가 아니라 보유 개수로 offset 을 잡는다 — 삭제로 저장소와 배열이 함께 하나 줄면
        // offset 도 같이 줄어 경계가 어긋나지 않는다. 화면에 없는 레코드는 지울 수 없으므로 항상 일치한다.
        descriptor.fetchOffset = listMatches.count

        let fetched = (try? context.fetch(descriptor)) ?? []
        listMatches.append(contentsOf: fetched)
        hasMore = fetched.count == pageSize
        rebuildSessions()
        isLoadingMore = false
    }

    /// CloudKit 동기화라 다른 기기로 전파되고 되돌릴 수 없다. 호출부가 확인 다이얼로그를 받는다.
    ///
    /// 서비스와 이 VM 이 서로 다른 ModelContext 를 들고 있다 — 같은 컨테이너라 저장소에는
    /// 반영되지만 배열은 자동으로 갱신되지 않으므로 직접 지운다.
    func delete(_ match: Match) {
        try? MatchPersistenceService.shared.delete(match)
        listMatches.removeAll { $0.id == match.id }
        calendarMatches.removeAll { $0.id == match.id }
        rebuildSessions()
    }

    /// 누적 배열 전체를 다시 그룹핑한다. 페이지 경계에서 한 세션이 둘로 갈리는 문제가
    /// 여기서 자연히 사라진다 — 경계를 따로 병합할 필요가 없다.
    private func rebuildSessions() {
        listSessions = MatchSessionGroup.group(listMatches)
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
        let descriptor = FetchDescriptor<Match>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Match.startedAt, order: .reverse)]
        )
        calendarMatches = (try? context.fetch(descriptor)) ?? []
    }
}
