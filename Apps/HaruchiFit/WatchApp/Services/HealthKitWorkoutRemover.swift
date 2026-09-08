import Foundation
import HealthKit

/// `WorkoutRemoving` 의 HealthKit 구현.
///
/// **실패는 삼킨다.** 권한이 회수됐거나 이미 지워진 경우인데, 어느 쪽이든 앱 저장소에는
/// 기록이 남지 않으므로 잔디·기록에는 영향이 없다 (W2 플랜 1절).
///
/// 삭제까지 짧은 순간 HealthKit 에 존재한다는 한계가 있다 — 요약을 보고 버튼을 누르는
/// 수 초 안의 일이고, `stopWorkout()` 이 `finishWorkout()` 을 무조건 부르는 이상
/// 되돌릴 수단이 사후 삭제뿐이다.
nonisolated struct HealthKitWorkoutRemover: WorkoutRemoving {
    private let store = HKHealthStore()

    func remove(workoutWith uuid: UUID) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let samples: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(),
                                      predicate: HKQuery.predicateForObject(with: uuid),
                                      limit: 1,
                                      sortDescriptors: nil)
            { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            store.execute(query)
        }

        guard let workout = samples.first else { return }
        try? await store.delete(workout)
    }
}
