import Foundation
@testable import Hanjan
import Testing

@MainActor struct PendingEntriesTests {
    @Test func removalBeforeSessionAndAdditionSurvivesRestoration() throws {
        let name = "pending-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let id = UUID()
        let value = entry(sessionId: id)
        var pending = PendingEntries(defaults: defaults)
        pending.remove(value.id, sessionId: id)
        pending.add(value)
        pending = PendingEntries(defaults: defaults)
        var current = LiveSession(id: id, startedAt: Date(), limit: 8, currentKindId: value.kindId)
        pending.merge(into: &current)
        #expect(current.ledger.activeEntries.isEmpty)
        #expect(current.ledger.removedIds.contains(value.id))
    }

    @Test func endBeforeStartSurvivesRestoration() throws {
        let name = "pending-end-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var value = session()
        let end = Date(timeIntervalSince1970: 42)
        var pending = PendingEntries(defaults: defaults)
        pending.end(sessionId: value.id, at: end)
        pending = PendingEntries(defaults: defaults)
        pending.merge(into: &value)
        #expect(value.endedAt == end)
    }

}
