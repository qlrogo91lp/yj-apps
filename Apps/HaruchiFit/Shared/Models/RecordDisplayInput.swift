import Foundation
import SwiftData

/// `@Query`의 객체 동일성으로는 잡히지 않는 제자리 편집을 화면이 관찰하게 만드는 값 스냅샷.
struct RecordDisplayInput: Equatable {
    struct SegmentInput: Equatable {
        let kind: SegmentKind
        let durationSeconds: Int
    }

    let id: PersistentIdentifier
    let startedAt: Date
    let totalSeconds: Int
    let totalCalories: Double?
    let bodyParts: [BodyPart]
    let segments: [SegmentInput]

    init(record: WorkoutRecord) {
        id = record.persistentModelID
        startedAt = record.startedAt
        totalSeconds = record.totalSeconds
        totalCalories = record.totalCalories
        bodyParts = record.bodyParts
        segments = record.orderedSegments.map { SegmentInput(kind: $0.kind, durationSeconds: $0.durationSeconds) }
    }
}
