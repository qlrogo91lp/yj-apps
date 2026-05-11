import Foundation

enum MatchFormat: String, CaseIterable, Codable {
    case oneSet = "one_set"
    case bestOfThree = "best_of_3"

    var localizedTitle: String {
        switch self {
        case .oneSet: String(localized: "match_format_one_set")
        case .bestOfThree: String(localized: "match_format_best_of_3")
        }
    }

    var localizedDescription: String {
        switch self {
        case .oneSet: String(localized: "match_format_one_set_desc")
        case .bestOfThree: String(localized: "match_format_best_of_3_desc")
        }
    }

    var setsToWin: Int {
        switch self {
        case .oneSet: 1
        case .bestOfThree: 2
        }
    }
}
