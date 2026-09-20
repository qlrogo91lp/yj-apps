import Foundation
@testable import HaruchiFit_Watch_App

/// 어떤 워크아웃을 지워달라고 했는지 기록하는 스파이. 실제 HealthKit 을 건드리지 않는다.
///
/// **`actor` 가 아니라 `@MainActor final class` 다.** 이 프로젝트는
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 라 `WorkoutRemoving` 이 암묵적으로 MainActor
/// 격리되는데, Swift 6.4(Xcode 27)부터 actor 는 전역 액터에 격리된 프로토콜에 적합할 수 없다.
/// 호출부인 `WorkoutViewModel` 도 `@MainActor` 라 격리를 맞추는 편이 실제와도 가깝다.
@MainActor
final class WorkoutRemovingSpy: WorkoutRemoving {
    private(set) var removed: [UUID] = []

    func remove(workoutWith uuid: UUID) async {
        removed.append(uuid)
    }
}
