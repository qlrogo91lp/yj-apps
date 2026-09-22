import Foundation
import SwiftData
@testable import TennisCounter
import Testing
import WorkoutCore

private actor WorkoutDeleterSpy: WorkoutDeleting {
    private let outcome: WorkoutDeletionOutcome
    private var calls: [[UUID]] = []

    init(outcome: WorkoutDeletionOutcome) {
        self.outcome = outcome
    }

    func deleteWorkouts(uuids: [UUID]) async -> WorkoutDeletionOutcome {
        calls.append(uuids)
        return outcome
    }

    func receivedUUIDs() -> [[UUID]] {
        calls
    }
}

private enum HealthKitDeletionTestStorage {
    @MainActor static var retainedContainers: [ModelContainer] = []
}

extension HistoryViewModelTests {
    private struct Fixture {
        let container: ModelContainer
        let viewModel: HistoryViewModel
        let session: MatchSessionGroup
    }

    private func makeFixture(
        healthKitUUID: UUID?,
        matchCount: Int = 1,
        workoutDeleter: any WorkoutDeleting
    ) throws -> Fixture {
        let configuration = ModelConfiguration(
            UUID().uuidString,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: Match.self,
            SetRecord.self,
            WorkoutSessionRecord.self,
            configurations: configuration
        )
        HealthKitDeletionTestStorage.retainedContainers.append(container)
        MatchPersistenceService.shared.configure(with: ModelContext(container))
        SessionPersistenceService.shared.configure(with: ModelContext(container))

        let context = ModelContext(container)
        let sessionID = UUID()
        for index in 0 ..< matchCount {
            let match = Match()
            match.workoutSessionId = sessionID
            match.startedAt = Date().addingTimeInterval(Double(index * 60))
            context.insert(match)
        }
        try context.save()

        let record = WorkoutSessionRecord()
        record.workoutSessionId = sessionID
        record.healthKitUUID = healthKitUUID
        try SessionPersistenceService.shared.upsert(record)

        let viewModel = HistoryViewModel(workoutDeleter: workoutDeleter)
        viewModel.configure(modelContext: context)
        viewModel.loadInitial()
        let session = try #require(viewModel.listSessions.first { $0.id == sessionID })
        return Fixture(container: container, viewModel: viewModel, session: session)
    }

    @Test func deleteWithHealthKitUUIDPassesUUIDToDeleter() async throws {
        let uuid = UUID()
        let spy = WorkoutDeleterSpy(outcome: .deleted)
        let fixture = try makeFixture(healthKitUUID: uuid, workoutDeleter: spy)

        let task = try #require(fixture.viewModel.delete(fixture.session))
        await task.value

        #expect(await spy.receivedUUIDs() == [[uuid]])
    }

    @Test func deleteWithoutHealthKitUUIDDoesNotCallDeleter() async throws {
        let spy = WorkoutDeleterSpy(outcome: .failed)
        let fixture = try makeFixture(healthKitUUID: nil, workoutDeleter: spy)

        let task = fixture.viewModel.delete(fixture.session)

        #expect(task == nil)
        #expect(await spy.receivedUUIDs().isEmpty)
        #expect(fixture.viewModel.deletionFailure == nil)
    }

    @Test func deleteMultiMatchSessionPassesOneUUID() async throws {
        let uuid = UUID()
        let spy = WorkoutDeleterSpy(outcome: .deleted)
        let fixture = try makeFixture(healthKitUUID: uuid, matchCount: 3, workoutDeleter: spy)

        let task = try #require(fixture.viewModel.delete(fixture.session))
        await task.value

        #expect(await spy.receivedUUIDs() == [[uuid]])
    }

    @Test func deleteWhenHealthKitDeletionFailsStillDeletesSwiftData() async throws {
        let spy = WorkoutDeleterSpy(outcome: .failed)
        let fixture = try makeFixture(healthKitUUID: UUID(), workoutDeleter: spy)

        let task = try #require(fixture.viewModel.delete(fixture.session))
        await task.value

        let reloadedContext = ModelContext(fixture.container)
        #expect(try reloadedContext.fetch(FetchDescriptor<Match>()).isEmpty)
        #expect(try SessionPersistenceService.shared.fetchAll().isEmpty)
    }

    @Test(arguments: [WorkoutDeletionOutcome.failed, .notAuthorized])
    func deleteWithFailureOutcomePublishesFailure(outcome: WorkoutDeletionOutcome) async throws {
        let spy = WorkoutDeleterSpy(outcome: outcome)
        let fixture = try makeFixture(healthKitUUID: UUID(), workoutDeleter: spy)

        let task = try #require(fixture.viewModel.delete(fixture.session))
        await task.value

        #expect(fixture.viewModel.deletionFailure == outcome)
    }

    @Test(arguments: [WorkoutDeletionOutcome.deleted, .nothingToDelete])
    func deleteWithSuccessfulOutcomeLeavesFailureNil(outcome: WorkoutDeletionOutcome) async throws {
        let spy = WorkoutDeleterSpy(outcome: outcome)
        let fixture = try makeFixture(healthKitUUID: UUID(), workoutDeleter: spy)

        let task = try #require(fixture.viewModel.delete(fixture.session))
        await task.value

        #expect(fixture.viewModel.deletionFailure == nil)
    }
}
