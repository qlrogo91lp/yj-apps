import Foundation

enum MatchFormat: String, CaseIterable {
    case oneSet = "one_set"
    case bestOfThree = "best_of_3"

    var localizedTitle: String {
        switch self {
        case .oneSet: return String(localized: "match_format_one_set")
        case .bestOfThree: return String(localized: "match_format_best_of_3")
        }
    }

    var localizedDescription: String {
        switch self {
        case .oneSet: return String(localized: "match_format_one_set_desc")
        case .bestOfThree: return String(localized: "match_format_best_of_3_desc")
        }
    }

    var setsToWin: Int {
        switch self {
        case .oneSet: return 1
        case .bestOfThree: return 2
        }
    }
}
