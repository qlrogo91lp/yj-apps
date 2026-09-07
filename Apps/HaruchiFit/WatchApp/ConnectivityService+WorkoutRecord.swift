import ConnectivityCore

extension ConnectivityService: WorkoutRecordSending {
    /// 기록은 유실되면 안 된다 — 폰이 꺼져 있어도 `transferUserInfo` 가 큐잉하는 `.reliable`.
    func sendReliably(_ message: WorkoutRecordMessage) {
        send(message, via: .reliable)
    }
}
