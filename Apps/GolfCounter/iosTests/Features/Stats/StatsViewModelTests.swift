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

    private func bucketCount(_ summary: StatsSummary, _ bucket: StatsSummary.Bucket) -> Int {
        summary.distribution.first { $0.bucket == bucket }?.count ?? -1
    }

    @Test func 홀당퍼트는_9홀과18홀을_함께센다() {
        // 18홀 × 2퍼트 + 9홀 × 1퍼트 = 45퍼트 / 27홀
        let rounds = [makeFullRound(daysAgo: 0, scorePerHole: 5, puttsPerHole: 2),
                      makeHalfRound(daysAgo: 1, scorePerHole: 5, puttsPerHole: 1)]

        let summary = StatsViewModel().summary(from: rounds)

        let puttsPerHole = summary.puttsPerHole ?? 0
        #expect(abs(puttsPerHole - 45.0 / 27.0) < 0.0001)
    }

    @Test func 스코어분포_네구간의_경계가_정확하다() {
        // Par 4 홀에서 3타(버디)·4타(파)·5타(보기)·6타(더블)·7타(더블+)
        let round = makeRound(daysAgo: 0,
                              pars: [4, 4, 4, 4, 4],
                              scores: [3, 4, 5, 6, 7],
                              putts: [1, 2, 2, 3, 3])

        let summary = StatsViewModel().summary(from: [round])

        #expect(bucketCount(summary, .birdieOrBetter) == 1)
        #expect(bucketCount(summary, .par) == 1)
        #expect(bucketCount(summary, .bogey) == 1)
        #expect(bucketCount(summary, .doubleOrWorse) == 2)
        #expect(summary.distribution.count == 4)
    }

    @Test func 스코어분포_비율은_집계대상홀기준이다() {
        let round = makeRound(daysAgo: 0, pars: [4, 4], scores: [4, 5], putts: [2, 2])

        let summary = StatsViewModel().summary(from: [round])

        let parBucket = summary.distribution.first { $0.bucket == .par }
        #expect(parBucket?.ratio == 0.5)
    }

    @Test func 파가0인홀은_모든집계에서_빠진다() {
        // 2번 홀은 워치에서 건너뛴 홀(par 0)이다.
        let round = makeRound(daysAgo: 0, pars: [4, 0, 3], scores: [4, 0, 3], putts: [2, 0, 1])

        let summary = StatsViewModel().summary(from: [round])

        #expect(bucketCount(summary, .par) == 2)
        #expect(bucketCount(summary, .birdieOrBetter) == 0)
        #expect(summary.puttsPerHole == 1.5)
    }

    @Test func 타수가0인홀은_버디로_집계되지않는다() {
        // 파는 골랐지만 한 타도 안 치고 넘어간 홀. score - par = -4라 그냥 넣으면 버디가 된다.
        let round = makeRound(daysAgo: 0, pars: [4, 4], scores: [4, 0], putts: [2, 0])

        let summary = StatsViewModel().summary(from: [round])

        #expect(bucketCount(summary, .birdieOrBetter) == 0)
        #expect(bucketCount(summary, .par) == 1)
        #expect(summary.puttsPerHole == 2)
    }

    @Test func 파별성적은_par345를_항상_세칸으로_돌려준다() {
        // Par 3에서 +1, Par 4에서 +1과 +3(평균 +2), Par 5는 친 적 없음
        let round = makeRound(daysAgo: 0,
                              pars: [3, 4, 4],
                              scores: [4, 5, 7],
                              putts: [2, 2, 3])

        let summary = StatsViewModel().summary(from: [round])

        #expect(summary.parPerformance.map(\.par) == [3, 4, 5])
        #expect(summary.parPerformance.map(\.averageOverPar) == [1, 2, nil])
    }

    @Test func 집계대상홀이없으면_홀단위지표가_비어있다() {
        let round = makeRound(daysAgo: 0, pars: [0, 0], scores: [0, 0], putts: [0, 0])

        let summary = StatsViewModel().summary(from: [round])

        #expect(summary.puttsPerHole == nil)
        #expect(summary.distribution.allSatisfy { $0.count == 0 && $0.ratio == 0 })
        #expect(summary.parPerformance.allSatisfy { $0.averageOverPar == nil })
    }
}
