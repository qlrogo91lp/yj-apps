import Foundation

enum MatchFormat: String, CaseIterable, Codable {
    case oneSet = "one_set"
    case bestOfThree = "best_of_3"

    var setsToWin: Int {
        switch self {
        case .oneSet: 1
        case .bestOfThree: 2
        }
    }
}
