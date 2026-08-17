import Foundation
@testable import GolfCounter
import Testing

@MainActor
struct StatsViewModelTests {
    /// 파·타수·퍼팅을 홀 단위로 지정해 라운드를 만든다.
    private func makeRound(daysAgo: Int,
                           pars: [Int],
                           scores: [Int],
                           putts: [Int]) -> GolfRound
    {
        let round = GolfRound()
        round.startedAt = Date(timeIntervalSince1970: 1_000_000 - Double(daysAgo) * 86400)
        round.holePars = pars
        round.holeScores = scores
        round.puttCounts = putts
        return round
    }

    /// 18홀 라운드 하나. 모든 홀이 Par 4이고 타수·퍼팅은 균일하다.
    private func makeFullRound(daysAgo: Int, scorePerHole: Int, puttsPerHole: Int = 2) -> GolfRound {
        makeRound(daysAgo: daysAgo,
                  pars: Array(repeating: 4, count: 18),
                  scores: Array(repeating: scorePerHole, count: 18),
                  putts: Array(repeating: puttsPerHole, count: 18))
    }

    /// 9홀 라운드 하나.
    private func makeHalfRound(daysAgo: Int, scorePerHole: Int, puttsPerHole: Int = 2) -> GolfRound {
        makeRound(daysAgo: daysAgo,
                  pars: Array(repeating: 4, count: 9),
                  scores: Array(repeating: scorePerHole, count: 9),
                  putts: Array(repeating: puttsPerHole, count: 9))
    }

    @Test func 라운드가없으면_전지표가_비어있다() {
        let summary = StatsViewModel().summary(from: [])

        #expect(summary.roundCount == 0)
        #expect(summary.fullRoundCount == 0)
        #expect(summary.trend.isEmpty)
        #expect(summary.averageStrokes == nil)
        #expect(summary.averageOverPar == nil)
        #expect(summary.best == nil)
    }

    @Test func 라운드가하나면_추이점이_하나다() {
        let summary = StatsViewModel().summary(from: [makeFullRound(daysAgo: 0, scorePerHole: 5)])

        #expect(summary.trend.count == 1)
        #expect(summary.trend[0].relativeToPar == 18)
        #expect(summary.trend[0].isFullRound == true)
        #expect(summary.averageStrokes == 90)
    }

    @Test func 평균타수와평균오버파는_18홀라운드만_집계한다() {
        // 18홀 두 개(90타/72타)와 9홀 하나. 9홀이 섞이면 평균 타수가 무너진다.
        let rounds = [makeFullRound(daysAgo: 0, scorePerHole: 5),
                      makeFullRound(daysAgo: 1, scorePerHole: 4),
                      makeHalfRound(daysAgo: 2, scorePerHole: 5)]

        let summary = StatsViewModel().summary(from: rounds)

        #expect(summary.roundCount == 3)
        #expect(summary.fullRoundCount == 2)
        #expect(summary.averageStrokes == 81)
        #expect(summary.averageOverPar == 9)
    }

    @Test func 풀라운드가없으면_라운드단위지표가_nil이다() {
        let summary = StatsViewModel().summary(from: [makeHalfRound(daysAgo: 0, scorePerHole: 5)])

        #expect(summary.roundCount == 1)
        #expect(summary.fullRoundCount == 0)
        #expect(summary.averageStrokes == nil)
        #expect(summary.averageOverPar == nil)
        // 베스트는 9홀도 대상이다 — 대신 홀 수를 함께 들고 온다.
        #expect(summary.best?.relativeToPar == 9)
        #expect(summary.best?.holeCount == 9)
    }

    @Test func 베스트는_오버파가_가장낮은라운드다() {
        let rounds = [makeFullRound(daysAgo: 0, scorePerHole: 5),
                      makeFullRound(daysAgo: 1, scorePerHole: 4)]

        let summary = StatsViewModel().summary(from: rounds)

        #expect(summary.best?.relativeToPar == 0)
        #expect(summary.best?.holeCount == 18)
    }

    @Test func 베스트가동률이면_최신라운드를_고른다() {
        let newer = makeFullRound(daysAgo: 0, scorePerHole: 4)
        let older = makeFullRound(daysAgo: 5, scorePerHole: 4)

        let summary = StatsViewModel().summary(from: [older, newer])

        #expect(summary.best?.relativeToPar == 0)
        #expect(summary.trend.last?.id == newer.id)
    }

    @Test func 추이는_최근10라운드만_오래된순으로_담는다() {
        let rounds = (0 ..< 12).map { makeFullRound(daysAgo: $0, scorePerHole: 5) }

        let summary = StatsViewModel().summary(from: rounds)

        #expect(summary.roundCount == 12)
        #expect(summary.trend.count == 10)
        // daysAgo가 클수록 과거다 — 배열 맨 앞이 가장 오래된 점이어야 한다.
        #expect(summary.trend[0].date < summary.trend[9].date)
        #expect(summary.trend[9].date == rounds[0].startedAt)
    }

    @Test func 중단된라운드는_18홀라운드로_치지않는다() {
        // 18홀을 골랐지만 3홀만 치고 끝낸 라운드.
        let partial = makeRound(daysAgo: 0, pars: [4, 4, 3], scores: [5, 4, 3], putts: [2, 2, 1])

        let summary = StatsViewModel().summary(from: [partial])

        #expect(summary.fullRoundCount == 0)
        #expect(summary.averageStrokes == nil)
        #expect(summary.trend[0].isFullRound == false)
    }
}
