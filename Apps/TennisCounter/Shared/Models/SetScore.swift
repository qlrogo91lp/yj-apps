import Foundation

struct SetScore: Codable {
    let my: Int
    let your: Int

    var isMatchTieBreak: Bool {
        max(my, your) >= Score.matchTieBreakTarget
    }
}
