import Foundation

/// 수동 기록 폼의 입력. 시작과 운동 시간만 필수이며, 나머지는 기본값을 갖는다.
struct ManualRecordDraft {
    enum ValidationError: Error {
        case durationOutOfRange
        case endsInFuture
        case notManual
    }

    var startedAt: Date
    var durationMinutes: Int
    var kind: SegmentKind
    var bodyParts: Set<BodyPart>
    var memo: String

    init(startedAt: Date = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60 - 3600),
         durationMinutes: Int = 60,
         kind: SegmentKind = .strength,
         bodyParts: Set<BodyPart> = [],
         memo: String = "")
    {
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.kind = kind
        self.bodyParts = bodyParts
        self.memo = memo
    }

    var endedAt: Date {
        startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    func validate(now: Date = Date()) throws {
        guard (1 ... 1440).contains(durationMinutes) else { throw ValidationError.durationOutOfRange }
        guard endedAt <= now else { throw ValidationError.endsInFuture }
    }
}
