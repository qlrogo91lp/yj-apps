import Foundation
import SwiftData

enum MatchFormat: String, Codable {
    case oneSet = "one_set"
    case bestOfThree = "best_of_3"

    var setsToWin: Int {
        switch self {
        case .oneSet: return 1
        case .bestOfThree: return 2
        }
    }
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
