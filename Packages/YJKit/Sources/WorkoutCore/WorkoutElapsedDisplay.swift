import Foundation

/// 운동 경과시간의 순수 표시 기준. Timer나 HealthKit 이벤트 도착 간격과 무관하게, 기준시각과
/// 현재(또는 고정된) 시각의 차이로 경과시간을 계산한다 — 콜백이 몇 번 끊겨도 다음 호출에서
/// `Date()`로 다시 계산하면 항상 정확하다.
///
/// `referenceDate`는 정지 누적이 반영된 가상 시작시각이다. resume마다 정지했던 길이만큼
/// 앞으로 밀려서, 이후 `elapsed(at:)`가 그 구간을 자동으로 빼게 한다.
public struct WorkoutElapsedDisplay: Equatable, Sendable {
    public let referenceDate: Date
    /// nil이면 실행 중. 값이 있으면 그 시각에서 경과시간이 고정된다.
    public let pausedAt: Date?

    public init(referenceDate: Date, pausedAt: Date? = nil) {
        self.referenceDate = referenceDate
        self.pausedAt = pausedAt
    }

    public func elapsed(at date: Date) -> TimeInterval {
        max(0, (pausedAt ?? date).timeIntervalSince(referenceDate))
    }

    /// 정지를 시작한다. 이미 정지 중이면 첫 정지 경계를 보존하고 무시한다.
    public func pausing(at date: Date) -> Self {
        guard pausedAt == nil else { return self }
        return Self(referenceDate: referenceDate, pausedAt: date)
    }

    /// 정지를 끝낸다. 정지 중이 아니면 무시한다. 정지했던 길이만큼 `referenceDate`를 앞으로
    /// 밀어서, 이후 `elapsed(at:)`가 그 구간을 자동으로 뺀다.
    public func resuming(at date: Date) -> Self {
        guard let pausedAt else { return self }
        let pausedSpan = date.timeIntervalSince(pausedAt)
        return Self(referenceDate: referenceDate.addingTimeInterval(pausedSpan), pausedAt: nil)
    }
}
