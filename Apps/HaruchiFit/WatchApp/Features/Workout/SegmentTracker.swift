import Foundation

/// 세션 안의 구간 경계를 잰다. 근력↔유산소 전환 한 번이 구간 하나를 닫고 다음을 연다.
///
/// **벽시계로 잰다.** `WorkoutSessionService.elapsedSeconds` 는 1초 `Timer` 가 올리는 틱
/// 카운터라 손목을 내리면 멈추고, 다시 켜져도 밀린 만큼 따라잡지 않는다 — 실기기에서 40분
/// 세션의 구간이 몇 초로 잡혀 요약이 "근력 0분" 을 띄웠다.
///
/// 요약 상단의 총 시간도 `stopWorkout()` 이 `Date().timeIntervalSince(start)` 로 내므로,
/// 같은 기준으로 재야 **구간 합계와 총 시간이 어긋나지 않는다.** 둘 다 일시정지한 시간을
/// 포함한다 — 한쪽만 빼면 합계가 총 시간과 안 맞는다.
struct SegmentTracker {
    private let now: () -> Date
    private(set) var startedAt: Date
    /// 열려 있는 구간이 시작된 오프셋(초).
    private var openStart = 0
    private(set) var closed: [WorkoutRecordMessage.SegmentPayload] = []

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        startedAt = now()
    }

    /// 세션 시작으로부터 흐른 시간(초).
    var elapsedSeconds: Int {
        max(0, Int(now().timeIntervalSince(startedAt)))
    }

    /// 새 세션을 연다. 쌓인 구간을 버리고 기준 시각을 다시 잡는다.
    mutating func reset() {
        startedAt = now()
        openStart = 0
        closed = []
    }

    /// 열린 구간을 닫고 다음 구간을 연다.
    /// 길이가 0이면 버린다 — 전환을 연달아 눌렀을 때 빈 구간이 쌓이는 것을 막는다.
    mutating func closeOpenSegment(kind: SegmentKind) {
        let elapsed = elapsedSeconds
        let duration = elapsed - openStart
        if duration > 0 {
            closed.append(.init(kind: kind, startOffset: openStart, durationSeconds: duration))
        }
        openStart = elapsed
    }
}
