@testable import GolfCounter_Watch_App
import Testing

struct ScorecardChunksTests {
    @Test func 홀이_없으면_페이지가_없다() {
        #expect(ScorecardChunks.ranges(holeCount: 0).isEmpty)
    }

    @Test func 아홉홀_이하는_한_페이지다() {
        #expect(ScorecardChunks.ranges(holeCount: 1) == [0 ..< 1])
        #expect(ScorecardChunks.ranges(holeCount: 9) == [0 ..< 9])
    }

    @Test func 열홀부터_두_페이지로_나뉜다() {
        #expect(ScorecardChunks.ranges(holeCount: 10) == [0 ..< 9, 9 ..< 10])
        #expect(ScorecardChunks.ranges(holeCount: 18) == [0 ..< 9, 9 ..< 18])
    }

    @Test func 음수가_들어와도_빈_배열을_돌려준다() {
        #expect(ScorecardChunks.ranges(holeCount: -3).isEmpty)
    }
}
