import Foundation
import SwiftData

extension ModelContext {
    /// 같은 `healthKitUUID` 로 겹친 기록을 하나만 남기고 지운다. 지운 수를 돌려준다.
    /// 재설치 직후 HealthKit 재가져오기가 만든 임시 기록과 iCloud 에서 내려온 원래 기록이 겹치는 경우를 정리한다.
    /// 수동 기록(`healthKitUUID == nil`)은 건드리지 않고, `protected` 가 낀 묶음은 통째로 건너뛴다.
    @discardableResult
    func removeDuplicateWorkouts(protecting protected: Set<PersistentIdentifier> = []) throws -> Int {
        let descriptor = FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.healthKitUUID != nil })
        var groups: [UUID: [WorkoutRecord]] = [:]
        for record in try fetch(descriptor) {
            guard let uuid = record.healthKitUUID else { continue }
            groups[uuid, default: []].append(record)
        }
        var deleted = 0

        for group in groups.values where group.count > 1 {
            guard !group.contains(where: { protected.contains($0.persistentModelID) }),
                  let keeper = group.max(by: Self.keepsLater) else { continue }
            for record in group where record !== keeper {
                Self.carryAnnotations(from: record, to: keeper)
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

    /// `max(by:)` 용 비교 — 워치 · 수동 기록이 HealthKit 가져오기보다, 주석이 많은 쪽이 적은 쪽보다 남는다.
    private static func keepsLater(_ lhs: WorkoutRecord, _ rhs: WorkoutRecord) -> Bool {
        let lhsOriginal = lhs.source != .healthKitImport
        let rhsOriginal = rhs.source != .healthKitImport
        if lhsOriginal != rhsOriginal { return !lhsOriginal }
        return annotationScore(lhs) < annotationScore(rhs)
    }

    /// 남는 쪽이 비어 있을 때만 지워지는 쪽의 메모 · 부위를 옮긴다 — 복원 전에 임시 기록에 단 메모를 잃지 않게.
    private static func carryAnnotations(from removed: WorkoutRecord, to keeper: WorkoutRecord) {
        if keeper.memo?.isEmpty != false, let memo = removed.memo, !memo.isEmpty {
            keeper.memo = memo
        }
        if keeper.bodyPartsRaw.isEmpty { keeper.bodyPartsRaw = removed.bodyPartsRaw }
    }

    private static func annotationScore(_ record: WorkoutRecord) -> Int {
        (record.segments?.count ?? 0) + (record.memo?.isEmpty == false ? 1 : 0) + record.bodyPartsRaw.count
    }
}
