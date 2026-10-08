import Foundation
import SwiftData

extension WorkoutRecord {
    static func makeManual(from draft: ManualRecordDraft, now: Date = Date()) throws -> WorkoutRecord {
        try draft.validate(now: now)
        let record = WorkoutRecord(startedAt: draft.startedAt,
                                   endedAt: draft.endedAt,
                                   totalSeconds: draft.durationMinutes * 60,
                                   source: .manual)
        record.bodyPartsRaw = BodyPart.allCases.filter(draft.bodyParts.contains).map(\.rawValue)
        record.setMemo(draft.memo)
        record.segments = [Segment(kind: draft.kind, startOffset: 0, durationSeconds: record.totalSeconds)]
        return record
    }

    /// 기존 수동 기록의 영속 ID를 유지한다. 저장과 rollback은 호출부가 맡는다.
    func applyManual(_ draft: ManualRecordDraft, now: Date = Date(), in context: ModelContext) throws {
        guard source == .manual else { throw ManualRecordDraft.ValidationError.notManual }
        try draft.validate(now: now)
        let oldSegments = segments ?? []
        startedAt = draft.startedAt
        endedAt = draft.endedAt
        totalSeconds = draft.durationMinutes * 60
        bodyPartsRaw = BodyPart.allCases.filter(draft.bodyParts.contains).map(\.rawValue)
        setMemo(draft.memo)
        segments = [Segment(kind: draft.kind, startOffset: 0, durationSeconds: totalSeconds)]
        oldSegments.forEach(context.delete)
    }
}
