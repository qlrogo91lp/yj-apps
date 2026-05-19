import Foundation
import SwiftData

@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var caloriesBurned: Double?
    var durationSeconds: Int?
    var opponentName: String?
    var myTotalSets: Int = 0
    var yourTotalSets: Int = 0
    var isCompleted: Bool = false
    @Relationship(deleteRule: .cascade) var sets: [SetRecord] = []

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
