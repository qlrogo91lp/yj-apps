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

    @Test func holePars가_holeScores보다_짧으면_초과홀은_무시된다() {
        // 8번째 홀을 플레이했지만 파는 아직 세팅되지 않은 상태(배열 길이 불일치)를 시뮬레이션한다.
        var snapshot = makeSnapshot()
        snapshot.holeScores.append(5)

        // 옛 공식(totalStrokes - holePars.reduce(0,+))이라면 32 - 27 = 5 가 되어 완전히 틀린 값을 낸다.
        // 새 공식은 짝지어지는 앞 7홀만 더해 기존과 동일하게 0 이어야 한다.
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

        let saved = RoundSnapshotStore.save(snapshot, to: defaults)

        #expect(saved)
        #expect(RoundSnapshotStore.load(from: defaults) == snapshot)
    }

    @Test func 스토어_defaults가_nil이면_저장은_false를_반환한다() {
        let saved = RoundSnapshotStore.save(makeSnapshot(), to: nil)

        #expect(!saved)
    }

    @Test func 스토어_클리어후_로드는_nil이다() throws {
        let defaults = try #require(UserDefaults(suiteName: #function))
        defaults.removePersistentDomain(forName: #function)
        RoundSnapshotStore.save(makeSnapshot(), to: defaults)

        RoundSnapshotStore.clear(from: defaults)

        #expect(RoundSnapshotStore.load(from: defaults) == nil)
    }

    @Test func id와_holeCount가_코더블_왕복에서_유지된다() throws {
        let id = UUID()
        let snapshot = RoundSnapshot(id: id,
                                     holeCount: 9,
                                     startedAt: Date(timeIntervalSince1970: 1000),
                                     courseName: "테스트CC",
                                     currentHoleIndex: 2,
                                     holeScores: [4, 3, 5],
                                     holePars: [4, 3, 4],
                                     puttCounts: [2, 1, 2])

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.holeCount == 9)
        #expect(decoded == snapshot)
    }

    @Test func 구버전_스냅샷은_id가_새로_발급되고_holeCount가_18로_채워진다() throws {
        let data = try Self.legacySnapshotJSON(currentHoleIndex: 2,
                                               holeScores: [4, 3, 5],
                                               holePars: [4, 3, 4],
                                               puttCounts: [2, 1, 2])

        let snapshot = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(snapshot.holeCount == 18)
        #expect(snapshot.currentHoleIndex == 2)
        #expect(snapshot.holeScores == [4, 3, 5])
    }

    @Test func 구버전_스냅샷이_18홀을_넘겼어도_기록이_잘리지_않는다() throws {
        // 상한이 없던 시절에는 "다음"을 계속 눌러 20홀까지 갈 수 있었다.
        let data = try Self.legacySnapshotJSON(currentHoleIndex: 19,
                                               holeScores: Array(repeating: 4, count: 20),
                                               holePars: Array(repeating: 4, count: 20),
                                               puttCounts: Array(repeating: 2, count: 20))

        let snapshot = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(snapshot.holeCount == 20)
        #expect(snapshot.holeScores.count == 20)
    }

    /// `id`·`holeCount`가 없던 시절의 와이어 포맷.
    private static func legacySnapshotJSON(currentHoleIndex: Int,
                                           holeScores: [Int],
                                           holePars: [Int],
                                           puttCounts: [Int]) throws -> Data
    {
        let dictionary: [String: Any] = [
            "startedAt": 0,
            "currentHoleIndex": currentHoleIndex,
            "holeScores": holeScores,
            "holePars": holePars,
            "puttCounts": puttCounts,
        ]
        return try JSONSerialization.data(withJSONObject: dictionary)
    }
}
