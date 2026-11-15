import Foundation
@testable import Hanjan
import SwiftData
import Testing

@MainActor
struct RecordStoreTests {
    private let container: ModelContainer
    private let store: RecordStore
    private let record: SessionRecord

    init() throws {
        let schema = Schema(HanjanSchema.models)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        store = RecordStore(context: container.mainContext)
        record = SessionRecord(startedAt: Date(timeIntervalSince1970: 0), endedAt: Date(timeIntervalSince1970: 3600), limit: 8)
        container.mainContext.insert(record)
        for (offset, isToastOnly) in [false, false, true].enumerated() {
            let value = entry(TimeInterval(offset), toast: isToastOnly, sessionId: record.id)
            container.mainContext.insert(EntryRecord(
                id: value.id,
                kindId: value.kindId,
                kindName: value.kindName,
                alcoholGrams: value.alcoholGrams,
                loggedAt: value.loggedAt,
                source: value.source.rawValue,
                isToastOnly: value.isToastOnly,
                session: record
            ))
        }
        record.totalGrams = 2 * DrinkPresets.soju.alcoholGrams
        record.toastOnlyCount = 1
        try container.mainContext.save()
    }

    private func allEntries() throws -> [EntryRecord] {
        try container.mainContext.fetch(FetchDescriptor<EntryRecord>())
    }

    @Test func ledger_readsEntryRecords() {
        let ledger = RecordStore.ledger(of: record)
        #expect(ledger.drinkEntries.count == 2)
        #expect(ledger.activeEntries.count == 3)
        #expect(ledger.countsByKind().map(\.count) == [2])
    }

    @Test func setCount_increase_addsRecordsAndGrams() throws {
        try store.setCount(3, kind: DrinkPresets.beer, in: record, now: Date(timeIntervalSince1970: 100))
        #expect(try allEntries().count == 6)
        #expect(record.entries?.count == 6)
        let expected = 2 * DrinkPresets.soju.alcoholGrams + 3 * DrinkPresets.beer.alcoholGrams
        #expect(abs(record.totalGrams - expected) < 0.0001)
        #expect(record.toastOnlyCount == 1)
    }

    @Test func setCount_decrease_deletesRecords() throws {
        try store.setCount(0, kind: DrinkPresets.soju, in: record, now: Date(timeIntervalSince1970: 100))
        #expect(try allEntries().count == 1)
        #expect(record.totalGrams == 0)
        #expect(record.toastOnlyCount == 1)
    }

    @Test func setCount_decrease_recordsRemovalHistory() throws {
        let sojuIds = try allEntries().filter { !$0.isToastOnly }.map(\.id)
        let latest = RecordStore.ledger(of: record).drinkEntries.last
        try store.setCount(1, kind: DrinkPresets.soju, in: record, now: Date(timeIntervalSince1970: 100))
        #expect(record.removedEntryIds == Set([latest?.id].compactMap(\.self)))
        #expect(record.removedEntryIds.isSubset(of: Set(sojuIds)))
        // 늦게 다시 도착한 같은 잔은 복원된 장부에서 계속 걸러진다
        var ledger = record.ledger
        if let latest { ledger.add(latest) }
        #expect(ledger.drinkEntries.count == 1)
    }

    @Test func setCount_keepsEarlierRemovalHistory() throws {
        let earlier = UUID()
        record.removedEntryIds = [earlier]
        try store.setCount(0, kind: DrinkPresets.soju, in: record, now: Date(timeIntervalSince1970: 100))
        #expect(record.removedEntryIds.contains(earlier))
        #expect(record.removedEntryIds.count == 3)
    }

    @Test func saveReview_reusesCompanionByName() throws {
        container.mainContext.insert(CompanionRecord(name: "지민"))
        try store.saveReview(record, condition: 2, companions: [" 지민 ", "민수", "", "민수"], placeName: "  ", memo: "즐거웠다")
        let companions = try container.mainContext.fetch(FetchDescriptor<CompanionRecord>())
        #expect(companions.count == 2)
        #expect(Set(record.companions?.map(\.name) ?? []) == ["지민", "민수"])
        #expect(record.condition == 2)
        #expect(record.placeName == nil)
        #expect(record.memo == "즐거웠다")
    }

    @Test func saveReview_outOfRangeCondition_isNil() throws {
        try store.saveReview(record, condition: 9, companions: [], placeName: "성수동", memo: "")
        #expect(record.condition == nil)
        #expect(record.placeName == "성수동")
        #expect(record.memo == nil)
    }

    @Test func delete_removesSessionAndEntries() throws {
        try store.delete(record)
        #expect(try container.mainContext.fetch(FetchDescriptor<SessionRecord>()).isEmpty)
        #expect(try allEntries().isEmpty)
    }

    @Test func delete_preventsLateSessionAndAliasFromReturning() throws {
        let defaults = try #require(UserDefaults(suiteName: "RecordDeletion.\(UUID())"))
        let archive = SessionArchive(context: container.mainContext, defaults: defaults)
        let alias = UUID()
        record.mergedSessionIds = [alias]
        let original = record.id
        try container.mainContext.save()
        try RecordStore(context: container.mainContext, archive: archive).delete(record)
        for id in [original, alias] {
            let late = LiveSession(id: id, startedAt: Date(), endedAt: Date(), limit: 8, currentKindId: DrinkPresets.soju.id)
            try archive.save(late)
        }
        #expect(try container.mainContext.fetch(FetchDescriptor<SessionRecord>()).isEmpty)
    }

    @Test func editableKinds_catalogFirstThenUnknownKindsWithSameGrams() {
        let removedKind = UUID()
        let extra = EntryRecord(kindId: removedKind, kindName: "하이볼", alcoholGrams: 11, session: record)
        container.mainContext.insert(extra)
        let kinds = RecordStore.editableKinds(of: record, catalog: [DrinkPresets.soju, DrinkPresets.beer])
        #expect(kinds.map(\.name) == ["소주", "맥주", "하이볼"])
        #expect(abs((kinds.last?.alcoholGrams ?? 0) - 11) < 0.0001)
    }
}
