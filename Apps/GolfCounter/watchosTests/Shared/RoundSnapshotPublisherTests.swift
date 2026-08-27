import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct RoundSnapshotPublisherTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func makeSnapshot() -> RoundSnapshot {
        RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: "테스트CC",
                      currentHoleIndex: 1,
                      holeScores: [4, 3],
                      holePars: [4, 3],
                      puttCounts: [2, 1])
    }

    @Test func publish한_스냅샷을_다시_읽을_수_있다() {
        let defaults = makeDefaults()
        let publisher = RoundSnapshotPublisher(defaults: defaults)
        let snapshot = makeSnapshot()

        publisher.publish(snapshot)

        #expect(publisher.loadCurrent() == snapshot)
    }

    @Test func clear하면_스냅샷이_사라진다() {
        let defaults = makeDefaults()
        let publisher = RoundSnapshotPublisher(defaults: defaults)
        publisher.publish(makeSnapshot())

        publisher.clear()

        #expect(publisher.loadCurrent() == nil)
    }

    @Test func 저장된적_없으면_nil이다() {
        let publisher = RoundSnapshotPublisher(defaults: makeDefaults())

        #expect(publisher.loadCurrent() == nil)
    }
}
