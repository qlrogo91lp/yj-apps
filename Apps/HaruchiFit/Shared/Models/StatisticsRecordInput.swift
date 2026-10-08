import Foundation

/// 통계 집계가 영속 모델의 제자리 변경까지 관찰할 수 있게 만드는 값 스냅샷.
struct StatisticsRecordInput: Equatable {
    struct SegmentInput: Equatable {
        let kind: SegmentKind
        let durationSeconds: Int
    }

    let startedAt: Date
    let totalSeconds: Int
    let totalCalories: Double?
    let bodyParts: [BodyPart]
    let segments: [SegmentInput]

    init(startedAt: Date,
         totalSeconds: Int,
         totalCalories: Double?,
         bodyParts: [BodyPart],
         segments: [SegmentInput])
    {
        self.startedAt = startedAt
        self.totalSeconds = totalSeconds
        self.totalCalories = totalCalories
        self.bodyParts = bodyParts
        self.segments = segments
    }

    init(record: WorkoutRecord) {
        self.init(startedAt: record.startedAt,
                  totalSeconds: record.totalSeconds,
                  totalCalories: record.totalCalories,
                  bodyParts: record.bodyParts,
                  segments: record.orderedSegments.map {
                      SegmentInput(kind: $0.kind, durationSeconds: $0.durationSeconds)
                  })
    }
}
