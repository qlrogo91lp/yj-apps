import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData

/// 잔디 테스트가 쓰는 레코드 생성기.
///
/// **인메모리 컨테이너를 띄운다.** `@Model` 인스턴스를 컨텍스트 없이 만들면 to-many 관계
/// 대입의 동작이 보장되지 않는다. 컨테이너 하나 띄우는 비용이 그 불확실성보다 싸다.
///
/// **타임존을 고정한다.** 집계가 `Calendar.current` 를 쓰므로 고정하지 않으면 하루 경계
/// 테스트가 기계마다 다른 답을 낸다.
@MainActor
enum GrassFixture {
    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutRecord.self, Segment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// `segments` 는 (종류, 시작 오프셋, 길이) 튜플이다.
    @discardableResult
    static func record(in context: ModelContext,
                       startedAt: Date,
                       totalSeconds: Int,
                       totalCalories: Double? = nil,
                       segments: [(SegmentKind, Int, Int)] = []) -> WorkoutRecord
    {
        let record = WorkoutRecord(startedAt: startedAt,
                                   totalSeconds: totalSeconds,
                                   totalCalories: totalCalories)
        context.insert(record)
        record.segments = segments.map {
            Segment(kind: $0.0, startOffset: $0.1, durationSeconds: $0.2)
        }
        return record
    }

    static let seoul: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int,
                     _ hour: Int = 12, _ minute: Int = 0) -> Date
    {
        seoul.date(from: DateComponents(year: year, month: month, day: day,
                                        hour: hour, minute: minute))!
    }
}
