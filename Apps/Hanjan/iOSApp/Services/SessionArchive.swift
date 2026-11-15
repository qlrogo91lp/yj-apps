import Foundation
import SwiftData

@MainActor final class SessionArchive {
    private let context: ModelContext
    private let defaults: UserDefaults
    private let deletedKey = "deletedSessionIds"
    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
    }

    private var deletedIds: Set<UUID> {
        Set((defaults.stringArray(forKey: deletedKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    /// 저장된 별칭까지 수집할 수 있도록 기록을 삭제하기 전에 호출한다.
    func markDeleted(sessionId: UUID) {
        var ids = deletedIds
        ids.insert(sessionId)
        if let record = try? record(owning: sessionId) {
            ids.insert(record.id)
            ids.formUnion(record.mergedSessionIds)
        }
        defaults.set(ids.map(\.uuidString).sorted(), forKey: deletedKey)
    }

    func record(owning id: UUID) throws -> SessionRecord? {
        try context.fetch(FetchDescriptor<SessionRecord>()).first { $0.owns(sessionId: id) }
    }

    func save(_ session: LiveSession) throws {
        let ids = session.mergedSessionIds.union([session.id])
        guard deletedIds.isDisjoint(with: ids) else { return }
        let matches = try context.fetch(FetchDescriptor<SessionRecord>()).filter { record in
            ids.contains(where: { record.owns(sessionId: $0) }) || session.owns(sessionId: record.id)
        }
        guard matches.allSatisfy({ deletedIds.isDisjoint(with: $0.mergedSessionIds.union([$0.id])) }) else { return }
        let record = matches.first(where: { $0.id == session.id }) ?? matches.first ?? SessionRecord(id: session.id, startedAt: session.startedAt)
        if record.modelContext == nil { context.insert(record) }
        var merged = session
        if record.id != session.id, record.owns(sessionId: session.id) {
            merged = LiveSession(id: record.id, startedAt: record.startedAt, endedAt: record.endedAt, limit: record.limit,
                                 currentKindId: session.currentKindId, toast: session.toast, latitude: session.latitude,
                                 longitude: session.longitude, ledger: session.ledger,
                                 mergedSessionIds: record.mergedSessionIds.union(session.mergedSessionIds))
        }
        var ledger = record.ledger
        ledger.merge(session.ledger)
        for old in matches {
            if old !== record { ledger.merge(old.ledger) }
            merged.mergedSessionIds.formUnion(old.mergedSessionIds)
            if old.id != merged.id { merged.mergedSessionIds.insert(old.id) }
            merged.endedAt = old.endedAt ?? merged.endedAt
            merged.latitude = merged.latitude ?? old.latitude
            merged.longitude = merged.longitude ?? old.longitude
        }
        merged.ledger = ledger
        for duplicate in matches where duplicate !== record {
            context.delete(duplicate)
        }
        record.apply(merged)
        let existing = record.entries ?? []
        let active = Set(ledger.activeEntries.map(\.id))
        for item in existing where !active.contains(item.id) {
            context.delete(item)
        }
        let existingIds = Set(existing.map(\.id))
        for item in ledger.activeEntries where !existingIds.contains(item.id) {
            let entry = EntryRecord(id: item.id, kindId: item.kindId, kindName: item.kindName,
                                    alcoholGrams: item.alcoholGrams, loggedAt: item.loggedAt,
                                    source: item.source.rawValue, isToastOnly: item.isToastOnly, session: record)
            context.insert(entry)
        }
        try context.save()
    }

    func seedPresetsIfNeeded() throws {
        let existing = try context.fetch(FetchDescriptor<DrinkKindRecord>())
        for kind in DrinkPresets.all where !existing.contains(where: { $0.id == kind.id }) {
            context.insert(DrinkKindRecord(id: kind.id, name: kind.name, abv: kind.abv, volumeML: kind.volumeML,
                                           isPreset: kind.isPreset, sortOrder: kind.sortOrder))
        }
        try context.save()
    }

    func kinds() throws -> [DrinkKind] {
        try context.fetch(FetchDescriptor<DrinkKindRecord>(sortBy: [SortDescriptor(\.sortOrder)])).map {
            DrinkKind(id: $0.id, name: $0.name, abv: $0.abv, volumeML: $0.volumeML, isPreset: $0.isPreset, sortOrder: $0.sortOrder)
        }
    }
}
