import Foundation
import SwiftData
@testable import TennisCounter
import Testing
import WorkoutCore

@Suite(.serialized)
@MainActor
struct HistorySelectionTests {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Match.self, SetRecord.self, WorkoutSessionRecord.self,
            configurations: configuration
        )
        SessionPersistenceService.shared.configure(with: ModelContext(container))
        return ModelContext(container)
    }

    private func insertMatch(sessionId: UUID?, start: Date, in context: ModelContext) -> Match {
        let match = Match()
        match.workoutSessionId = sessionId
        match.startedAt = start
        context.insert(match)
        return match
    }

    @Test func detailResolvesCrossMidnightSessionBeforeSharing() throws {
        let context = try makeContext()
        let sessionId = UUID()
        let calendar = Calendar.current
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 23)))
        let first = insertMatch(sessionId: sessionId, start: start, in: context)
        first.endedAt = start.addingTimeInterval(1800)
        first.workoutElapsedSeconds = 1800
        first.workoutCaloriesBurned = 100
        let second = insertMatch(sessionId: sessionId, start: start.addingTimeInterval(3600), in: context)
        second.endedAt = start.addingTimeInterval(5400)
        second.workoutElapsedSeconds = 5400
        second.workoutCaloriesBurned = 300
        try context.save()
        let daySlice = MatchSessionGroup(id: sessionId, matches: [first], record: nil)
        let viewModel = HistoryViewModel()
        viewModel.configure(modelContext: context)

        let detail = try #require(viewModel.sessionForDetail(daySlice))
        let share = try #require(SessionShareData(session: detail))

        #expect(detail.matches.map(\.id) == [first.id, second.id])
        #expect(share.result.durationSeconds == 5400)
        #expect(share.result.caloriesBurned == 300)
        #expect(share.startedAt == start)
        #expect(share.endedAt == start.addingTimeInterval(5400))
    }

    @Test func detailResolvesUnloadedMatchesWithoutChangingListPages() throws {
        let context = try makeContext()
        let sessionId = UUID()
        let base = Date(timeIntervalSince1970: 100_000)
        var expected: [UUID] = []
        for index in 0 ..< 25 {
            let match = insertMatch(sessionId: sessionId, start: base.addingTimeInterval(Double(index * 60)), in: context)
            match.workoutElapsedSeconds = (index + 1) * 60
            match.workoutCaloriesBurned = index == 0 ? 500 : 100
            expected.append(match.id)
        }
        _ = insertMatch(sessionId: UUID(), start: base.addingTimeInterval(-3600), in: context)
        try context.save()
        let viewModel = HistoryViewModel()
        viewModel.configure(modelContext: context)
        viewModel.loadInitial()
        let partial = try #require(viewModel.listSessions.first)
        #expect(partial.matches.count == 20)

        let detail = try #require(viewModel.sessionForDetail(partial))
        let share = try #require(SessionShareData(session: detail))

        #expect(detail.matches.map(\.id) == expected)
        #expect(share.result.durationSeconds == 1500)
        #expect(share.result.caloriesBurned == 500)
        #expect(viewModel.listMatches.count == 20)
        #expect(viewModel.hasMore)
    }

    @Test func detailKeepsRecordOnlySessionIdentityAndMetrics() throws {
        let context = try makeContext()
        let record = WorkoutSessionRecord()
        let sessionId = UUID()
        record.workoutSessionId = sessionId
        record.elapsedSeconds = 2400
        record.activeCalories = 300
        context.insert(record)
        _ = insertMatch(sessionId: nil, start: Date(), in: context)
        try context.save()
        let selected = MatchSessionGroup(id: sessionId, matches: [], record: record)
        let viewModel = HistoryViewModel()
        viewModel.configure(modelContext: context)

        let detail = try #require(viewModel.sessionForDetail(selected))

        #expect(detail.id == sessionId)
        #expect(detail.matches.isEmpty)
        #expect(detail.record === record)
        #expect(SessionShareData(session: detail)?.result.durationSeconds == 2400)
    }

    @Test func detailKeepsLegacyNilSessionAsOneMatch() throws {
        let context = try makeContext()
        let selectedMatch = insertMatch(sessionId: nil, start: Date(), in: context)
        _ = insertMatch(sessionId: nil, start: Date().addingTimeInterval(60), in: context)
        _ = insertMatch(sessionId: UUID(), start: Date().addingTimeInterval(120), in: context)
        try context.save()
        let selected = MatchSessionGroup(id: selectedMatch.id, matches: [selectedMatch], record: nil)
        let viewModel = HistoryViewModel()
        viewModel.configure(modelContext: context)

        let detail = try #require(viewModel.sessionForDetail(selected))

        #expect(detail.id == selectedMatch.id)
        #expect(detail.matches.map(\.id) == [selectedMatch.id])
        #expect(detail.record == nil)
    }

    @Test func repeatedAppearancePreservesBrowsingStateAndLoadedPages() throws {
        let context = try makeContext()
        let base = Date()
        for index in 0 ..< 45 {
            _ = insertMatch(sessionId: UUID(), start: base.addingTimeInterval(Double(-index * 60)), in: context)
        }
        try context.save()
        let viewModel = HistoryViewModel()
        viewModel.configure(modelContext: context)
        viewModel.activate(1)
        #expect(viewModel.listMatches.count == 20)
        viewModel.loadNextPage()
        viewModel.toggleViewMode()
        viewModel.changeMonth(by: -1)
        let selectedDay = try #require(Calendar.current.date(byAdding: .day, value: 3, to: viewModel.currentMonth.startOfMonth))
        viewModel.selectedDate = selectedDay
        let month = viewModel.currentMonth
        let loadedIds = viewModel.listMatches.map(\.id)
        #expect(loadedIds.count == 40)

        viewModel.activate(1)

        #expect(viewModel.viewMode == .calendar)
        #expect(viewModel.currentMonth == month)
        #expect(viewModel.selectedDate == selectedDay)
        #expect(viewModel.listMatches.map(\.id) == loadedIds)
        #expect(viewModel.hasMore)
    }

    @Test func appearanceBeforeConfigurationDoesNotConsumeInitialization() throws {
        let viewModel = HistoryViewModel()
        viewModel.activate(1)
        let context = try makeContext()
        let match = insertMatch(sessionId: UUID(), start: Date(), in: context)
        try context.save()
        viewModel.configure(modelContext: context)

        viewModel.activate(0) // 아직 기록 탭을 선택하지 않은 초기 마운트.
        #expect(viewModel.listMatches.isEmpty)

        viewModel.activate(1)

        #expect(viewModel.listMatches.map(\.id) == [match.id])
        #expect(viewModel.selectedDate != nil)
    }

    @Test func tabReactivationLoadsWorkoutSavedAfterEmptyInitialVisit() throws {
        let context = try makeContext()
        let viewModel = HistoryViewModel()
        viewModel.configure(modelContext: context)
        viewModel.activate(1)
        #expect(viewModel.listSessions.isEmpty)
        #expect(!viewModel.hasMore)
        let sessionId = UUID()
        let match = insertMatch(sessionId: sessionId, start: Date(), in: context)
        let record = WorkoutSessionRecord()
        record.workoutSessionId = sessionId
        record.startedAt = match.startedAt
        record.elapsedSeconds = 2400
        record.activeCalories = 300
        context.insert(record)
        try context.save()

        viewModel.activate(2)

        let session = try #require(viewModel.listSessions.first)
        #expect(viewModel.listSessions.count == 1)
        #expect(session.id == sessionId)
        #expect(session.matches.map(\.id) == [match.id])
        #expect(session.elapsedSeconds == 2400)
        #expect(viewModel.calendarMatches.map(\.id) == [match.id])
    }

    @Test func tabReactivationRefreshesPagesAndCalendarWithoutResettingSelection() throws {
        let context = try makeContext()
        let base = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        for index in 0 ..< 45 {
            _ = insertMatch(sessionId: UUID(), start: base.addingTimeInterval(Double(-index * 60)), in: context)
        }
        try context.save()
        let viewModel = HistoryViewModel()
        viewModel.configure(modelContext: context)
        viewModel.activate(1)
        viewModel.loadNextPage()
        #expect(viewModel.listMatches.count == 40)
        viewModel.toggleViewMode()
        viewModel.changeMonth(by: -1)
        let selectedDay = try #require(Calendar.current.date(byAdding: .day, value: 3, to: viewModel.currentMonth.startOfMonth))
        viewModel.selectedDate = selectedDay
        let month = viewModel.currentMonth
        let newest = insertMatch(sessionId: UUID(), start: base.addingTimeInterval(60), in: context)
        let calendarMatch = insertMatch(sessionId: UUID(), start: selectedDay, in: context)
        try context.save()

        // onChange와 onAppear가 같은 활성화 신호를 전달해도 한 번만 읽는다.
        viewModel.activate(1)
        #expect(viewModel.listMatches.count == 40)
        #expect(!viewModel.listMatches.contains { $0.id == newest.id })

        viewModel.activate(2)

        #expect(viewModel.listMatches.count == 20)
        #expect(viewModel.listMatches.first?.id == newest.id)
        #expect(Set(viewModel.listMatches.map(\.id)).count == 20)
        #expect(viewModel.hasMore)
        #expect(viewModel.calendarMatches.map(\.id) == [calendarMatch.id])
        #expect(viewModel.calendarSourceMatches?.count == 47)
        #expect(viewModel.viewMode == .calendar)
        #expect(viewModel.currentMonth == month)
        #expect(viewModel.selectedDate == selectedDay)

        viewModel.loadNextPage()
        viewModel.activate(2)
        #expect(viewModel.listMatches.count == 40)
        #expect(Set(viewModel.listMatches.map(\.id)).count == 40)
    }
}
