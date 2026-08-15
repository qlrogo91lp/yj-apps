import Foundation

/// 라운드에 무엇이 기록됐는지 — 홀별 타수·파·퍼트와 현재 홀 위치 (spec §3).
///
/// 홀 데이터는 관계가 아니라 **병렬 배열**이다(인덱스 = 홀 번호 - 1). 세 배열의
/// 길이가 항상 같아야 한다는 불변식을 이 타입이 책임진다 — 홀을 늘리는 경로가
/// `advanceToNextHole()`과 복구 `init` 둘뿐이고, 양쪽 다 용량을 함께 맞춘다.
struct HoleProgress: Equatable {
    /// 이 라운드의 홀 수 상한 (9 또는 18). 중간 변경·연장은 없다 (spec §3.1).
    /// 기본값을 두지 않는 이유: 상한 없는 HoleProgress는 의미가 없다.
    let holeCount: Int
    private(set) var holeScores: [Int]
    private(set) var holePars: [Int]
    private(set) var puttCounts: [Int]
    private(set) var currentHoleIndex: Int

    init(holeCount: Int) {
        self.holeCount = holeCount
        holeScores = [0]
        holePars = [0]
        puttCounts = [0]
        currentHoleIndex = 0
    }

    /// 스냅샷 복구용 (spec §12). 길이가 어긋난 값이 들어와도 현재 홀까지 용량을 맞춘다.
    init(holeCount: Int, holeScores: [Int], holePars: [Int], puttCounts: [Int], currentHoleIndex: Int) {
        self.holeCount = holeCount
        self.holeScores = holeScores
        self.holePars = holePars
        self.puttCounts = puttCounts
        self.currentHoleIndex = max(currentHoleIndex, 0)
        ensureCapacityForCurrentHole()
    }

    // MARK: - 현재 홀

    var currentHoleNumber: Int {
        currentHoleIndex + 1
    }

    var currentScore: Int {
        holeScores[currentHoleIndex]
    }

    var currentPutts: Int {
        puttCounts[currentHoleIndex]
    }

    /// 0은 "아직 파가 설정되지 않음"을 뜻한다.
    var currentPar: Int {
        holePars[currentHoleIndex]
    }

    var canGoToPreviousHole: Bool {
        currentHoleIndex > 0
    }

    var canGoToNextHole: Bool {
        currentHoleIndex + 1 < holeCount
    }

    /// 현재 홀이 "방금 만들어졌고 아직 아무것도 입력되지 않은" phantom hole 상태인지 판단한다.
    /// 세 배열의 마지막 원소가 현재 홀과 정확히 일치할 때만 안전하게 pop할 수 있다.
    ///
    /// 파 편집 중(`isEditingPar`) 여부는 여기 조건에 없다 — 그것은 `RoundViewModel`의
    /// 상태이므로 호출부가 판단한다. 이 타입은 "기록 상태" 사실만 본다.
    var isPristinePhantomHole: Bool {
        currentScore == 0
            && currentPar == 0
            && currentPutts == 0
            && currentHoleIndex == holeScores.count - 1
            && currentHoleIndex == holePars.count - 1
            && currentHoleIndex == puttCounts.count - 1
    }

    // MARK: - 카운터

    mutating func apply(_ mode: StrokeInputMode) {
        switch mode {
        case .swing:
            holeScores[currentHoleIndex] += 1
        case .putt:
            holeScores[currentHoleIndex] += 1
            puttCounts[currentHoleIndex] += 1
        }
    }

    /// `apply`의 정확한 역연산.
    mutating func revert(_ mode: StrokeInputMode) {
        holeScores[currentHoleIndex] -= 1
        if mode == .putt {
            puttCounts[currentHoleIndex] -= 1
        }
    }

    mutating func setPar(_ par: Int) {
        holePars[currentHoleIndex] = par
    }

    // MARK: - 홀 이동

    mutating func advanceToNextHole() {
        guard canGoToNextHole else { return }
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
    }

    mutating func retreatToPreviousHole() {
        currentHoleIndex -= 1
    }

    /// 말단 phantom hole을 배열에서 제거하고 이전 홀로 돌아간다.
    /// 호출 전 `isPristinePhantomHole` 확인이 필수다 — 아니면 기록된 홀이 날아간다.
    mutating func removePhantomHoleAndRetreat() {
        holeScores.removeLast()
        holePars.removeLast()
        puttCounts.removeLast()
        currentHoleIndex -= 1
    }

    /// 홀 배열 세 개의 길이를 현재 홀까지 맞춘다. 세 배열은 항상 같은 길이를 유지한다.
    private mutating func ensureCapacityForCurrentHole() {
        let needed = currentHoleIndex + 1
        while holeScores.count < needed {
            holeScores.append(0)
        }
        while holePars.count < needed {
            holePars.append(0)
        }
        while puttCounts.count < needed {
            puttCounts.append(0)
        }
    }
}
