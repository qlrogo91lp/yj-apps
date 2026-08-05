import Foundation

/// 폰이 워치의 경과시간을 매초 로컬 보간할 때 쓰는 계산.
///
/// 시간 "값"을 매초 전송하는 대신 기준점(앵커)만 이따금 동기화하고, 수신 이후 흐른 시간을
/// 더한다. 드리프트가 누적되지 않고(앵커 수신마다 리셋), 메시지가 유실돼도 다음 앵커로
/// 자동 복구되며, 폰이 백그라운드에서 돌아와도 재계산만으로 즉시 정확해진다.
public enum WorkoutAnchor {
    /// - Parameters:
    ///   - anchorElapsed: 앵커에 실려온 워치 기준 경과 초.
    ///   - isPaused: 앵커 시점의 일시정지 여부. true면 시간이 흐르지 않는다.
    ///   - sentAt: 앵커 발신 시각(Unix epoch). 스탬프를 안 붙이는 구버전 발신자면 nil.
    ///   - now: 현재 시각(Unix epoch).
    public static func interpolatedElapsed(anchorElapsed: TimeInterval,
                                           isPaused: Bool,
                                           sentAt: TimeInterval?,
                                           now: TimeInterval = Date().timeIntervalSince1970) -> TimeInterval
    {
        guard !isPaused, let sentAt else { return anchorElapsed }
        // 기기 시계가 어긋나 음수가 나오면 앵커 값을 유지한다 — 시간이 거꾸로 가는 것보다 낫다.
        return anchorElapsed + max(0, now - sentAt)
    }
}
