import Foundation
@testable import GolfCounter
import Testing

struct ScoreFormatAverageTests {
    @Test func 양수평균은_플러스부호와_소수한자리다() {
        #expect(ScoreFormat.averageRelativeToPar(18.64) == "+18.6")
        #expect(ScoreFormat.averageRelativeToPar(1.25) == "+1.3")
    }

    @Test func 음수평균은_마이너스부호와_소수한자리다() {
        #expect(ScoreFormat.averageRelativeToPar(-2.34) == "-2.3")
    }

    @Test func 반올림해서0이되면_E로_표기한다() {
        #expect(ScoreFormat.averageRelativeToPar(0) == "E")
        #expect(ScoreFormat.averageRelativeToPar(0.04) == "E")
        #expect(ScoreFormat.averageRelativeToPar(-0.04) == "E")
    }
}
