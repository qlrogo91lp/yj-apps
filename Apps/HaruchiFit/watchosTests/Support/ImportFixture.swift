import Foundation
@testable import HaruchiFit_Watch_App

/// import 테스트용 순수 값. `RecordFixture`(워치 전송 페이로드)와 역할이 다르다.
enum ImportFixture {
    static func workout(uuid: UUID = UUID(),
                        kind: SegmentKind = .cardio,
                        totalSeconds: Int = 1800,
                        activeCalories: Double? = 240,
                        averageHeartRate: Double? = 132) -> ImportedWorkout
    {
        let start = Date(timeIntervalSince1970: 0)
        return ImportedWorkout(uuid: uuid,
                               kind: kind,
                               startedAt: start,
                               endedAt: start.addingTimeInterval(TimeInterval(totalSeconds)),
                               totalSeconds: totalSeconds,
                               activeCalories: activeCalories,
                               averageHeartRate: averageHeartRate)
    }
}
