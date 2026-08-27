import Foundation

/// 홀 편집 시트의 상태. 워치 카운터와 같은 불변식(타수 ≥ 퍼팅 ≥ 0, 상한 없음)을 강제한다 (history spec §4).
/// UI 프레임워크를 import하지 않아 시트 없이 테스트할 수 있다.
struct RoundEditViewModel: Equatable {
    /// 파 선택지. 워치 파 선택 화면과 같은 3개다.
    static let parOptions = [3, 4, 5]

    private(set) var par: Int
    private(set) var score: Int
    private(set) var putts: Int

    init(par: Int, score: Int, putts: Int) {
        self.par = max(0, par)
        self.putts = max(0, putts)
        // 깨진 데이터가 들어와도 불변식을 지킨 상태에서 편집을 시작한다.
        self.score = max(self.putts, max(0, score))
    }

    var canDecrementScore: Bool {
        score > putts
    }

    var canDecrementPutts: Bool {
        putts > 0
    }

    /// 저장 버튼 활성화 조건. `par == 0 && score > 0`("해석 불가" 상태, invariant spec §3)이
    /// 저장될 수 없다는 불변식의 나머지 절반이다 — `HoleEditSheet`는 그리기만 한다.
    var isSaveable: Bool {
        Self.parOptions.contains(par)
    }

    mutating func setPar(_ newPar: Int) {
        guard Self.parOptions.contains(newPar) else { return }
        par = newPar
    }

    /// 상한을 두지 않는다 — par×2 제한은 폐기됐다 (history spec §4).
    mutating func incrementScore() {
        score += 1
    }

    mutating func decrementScore() {
        score = max(putts, score - 1)
    }

    /// 타수가 모자라면 함께 올린다 — 워치 퍼팅 모드 `+`와 같은 동작이다.
    mutating func incrementPutts() {
        putts += 1
        score = max(score, putts)
    }

    mutating func decrementPutts() {
        putts = max(0, putts - 1)
    }

    /// 편집 결과를 라운드의 병렬 배열에 되쓴다.
    /// `holeScores`에 없는 홀은 존재하지 않는 홀이므로 무시하고, 나머지 두 배열이 짧으면 0으로 채운다.
    ///
    /// 타수가 0이면 파도 0으로 쓴다 — 저장 경계에서의 정규화다 (invariant spec §5.4).
    /// 덕분에 타수를 0까지 내리는 것이 "이 홀은 사실 안 쳤다"의 구제 경로가 된다 —
    /// 라운드가 끝난 뒤 워치 오기록을 고칠 수 있는 유일한 지점이다.
    func apply(to round: GolfRound, holeIndex: Int) {
        guard holeIndex >= 0, holeIndex < round.holeScores.count else { return }
        let count = round.holeScores.count

        var pars = Self.padded(round.holePars, to: count)
        var putts = Self.padded(round.puttCounts, to: count)
        pars[holeIndex] = score > 0 ? par : 0
        putts[holeIndex] = self.putts

        round.holeScores[holeIndex] = score
        round.holePars = pars
        round.puttCounts = putts
    }

    private static func padded(_ array: [Int], to count: Int) -> [Int] {
        guard array.count < count else { return array }
        return array + Array(repeating: 0, count: count - array.count)
    }
}
