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
}
