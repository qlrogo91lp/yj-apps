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
}
