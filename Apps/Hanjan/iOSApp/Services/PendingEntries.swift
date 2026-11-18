import Foundation

struct PendingEntries {
    private let defaults: UserDefaults
    private let key = "pendingSessionEntries"
    private var ledgers: [UUID: DrinkLedger]
    private var endings: [UUID: Date]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ledgers = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([UUID: DrinkLedger].self, from: $0) } ?? [:]
        endings = defaults.data(forKey: "pendingSessionEndings").flatMap { try? JSONDecoder().decode([UUID: Date].self, from: $0) } ?? [:]
    }

    mutating func add(_ entry: DrinkEntry) {
        var ledger = ledgers[entry.sessionId] ?? DrinkLedger()
        ledger.add(entry); ledgers[entry.sessionId] = ledger; persist()
    }

    mutating func remove(_ id: UUID, sessionId: UUID) {
        var ledger = ledgers[sessionId] ?? DrinkLedger()
        ledger.remove(id: id); ledgers[sessionId] = ledger; persist()
    }

    mutating func end(sessionId: UUID, at date: Date) {
        endings[sessionId] = endings[sessionId] ?? date
        persist()
    }

    mutating func merge(into session: inout LiveSession) {
        for id in session.mergedSessionIds.union([session.id]) {
            if let ledger = ledgers.removeValue(forKey: id) { session.ledger.merge(ledger) }
            if let ended = endings.removeValue(forKey: id) { session.endedAt = session.endedAt ?? ended }
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(ledgers) { defaults.set(data, forKey: key) }
        if let data = try? JSONEncoder().encode(endings) { defaults.set(data, forKey: "pendingSessionEndings") }
    }
}
