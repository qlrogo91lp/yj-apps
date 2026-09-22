import Foundation
import HealthKit

public enum WorkoutDeletionOutcome: Equatable, Sendable {
    /// 지울 대상이 없었다. 구버전 기록처럼 healthKitUUID가 없는 경우 사용자에게 알리지 않는다.
    case nothingToDelete
    case deleted
    case notAuthorized
    case failed
}

public protocol WorkoutDeleting: Sendable {
    func deleteWorkouts(uuids: [UUID]) async -> WorkoutDeletionOutcome
}

public final class WorkoutDeletionService: WorkoutDeleting, @unchecked Sendable {
    private let store: HKHealthStore

    public init() {
        store = HKHealthStore()
    }

    public func deleteWorkouts(uuids: [UUID]) async -> WorkoutDeletionOutcome {
        guard !uuids.isEmpty else { return .nothingToDelete }
        guard HKHealthStore.isHealthDataAvailable() else { return .failed }

        let workoutType = HKObjectType.workoutType()
        do {
            try await store.requestAuthorization(toShare: [workoutType], read: [])
            guard store.authorizationStatus(for: workoutType) == .sharingAuthorized else {
                return .notAuthorized
            }

            for uuid in uuids {
                let predicate = HKQuery.predicateForObject(with: uuid)
                _ = try await store.deleteObjects(of: workoutType, predicate: predicate)
            }
            return .deleted
        } catch {
            return .failed
        }
    }
}
