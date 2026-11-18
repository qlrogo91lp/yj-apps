import ConnectivityCore
import Foundation
@testable import Hanjan
import SwiftData
import Testing

@MainActor struct PhoneSessionStoreTests {
    @Test func lateEndedSessionDoesNotEndCurrentSession() throws {
        UserDefaults.standard.removeObject(forKey: "phoneLiveSession")
        defer { UserDefaults.standard.removeObject(forKey: "phoneLiveSession") }
        let container = try ModelContainer(for: Schema(HanjanSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let archive = SessionArchive(context: container.mainContext)
        let store = PhoneSessionStore(connectivity: ConnectivityService(), archive: archive, settings: AppSettings())
        store.start()
        let currentId = try #require(store.session?.id)
        var ended = session(0)
        ended.endedAt = Date(timeIntervalSince1970: 100)
        store.receive(ended)
        #expect(store.session?.id == currentId)
        #expect(try archive.record(owning: ended.id)?.endedAt == ended.endedAt)
    }

    private func makeStore(_ defaults: UserDefaults, now: @escaping () -> Date) throws -> (PhoneSessionStore, ModelContainer) {
        let container = try ModelContainer(for: Schema(HanjanSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return (PhoneSessionStore(connectivity: ConnectivityService(), archive: SessionArchive(context: container.mainContext),
                                  settings: AppSettings(defaults: defaults), now: now, defaults: defaults), container)
    }

    @Test func staleSnapshotAndEndDoNotAffectNewSession() throws {
        var time = Date(timeIntervalSince1970: 100)
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let (store, container) = try makeStore(defaults, now: { time })
        defer { withExtendedLifetime(container) {} }
        store.start(); store.tapMain()
        let old = try #require(store.session)
        store.end(); time.addTimeInterval(10); store.start()
        let fresh = try #require(store.session)
        store.receive(old)
        store.receiveEnd(SessionEndMessage(sessionId: old.id, endedAt: time))
        #expect(store.session == fresh)
        let (restored, restoredContainer) = try makeStore(defaults, now: { time })
        defer { withExtendedLifetime(restoredContainer) {} }
        restored.receive(old)
        #expect(restored.session == fresh)
    }

    @Test func overlappingSessionsMergeButAbsorbedEndDoesNotEndPrimary() throws {
        let time = Date(timeIntervalSince1970: 100)
        let (store, container) = try makeStore(#require(UserDefaults(suiteName: UUID().uuidString)), now: { time })
        defer { withExtendedLifetime(container) {} }
        store.start(); store.tapMain()
        let primary = try #require(store.session)
        var other = session(100)
        other.ledger.add(other.makeEntry(id: UUID(), at: time, kind: DrinkPresets.soju, source: .watch))
        store.receive(other)
        #expect(store.session?.ledger.drinkEntries.count == 2)
        store.receiveEnd(SessionEndMessage(sessionId: other.id, endedAt: time))
        #expect(store.session?.id == primary.id)
    }

    @Test func nonOverlappingAndEndedSnapshotsAreIgnored() throws {
        let (store, container) = try makeStore(#require(UserDefaults(suiteName: UUID().uuidString)), now: { Date(timeIntervalSince1970: 200) })
        defer { withExtendedLifetime(container) {} }
        store.start()
        let fresh = try #require(store.session)
        var old = session(100)
        old.ledger.add(old.makeEntry(id: UUID(), at: Date(timeIntervalSince1970: 110), kind: DrinkPresets.soju, source: .watch))
        store.receive(old)
        #expect(store.session == fresh)
        old.endedAt = Date(timeIntervalSince1970: 150)
        store.receive(old)
        #expect(store.session == fresh)
    }

    @Test func remembersOnlyTwentyEndedIds() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let (store, container) = try makeStore(defaults, now: Date.init)
        defer { withExtendedLifetime(container) {} }
        var ids: [UUID] = []
        for _ in 0 ..< 21 {
            store.start(); try ids.append(#require(store.session?.id)); store.end()
        }
        let saved = try #require(defaults.stringArray(forKey: "hanjan.phone.endedSessionIds"))
        #expect(saved.count == 20)
        #expect(!saved.contains(ids[0].uuidString))
        #expect(saved.contains(ids[20].uuidString))
    }
}
