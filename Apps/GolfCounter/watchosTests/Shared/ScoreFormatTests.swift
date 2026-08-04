import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct ScoreFormatTests {
    @Test func 이븐파는_E로_표시한다() {
        #expect(ScoreFormat.relativeToPar(0) == "E")
    }

    @Test func 오버파는_플러스부호를_붙인다() {
        #expect(ScoreFormat.relativeToPar(3) == "+3")
    }

    @Test func 언더파는_음수부호를_유지한다() {
        #expect(ScoreFormat.relativeToPar(-2) == "-2")
    }
}
