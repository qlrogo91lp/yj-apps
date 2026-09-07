import Foundation

/// HealthKit 에 이미 저장된 워크아웃을 지우는 통로.
///
/// `stopWorkout()` 이 `finishWorkout()` 을 무조건 부르므로 요약 화면이 뜨는 시점엔
/// **HKWorkout 이 이미 저장돼 있다.** 제품 스펙이 "폐기하면 HealthKit 에도 저장하지 않는다"고
/// 못박았으니 사후 삭제로 지킨다 (W2 플랜 1절 A안).
protocol WorkoutRemoving {
    func remove(workoutWith uuid: UUID) async
}
