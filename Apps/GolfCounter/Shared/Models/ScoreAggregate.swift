import Foundation

/// 홀 배열에서 라운드 지표를 집계한다.
/// iOS(`GolfRound`)와 워치(`RoundSnapshot`)가 같은 규칙을 쓰도록 계산을 한 곳에 모아 둔다 (history spec §3).
enum ScoreAggregate {
    /// 집계 대상 홀(`par > 0 && score > 0`)에 대해서만 `Σ(score − par)` (history spec §3).
    ///
    /// `score == 0`인 홀(파는 골랐지만 한 타도 안 친 홀)을 넣으면 `0 − par`가 언더파로
    /// 새어 들어가 버디로 잘못 집계된다. 배열 길이가 다르면 짧은 쪽까지만 본다.
    static func relativeToPar(holeScores: [Int], holePars: [Int]) -> Int {
        zip(holeScores, holePars)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .reduce(0) { $0 + $1.0 - $1.1 }
    }

    /// 집계 대상 홀(`par > 0 && score > 0`)의 개수. `relativeToPar`와 **같은 필터**를 써
    /// 두 지표가 항상 같은 홀 집합을 본다 (invariant spec §7.1).
    static func recordedHoleCount(holeScores: [Int], holePars: [Int]) -> Int {
        zip(holeScores, holePars)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .count
    }

    /// 집계 대상 홀(`par > 0 && score > 0`)의 파·타수·퍼팅을 모은다.
    /// `relativeToPar`·`recordedHoleCount`와 **같은 필터**를 쓴다.
    /// `puttCounts`가 짧으면 그 홀의 퍼팅은 0으로 본다 — 대상 홀은 파·타수 배열만 정한다.
    static func countedHoles(holeScores: [Int],
                             holePars: [Int],
                             puttCounts: [Int]) -> [CountedHole]
    {
        zip(holeScores, holePars).enumerated().compactMap { index, pair in
            let (score, par) = pair
            guard par > 0, score > 0 else { return nil }
            let putts = index < puttCounts.count ? puttCounts[index] : 0
            return CountedHole(par: par, score: score, putts: putts)
        }
    }

    struct CountedHole: Equatable {
        let par: Int
        let score: Int
        let putts: Int
    }
}
