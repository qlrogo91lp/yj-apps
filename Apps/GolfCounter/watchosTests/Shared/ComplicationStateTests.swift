import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct ComplicationStateTests {
    private func makeSnapshot(holeScores: [Int], holePars: [Int], currentHoleIndex: Int) -> RoundSnapshot {
        RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: "테스트CC",
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: [])
    }

    @Test func 스냅샷없으면_비활성이고_값은_0이다() {
        let state = ComplicationState(snapshot: nil)

        #expect(state.isRoundActive == false)
        #expect(state.holeNumber == 0)
        #expect(state.totalStrokes == 0)
        #expect(state.relativeToPar == 0)
    }

    @Test func 스냅샷있으면_활성이고_파생값을_노출한다() {
        let snapshot = makeSnapshot(holeScores: [4, 3, 6], holePars: [4, 3, 5], currentHoleIndex: 2)

        let state = ComplicationState(snapshot: snapshot)

        #expect(state.isRoundActive == true)
        #expect(state.holeNumber == 3)
        #expect(state.totalStrokes == 13)
        #expect(state.relativeToPar == 1)
    }

    @Test func 표시문자열_오버파는_부호를_붙인다() {
        let snapshot = makeSnapshot(holeScores: [4, 3, 6], holePars: [4, 3, 5], currentHoleIndex: 2)

        let state = ComplicationState(snapshot: snapshot)

        #expect(state.holeText == "H3")
        #expect(state.relativeToParText == "+1")
    }

    @Test func 표시문자열_이븐파는_0으로_표시한다() {
        let snapshot = makeSnapshot(holeScores: [4, 3], holePars: [4, 3], currentHoleIndex: 1)

        let state = ComplicationState(snapshot: snapshot)

        #expect(state.relativeToParText == "0")
    }

    @Test func 표시문자열_언더파는_음수부호를_유지한다() {
        let snapshot = makeSnapshot(holeScores: [3, 3], holePars: [4, 3], currentHoleIndex: 1)

        let state = ComplicationState(snapshot: snapshot)

        #expect(state.relativeToParText == "-1")
    }
}
