/// 크라운 회전을 점수로 바꾸는 관문. 한 번 돌리기(크라운이 멈출 때까지)에 최대 1점만 통과시킨다.
///
/// 회전량만큼 점수를 넣던 첫 구현은 크라운을 한 번 돌리면 세트 스코어가 4까지 올라갔다 (1.1.8 실기기).
/// 회전량 단위가 감도·범위에 따라 달라 "몇 칸 = 몇 점"을 믿을 수 없으므로, 기준값을 넘는 순간
/// 한 점만 넣고 크라운이 멈출 때까지 잠근다.
struct CrownPointGate {
    /// 실기기에서 맞춘 값이 아니라 추정치다 — 너무 둔하거나 예민하면 이 값만 바꾼다.
    /// 라켓 쥔 손목이 스쳐도 들어가지 않도록 보수적으로(많이 돌려야 들어가게) 잡는다.
    static let defaultThreshold = 30.0

    let threshold: Double
    private var isLocked = false

    init(threshold: Double = Self.defaultThreshold) {
        self.threshold = threshold
    }

    /// `offset` 은 이번 회전을 시작한 뒤의 누적 회전량. 위(+)는 내 점수, 아래(-)는 상대 점수.
    /// 기준값을 처음 넘는 순간 한 번만 방향을 돌려주고, 그 뒤로는 `idle()` 전까지 nil.
    mutating func rotate(to offset: Double) -> PlayerSide? {
        guard !isLocked, abs(offset) >= threshold else { return nil }
        isLocked = true
        return offset > 0 ? .me : .opponent
    }

    /// 크라운이 멈췄다. 다음 회전은 새로 센다.
    mutating func idle() {
        isLocked = false
    }
}
