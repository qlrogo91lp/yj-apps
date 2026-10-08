import SwiftData

/// 수동 기록의 SwiftData 쓰기. HealthKit 권한이나 워치 연결을 요구하지 않는다.
@MainActor
struct ManualRecordStore {
    let context: ModelContext

    func save(_ draft: ManualRecordDraft, editing record: WorkoutRecord?) throws {
        do {
            if let record {
                try record.applyManual(draft, in: context)
            } else {
                try context.insert(WorkoutRecord.makeManual(from: draft))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
