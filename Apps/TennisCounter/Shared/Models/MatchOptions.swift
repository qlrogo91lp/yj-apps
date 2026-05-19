import Foundation

struct MatchOptions {
    let mode: MatchFormat
    let noAdRule: Bool // default true (NO-AD = sudden death deuce)
    let noTieRule: Bool // default false (tiebreak enabled)
}
