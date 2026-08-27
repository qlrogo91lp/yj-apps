import Foundation

enum MatchPhase {
    case modeSelection
    case playing(MatchOptions)
    case finished(MatchSession)
}
