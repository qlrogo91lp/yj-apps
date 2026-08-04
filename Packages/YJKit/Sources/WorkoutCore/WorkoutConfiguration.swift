import HealthKit

/// 앱별 워크아웃 종목 설정. 소비자 앱이 자기 종목으로 만들어 서비스에 주입한다.
public struct WorkoutConfiguration: Equatable, Sendable {
    public let activityType: HKWorkoutActivityType
    public let locationType: HKWorkoutSessionLocationType
    /// 기본 세트(활동/휴식 에너지·심박·워크아웃) 외에 추가로 읽고 수집할 수량 타입.
    /// 종목마다 필요한 지표가 달라 소비자가 지정한다 — 비워 두면 권한 요청 항목이 늘지 않는다.
    public let additionalReadTypes: Set<HKQuantityTypeIdentifier>

    public init(activityType: HKWorkoutActivityType,
                locationType: HKWorkoutSessionLocationType = .outdoor,
                additionalReadTypes: Set<HKQuantityTypeIdentifier> = [])
    {
        self.activityType = activityType
        self.locationType = locationType
        self.additionalReadTypes = additionalReadTypes
    }
}
