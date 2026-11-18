import Foundation
@testable import Hanjan_Watch_App
import Testing

@MainActor struct WatchSessionStoreTests {
    private func defaults() -> UserDefaults {
        let name = "WatchSessionStoreTests.\(UUID())"
        return UserDefaults(suiteName: name)!
    }

    @Test func tapThreeThenUndo() {
        let store = WatchSessionStore(defaults: defaults(), now: { Date(timeIntervalSince1970: 100) })
        store.start(); store.tapMain(); store.tapMain(); store.tapMain(); store.undo()
        #expect(store.session?.ledger.drinkEntries.count == 2)
    }

    @Test func toastEveryThreeDrinksOnce() {
        var time = Date(timeIntervalSince1970: 100)
        let store = WatchSessionStore(defaults: defaults(), now: { time })
        store.start(); store.cycleToast(); store.cycleToast()
        for _ in 0 ..< 3 {
            time.addTimeInterval(1); store.tapMain()
        }
        #expect(store.session?.ledger.drinkEntries.count == 1)
        #expect(store.session?.ledger.activeEntries.count == 3)
    }

    @Test func autoEndClearsLocalSession() {
        var time = Date(timeIntervalSince1970: 100)
        let storage = defaults()
        let store = WatchSessionStore(defaults: storage, now: { time })
        store.start(); time.addTimeInterval(10800); store.tick()
        #expect(store.session == nil)
        #expect(WatchSessionStore(defaults: storage).session == nil)
    }

    @Test func incomingStateMergesWithoutLosingEntries() throws {
        let store = WatchSessionStore(defaults: defaults())
        store.start()
        let old = try #require(store.session)
        store.tapMain()
        store.receive(SessionStateMessage(session: old))
        #expect(store.session?.ledger.activeEntries.count == 1)
    }

    @Test func restoresSession() {
        let storage = defaults()
        let store = WatchSessionStore(defaults: storage)
        store.start(); store.tapMain()
        let restored = WatchSessionStore(defaults: storage)
        #expect(restored.session == store.session)
    }

    @Test func staleSnapshotAndEndDoNotAffectNewSession() throws {
        var time = Date(timeIntervalSince1970: 100)
        let storage = defaults()
        let store = WatchSessionStore(defaults: storage, now: { time })
        store.start(); store.tapMain()
        let old = try #require(store.session)
        store.end(); time.addTimeInterval(10); store.start()
        let fresh = try #require(store.session)
        store.receive(SessionStateMessage(session: old))
        store.receive(SessionEndMessage(sessionId: old.id, endedAt: time))
        #expect(store.session == fresh)
        let restored = WatchSessionStore(defaults: storage, now: { time })
        restored.receive(SessionStateMessage(session: old))
        #expect(restored.session == fresh)
    }

    @Test func sessionsStartedOneMinuteApartMergeAndAbsorbedEndFinishesSession() throws {
        let time = Date(timeIntervalSince1970: 100)
        let store = WatchSessionStore(defaults: defaults(), now: { time })
        store.start()
        let primary = try #require(store.session)
        let other = LiveSession(id: UUID(), startedAt: time.addingTimeInterval(60), limit: 8, currentKindId: DrinkPresets.soju.id)
        store.receive(SessionStateMessage(session: other))
        #expect(store.session?.id == primary.id)
        #expect(store.session?.owns(sessionId: other.id) == true)
        store.receive(SessionEndMessage(sessionId: other.id, endedAt: time.addingTimeInterval(60)))
        #expect(store.session == nil)
        store.receive(SessionStateMessage(session: other))
        #expect(store.session == nil)
        store.receive(SessionStateMessage(session: primary))
        #expect(store.session == nil)
    }

    @Test func inactiveSessionAfterThreeHoursAndEndedSnapshotsAreIgnored() throws {
        let store = WatchSessionStore(defaults: defaults(), now: { Date(timeIntervalSince1970: 10911) })
        store.start()
        let fresh = try #require(store.session)
        var old = LiveSession(id: UUID(), startedAt: Date(timeIntervalSince1970: 100), limit: 8, currentKindId: DrinkPresets.soju.id)
        old.ledger.add(old.makeEntry(id: UUID(), at: Date(timeIntervalSince1970: 110), kind: DrinkPresets.soju, source: .phone))
        store.receive(SessionStateMessage(session: old))
        #expect(store.session == fresh)
        old.endedAt = Date(timeIntervalSince1970: 150)
        store.receive(SessionStateMessage(session: old))
        #expect(store.session == fresh)
    }

    @Test func overlapWindowIsSymmetricAtThreeHourBoundary() {
        let first = LiveSession(id: UUID(), startedAt: Date(timeIntervalSince1970: 100), limit: 8, currentKindId: DrinkPresets.soju.id)
        let boundary = LiveSession(id: UUID(), startedAt: Date(timeIntervalSince1970: 10900), limit: 8, currentKindId: DrinkPresets.soju.id)
        let later = LiveSession(id: UUID(), startedAt: Date(timeIntervalSince1970: 10901), limit: 8, currentKindId: DrinkPresets.soju.id)
        #expect(first.overlaps(boundary)); #expect(boundary.overlaps(first))
        #expect(!first.overlaps(later)); #expect(!later.overlaps(first))
    }

    @Test func remembersOnlyTwentyEndedIds() throws {
        let storage = defaults()
        let store = WatchSessionStore(defaults: storage)
        var ids: [UUID] = []
        for _ in 0 ..< 21 {
            store.start(); try ids.append(#require(store.session?.id)); store.end()
        }
        let saved = try #require(storage.stringArray(forKey: "hanjan.watch.endedSessionIds"))
        #expect(saved.count == 20)
        #expect(!saved.contains(ids[0].uuidString))
        #expect(saved.contains(ids[20].uuidString))
    }
}
