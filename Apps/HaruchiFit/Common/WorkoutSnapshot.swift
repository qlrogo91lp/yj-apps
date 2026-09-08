import Foundation

/// 진행 중인 세션의 상태. **컴플리케이션이 읽는 유일한 데이터원이다** — HealthKit 을 보지 않는다
/// (아키텍처 D-M4). 워치 앱과 컴플리케이션은 다른 프로세스라 App Group 을 거쳐 오간다.
///
/// **경과시간을 `startedAt` 하나로 계산하지 않는 이유** — 일시정지가 있어 시작 시각부터의
/// 벽시계 시간은 실제 경과시간보다 길다. `capturedAt` 과 `elapsedSeconds` 를 짝으로 남겨야
/// 컴플리케이션이 기준점을 거꾸로 잡을 수 있다.
struct WorkoutSnapshot: Codable, Equatable {
    let startedAt: Date
    /// 현재 구간의 종류. 전환할 때마다 새로 발행된다.
    let mode: SegmentKind
    let isPaused: Bool
    /// `capturedAt` 시점의 경과시간. 둘은 함께여야 의미가 있다.
    let elapsedSeconds: Int
    let capturedAt: Date
}
