@testable import TennisCounter
import Foundation
import Testing
import SwiftData

@MainActor
struct HistoryViewModelTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        return ModelContext(container)
    }

    private func insertMatches(count: Int, in context: ModelContext) throws {
        for i in 0..<count {
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
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: now)!

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
}
