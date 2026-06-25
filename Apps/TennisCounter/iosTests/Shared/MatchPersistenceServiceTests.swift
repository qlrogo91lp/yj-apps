import Foundation
import SwiftData
@testable import TennisCounter
import Testing

@MainActor
struct MatchPersistenceServiceTests {
    private func makeService() throws -> MatchPersistenceService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        let service = MatchPersistenceService.shared
        service.configure(with: ModelContext(container))
        return service
    }

    @Test func upsertSameSessionKeepsSingleRecord() throws {
        let service = try makeService()
        let sid = UUID()

        let m1 = Match(); m1.workoutSessionId = sid; m1.myTotalSets = 1
        try service.upsert(m1)

        let m2 = Match(); m2.workoutSessionId = sid; m2.myTotalSets = 2
        try service.upsert(m2)

        let all = try service.fetchByWorkoutSession(sid)
        #expect(all.count == 1)
        #expect(all.first?.myTotalSets == 2) // 최신으로 갱신
    }
}
