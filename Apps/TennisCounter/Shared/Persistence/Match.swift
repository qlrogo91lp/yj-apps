import Foundation
import SwiftData

@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var caloriesBurned: Double?
    /// 활동 + 휴식. CloudKit 요구사항상 optional이며, 총 칼로리 도입 전 기록은 nil이다.
    var totalCaloriesBurned: Double?
    var durationSeconds: Int?
    var opponentName: String?
    var myTotalSets: Int = 0
    var yourTotalSets: Int = 0
    var isCompleted: Bool = false
    /// CloudKit 요구사항: optional + inverse 지정
    @Relationship(deleteRule: .cascade, inverse: \SetRecord.match) var sets: [SetRecord]?

    var workoutSessionId: UUID?
    var mode: String = MatchFormat.oneSet.rawValue
    var noAdRule: Bool = true
    var resultRaw: String = "win"
    var averageHeartRate: Double?

    var matchFormat: MatchFormat {
        get { MatchFormat(rawValue: mode) ?? .oneSet }
        set { mode = newValue.rawValue }
    }

    init() {}
}
