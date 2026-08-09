import Foundation
import SwiftData
@testable import TennisCounter
import Testing

/// MatchPersistenceService는 싱글턴이라 테스트마다 컨텍스트를 갈아끼운다. 병렬 실행 시
/// 서로의 컨텍스트를 덮어쓰므로 직렬 실행이 필요하다.
@Suite(.serialized)
@MainActor
struct MatchPersistenceServiceTests {
    private func makeService() throws -> MatchPersistenceService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        let service = MatchPersistenceService.shared
        service.configure(with: ModelContext(container))
        return service
    }

    /// 스펙 1-1 재현: 중복 제거 키가 워크아웃 단위라 같은 워크아웃의 두 번째 경기를
    /// 저장하면 첫 경기가 삭제됐다. 워크아웃 하나에 경기 여러 판은 정상 사용 경로다.
    @Test func upsertSameWorkoutDifferentMatchIdKeepsBoth() throws {
        let service = try makeService()
        let workoutId = UUID()

        let first = Match()
        first.workoutSessionId = workoutId
        first.matchId = UUID()
        first.myTotalSets = 1
        try service.upsert(first)

        let second = Match()
        second.workoutSessionId = workoutId
        second.matchId = UUID()
        second.myTotalSets = 2
        try service.upsert(second)

        let all = try service.fetchByWorkoutSession(workoutId)
        #expect(all.count == 2)
        #expect(Set(all.map(\.myTotalSets)) == [1, 2])
    }

    /// 폰·워치 양쪽 저장과 워치의 저장 재시도를 흡수하는 경로.
    @Test func upsertSameMatchIdReplaces() throws {
        let service = try makeService()
        let matchId = UUID()

        let first = Match()
        first.matchId = matchId
        first.myTotalSets = 1
        try service.upsert(first)

        let retry = Match()
        retry.matchId = matchId
        retry.myTotalSets = 2
        try service.upsert(retry)

        let all = try service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.myTotalSets == 2)
    }

    /// 구버전 워치 페이로드에는 matchId가 없다. 이때는 중복 제거를 하지 않는다.
    @Test func upsertWithoutMatchIdAlwaysInserts() throws {
        let service = try makeService()
        let workoutId = UUID()

        let first = Match()
        first.workoutSessionId = workoutId
        first.myTotalSets = 1
        try service.upsert(first)

        let second = Match()
        second.workoutSessionId = workoutId
        second.myTotalSets = 2
        try service.upsert(second)

        #expect(try service.fetchAll().count == 2)
    }

    @Test func upsertReplacesOnlyMatchingMatchId() throws {
        let service = try makeService()
        let untouched = UUID()
        let replaced = UUID()

        let other = Match()
        other.matchId = untouched
        other.myTotalSets = 9
        try service.upsert(other)

        let first = Match()
        first.matchId = replaced
        first.myTotalSets = 1
        try service.upsert(first)

        let second = Match()
        second.matchId = replaced
        second.myTotalSets = 2
        try service.upsert(second)

        let all = try service.fetchAll()
        #expect(all.count == 2)
        #expect(all.first(where: { $0.matchId == untouched })?.myTotalSets == 9)
        #expect(all.first(where: { $0.matchId == replaced })?.myTotalSets == 2)
    }

    @Test func fetchAllSortsByStartedAtDescending() throws {
        let service = try makeService()

        let older = Match()
        older.matchId = UUID()
        older.startedAt = Date(timeIntervalSince1970: 1000)
        try service.upsert(older)

        let newer = Match()
        newer.matchId = UUID()
        newer.startedAt = Date(timeIntervalSince1970: 2000)
        try service.upsert(newer)

        let all = try service.fetchAll()
        #expect(all.map(\.startedAt) == [newer.startedAt, older.startedAt])
    }

    @Test func fetchByWorkoutSessionIgnoresOtherSessions() throws {
        let service = try makeService()
        let target = UUID()

        let mine = Match()
        mine.matchId = UUID()
        mine.workoutSessionId = target
        try service.upsert(mine)

        let others = Match()
        others.matchId = UUID()
        others.workoutSessionId = UUID()
        try service.upsert(others)

        #expect(try service.fetchByWorkoutSession(target).count == 1)
        #expect(try service.fetchByWorkoutSession(UUID()).isEmpty)
    }
}
