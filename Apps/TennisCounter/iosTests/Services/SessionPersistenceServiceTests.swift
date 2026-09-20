import Foundation
import SwiftData
@testable import TennisCounter
import Testing

@MainActor
struct SessionPersistenceServiceTests {
    private func makeService() -> SessionPersistenceService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: WorkoutSessionRecord.self, configurations: config)
        let service = SessionPersistenceService()
        service.configure(with: ModelContext(container))
        return service
    }

    @Test func upsertThenFetch() throws {
        let service = makeService()
        let id = UUID()
        let record = WorkoutSessionRecord()
        record.workoutSessionId = id
        record.elapsedSeconds = 1523
        record.averageHeartRate = 142
        try service.upsert(record)

        let all = try service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.elapsedSeconds == 1523)
        #expect(all.first?.averageHeartRate == 142)
    }

    @Test func upsertSameSessionIdReplaces() throws {
        let service = makeService()
        let id = UUID()

        let first = WorkoutSessionRecord()
        first.workoutSessionId = id
        first.elapsedSeconds = 100
        try service.upsert(first)

        let second = WorkoutSessionRecord()
        second.workoutSessionId = id
        second.elapsedSeconds = 200
        try service.upsert(second)

        let all = try service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.elapsedSeconds == 200)
    }

    @Test func deleteBySessionId() throws {
        let service = makeService()
        let id = UUID()
        let record = WorkoutSessionRecord()
        record.workoutSessionId = id
        try service.upsert(record)

        try service.delete(sessionId: id)
        #expect(try service.fetchAll().isEmpty)
    }
}
