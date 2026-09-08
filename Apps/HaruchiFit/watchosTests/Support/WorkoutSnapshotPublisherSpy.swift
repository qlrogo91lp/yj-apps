@testable import HaruchiFit_Watch_App

/// 무엇을 언제 발행했는지 기록하는 스파이. 실제 App Group 저장도 WidgetKit 갱신도 하지 않는다.
final class WorkoutSnapshotPublisherSpy: WorkoutSnapshotPublishing {
    private(set) var published: [WorkoutSnapshot] = []
    private(set) var clearCount = 0

    func publish(_ snapshot: WorkoutSnapshot) {
        published.append(snapshot)
    }

    func clear() {
        clearCount += 1
    }
}
