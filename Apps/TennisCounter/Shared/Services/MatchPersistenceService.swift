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

    func save(_ match: Match) throws {
        guard let context = modelContext else { return }
        context.insert(match)
        try context.save()
    }

    func fetchAll() throws -> [Match] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchByWorkoutSession(_ sessionId: UUID) throws -> [Match] {
        guard let context = modelContext else { return [] }
        let id = sessionId
        var descriptor = FetchDescriptor<Match>(
            predicate: #Predicate { $0.workoutSessionId == id }
        )
        descriptor.sortBy = [SortDescriptor(\.startedAt)]
        return try context.fetch(descriptor)
    }
}
