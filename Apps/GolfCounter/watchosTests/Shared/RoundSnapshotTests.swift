import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct RoundSnapshotTests {
    private func makeSnapshot() -> RoundSnapshot {
        RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: "테스트CC",
                      currentHoleIndex: 6,
                      holeScores: [4, 3, 6, 5, 4, 3, 2],
                      holePars: [4, 3, 5, 4, 4, 3, 4],
                      puttCounts: [2, 1, 2, 2, 1, 1, 1])
    }

    @Test func 파생값_현재홀번호와_누적오버파() {
        let snapshot = makeSnapshot()

        #expect(snapshot.currentHoleNumber == 7)
        #expect(snapshot.totalStrokes == 27)
        #expect(snapshot.relativeToPar == 0)
    }

    @Test func 코더블_왕복시_동일하다() throws {
        let snapshot = makeSnapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(decoded == snapshot)
    }

    @Test func 스토어_저장후_로드하면_동일하다() throws {
        let defaults = try #require(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        let snapshot = makeSnapshot()

        RoundSnapshotStore.save(snapshot, to: defaults)

        #expect(RoundSnapshotStore.load(from: defaults) == snapshot)
    }

    @Test func 스토어_클리어후_로드는_nil이다() throws {
        let defaults = try #require(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        RoundSnapshotStore.save(makeSnapshot(), to: defaults)

        RoundSnapshotStore.clear(from: defaults)

        #expect(RoundSnapshotStore.load(from: defaults) == nil)
    }
}
