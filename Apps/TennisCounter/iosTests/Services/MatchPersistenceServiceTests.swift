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

    @Test func upsertWithoutSessionIdKeepsEveryRecord() throws {
        let service = try makeService()

        let m1 = Match(); m1.myTotalSets = 1
        try service.upsert(m1)
        let m2 = Match(); m2.myTotalSets = 2
        try service.upsert(m2)

        // workoutSessionId가 없으면 중복 제거 대상이 아니다
        #expect(try service.fetchAll().count == 2)
    }

    @Test func upsertReplacesOnlyMatchingSession() throws {
        let service = try makeService()
        let untouched = UUID()
        let replaced = UUID()

        let other = Match(); other.workoutSessionId = untouched; other.myTotalSets = 9
        try service.upsert(other)

        let first = Match(); first.workoutSessionId = replaced; first.myTotalSets = 1
        try service.upsert(first)
        let second = Match(); second.workoutSessionId = replaced; second.myTotalSets = 2
        try service.upsert(second)

        #expect(try service.fetchAll().count == 2)
        #expect(try service.fetchByWorkoutSession(untouched).first?.myTotalSets == 9)
        #expect(try service.fetchByWorkoutSession(replaced).first?.myTotalSets == 2)
    }

    @Test func fetchAllSortsByStartedAtDescending() throws {
        let service = try makeService()

        let older = Match(); older.startedAt = Date(timeIntervalSince1970: 1000)
        try service.upsert(older)
        let newer = Match(); newer.startedAt = Date(timeIntervalSince1970: 2000)
        try service.upsert(newer)

        let all = try service.fetchAll()
        #expect(all.map(\.startedAt) == [newer.startedAt, older.startedAt])
    }

    @Test func fetchByWorkoutSessionIgnoresOtherSessions() throws {
        let service = try makeService()
        let target = UUID()

        let mine = Match(); mine.workoutSessionId = target
        try service.upsert(mine)
        let others = Match(); others.workoutSessionId = UUID()
        try service.upsert(others)

        #expect(try service.fetchByWorkoutSession(target).count == 1)
        #expect(try service.fetchByWorkoutSession(UUID()).isEmpty)
    }
}
