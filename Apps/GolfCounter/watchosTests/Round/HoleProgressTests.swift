@testable import GolfCounter_Watch_App
import Testing

struct HoleProgressTests {
    @Test func 초기상태는_1홀이고_값이_모두_0이다() {
        let progress = HoleProgress(holeCount: 18)

        #expect(progress.currentHoleIndex == 0)
        #expect(progress.currentHoleNumber == 1)
        #expect(progress.currentScore == 0)
        #expect(progress.currentPutts == 0)
        #expect(progress.currentPar == 0)
        #expect(progress.holeScores == [0])
        #expect(progress.holePars == [0])
        #expect(progress.puttCounts == [0])
    }

    @Test func 스윙_적용은_타수만_올린다() {
        var progress = HoleProgress(holeCount: 18)

        progress.apply(.swing)
        progress.apply(.swing)

        #expect(progress.currentScore == 2)
        #expect(progress.currentPutts == 0)
    }

    @Test func 퍼팅_적용은_타수와_퍼팅을_함께_올린다() {
        var progress = HoleProgress(holeCount: 18)

        progress.apply(.putt)

        #expect(progress.currentScore == 1)
        #expect(progress.currentPutts == 1)
    }

    @Test func 스윙_되돌리기는_타수만_내린다() {
        var progress = HoleProgress(holeCount: 18)
        progress.apply(.swing)
        progress.apply(.putt)

        progress.revert(.putt)
        progress.revert(.swing)

        #expect(progress.currentScore == 0)
        #expect(progress.currentPutts == 0)
    }

    @Test func 퍼팅_되돌리기는_타수와_퍼팅을_함께_내린다() {
        var progress = HoleProgress(holeCount: 18)
        progress.apply(.putt)
        progress.apply(.putt)

        progress.revert(.putt)

        #expect(progress.currentScore == 1)
        #expect(progress.currentPutts == 1)
    }

    @Test func 파를_설정하면_현재홀의_파가_바뀐다() {
        var progress = HoleProgress(holeCount: 18)

        progress.setPar(4)

        #expect(progress.currentPar == 4)
        #expect(progress.holePars == [4])
    }

    @Test func 다음홀로_가면_세_배열이_함께_늘어난다() {
        var progress = HoleProgress(holeCount: 18)
        progress.setPar(4)
        progress.apply(.swing)

        progress.advanceToNextHole()

        #expect(progress.currentHoleIndex == 1)
        #expect(progress.holeScores == [1, 0])
        #expect(progress.holePars == [4, 0])
        #expect(progress.puttCounts == [0, 0])
    }

    @Test func 이전홀로_가면_인덱스만_내려가고_배열은_그대로다() {
        var progress = HoleProgress(holeCount: 18)
        progress.setPar(4)
        progress.advanceToNextHole()

        progress.retreatToPreviousHole()

        #expect(progress.currentHoleIndex == 0)
        #expect(progress.currentPar == 4)
        #expect(progress.holeScores.count == 2)
    }

    @Test func 첫홀에서는_이전홀로_갈_수_없다() {
        let progress = HoleProgress(holeCount: 18)

        #expect(progress.canGoToPreviousHole == false)
    }

    @Test func 홀을_옮기면_이전홀로_갈_수_있다() {
        var progress = HoleProgress(holeCount: 18)

        progress.advanceToNextHole()

        #expect(progress.canGoToPreviousHole)
    }

    @Test func 길이가_어긋난_배열로_시작해도_현재홀까지_용량이_채워진다() {
        let progress = HoleProgress(holeCount: 18, holeScores: [4],
                                    holePars: [4],
                                    puttCounts: [2],
                                    currentHoleIndex: 3)

        #expect(progress.holeScores == [4, 0, 0, 0])
        #expect(progress.holePars == [4, 0, 0, 0])
        #expect(progress.puttCounts == [2, 0, 0, 0])
        #expect(progress.currentScore == 0)
    }

    @Test func 음수_인덱스로_시작하면_0으로_보정된다() {
        let progress = HoleProgress(holeCount: 18, holeScores: [3],
                                    holePars: [4],
                                    puttCounts: [1],
                                    currentHoleIndex: -5)

        #expect(progress.currentHoleIndex == 0)
        #expect(progress.currentScore == 3)
    }

    @Test func 새로_만든_홀은_phantom_hole이다() {
        var progress = HoleProgress(holeCount: 18)
        progress.setPar(4)
        progress.apply(.swing)

        progress.advanceToNextHole()

        #expect(progress.isPristinePhantomHole)
    }

    @Test func 타수를_입력하면_phantom_hole이_아니다() {
        var progress = HoleProgress(holeCount: 18)
        progress.advanceToNextHole()

        progress.apply(.swing)

        #expect(progress.isPristinePhantomHole == false)
    }

    @Test func 파만_설정해도_phantom_hole이_아니다() {
        var progress = HoleProgress(holeCount: 18)
        progress.advanceToNextHole()

        progress.setPar(3)

        #expect(progress.isPristinePhantomHole == false)
    }

    @Test func 값이_비어도_말단이_아니면_phantom_hole이_아니다() {
        var progress = HoleProgress(holeCount: 18)
        progress.advanceToNextHole()
        progress.advanceToNextHole()

        // index 1은 score·par·putts가 전부 0이지만 말단(index 2)이 아니라 pop 대상이 아니다
        progress.retreatToPreviousHole()

        #expect(progress.currentHoleIndex == 1)
        #expect(progress.currentScore == 0)
        #expect(progress.currentPar == 0)
        #expect(progress.isPristinePhantomHole == false)
    }

    @Test func phantom_hole을_제거하면_이전홀_데이터가_그대로_남는다() {
        var progress = HoleProgress(holeCount: 18)
        progress.setPar(4)
        progress.apply(.putt)
        progress.advanceToNextHole()

        progress.removePhantomHoleAndRetreat()

        #expect(progress.currentHoleIndex == 0)
        #expect(progress.holeScores == [1])
        #expect(progress.holePars == [4])
        #expect(progress.puttCounts == [1])
    }

    @Test func 마지막_홀에서는_다음홀로_갈_수_없다() {
        var progress = HoleProgress(holeCount: 18)
        for _ in 1 ..< 18 {
            progress.advanceToNextHole()
        }

        #expect(progress.currentHoleNumber == 18)
        #expect(progress.canGoToNextHole == false)
    }

    @Test func 상한에_도달하면_다음홀_이동이_아무것도_바꾸지_않는다() {
        var progress = HoleProgress(holeCount: 9)
        for _ in 1 ..< 9 {
            progress.advanceToNextHole()
        }

        progress.advanceToNextHole()

        #expect(progress.currentHoleIndex == 8)
        #expect(progress.holeScores.count == 9)
    }

    @Test func 아홉홀_라운드는_아홉번째_홀이_마지막이다() {
        var progress = HoleProgress(holeCount: 9)
        progress.advanceToNextHole()

        #expect(progress.canGoToNextHole)
        #expect(progress.holeCount == 9)
    }
}
