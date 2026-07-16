import Foundation
import SwiftData

/// 제너릭 SwiftData CRUD 서비스. predicate·정렬은 호출부가 주입한다 — 코어는 도메인 모델을 모른다.
/// ⚠️ 단일 ModelContext 전제: 컨텍스트를 공유하는 다른 쓰기 경로와 rollback이 간섭할 수 있다.
@MainActor
public final class PersistenceService<Model: PersistentModel> {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll(sortBy: [SortDescriptor<Model>] = []) throws -> [Model] {
        try context.fetch(FetchDescriptor<Model>(sortBy: sortBy))
    }

    public func fetch(matching predicate: Predicate<Model>,
                      sortBy: [SortDescriptor<Model>] = []) throws -> [Model]
    {
        try context.fetch(FetchDescriptor<Model>(predicate: predicate, sortBy: sortBy))
    }

    /// replacing 조건에 걸리는 기존 레코드를 지우고 삽입한다 (테니스 workoutSessionId 중복 제거의 일반화).
    /// save 실패 시 rollback 후 원본 에러를 그대로 던진다.
    public func upsert(_ model: Model, replacing predicate: Predicate<Model>? = nil) throws {
        if let predicate {
            for old in try fetch(matching: predicate) {
                context.delete(old)
            }
        }
        context.insert(model)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func delete(_ model: Model) throws {
        context.delete(model)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
