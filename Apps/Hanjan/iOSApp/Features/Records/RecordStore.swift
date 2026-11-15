import Foundation
import SwiftData

/// 기록 탭이 SwiftData 를 직접 읽고 쓰는 곳. 끝난 세션만 다룬다 — 진행 중 세션은 홈의 세션 저장소 몫이다.
struct RecordStore {
    let context: ModelContext

    // MARK: - 읽기

    /// 짠만 포함, 삭제 이력에 있는 잔은 뺀 기록.
    static func entries(of record: SessionRecord) -> [DrinkEntry] {
        record.ledger.activeEntries
    }

    /// 화면의 잔 수는 저장된 숫자가 아니라 기록(저장된 잔 + 삭제 이력)에서 계산한다.
    static func ledger(of record: SessionRecord) -> DrinkLedger {
        record.ledger
    }

    /// 스테퍼로 고칠 수 있는 술 목록. 술 목록 순서대로, 그 뒤에 목록에서 지워진 술(기록에만 남은 것)을 붙인다.
    /// 지워진 술은 기록의 한 잔 알코올량을 그대로 갖도록 도수·용량을 거꾸로 맞춘다.
    static func editableKinds(of record: SessionRecord, catalog: [DrinkKind]) -> [DrinkKind] {
        let known = Set(catalog.map(\.id))
        let recorded = entries(of: record)
        let orphans = ledger(of: record).countsByKind()
            .filter { !known.contains($0.kindId) }
            .map { count in
                let grams = recorded.first { $0.kindId == count.kindId && !$0.isToastOnly }?.alcoholGrams ?? 0
                return DrinkKind(id: count.kindId, name: count.name, abv: grams / 0.789, volumeML: 100, isPreset: false, sortOrder: Int.max)
            }
        return catalog + orphans
    }

    /// 설정의 술 목록. 아직 비어 있으면(첫 실행 시드 전) 프리셋을 쓴다.
    func catalog() -> [DrinkKind] {
        let records = (try? context.fetch(FetchDescriptor<DrinkKindRecord>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        guard !records.isEmpty else { return DrinkPresets.all }
        return records.map {
            DrinkKind(id: $0.id, name: $0.name, abv: $0.abv, volumeML: $0.volumeML, isPreset: $0.isPreset, sortOrder: $0.sortOrder)
        }
    }

    func session(id: UUID) -> SessionRecord? {
        var descriptor = FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func companionNames() -> [String] {
        let records = (try? context.fetch(FetchDescriptor<CompanionRecord>(sortBy: [SortDescriptor(\.name)]))) ?? []
        var seen = Set<String>()
        return records.map(\.name).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    // MARK: - 쓰기

    /// 술 하나의 마신 잔 수를 `count` 로 맞추고 합계를 다시 계산한다.
    /// 지운 잔은 삭제 이력(`removedEntryIds`)에 남긴다 — 끊겨 있던 워치가 같은 잔을 늦게 보내도 되살아나지 않는다.
    func setCount(_ count: Int, kind: DrinkKind, in record: SessionRecord, now: Date) throws {
        let current = Self.entries(of: record)
        let next = EntryEdit.adjust(current, kind: kind, to: count, sessionId: record.id, now: now)
        let nextIds = Set(next.map(\.id))
        let currentIds = Set(current.map(\.id))
        record.removedEntryIds.formUnion(currentIds.subtracting(nextIds))
        for item in record.entries ?? [] where !nextIds.contains(item.id) {
            context.delete(item)
        }
        for entry in next where !currentIds.contains(entry.id) {
            context.insert(EntryRecord(
                id: entry.id,
                kindId: entry.kindId,
                kindName: entry.kindName,
                alcoholGrams: entry.alcoholGrams,
                loggedAt: entry.loggedAt,
                source: entry.source.rawValue,
                isToastOnly: entry.isToastOnly,
                session: record
            ))
        }
        let ledger = DrinkLedger(entries: next, removedIds: record.removedEntryIds)
        record.totalGrams = ledger.totalGrams
        record.toastOnlyCount = ledger.activeEntries.count(where: \.isToastOnly)
        try context.save()
    }

    /// 다음 날 회고. 전부 선택 입력이라 빈 값은 nil 로 남긴다. 함께한 사람은 같은 이름이면 기존 기록을 다시 쓴다.
    func saveReview(_ record: SessionRecord, condition: Int?, companions: [String], placeName: String, memo: String) throws {
        record.condition = condition.flatMap { (1 ... 5).contains($0) ? $0 : nil }

        var seen = Set<String>()
        let names = companions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        let existing = try context.fetch(FetchDescriptor<CompanionRecord>())
        record.companions = names.map { name in
            if let found = existing.first(where: { $0.name == name }) { return found }
            let created = CompanionRecord(name: name)
            context.insert(created)
            return created
        }

        let place = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        record.placeName = place.isEmpty ? nil : place
        record.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : memo
        try context.save()
    }

    /// CloudKit 으로 다른 기기에도 전파되고 되돌릴 수 없다. 호출부가 확인을 받는다.
    func delete(_ record: SessionRecord) throws {
        context.delete(record)
        try context.save()
    }
}
