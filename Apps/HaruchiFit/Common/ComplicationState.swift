import Foundation

/// 컴플리케이션이 그릴 표시값. 스냅샷 유무가 평상시와 진행 중을 가른다 (제품 스펙 WC절).
///
/// **위젯 타깃에는 테스트 타깃이 없다.** 그래서 표시 규칙을 여기로 내려 `watchosTests` 에서
/// 검증한다 — 골프의 `ComplicationState` 가 같은 이유로 같은 자리에 있다.
struct ComplicationState: Equatable {
    let isActive: Bool
    /// 진행 중일 때의 구간 종류. 비활성일 때 값은 그리지 않는다.
    let mode: SegmentKind
    let isPaused: Bool
    /// `Text(_:style: .timer)` 의 기준점. 여기서부터 흐른 시간이 곧 경과시간이다.
    /// 비활성이면 그릴 타이머가 없어 nil.
    let timerReference: Date?
    /// 정지 중에는 타이머를 태울 수 없어 이 고정 문자열을 그린다.
    let elapsedText: String

    init(snapshot: WorkoutSnapshot?) {
        isActive = snapshot != nil
        mode = snapshot?.mode ?? .strength
        isPaused = snapshot?.isPaused ?? false
        // 시작 시각이 아니라 경과시간에서 거꾸로 잡는다 — 일시정지한 만큼 어긋나기 때문이다.
        timerReference = snapshot.map { $0.capturedAt.addingTimeInterval(-Double($0.elapsedSeconds)) }
        elapsedText = SummaryFormat.duration(snapshot?.elapsedSeconds ?? 0)
    }
}
