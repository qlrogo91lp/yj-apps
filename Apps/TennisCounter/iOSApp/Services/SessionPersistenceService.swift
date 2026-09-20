import Foundation
import SwiftData

/// 세션 레코드 CRUD. 중복 제거 키는 `workoutSessionId` 다 —
/// 경기와 달리 워크아웃 하나에 레코드도 하나라서 키가 겹치지 않는다.
final class SessionPersistenceService {
    static let shared = SessionPersistenceService()

    private var context: ModelContext?

    func configure(with context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [WorkoutSessionRecord] {
        guard let context else { return [] }
        return try context.fetch(FetchDescriptor<WorkoutSessionRecord>())
    }

    func upsert(_ record: WorkoutSessionRecord) throws {
        guard let context else { return }
        if let id = record.workoutSessionId {
            let existing = try context.fetch(
                FetchDescriptor<WorkoutSessionRecord>(
                    predicate: #Predicate { $0.workoutSessionId == id }
                )
            )
            for old in existing {
                context.delete(old)
            }
        }
        context.insert(record)
        try context.save()
    }

    func delete(sessionId: UUID) throws {
        guard let context else { return }
        let matching = try context.fetch(
            FetchDescriptor<WorkoutSessionRecord>(
                predicate: #Predicate { $0.workoutSessionId == sessionId }
            )
        )
        for record in matching {
            context.delete(record)
        }
        try context.save()
    }
}
