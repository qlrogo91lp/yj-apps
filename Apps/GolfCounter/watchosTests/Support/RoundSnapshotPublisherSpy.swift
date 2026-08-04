import Foundation
@testable import GolfCounter_Watch_App

/// 스냅샷 발행 호출을 기록만 하는 테스트 더블. WidgetKit·App Group을 건드리지 않는다.
final class RoundSnapshotPublisherSpy: RoundSnapshotPublishing {
    private(set) var published: [RoundSnapshot] = []
    private(set) var clearCallCount = 0
    var stored: RoundSnapshot?

    func publish(_ snapshot: RoundSnapshot) {
        published.append(snapshot)
        stored = snapshot
    }

    func clear() {
        clearCallCount += 1
        stored = nil
    }

    func loadCurrent() -> RoundSnapshot? {
        stored
    }
}
