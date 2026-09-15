@testable import TennisCounter_Watch_App
import Testing

struct CrownPointGateTests {

    @Test func largeJumpYieldsSinglePoint() {
        // 버그 재현: 크라운 한 번에 회전량이 크게 튀면 그만큼 점수가 들어가 세트 스코어가 4까지 올랐다.
        var gate = CrownPointGate(threshold: 30)
        #expect(gate.rotate(to: 100) == .me)
        #expect(gate.rotate(to: 250) == nil)
        #expect(gate.rotate(to: 400) == nil)
    }

    @Test func belowThresholdYieldsNothing() {
        var gate = CrownPointGate(threshold: 30)
        #expect(gate.rotate(to: 10) == nil)
        #expect(gate.rotate(to: 29) == nil)
    }

    @Test func gradualRotationYieldsPointAtThreshold() {
        var gate = CrownPointGate(threshold: 30)
        #expect(gate.rotate(to: 15) == nil)
        #expect(gate.rotate(to: 30) == .me)
    }

    @Test func downwardRotationYieldsOpponent() {
        var gate = CrownPointGate(threshold: 30)
        #expect(gate.rotate(to: -30) == .opponent)
    }

    @Test func reversalWithinGestureIsIgnored() {
        var gate = CrownPointGate(threshold: 30)
        #expect(gate.rotate(to: 50) == .me)
        #expect(gate.rotate(to: -50) == nil)
    }

    @Test func idleUnlocksNextGesture() {
        var gate = CrownPointGate(threshold: 30)
        #expect(gate.rotate(to: 100) == .me)
        gate.idle()
        #expect(gate.rotate(to: 100) == .me)
    }
}
