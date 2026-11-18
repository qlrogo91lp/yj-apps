import Foundation
import SwiftData

extension ModelContext {
    @discardableResult
    func removeDuplicateWorkouts(protecting protected: Set<PersistentIdentifier> = []) throws -> Int {
        let descriptor = FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.healthKitUUID != nil })
        let records = try fetch(descriptor)
        let groups = Dictionary(grouping: records, by: { $0.healthKitUUID! })
        var deleted = 0

        for group in groups.values where group.count > 1 {
            guard !group.contains(where: { protected.contains($0.persistentModelID) }) else { continue }
            let keeper = group.max { lhs, rhs in
                let lhsOriginal = lhs.source != .healthKitImport
                let rhsOriginal = rhs.source != .healthKitImport
                if lhsOriginal != rhsOriginal { return !lhsOriginal }
                return annotationScore(lhs) < annotationScore(rhs)
            }!
            for record in group where record !== keeper {
                if keeper.memo?.isEmpty != false, let memo = record.memo, !memo.isEmpty {
                    keeper.memo = memo
                }
                if keeper.bodyPartsRaw.isEmpty { keeper.bodyPartsRaw = record.bodyPartsRaw }
                delete(record)
                deleted += 1
            }
        }

        if deleted > 0 {
            do { try save() } catch {
                rollback()
                throw error
            }
        }
        return deleted
    }

    private func annotationScore(_ record: WorkoutRecord) -> Int {
        (record.segments?.count ?? 0) + (record.memo?.isEmpty == false ? 1 : 0) + record.bodyPartsRaw.count
    }
}
