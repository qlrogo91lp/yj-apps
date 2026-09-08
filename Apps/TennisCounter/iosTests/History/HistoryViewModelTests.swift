import Foundation
import SwiftData
@testable import TennisCounter
import Testing

/// 삭제 테스트가 싱글턴 MatchPersistenceService 의 컨텍스트를 갈아끼우므로 직렬 실행이 필요하다.
@Suite(.serialized)
@MainActor
struct HistoryViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
    }

    private func makeContext() throws -> ModelContext {
        try ModelContext(makeContainer())
    }

    /// 프로덕션과 같은 모양 — iOSApp 이 서비스에 별도 ModelContext 를 주고 VM 은
    /// @Environment(\.modelContext) 를 받는다. 같은 컨테이너, 다른 컨텍스트.
    private func makeSharedContainerContext() throws -> ModelContext {
        let container = try makeContainer()
        MatchPersistenceService.shared.configure(with: ModelContext(container))
        return ModelContext(container)
    }

    private func insertMatch(
        session: UUID?,
        startedAt: Date,
        in context: ModelContext
    ) -> Match {
        let match = Match()
        match.workoutSessionId = session
        match.startedAt = startedAt
        context.insert(match)
        return match
    }

    private func insertMatches(count: Int, in context: ModelContext) throws {
        for i in 0 ..< count {
            let match = Match()
            match.startedAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            context.insert(match)
        }
        try context.save()
    }

    @Test func loadInitial_setsFirstPage() throws {
        let context = try makeContext()
        try insertMatches(count: 25, in: context)

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        #expect(vm.listMatches.count == 20)
        #expect(vm.hasMore == true)
    }

    @Test func loadNextPage_appendsMatches() throws {
        let context = try makeContext()
        try insertMatches(count: 25, in: context)

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()
        vm.loadNextPage()

        #expect(vm.listMatches.count == 25)
        #expect(vm.hasMore == false)
    }

    @Test func loadNextPage_setsHasMoreFalse_whenFewerThanPageSize() throws {
        let context = try makeContext()
        try insertMatches(count: 10, in: context)

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        #expect(vm.listMatches.count == 10)
        #expect(vm.hasMore == false)
    }

    @Test func loadNextPage_doesNothing_whenIsLoadingMore() throws {
        let context = try makeContext()
        try insertMatches(count: 25, in: context)

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        vm.isLoadingMore = true
        vm.loadNextPage()

        #expect(vm.listMatches.count == 20)
    }

    @Test func changeMonth_updatesCalendarMatches() throws {
        let context = try makeContext()
        let now = Date()
        let nextMonth = try #require(Calendar.current.date(byAdding: .month, value: 1, to: now))

        let currentMonthMatch = Match()
        currentMonthMatch.startedAt = now
        context.insert(currentMonthMatch)

        let nextMonthMatch = Match()
        nextMonthMatch.startedAt = nextMonth
        context.insert(nextMonthMatch)

        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        #expect(vm.calendarMatches.count == 1)
        #expect(Calendar.current.isDate(vm.calendarMatches[0].startedAt, equalTo: now, toGranularity: .month))

        vm.changeMonth(by: 1)

        #expect(vm.calendarMatches.count == 1)
        #expect(Calendar.current.isDate(vm.calendarMatches[0].startedAt, equalTo: nextMonth, toGranularity: .month))
    }

    // MARK: - 세션 그룹

    @Test func matchesGroupIntoSessions() throws {
        let context = try makeContext()
        let session = UUID()
        let base = Date()
        _ = insertMatch(session: session, startedAt: base, in: context)
        _ = insertMatch(session: session, startedAt: base.addingTimeInterval(600), in: context)
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        #expect(vm.listSessions.count == 1)
        #expect(vm.listSessions.first?.matches.count == 2)
    }

    @Test func nilSessionIdBecomesOwnSession() throws {
        let context = try makeContext()
        let base = Date()
        _ = insertMatch(session: nil, startedAt: base, in: context)
        _ = insertMatch(session: nil, startedAt: base.addingTimeInterval(600), in: context)
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        #expect(vm.listSessions.count == 2)
    }

    @Test func sessionsSortedByLatestMatch() throws {
        let context = try makeContext()
        let older = UUID()
        let newer = UUID()
        let base = Date()
        _ = insertMatch(session: older, startedAt: base, in: context)
        _ = insertMatch(session: newer, startedAt: base.addingTimeInterval(7200), in: context)
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        #expect(vm.listSessions.map(\.id) == [newer, older])
    }

    /// 페이지 경계에 걸친 세션이 둘로 갈리면 안 된다. 누적 배열 전체를 다시 그룹핑하므로
    /// 경계를 따로 병합할 필요가 없다.
    @Test func pageBoundaryMergesSameSession() throws {
        let context = try makeContext()
        let boundary = UUID()
        let base = Date()
        // 최신순 18~21번째가 한 세션 — 20개 경계를 가로지른다
        for index in 0 ..< 25 {
            let session = (18 ... 21).contains(index) ? boundary : UUID()
            _ = insertMatch(session: session, startedAt: base.addingTimeInterval(TimeInterval(-index * 3600)), in: context)
        }
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()
        vm.loadNextPage()

        let merged = vm.listSessions.filter { $0.id == boundary }
        #expect(merged.count == 1)
        #expect(merged.first?.matches.count == 4)
    }

    // MARK: - 삭제

    /// 페이지 번호로 offset 을 잡으면 삭제 후 다음 페이지가 한 칸 밀려 경계의 경기가
    /// 영영 안 나온다. 보유 개수를 offset 으로 쓰면 어긋나지 않는다.
    @Test func deleteDoesNotSkipNextPage() throws {
        let context = try makeSharedContainerContext()
        let base = Date()
        for index in 0 ..< 25 {
            _ = insertMatch(session: UUID(), startedAt: base.addingTimeInterval(TimeInterval(-index * 3600)), in: context)
        }
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()
        let removed = try #require(vm.listMatches.first)
        let removedId = removed.id
        vm.delete(removed)
        vm.loadNextPage()

        // 25개에서 하나 지웠으니 24개가 모두 나와야 하고 중복도 없어야 한다
        #expect(vm.listMatches.count == 24)
        #expect(Set(vm.listMatches.map(\.id)).count == 24)
        #expect(!vm.listMatches.contains { $0.id == removedId })
    }

    @Test func deleteRemovesMatchFromSession() throws {
        let context = try makeSharedContainerContext()
        let session = UUID()
        let base = Date()
        let first = insertMatch(session: session, startedAt: base, in: context)
        _ = insertMatch(session: session, startedAt: base.addingTimeInterval(600), in: context)
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()
        vm.delete(first)

        #expect(vm.listSessions.count == 1)
        #expect(vm.listSessions.first?.matches.count == 1)
    }

    @Test func deletingLastMatchRemovesSession() throws {
        let context = try makeSharedContainerContext()
        let only = insertMatch(session: UUID(), startedAt: Date(), in: context)
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()
        vm.delete(only)

        #expect(vm.listSessions.isEmpty)
        #expect(vm.listMatches.isEmpty)
    }

    // MARK: - 날짜 선택

    /// 달을 넘기면 그 달에서 경기가 있는 가장 최근 날짜를 고른다. loadCalendarMatches 를
    /// 먼저 부르지 않으면 이전 달 데이터로 고르게 된다.
    @Test func selectsMostRecentMatchDayOnMonthChange() throws {
        let context = try makeContext()
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = try #require(calendar.date(byAdding: .month, value: -1, to: now))
        let lastMonthEarlier = try #require(calendar.date(byAdding: .day, value: -3, to: lastMonth))

        _ = insertMatch(session: UUID(), startedAt: now, in: context)
        _ = insertMatch(session: UUID(), startedAt: lastMonth, in: context)
        _ = insertMatch(session: UUID(), startedAt: lastMonthEarlier, in: context)
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()
        vm.changeMonth(by: -1)

        let selected = try #require(vm.selectedDate)
        #expect(calendar.isDate(selected, inSameDayAs: lastMonth))
    }

    @Test func selectsNothingWhenMonthHasNoMatches() throws {
        let context = try makeContext()
        _ = insertMatch(session: UUID(), startedAt: Date(), in: context)
        try context.save()

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()
        vm.changeMonth(by: -1)

        #expect(vm.selectedDate == nil)
    }

    @Test func loadInitialSelectsToday() throws {
        let context = try makeContext()
        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        let selected = try #require(vm.selectedDate)
        #expect(Calendar.current.isDateInToday(selected))
    }
}
