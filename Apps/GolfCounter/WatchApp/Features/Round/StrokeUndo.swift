import Foundation

/// 현재 홀에서 되돌릴 수 있는 입력 기록 (spec §7).
///
/// 되돌리기 스코프가 현재 홀이라는 규칙이 이 타입의 생명주기로 표현된다 —
/// 홀을 옮기면 `RoundViewModel`이 `clear()`를 부른다.
struct StrokeUndo: Equatable {
    /// 현재 홀에서 친 타의 종류 순서. 되돌리기의 유일한 상태다.
    ///
    /// `incrementStroke()`가 하는 일이 모드에 따라 (타수 +1) 또는 (타수 +1, 퍼트 +1)
    /// 두 가지뿐이므로, 어느 쪽이었는지만 알면 정확히 되돌릴 수 있다. 배열 전체를
    /// 복사할 필요가 없다.
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
