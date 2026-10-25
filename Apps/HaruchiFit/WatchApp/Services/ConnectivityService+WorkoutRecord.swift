import ConnectivityCore

extension ConnectivityService: WorkoutRecordSending {
    /// 기록은 유실되면 안 된다 — 항상 `transferUserInfo` 로 큐잉하는 `.queued`.
    /// `.reliable` 은 폰이 근처에 있으면 `sendMessage` 를 쓰는데, 실패해도 다시 보내지 않아 기록이 사라진다.
    func sendReliably(_ message: WorkoutRecordMessage) {
        send(message, via: .queued)
    }
}
