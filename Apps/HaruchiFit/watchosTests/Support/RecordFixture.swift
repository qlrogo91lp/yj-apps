import Foundation
@testable import HaruchiFit_Watch_App

/// 테스트용 전송 페이로드. 두 스위트가 함께 쓴다.
enum RecordFixture {
    static func make(healthKitUUID: UUID? = UUID(),
                     totalSeconds: Int = 600) -> WorkoutRecordMessage
    {
        WorkoutRecordMessage(healthKitUUID: healthKitUUID,
                             startedAt: Date(timeIntervalSince1970: 0),
                             endedAt: Date(timeIntervalSince1970: TimeInterval(totalSeconds)),
                             totalSeconds: totalSeconds,
                             activeCalories: 412,
                             totalCalories: 520,
                             averageHeartRate: 128,
                             segments: [.init(kind: .strength, startOffset: 0, durationSeconds: totalSeconds)])
    }
}
