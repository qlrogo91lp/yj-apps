import Foundation
import HealthKit

/// 앵커드 쿼리 한 번. **규칙을 갖지 않는다** — 매핑 표로 거르고 순수 값으로 옮기는 것까지다.
///
/// 백그라운드 배달(`enableBackgroundDelivery`)을 쓰지 않는다 (D-M4). 컴플리케이션이
/// 집계 값을 안 보여주므로 앱을 안 열어도 갱신될 이유가 없다.
///
/// `nonisolated` — 타깃 기본 격리가 MainActor 인데, 쿼리 콜백은 그 격리가 아니다.
/// `HealthKitWorkoutRemover` 와 같은 이유다.
nonisolated struct HealthKitWorkoutImporter {
    struct Batch {
        let workouts: [ImportedWorkout]
        let anchor: HKQueryAnchor?
    }

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        [HKObjectType.workoutType(),
         HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.basalEnergyBurned),
         HKQuantityType(.heartRate)]
    }

    /// **읽기 전용이다** — `toShare` 가 비어 있다. iOS 앱은 HealthKit 에 쓰지 않는다.
    ///
    /// 이미 결정한 사용자에게는 시스템이 시트를 띄우지 않으므로 매번 불러도 무해하다.
    /// **읽기 권한은 허용 여부를 알려주지 않는다** — 거부 상태에서도 에러가 아니라 빈
    /// 결과가 온다 (스펙 7절). 그래서 반환값이 없다.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetch(since anchor: HKQueryAnchor?) async -> Batch {
        guard HKHealthStore.isHealthDataAvailable() else {
            return Batch(workouts: [], anchor: nil)
        }

        return await withCheckedContinuation { continuation in
            // updateHandler 를 달지 않는다 — 달면 쿼리가 계속 살아 배치 경계가 흐려진다.
            let query = HKAnchoredObjectQuery(type: .workoutType(),
                                              predicate: nil,
                                              anchor: anchor,
                                              limit: HKObjectQueryNoLimit)
            { _, samples, _, newAnchor, _ in
                // 세 번째 인자가 HKDeletedObject 다. **지금은 읽지 않고 버린다** — 건강 앱
                // 삭제 반영은 3개 앱에 걸리는 문제라 YJKit 범위로 옮겼다 (스펙 4절).
                let workouts = (samples as? [HKWorkout] ?? []).compactMap(Self.imported(from:))
                continuation.resume(returning: Batch(workouts: workouts, anchor: newAnchor))
            }
            store.execute(query)
        }
    }

    /// 매핑 표에 없으면 nil 을 돌려 **입구에서 걸러낸다** (D-M5).
    /// 정적 메서드라 쿼리 콜백이 `HKHealthStore` 를 캡처하지 않는다.
    private static func imported(from workout: HKWorkout) -> ImportedWorkout? {
        guard let kind = WorkoutTypeMapping.kind(for: workout.workoutActivityType) else { return nil }

        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
        // 없으면 없는 대로 둔다. 워크아웃마다 HKStatisticsQuery 를 하나씩 돌리면 첫
        // 동기화에서 쿼리가 수백 개가 되고, 심박은 참고 표시값이다 (스펙 5절 · D5).
        let heartRate = workout.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))

        return ImportedWorkout(uuid: workout.uuid,
                               kind: kind,
                               startedAt: workout.startDate,
                               endedAt: workout.endDate,
                               totalSeconds: Int(workout.duration.rounded()),
                               activeCalories: calories,
                               averageHeartRate: heartRate)
    }
}
