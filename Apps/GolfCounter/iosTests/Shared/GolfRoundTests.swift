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
}
