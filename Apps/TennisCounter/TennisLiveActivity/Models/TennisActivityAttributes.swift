import ActivityKit
import Foundation

struct TennisActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var myPoint: String
        var yourPoint: String
        var myGame: Int
        var yourGame: Int
        var mySet: Int
        var yourSet: Int
        var isTieBreak: Bool

        static let empty = ContentState(
            myPoint: "0", yourPoint: "0",
            myGame: 0, yourGame: 0,
            mySet: 0, yourSet: 0,
            isTieBreak: false
        )
    }

    let matchMode: String
}
