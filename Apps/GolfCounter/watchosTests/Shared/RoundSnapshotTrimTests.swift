import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct RoundSnapshotTrimTests {
    private func snapshot(currentHoleIndex: Int,
                          holeScores: [Int],
                          holePars: [Int],
                          puttCounts: [Int]) -> RoundSnapshot
    {
        RoundSnapshot(holeCount: 18,
                      startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: nil,
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: puttCounts)
    }

    @Test func 말단의_미기록_홀이_제거된다() {
        let trimmed = snapshot(currentHoleIndex: 4,
                               holeScores: [4, 5, 0, 0, 0],
                               holePars: [4, 5, 0, 0, 0],
                               puttCounts: [2, 2, 0, 0, 0]).trimmed()

        #expect(trimmed.holeScores == [4, 5])
        #expect(trimmed.holePars == [4, 5])
        #expect(trimmed.puttCounts == [2, 2])
    }

    @Test func 중간에_낀_미기록_홀은_보존된다() {
        // 사용자가 의도적으로 건너뛴 홀일 수 있다.
        let trimmed = snapshot(currentHoleIndex: 3,
                               holeScores: [4, 0, 5, 0],
                               holePars: [4, 0, 5, 0],
                               puttCounts: [2, 0, 2, 0]).trimmed()

        #expect(trimmed.holePars == [4, 0, 5])
    }

    @Test func 전부_미기록이면_빈_배열이_된다() {
        let trimmed = snapshot(currentHoleIndex: 2,
                               holeScores: [0, 0, 0],
                               holePars: [0, 0, 0],
                               puttCounts: [0, 0, 0]).trimmed()

        #expect(trimmed.holeScores.isEmpty)
        #expect(trimmed.holePars.isEmpty)
        #expect(trimmed.puttCounts.isEmpty)
        #expect(trimmed.currentHoleIndex == 0)
    }

    @Test func 트림하면_현재홀_인덱스가_남은_범위로_클램프된다() {
        let trimmed = snapshot(currentHoleIndex: 4,
                               holeScores: [4, 5, 0, 0, 0],
                               holePars: [4, 5, 0, 0, 0],
                               puttCounts: [2, 2, 0, 0, 0]).trimmed()

        #expect(trimmed.currentHoleIndex == 1)
    }

    @Test func 트림할게_없으면_그대로다() {
        let original = snapshot(currentHoleIndex: 1,
                                holeScores: [4, 5],
                                holePars: [4, 5],
                                puttCounts: [2, 2])

        #expect(original.trimmed() == original)
    }

    @Test func 기록홀수는_파와타수가_모두있는_홀_개수다() {
        let value = snapshot(currentHoleIndex: 4,
                             holeScores: [4, 5, 0, 0, 0],
                             holePars: [4, 5, 0, 0, 0],
                             puttCounts: [2, 2, 0, 0, 0])

        #expect(value.recordedHoleCount == 2)
    }

    @Test func 아무것도_치지_않았으면_기록홀수가_0이다() {
        let value = snapshot(currentHoleIndex: 0,
                             holeScores: [0],
                             holePars: [0],
                             puttCounts: [0])

        #expect(value.recordedHoleCount == 0)
    }

    @Test func 기록홀수_중간에_건너뛴홀은_세지않는다() {
        // 3번 홀을 건너뛴 상태(파 0)가 배열 중간에 남아 있다.
        let value = snapshot(currentHoleIndex: 3,
                             holeScores: [4, 5, 0, 3],
                             holePars: [4, 5, 0, 3],
                             puttCounts: [2, 2, 0, 1])

        // 옛 공식(trimmed().holePars.count)이라면 말단만 자르므로 4가 나온다.
        #expect(value.recordedHoleCount == 3)
    }

    @Test func 기록홀수_파만고르고_한타도치지않은홀은_세지않는다() {
        // 3번 홀은 파만 고르고 종료한 홀 — 워치 종료 경로로 만들 수 있다 (spec §4.1).
        let value = snapshot(currentHoleIndex: 2,
                             holeScores: [4, 5, 0],
                             holePars: [4, 5, 4],
                             puttCounts: [2, 2, 0])

        // 옛 정의(파가 있는 홀 개수)라면 3이 나온다.
        #expect(value.recordedHoleCount == 2)
    }
}
