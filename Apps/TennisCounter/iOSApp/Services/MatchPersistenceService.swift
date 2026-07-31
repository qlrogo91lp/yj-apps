import Foundation
import PersistenceCore
import SwiftData

enum PersistenceError: Error {
    case notConfigured
    case saveFailed(Error)
}

/// PersistenceCore 위의 앱 레이어. 코어는 도메인을 모르므로(제너릭 CRUD),
/// 테니스 규칙 — workoutSessionId 기준 중복 제거, startedAt 정렬 — 은 여기가 소유한다.
/// iOS 전용: Watch·Complication 타겟은 저장소를 쓰지 않는다.
@MainActor
final class MatchPersistenceService {
    static let shared = MatchPersistenceService()

    private var store: PersistenceService<Match>?

    private init() {}

    func configure(with context: ModelContext) {
        store = PersistenceService(context: context)
    }

    func fetchAll() throws -> [Match] {
        guard let store else { return [] }
        return try store.fetchAll(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
    }

    /// 같은 워크아웃 세션의 기존 기록을 지우고 삽입한다 — 워치·폰 양쪽 저장 요청이
    /// 중복 레코드를 만들지 않게 하는 규칙. sessionId가 없으면 그냥 삽입한다.
    func upsert(_ match: Match) throws {
        guard let store else { throw PersistenceError.notConfigured }
        do {
            if let sid = match.workoutSessionId {
                try store.upsert(match, replacing: #Predicate<Match> { $0.workoutSessionId == sid })
            } else {
                try store.upsert(match)
            }
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    func fetchByWorkoutSession(_ sessionId: UUID) throws -> [Match] {
        guard let store else { return [] }
        let id = sessionId
        return try store.fetch(
            matching: #Predicate<Match> { $0.workoutSessionId == id },
            sortBy: [SortDescriptor(\.startedAt)]
        )
    }
}
