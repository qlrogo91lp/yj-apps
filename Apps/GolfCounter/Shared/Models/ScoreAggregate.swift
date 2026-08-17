import Foundation

/// 홀 배열에서 라운드 지표를 집계한다.
/// iOS(`GolfRound`)와 워치(`RoundSnapshot`)가 같은 규칙을 쓰도록 계산을 한 곳에 모아 둔다 (history spec §3).
enum ScoreAggregate {
    /// 집계 대상 홀(`par > 0 && score > 0`)에 대해서만 `Σ(score − par)`.
    ///
    /// 두 종류의 홀을 뺀다 (history spec §3):
    /// - `par == 0` — 파 선택 화면을 넘기지 않은 홀. 양쪽 합에 0으로 기여해 원래도 무해했다.
    /// - `score == 0` — 파는 골랐지만 한 타도 치지 않고 넘어간 홀. 넣으면 `0 − par`가
    ///   그대로 언더파로 새어 들어가 버디로 잘못 집계된다.
    ///
    /// 배열 길이가 다르면 짧은 쪽까지만 본다 — 파를 아직 안 고른 말단 홀을 자동으로 무시한다.
    static func relativeToPar(holeScores: [Int], holePars: [Int]) -> Int {
        zip(holeScores, holePars)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .reduce(0) { $0 + $1.0 - $1.1 }
    }

    /// 집계 대상 홀(`par > 0 && score > 0`)의 개수.
    ///
    /// `relativeToPar`와 **같은 필터**를 쓴다 — 두 지표가 항상 같은 홀 집합을 본다 (invariant spec §7.1).
    /// 파만 고르고 한 타도 치지 않은 홀은 세지 않는다: 저장·전송 경계에서 정규화되어
    /// 사라질 홀이므로, 세면 홀 수와 오버파가 다른 홀 집합을 보게 된다.
    ///
    /// 배열 길이가 다르면 짧은 쪽까지만 본다 — `relativeToPar`와 같다.
    static func recordedHoleCount(holeScores: [Int], holePars: [Int]) -> Int {
        zip(holeScores, holePars)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .count
    }

    /// 집계 대상 홀(`par > 0 && score > 0`)의 파·타수·퍼팅을 모은다.
    ///
    /// `relativeToPar`·`recordedHoleCount`와 **같은 필터**를 쓴다 — 홀 단위 통계(스코어 분포·
    /// 파별 성적·홀당 퍼트)가 라운드 단위 지표와 다른 홀 집합을 보지 않게 한다.
    ///
    /// `puttCounts`가 짧으면 그 홀의 퍼팅은 0으로 본다 — 파·타수 배열의 길이만 대상 홀을
    /// 정하고, 퍼팅 배열은 방어적으로만 읽는다. `holeScores`·`holePars` 길이가 다르면
    /// `relativeToPar`와 같은 규칙으로 짧은 쪽까지만 본다.
    static func countedHoles(holeScores: [Int],
                             holePars: [Int],
                             puttCounts: [Int]) -> [(par: Int, score: Int, putts: Int)]
    {
        zip(holeScores, holePars).enumerated().compactMap { index, pair in
            let (score, par) = pair
            guard par > 0, score > 0 else { return nil }
            let putts = index < puttCounts.count ? puttCounts[index] : 0
            return (par: par, score: score, putts: putts)
        }
    }
}
