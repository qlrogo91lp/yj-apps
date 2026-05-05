import Foundation
import SwiftData

@MainActor
final class MatchPersistenceService {
    static let shared = MatchPersistenceService()

    private var modelContext: ModelContext?

    private init() {}

    func configure(with context: ModelContext) {
        modelContext = context
    }

    func save(_ record: MatchRecord) throws {
        guard let context = modelContext else { return }
        context.insert(record)
        try context.save()
    }

    func fetchAll() throws -> [MatchRecord] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<MatchRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchByWorkoutSession(_ sessionId: UUID) throws -> [MatchRecord] {
        guard let context = modelContext else { return [] }
        let id = sessionId
        var descriptor = FetchDescriptor<MatchRecord>(
            predicate: #Predicate { $0.workoutSessionId == id }
        )
        descriptor.sortBy = [SortDescriptor(\.startedAt)]
        return try context.fetch(descriptor)
    }
}
