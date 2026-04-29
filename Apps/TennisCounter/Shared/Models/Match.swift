import Foundation
import SwiftData

@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var matchFormat: String = "one_set"   // "one_set" | "best_of_3"
    @Relationship(deleteRule: .cascade) var sets: [SetRecord]? = []
    var opponentName: String?
    var caloriesBurned: Double?
    var durationSeconds: Int?
    var myTotalSets: Int = 0
    var yourTotalSets: Int = 0
    var isCompleted: Bool = false

    init(matchFormat: String = "one_set") {
        self.matchFormat = matchFormat
    }
}
