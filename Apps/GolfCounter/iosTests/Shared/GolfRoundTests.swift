import Foundation
@testable import GolfCounter
import Testing

struct GolfRoundTests {
    @Test func 파생합계_홀배열로부터_계산된다() {
        let round = GolfRound()
        round.holeScores = [4, 3, 6]
        round.holePars = [4, 3, 5]
        round.puttCounts = [2, 1, 2]

        #expect(round.totalStrokes == 13)
        #expect(round.totalPutts == 5)
        #expect(round.totalPar == 12)
        #expect(round.relativeToPar == 1)
    }

    @Test func 빈라운드_합계는_전부0이다() {
        let round = GolfRound()

        #expect(round.totalStrokes == 0)
        #expect(round.totalPutts == 0)
        #expect(round.totalPar == 0)
        #expect(round.relativeToPar == 0)
        #expect(round.endedAt == nil)
        #expect(round.courseName == nil)
    }

    @Test func holePars가_holeScores보다_짧으면_초과홀은_무시된다() {
        let round = GolfRound()
        // 4번째 홀은 스코어만 있고 파가 아직 기록되지 않은 상태(배열 길이 불일치)를 시뮬레이션한다.
        round.holeScores = [4, 3, 6, 5]
        round.holePars = [4, 3, 5]

        // 옛 공식(totalStrokes - holePars.reduce(0,+))이라면 18 - 12 = 6 이 되어 완전히 틀린 값을 낸다.
        // 새 공식은 짝지어지는 앞 3홀만 더해 0 + 0 + 1 = 1 이어야 한다.
        #expect(round.relativeToPar == 1)
    }

    @Test func recordedHoleCount_파와타수가_모두있는홀만_센다() {
        let round = GolfRound()
        round.holeScores = [4, 3, 0, 5]
        // 3번째 홀은 워치에서 건너뛴 홀 — par와 타수가 모두 0이라 세지 않는다.
        round.holePars = [4, 3, 0, 5]
        round.puttCounts = [2, 1, 0, 2]

        #expect(round.recordedHoleCount == 3)
        #expect(round.isFullRound == false)
    }

    @Test func isFullRound_파가18개면_참이다() {
        let round = GolfRound()
        round.holeScores = Array(repeating: 5, count: 18)
        round.holePars = Array(repeating: 4, count: 18)
        round.puttCounts = Array(repeating: 2, count: 18)

        #expect(round.recordedHoleCount == 18)
        #expect(round.isFullRound == true)
    }

    @Test func isFullRound_18홀중_일부만기록되면_거짓이다() {
        let round = GolfRound()
        round.holeScores = Array(repeating: 5, count: 9)
        round.holePars = Array(repeating: 4, count: 9)
        round.puttCounts = Array(repeating: 2, count: 9)

        #expect(round.recordedHoleCount == 9)
        #expect(round.isFullRound == false)
    }

    @Test func 파만고르고_한타도치지않은홀은_오버파에_반영되지않는다() {
        let round = GolfRound()
        // 3번 홀은 파만 고르고 넘어간 홀 — 워치 종료 직전이나 iOS 홀 편집으로 만들 수 있다.
        round.holeScores = [4, 3, 0]
        round.holePars = [4, 3, 4]
        round.puttCounts = [2, 1, 0]

        // 옛 공식이라면 0 − 4 = −4가 새어 들어간다.
        #expect(round.relativeToPar == 0)
        // 기록 홀 수도 오버파와 같은 필터를 쓴다 — 이 홀은 어느 쪽에도 안 들어간다 (spec §7.1).
        #expect(round.recordedHoleCount == 2)
    }
}
