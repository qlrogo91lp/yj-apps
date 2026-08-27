import Foundation

/// 현재 홀에서 되돌릴 수 있는 입력 기록 (spec §7, 2026-08-17 개정 — 홀별 보관).
///
/// 되돌리기의 **의미**는 여전히 "지금 보는 홀의 마지막 입력만"으로 한정된다. 하지만 그
/// 기록의 **수명**은 라운드 전체다 — 홀을 옮겼다 돌아와도 그 홀에서 친 기록은 그대로
/// 남아 있어야 한다(실기 확인, 2026-08-17). `RoundViewModel`은 매 호출마다 현재 홀
/// 인덱스를 함께 넘긴다.
struct StrokeUndo: Equatable {
    private var historyByHole: [Int: [StrokeInputMode]] = [:]

    func history(forHole hole: Int) -> [StrokeInputMode] {
        historyByHole[hole] ?? []
    }

    func canUndo(hole: Int) -> Bool {
        !history(forHole: hole).isEmpty
    }

    mutating func record(_ mode: StrokeInputMode, hole: Int) {
        historyByHole[hole, default: []].append(mode)
    }

    mutating func pop(hole: Int) -> StrokeInputMode? {
        guard var history = historyByHole[hole], !history.isEmpty else { return nil }
        let mode = history.removeLast()
        historyByHole[hole] = history
        return mode
    }
}
