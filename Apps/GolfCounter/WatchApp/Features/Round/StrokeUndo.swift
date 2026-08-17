import Foundation

/// 현재 홀에서 되돌릴 수 있는 입력 기록 (spec §7).
/// 되돌리기 스코프가 현재 홀이라 홀을 옮기면 `RoundViewModel`이 `clear()`를 부른다.
struct StrokeUndo: Equatable {
    /// 현재 홀에서 친 타의 종류 순서. 되돌리기의 유일한 상태다 — `incrementStroke()`가
    /// 모드에 따라 두 가지 일만 하므로, 어느 쪽이었는지만 알면 정확히 되돌릴 수 있다.
    private(set) var history: [StrokeInputMode] = []

    var canUndo: Bool {
        !history.isEmpty
    }

    mutating func record(_ mode: StrokeInputMode) {
        history.append(mode)
    }

    mutating func pop() -> StrokeInputMode? {
        history.popLast()
    }

    mutating func clear() {
        history.removeAll()
    }
}
