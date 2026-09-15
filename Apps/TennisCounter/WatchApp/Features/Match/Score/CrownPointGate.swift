/// 크라운 디텐트(딸깍)를 점수로 바꾸는 관문. 한 번 돌리기(크라운이 멈출 때까지)에 최대 1점만 통과시킨다.
///
/// 회전량을 직접 재던 앞선 두 구현은 회전량 단위가 감도·범위에 따라 달라 매번 빗나갔다 —
/// 처음엔 한 번에 4점이 들어갔고(1.1.8), 기준값을 세우자 몇 바퀴를 돌려야 1점이 됐다.
/// 디텐트는 시스템이 "한 칸"을 정해 주므로 단위를 추측할 필요가 없다.
struct CrownPointGate {
    /// 직전 디텐트 값. 첫 값은 기준점으로만 삼고 점수를 내지 않는다 —
    /// 화면에 들어올 때 0 이 아닌 값이 한 번 흘러와도 점수가 되지 않게.
    private var lastDetent: Double?
    private var isLocked = false

    /// 디텐트 값이 바뀌면 방향을 돌려준다. 위(증가)는 내 점수, 아래(감소)는 상대 점수.
    /// 여러 칸이 한꺼번에 뛰어도 1점이다 — 빠르게 돌렸을 때 점수가 쏟아지지 않게.
    mutating func detentChanged(to value: Double) -> PlayerSide? {
        let previous = lastDetent
        lastDetent = value
        guard let previous, !isLocked, value != previous else { return nil }
        isLocked = true
        return value > previous ? .me : .opponent
    }

    /// 크라운이 멈췄다. 다음 회전은 새로 센다.
    mutating func idle() {
        isLocked = false
    }
}
