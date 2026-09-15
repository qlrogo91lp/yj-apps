@testable import TennisCounter_Watch_App
import Testing

struct CrownPointGateTests {

    /// 첫 값은 기준점 — 화면 진입 때 흘러온 값이 점수가 되면 안 된다.
    private func started(at value: Double = 0) -> CrownPointGate {
        var gate = CrownPointGate()
        _ = gate.detentChanged(to: value)
        return gate
    }

    @Test func firstDetentIsBaselineOnly() {
        var gate = CrownPointGate()
        #expect(gate.detentChanged(to: 7) == nil)
    }

    @Test func oneDetentUpYieldsMyPoint() {
        var gate = started()
        #expect(gate.detentChanged(to: 1) == .me)
    }

    @Test func oneDetentDownYieldsOpponentPoint() {
        var gate = started()
        #expect(gate.detentChanged(to: -1) == .opponent)
    }

    @Test func multipleDetentsInOneGestureYieldSinglePoint() {
        // 버그 재현: 빠르게 돌리면 회전량만큼 점수가 들어가 세트 스코어가 4까지 올랐다 (1.1.8 실기기).
        var gate = started()
        #expect(gate.detentChanged(to: 3) == .me)
        #expect(gate.detentChanged(to: 6) == nil)
        #expect(gate.detentChanged(to: 12) == nil)
    }

    @Test func unchangedDetentYieldsNothing() {
        var gate = started(at: 4)
        #expect(gate.detentChanged(to: 4) == nil)
    }

    @Test func idleUnlocksNextGesture() {
        var gate = started()
        #expect(gate.detentChanged(to: 1) == .me)
        gate.idle()
        #expect(gate.detentChanged(to: 2) == .me)
    }

    @Test func idleWithoutRotationYieldsNothing() {
        var gate = started(at: 2)
        gate.idle()
        #expect(gate.detentChanged(to: 2) == nil)
    }
}
