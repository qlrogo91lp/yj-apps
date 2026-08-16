import Foundation

/// 홀 배열에서 라운드 지표를 집계한다.
/// iOS(`GolfRound`)와 워치(`RoundSnapshot`)가 같은 규칙을 쓰도록 계산을 한 곳에 모아 둔다 (spec §3).
enum ScoreAggregate {
    /// 집계 대상 홀(`par > 0 && score > 0`)에 대해서만 `Σ(score − par)`.
    ///
    /// 두 종류의 홀을 뺀다 (spec §3):
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
}
