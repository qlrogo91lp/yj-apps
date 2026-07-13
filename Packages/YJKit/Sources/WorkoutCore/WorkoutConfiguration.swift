import HealthKit

/// 앱별 워크아웃 종목 설정. 소비자 앱이 자기 종목으로 만들어 서비스에 주입한다.
public struct WorkoutConfiguration {
    public let activityType: HKWorkoutActivityType
    public let locationType: HKWorkoutSessionLocationType

    public init(activityType: HKWorkoutActivityType,
                locationType: HKWorkoutSessionLocationType = .outdoor)
    {
        self.activityType = activityType
        self.locationType = locationType
    }
}
