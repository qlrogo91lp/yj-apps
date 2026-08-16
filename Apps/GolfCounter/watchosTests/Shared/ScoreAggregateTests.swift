import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct ScoreAggregateTests {
    @Test func 파와타수가_모두있는홀만_합산한다() {
        let value = ScoreAggregate.relativeToPar(holeScores: [4, 3, 6],
                                                 holePars: [4, 3, 5])

        #expect(value == 1)
    }

    @Test func 파는골랐지만_타수가0인홀은_제외한다() {
        // 파만 고르고 한 타도 치지 않고 넘어간 홀. 옛 공식이라면 0 − 4 = −4가 새어 든다.
        let value = ScoreAggregate.relativeToPar(holeScores: [4, 0],
                                                 holePars: [4, 4])

        #expect(value == 0)
    }

    @Test func 파가0인홀은_제외한다() {
        // 파 선택 화면을 넘기지 않은 홀. 원래도 0으로 기여했지만 규칙으로 명시한다.
        let value = ScoreAggregate.relativeToPar(holeScores: [4, 0, 5],
                                                 holePars: [4, 0, 4])

        #expect(value == 1)
    }

    @Test func 배열길이가_다르면_짧은쪽까지만_본다() {
        // 타수는 쳤지만 파가 아직 배열에 없는 말단 홀을 자동으로 무시한다.
        let value = ScoreAggregate.relativeToPar(holeScores: [4, 3, 6, 5],
                                                 holePars: [4, 3, 5])

        #expect(value == 1)
    }

    @Test func 빈배열은_0이다() {
        #expect(ScoreAggregate.relativeToPar(holeScores: [], holePars: []) == 0)
    }
}
