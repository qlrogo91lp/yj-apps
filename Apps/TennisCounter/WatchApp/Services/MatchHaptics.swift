import WatchKit

/// 경기 중 촉각으로 구분해야 하는 이벤트. 어떤 `WKHapticType` 으로 울릴지는 `MatchHaptics` 만 안다.
enum MatchHapticEvent: Equatable {
    case point
    case undo
    case gameWon
    case setWon
    case matchFinished(MatchResult)
    case saveSucceeded
    case saveFailed
    case paused
    case resumed
}

protocol MatchHapticsPlaying {
    func play(_ event: MatchHapticEvent)
}

/// 어휘는 골프·하루치와 맞춘다 — `.click` 은 입력, `.directionDown` 은 되돌리기.
/// 자주 오는 이벤트일수록 가볍게, 드문 이벤트일수록 세게.
///
/// 설정 연동(작업 #8)은 `play(_:)` 첫 줄에서 건다 — 이벤트가 여기까지는 그대로 흘러오고
/// 마지막 관문에서 거른다.
struct MatchHaptics: MatchHapticsPlaying {
    func play(_ event: MatchHapticEvent) {
        WKInterfaceDevice.current().play(Self.type(for: event))
    }

    static func type(for event: MatchHapticEvent) -> WKHapticType {
        switch event {
        case .point: .click
        case .undo: .directionDown
        case .gameWon: .start
        case .setWon: .notification
        // 경기 결과는 갈래가 셋이라 따로 뺀다 — 한 switch 에 다 두면 순환 복잡도 제한에 걸린다
        case let .matchFinished(result): type(for: result)
        case .saveSucceeded: .success
        case .saveFailed: .failure
        case .paused: .stop
        case .resumed: .start
        }
    }

    private static func type(for result: MatchResult) -> WKHapticType {
        switch result {
        case .win: .success
        case .loss: .failure
        case .draw: .notification
        }
    }
}
