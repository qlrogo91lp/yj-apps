import Foundation
@testable import Hanjan
import SwiftData
import Testing

@MainActor struct SessionArchiveTests {
    @Test func upsertsAndMergesLateEntriesAndRemovals() throws {
        let container = try ModelContainer(for: Schema(HanjanSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let archive = SessionArchive(context: container.mainContext)
        var value = session()
        let first = entry(1, sessionId: value.id)
        value.ledger.add(first)
        value.endedAt = Date(timeIntervalSince1970: 2)
        try archive.save(value)
        try archive.save(value)
        let second = entry(3, sessionId: value.id)
        value.ledger.add(second)
        try archive.save(value)
        let records = try container.mainContext.fetch(FetchDescriptor<SessionRecord>())
        #expect(records.count == 1)
        #expect(records[0].entries?.count == 2)
        #expect(records[0].totalGrams == first.alcoholGrams + second.alcoholGrams)
        value.ledger.remove(id: first.id)
        try archive.save(value)
        #expect(records[0].entries?.count == 1)
        #expect(records[0].removedEntryIds.contains(first.id))
        var stale = session()
        stale = LiveSession(id: value.id, startedAt: value.startedAt, limit: value.limit, currentKindId: value.currentKindId)
        stale.ledger.add(first)
        try archive.save(stale)
        #expect(records[0].entries?.count == 1)
    }

    @Test func absorbingPreviouslySavedSessionKeepsOneRecord() throws {
        let container = try ModelContainer(for: Schema(HanjanSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let archive = SessionArchive(context: container.mainContext)
        var later = session(10)
        later.ledger.add(entry(11, sessionId: later.id))
        try archive.save(later)
        let earlier = session(0)
        try archive.save(earlier.absorbing(later))
        let records = try container.mainContext.fetch(FetchDescriptor<SessionRecord>())
        #expect(records.count == 1)
        #expect(records.first?.id == earlier.id)
        #expect(records.first?.owns(sessionId: later.id) == true)
    }

    @Test func preservesRecordEditsWhenStaleSessionArrives() throws {
        let container = try ModelContainer(for: Schema(HanjanSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let archive = SessionArchive(context: container.mainContext)
        var value = session()
        value.endedAt = Date(timeIntervalSince1970: 100)
        value.ledger.add(entry(1, sessionId: value.id))
        try archive.save(value)
        let record = try #require(try archive.record(owning: value.id))
        let records = RecordStore(context: container.mainContext)
        try records.setCount(2, kind: DrinkPresets.beer, in: record, now: Date(timeIntervalSince1970: 3))
        try records.setCount(0, kind: DrinkPresets.soju, in: record, now: Date(timeIntervalSince1970: 4))
        try archive.save(value)
        #expect(record.ledger.drinkEntries.count == 2)
        #expect(record.ledger.countsByKind().first?.kindId == DrinkPresets.beer.id)
        #expect(record.totalGrams == 2 * DrinkPresets.beer.alcoholGrams)
    }

    @Test func deletedSessionAndAbsorbedIdCannotRecreateRecord() throws {
        let name = "archive-deleted-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let container = try ModelContainer(for: Schema(HanjanSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let archive = SessionArchive(context: container.mainContext, defaults: defaults)
        let earlier = session(0)
        let later = session(10)
        let merged = earlier.absorbing(later)
        try archive.save(merged)
        archive.markDeleted(sessionId: earlier.id)
        let record = try #require(try archive.record(owning: earlier.id))
        try RecordStore(context: container.mainContext).delete(record)
        let restored = SessionArchive(context: container.mainContext, defaults: defaults)
        try restored.save(earlier)
        try restored.save(later)
        #expect(try container.mainContext.fetch(FetchDescriptor<SessionRecord>()).isEmpty)
    }

}
