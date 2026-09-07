@testable import HaruchiFit_Watch_App

/// 무엇이 전송됐는지 기록하는 스파이. 실제 `WCSession` 을 건드리지 않는다.
final class WorkoutRecordSendingSpy: WorkoutRecordSending {
    private(set) var sent: [WorkoutRecordMessage] = []

    func sendReliably(_ message: WorkoutRecordMessage) {
        sent.append(message)
    }
}
