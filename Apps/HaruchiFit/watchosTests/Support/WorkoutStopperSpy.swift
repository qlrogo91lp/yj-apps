import WorkoutCore

/// HealthKit의 첫 종료만 대기시킨다. 중복 호출은 실제 서비스처럼 nil을 반환한다.
@MainActor
final class WorkoutStopperSpy {
    private(set) var callCount = 0
    private var hasFinished = false
    private var completion: CheckedContinuation<WorkoutResult?, Never>?
    private var entryWaiter: CheckedContinuation<Void, Never>?

    func stop() async -> WorkoutResult? {
        callCount += 1
        guard completion == nil, !hasFinished else { return nil }
        return await withCheckedContinuation { continuation in
            completion = continuation
            entryWaiter?.resume()
            entryWaiter = nil
        }
    }

    func waitUntilPending() async {
        guard completion == nil else { return }
        await withCheckedContinuation { entryWaiter = $0 }
    }

    func complete(with result: WorkoutResult?) {
        hasFinished = result != nil
        let continuation = completion
        completion = nil
        continuation?.resume(returning: result)
    }
}
