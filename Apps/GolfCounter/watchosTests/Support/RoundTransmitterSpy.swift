import Foundation
@testable import GolfCounter_Watch_App

/// 발신 호출을 기록만 하는 테스트 더블. WatchConnectivity를 건드리지 않는다.
final class RoundTransmitterSpy: RoundTransmitting {
    private(set) var sent: [RoundCompletedMessage] = []

    func send(_ message: RoundCompletedMessage) {
        sent.append(message)
    }
}
