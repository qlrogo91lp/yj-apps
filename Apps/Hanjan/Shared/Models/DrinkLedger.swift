import Foundation

nonisolated struct KindCount: Codable, Equatable, Sendable {
    let kindId: UUID
    let name: String
    let count: Int
}

nonisolated struct DrinkLedger: Codable, Equatable, Sendable {
    private var entries: [UUID: DrinkEntry] = [:]
    private var removed: Set<UUID> = []

    init() {}

    /// 저장소에서 복원할 때 쓴다. 삭제 이력을 함께 넘겨야 늦게 도착한 추가를 계속 걸러낸다.
    init(entries: [DrinkEntry], removedIds: Set<UUID>) {
        removed = removedIds
        for entry in entries {
            add(entry)
        }
    }

    /// 지금까지 삭제된 잔 id. 아직 도착하지 않은 잔의 id 도 포함된다.
    var removedIds: Set<UUID> {
        removed
    }

    mutating func add(_ entry: DrinkEntry) {
        if !removed.contains(entry.id), entries[entry.id] == nil { entries[entry.id] = entry }
    }

    mutating func remove(id: UUID) {
        removed.insert(id); entries.removeValue(forKey: id)
    }

    mutating func merge(_ other: DrinkLedger) {
        removed.formUnion(other.removed)
        for entry in other.entries.values {
            add(entry)
        }
        for id in removed {
            entries.removeValue(forKey: id)
        }
    }

    var activeEntries: [DrinkEntry] {
        entries.values.sorted { $0.loggedAt == $1.loggedAt ? $0.id.uuidString < $1.id.uuidString : $0.loggedAt < $1.loggedAt }
    }

    var drinkEntries: [DrinkEntry] {
        activeEntries.filter { !$0.isToastOnly }
    }

    var last: DrinkEntry? {
        activeEntries.last
    }

    var totalGrams: Double {
        drinkEntries.reduce(0) { $0 + $1.alcoholGrams }
    }

    func sojuEquivalent() -> Double {
        totalGrams / DrinkPresets.soju.alcoholGrams
    }

    func countsByKind() -> [KindCount] {
        var result: [KindCount] = []
        for entry in drinkEntries {
            if let index = result.firstIndex(where: { $0.kindId == entry.kindId }) {
                let item = result[index]; result[index] = KindCount(kindId: item.kindId, name: item.name, count: item.count + 1)
            } else { result.append(KindCount(kindId: entry.kindId, name: entry.kindName, count: 1)) }
        }
        return result
    }
}
