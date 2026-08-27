import Foundation

struct MatchOptions {
    let mode: MatchFormat
    let noAdRule: Bool
    let noTieRule: Bool
    let gameThreshold: Int

    init(mode: MatchFormat, noAdRule: Bool, noTieRule: Bool, gameThreshold: Int = 6) {
        self.mode = mode
        self.noAdRule = noAdRule
        self.noTieRule = noTieRule
        self.gameThreshold = gameThreshold
    }
}
