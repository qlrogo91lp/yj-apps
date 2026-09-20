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
    @Published private(set) var calendarSourceMatches: [Match]?
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    @Published var currentMonth: Date = .init()
    @Published private(set) var listSessions: [MatchSessionGroup] = []
    @Published var selectedDate: Date?

    private var modelContext: ModelContext?
    private let pageSize: Int = 20

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
    }

    func loadInitial() {
        listMatches = []
        listSessions = []
        hasMore = true
        loadNextPage()
        loadCalendarMatches()
        selectedDate = Date()
    }

    func loadNextPage() {
        guard !isLoadingMore, hasMore, let context = modelContext else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let previousSessionIds = Set(listSessions.map(\.id))

        while hasMore {
            var descriptor = FetchDescriptor<Match>(
                sortBy: [SortDescriptor(\Match.startedAt, order: .reverse)]
            )
            descriptor.fetchLimit = pageSize
            // 페이지 번호가 아니라 보유 개수로 offset 을 잡는다 — 삭제로 저장소와 배열이 함께 줄면
            // 다음 페이지 경계도 함께 당겨져 건너뛰는 기록이 없다.
            descriptor.fetchOffset = listMatches.count

            let fetched = (try? context.fetch(descriptor)) ?? []
            guard !fetched.isEmpty else {
                hasMore = false
                rebuildSessions()
                return
            }

            listMatches.append(contentsOf: fetched)
            hasMore = fetched.count == pageSize
            rebuildSessions()

            if Set(listSessions.map(\.id)) != previousSessionIds || !hasMore { return }
        }
    }

    /// CloudKit 동기화라 다른 기기로 전파되고 되돌릴 수 없다. 호출부가 확인 다이얼로그를 받는다.
    ///
    /// 서비스와 이 VM 이 서로 다른 ModelContext 를 들고 있다 — 같은 컨테이너라 저장소에는
    /// 반영되지만 배열은 자동으로 갱신되지 않으므로 직접 지운다.
    func delete(_ session: MatchSessionGroup) {
        let matches = matchesToDelete(for: session)
        let matchIds = Set(matches.map(\.id))

        for match in matches {
            try? MatchPersistenceService.shared.delete(match)
        }
        try? SessionPersistenceService.shared.delete(sessionId: session.id)

        listMatches.removeAll { matchIds.contains($0.id) }
        calendarMatches.removeAll { matchIds.contains($0.id) }
        calendarSourceMatches?.removeAll { matchIds.contains($0.id) }
        rebuildSessions()
    }

    /// 페이지에 아직 실리지 않은 같은 워크아웃의 경기도 함께 지운다. 구버전의 nil 세션 ID는
    /// 화면 그룹에 포함된 경기만 지운다.
    private func matchesToDelete(for session: MatchSessionGroup) -> [Match] {
        guard session.matches.contains(where: { $0.workoutSessionId != nil }) else {
            return session.matches
        }
        return (try? MatchPersistenceService.shared.fetchByWorkoutSession(session.id)) ?? session.matches
    }

    /// 누적 배열 전체를 다시 그룹핑한다. 페이지 경계에서 한 세션이 둘로 갈리는 문제가
    /// 여기서 자연히 사라진다 — 경계를 따로 병합할 필요가 없다.
    private func rebuildSessions() {
        let records = (try? SessionPersistenceService.shared.fetchAll()) ?? []
        let sourceMatches = try? modelContext?.fetch(FetchDescriptor<Match>())
        let groupingRecords = MatchSessionGroup.recordsForGrouping(
            records,
            displayedMatches: listMatches,
            sourceMatches: sourceMatches
        ) { _ in true }
        listSessions = MatchSessionGroup.group(listMatches, records: groupingRecords)
    }

    func changeMonth(by value: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) else { return }
        currentMonth = newMonth
        // 먼저 그 달을 읽고 나서 고른다. 순서를 뒤집으면 이전 달 데이터로 고르게 된다.
        loadCalendarMatches()
        selectedDate = calendarMatches.map(\.startedAt).max()
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
        calendarSourceMatches = try? context.fetch(FetchDescriptor<Match>())
    }
}
