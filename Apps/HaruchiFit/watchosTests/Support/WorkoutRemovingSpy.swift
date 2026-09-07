import Foundation
@testable import HaruchiFit_Watch_App

/// 어떤 워크아웃을 지워달라고 했는지 기록하는 스파이. 실제 HealthKit 을 건드리지 않는다.
actor WorkoutRemovingSpy: WorkoutRemoving {
    private(set) var removed: [UUID] = []

    func remove(workoutWith uuid: UUID) async {
        removed.append(uuid)
    }
}
