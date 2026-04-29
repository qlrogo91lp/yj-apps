import Foundation
import SwiftData

enum MatchFormat: String, Codable {
    case oneSet = "one_set"
    case bestOf3 = "best_of_3"
}

@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var matchFormat: MatchFormat = MatchFormat.oneSet
    @Relationship(deleteRule: .cascade) var sets: [SetRecord] = []
    var opponentName: String?
    var caloriesBurned: Double?
    var durationSeconds: Int?
    var myTotalSets: Int = 0
    var yourTotalSets: Int = 0
    var isCompleted: Bool = false

    init(matchFormat: MatchFormat = .oneSet) {
        self.matchFormat = matchFormat
    }
}
