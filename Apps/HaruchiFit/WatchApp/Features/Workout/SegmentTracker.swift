import Foundation

/// 세션 안의 구간 경계를 잰다. 근력↔유산소 전환 한 번이 구간 하나를 닫고 다음을 연다.
///
/// **워치의 단일 시계다.** 화면·컴플리케이션·구간·저장 총시간이 모두 여기서 나온다.
/// `WorkoutSessionService.elapsedSeconds` 는 1초 `Timer` 가 올리는 틱 카운터라 손목을 내리면
/// 멈추고, 다시 켜져도 밀린 만큼 따라잡지 않는다 — 실기기에서 40분 세션의 구간이 몇 초로
/// 잡혀 요약이 "근력 0분" 을 띄웠다.
///
/// **일시정지한 시간은 뺀다.** 사용자가 기대하는 "운동한 시간" 이 그 뜻이고, 잔디 농도가
/// 이 값을 입력으로 삼는다 (`docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md`).
/// 정지 상태의 단일 소스는 `WorkoutSessionService` 이며, 이 타입은 전달받기만 한다.
struct SegmentTracker {
    private let now: () -> Date
    private(set) var startedAt: Date
    /// 열려 있는 구간이 시작된 오프셋(초).
    private var openStart = 0
    private(set) var closed: [WorkoutRecordMessage.SegmentPayload] = []

    /// 지금까지 정지로 흘려보낸 시간의 합.
    private var pausedAccumulated: TimeInterval = 0
    /// 정지 중이면 정지가 시작된 시각. 아니면 nil.
    private var pausedSince: Date?

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        startedAt = now()
    }

    /// 세션 시작으로부터 흐른 시간(초). **정지한 시간은 빠져 있다.**
    /// 정지 중에는 정지가 시작된 시점의 값에서 멈춘다.
    var elapsedSeconds: Int {
        let reference = pausedSince ?? now()
        return max(0, Int(reference.timeIntervalSince(startedAt) - pausedAccumulated))
    }

    /// 새 세션을 연다. 쌓인 구간과 정지 누적을 버리고 기준 시각을 다시 잡는다.
    mutating func reset() {
        startedAt = now()
        openStart = 0
        closed = []
        pausedAccumulated = 0
        pausedSince = nil
    }

    /// 정지를 시작한다. 이미 정지 중이면 아무 일도 하지 않는다 —
    /// 중복 신호가 와도 기준 시각을 덮어써 정지 길이를 잃지 않게 한다.
    mutating func pause() {
        guard pausedSince == nil else { return }
        pausedSince = now()
    }

    /// 정지를 끝내고 그 길이를 누적에 더한다. 정지 중이 아니면 아무 일도 하지 않는다.
    mutating func resume() {
        guard let since = pausedSince else { return }
        pausedAccumulated += now().timeIntervalSince(since)
        pausedSince = nil
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
