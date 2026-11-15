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
}
