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

}
