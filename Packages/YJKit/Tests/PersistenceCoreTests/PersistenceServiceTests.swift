import Foundation
import SwiftData
import Testing
@testable import PersistenceCore

@Model
final class StubRecord {
    var key: UUID = UUID()
    var value: Int = 0
    var createdAt: Date = Date()

    init(key: UUID = UUID(), value: Int = 0, createdAt: Date = Date()) {
        self.key = key
        self.value = value
        self.createdAt = createdAt
    }
}

@MainActor
struct PersistenceServiceTests {
    private func makeService() throws -> PersistenceService<StubRecord> {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StubRecord.self, configurations: config)
        return PersistenceService(context: ModelContext(container))
    }

    @Test func fetchAllReturnsEmptyWhenNoRecords() throws {
        let service = try makeService()
        #expect(try service.fetchAll().isEmpty)
    }

    @Test func upsertInsertsRecord() throws {
        let service = try makeService()
        try service.upsert(StubRecord(value: 7))
        let all = try service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.value == 7)
    }

    @Test func fetchAllAppliesSortDescriptors() throws {
        let service = try makeService()
        try service.upsert(StubRecord(value: 1))
        try service.upsert(StubRecord(value: 3))
        try service.upsert(StubRecord(value: 2))
        let sorted = try service.fetchAll(sortBy: [SortDescriptor(\.value, order: .reverse)])
        #expect(sorted.map(\.value) == [3, 2, 1])
    }

    @Test func fetchMatchingFiltersByPredicate() throws {
        let service = try makeService()
        let target = UUID()
        try service.upsert(StubRecord(key: target, value: 1))
        try service.upsert(StubRecord(value: 2))
        let matched = try service.fetch(matching: #Predicate { $0.key == target })
        #expect(matched.count == 1)
        #expect(matched.first?.value == 1)
    }

    @Test func upsertReplacingRemovesMatchesBeforeInsert() throws {
        let service = try makeService()
        let key = UUID()
        try service.upsert(StubRecord(key: key, value: 1),
                           replacing: #Predicate { $0.key == key })
        try service.upsert(StubRecord(key: key, value: 2),
                           replacing: #Predicate { $0.key == key })
        let matched = try service.fetch(matching: #Predicate { $0.key == key })
        #expect(matched.count == 1)
        #expect(matched.first?.value == 2) // 최신으로 갱신
    }

    @Test func upsertReplacingLeavesOtherRecordsUntouched() throws {
        let service = try makeService()
        let key = UUID()
        try service.upsert(StubRecord(value: 99)) // 무관한 레코드
        try service.upsert(StubRecord(key: key, value: 1),
                           replacing: #Predicate { $0.key == key })
        try service.upsert(StubRecord(key: key, value: 2),
                           replacing: #Predicate { $0.key == key })
        #expect(try service.fetchAll().count == 2)
    }

    @Test func deleteRemovesRecord() throws {
        let service = try makeService()
        let record = StubRecord(value: 5)
        try service.upsert(record)
        try service.delete(record)
        #expect(try service.fetchAll().isEmpty)
    }
}
