@testable import TennisCounter_Watch_App

/// 어떤 햅틱 이벤트가 어떤 순서로 재생됐는지 기록한다.
final class HapticsSpy: MatchHapticsPlaying {
    private(set) var played: [MatchHapticEvent] = []

    func play(_ event: MatchHapticEvent) {
        played.append(event)
    }
}
