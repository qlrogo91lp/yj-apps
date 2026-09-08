import Foundation
import PersistenceCore
import SwiftData

enum PersistenceError: Error {
    case notConfigured
    case saveFailed(Error)
}

/// PersistenceCore 위의 앱 레이어. 코어는 도메인을 모르므로(제너릭 CRUD),
/// 테니스 규칙 — matchId 기준 중복 제거, startedAt 정렬 — 은 여기가 소유한다.
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

    /// 같은 경기의 기존 기록을 지우고 삽입한다 — 폰·워치 양쪽 저장 요청과 워치의 저장
    /// 재시도가 중복 레코드를 만들지 않게 하는 규칙. matchId가 없으면 그냥 삽입한다.
    /// workoutSessionId는 워크아웃 식별자라 키로 쓰면 같은 워크아웃의 다른 경기까지 지운다.
    func upsert(_ match: Match) throws {
        guard let store else { throw PersistenceError.notConfigured }
        do {
            if let mid = match.matchId {
                try store.upsert(match, replacing: #Predicate<Match> { $0.matchId == mid })
            } else {
                try store.upsert(match)
            }
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    /// SetRecord 는 deleteRule: .cascade 라 함께 지워진다.
    /// CloudKit 동기화라 다른 기기로 전파되고 되돌릴 수 없다 — 호출부가 확인을 받는다.
    ///
    /// 넘어온 인스턴스를 그대로 지우지 않고 **id 로 다시 찾아** 지운다. iOSApp 이 이 서비스에
    /// 별도 ModelContext 를 주는데 화면은 @Environment(\.modelContext) 를 쓰므로, 다른
    /// 컨텍스트의 모델을 그대로 넘기면 삭제가 저장소에 반영되지 않는다 (화면에서만 사라졌다가
    /// 재실행하면 되살아난다).
    func delete(_ match: Match) throws {
        guard let store else { throw PersistenceError.notConfigured }
        let id = match.id
        do {
            for owned in try store.fetch(matching: #Predicate<Match> { $0.id == id }, sortBy: []) {
                try store.delete(owned)
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
