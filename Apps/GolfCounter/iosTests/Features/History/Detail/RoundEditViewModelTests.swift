import Foundation
@testable import GolfCounter
import Testing

@MainActor
struct RoundEditViewModelTests {
    @Test func 초기화_타수가퍼팅보다작으면_퍼팅까지올린다() {
        let model = RoundEditViewModel(par: 4, score: 1, putts: 3)

        #expect(model.score == 3)
        #expect(model.putts == 3)
    }

    @Test func 타수감소_퍼팅수아래로는_내려가지않는다() {
        var model = RoundEditViewModel(par: 4, score: 3, putts: 3)

        model.decrementScore()

        #expect(model.score == 3)
        #expect(model.canDecrementScore == false)
    }

    @Test func 타수감소_퍼팅보다크면_내려간다() {
        var model = RoundEditViewModel(par: 4, score: 5, putts: 2)

        model.decrementScore()

        #expect(model.score == 4)
        #expect(model.canDecrementScore == true)
    }

    @Test func 퍼팅증가_타수가모자라면_함께올라간다() {
        var model = RoundEditViewModel(par: 4, score: 2, putts: 2)

        model.incrementPutts()

        #expect(model.putts == 3)
        #expect(model.score == 3)
    }

    @Test func 퍼팅감소_0아래로는_내려가지않는다() {
        var model = RoundEditViewModel(par: 4, score: 3, putts: 0)

        model.decrementPutts()

        #expect(model.putts == 0)
        #expect(model.canDecrementPutts == false)
    }

    @Test func 타수증가_상한이없다() {
        var model = RoundEditViewModel(par: 3, score: 6, putts: 1)

        model.incrementScore()
        model.incrementScore()

        // par×2 제한은 폐기됐다 — 실제 골프는 초과할 수 있다 (spec §4).
        #expect(model.score == 8)
    }

    @Test func 파변경_3과4와5만_받는다() {
        var model = RoundEditViewModel(par: 4, score: 5, putts: 2)

        model.setPar(5)
        #expect(model.par == 5)

        model.setPar(7)
        #expect(model.par == 5)
    }

    @Test func 되쓰기_해당홀의_세배열을_모두갱신한다() {
        let round = GolfRound()
        round.holeScores = [4, 5, 3]
        round.holePars = [4, 4, 3]
        round.puttCounts = [2, 2, 1]
        var model = RoundEditViewModel(par: 5, score: 7, putts: 3)

        model.setPar(5)
        model.apply(to: round, holeIndex: 1)

        #expect(round.holeScores == [4, 7, 3])
        #expect(round.holePars == [4, 5, 3])
        #expect(round.puttCounts == [2, 3, 1])
    }

    @Test func 되쓰기_건너뛴홀에_파를넣으면_정상홀이된다() {
        let round = GolfRound()
        round.holeScores = [4, 0, 3]
        round.holePars = [4, 0, 3]
        round.puttCounts = [2, 0, 1]
        var model = RoundEditViewModel(par: 0, score: 0, putts: 0)

        model.setPar(4)
        model.incrementScore()
        model.apply(to: round, holeIndex: 1)

        #expect(round.holePars == [4, 4, 3])
        #expect(round.holeScores == [4, 1, 3])
        #expect(round.recordedHoleCount == 3)
    }

    @Test func 되쓰기_짧은배열은_0으로채워진다() {
        let round = GolfRound()
        round.holeScores = [4, 5, 3]
        round.holePars = [4]
        round.puttCounts = []
        let model = RoundEditViewModel(par: 3, score: 3, putts: 1)

        model.apply(to: round, holeIndex: 2)

        #expect(round.holePars == [4, 0, 3])
        #expect(round.puttCounts == [0, 0, 1])
    }

    @Test func 되쓰기_범위밖인덱스는_무시한다() {
        let round = GolfRound()
        round.holeScores = [4]
        round.holePars = [4]
        round.puttCounts = [2]
        let model = RoundEditViewModel(par: 5, score: 9, putts: 3)

        model.apply(to: round, holeIndex: 5)

        #expect(round.holeScores == [4])
    }

    @Test func 되쓰기_타수가0이면_파도지워_기록없는홀로_되돌린다() {
        let round = GolfRound()
        round.holeScores = [4, 3, 5]
        round.holePars = [4, 3, 5]
        round.puttCounts = [2, 1, 2]
        var model = RoundEditViewModel(par: 3, score: 3, putts: 0)

        model.decrementScore()
        model.decrementScore()
        model.decrementScore()
        model.apply(to: round, holeIndex: 1)

        #expect(model.score == 0)
        // 타수를 0까지 내린 것은 "이 홀은 사실 안 쳤다"는 뜻이다 (spec §5.4).
        #expect(round.holeScores == [4, 0, 5])
        #expect(round.holePars == [4, 0, 5])
        #expect(round.recordedHoleCount == 2)
    }

    @Test func 되쓰기_건너뛴홀에_파만넣으면_여전히_기록없는홀이다() {
        let round = GolfRound()
        round.holeScores = [4, 0, 3]
        round.holePars = [4, 0, 3]
        round.puttCounts = [2, 0, 1]
        var model = RoundEditViewModel(par: 0, score: 0, putts: 0)

        model.setPar(4)
        model.apply(to: round, holeIndex: 1)

        // 파만 고르고 타수를 안 넣었으므로 par-only 홀이 만들어지지 않는다 (spec §4.4).
        #expect(round.holePars == [4, 0, 3])
        #expect(round.holeScores == [4, 0, 3])
        #expect(round.recordedHoleCount == 2)
    }
}
