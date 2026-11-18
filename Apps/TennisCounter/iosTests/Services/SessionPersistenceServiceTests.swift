import Foundation
import SwiftData
@testable import TennisCounter
import Testing

@MainActor
struct SessionPersistenceServiceTests {
    private func makeService() throws -> SessionPersistenceService {
        try TestPersistence.make().sessions
    }

    @Test func fetchLatestEndedOrdersByEndDateThenStartDate() throws {
        let service = try makeService()
        let early = WorkoutSessionRecord()
        early.startedAt = Date(timeIntervalSince1970: 10)
        early.endedAt = Date(timeIntervalSince1970: 100)
        let first = WorkoutSessionRecord()
        first.startedAt = Date(timeIntervalSince1970: 20)
        first.endedAt = Date(timeIntervalSince1970: 200)
        let latest = WorkoutSessionRecord()
        latest.startedAt = Date(timeIntervalSince1970: 30)
        latest.endedAt = Date(timeIntervalSince1970: 200)
        try service.upsert(early)
        try service.upsert(first)
        try service.upsert(latest)
        #expect(try service.fetchLatestEnded()?.startedAt == latest.startedAt)
        #expect(try service.fetchLatestEnded()?.activeCalories == nil)
    }

    @Test func fetchLatestEndedIgnoresMissingEndDate() throws {
        let service = try makeService()
        let ended = WorkoutSessionRecord()
        ended.endedAt = Date(timeIntervalSince1970: 100)
        let ongoing = WorkoutSessionRecord()
        ongoing.startedAt = Date(timeIntervalSince1970: 200)
        try service.upsert(ended)
        try service.upsert(ongoing)
        #expect(try service.fetchLatestEnded()?.endedAt == ended.endedAt)
    }

    @Test func fetchLatestEndedReturnsNilForEmptyStore() throws {
        let service = try makeService()
        #expect(try service.fetchLatestEnded() == nil)
    }

    @Test func upsertThenFetch() throws {
        let service = try makeService()
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
        let service = try makeService()
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
        let service = try makeService()
        let id = UUID()
        let record = WorkoutSessionRecord()
        record.workoutSessionId = id
        try service.upsert(record)

        try service.delete(sessionId: id)
        #expect(try service.fetchAll().isEmpty)
    }
}
