import Foundation
import SwiftData

/// 한 번의 워크아웃이 끝난 시점의 최종값. 경기(`Match`)와 독립으로 저장된다.
///
/// 경기 레코드의 `workout*` 필드는 "그 경기가 끝난 시점까지의 누적값"이라 마지막 경기 이후
/// 구간이 빠진다. 이 레코드는 워크아웃이 실제로 끝난 시점의 값이다.
@Model
final class WorkoutSessionRecord {
    /// `Match.workoutSessionId` 와 잇는 키. CloudKit 요구사항상 optional.
    var workoutSessionId: UUID?
    var startedAt: Date = Date()
    var endedAt: Date?
    var elapsedSeconds: Int?
    var activeCalories: Double?
    var totalCalories: Double?
    /// **워크아웃 전체 평균.** 경기 구간 평균인 `Match.averageHeartRate` 와 성격이 다르다.
    var averageHeartRate: Double?
    /// 건강 앱 기록과 잇는 키.
    var healthKitUUID: UUID?

    init() {}
}
