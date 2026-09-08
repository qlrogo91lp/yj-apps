import Foundation
@testable import TennisCounter
import Testing

struct DayCellDotsTests {
    private func match(startedAt: Date, mySets: Int, yourSets: Int) -> Match {
        let match = Match()
        match.startedAt = startedAt
        match.myTotalSets = mySets
        match.yourTotalSets = yourSets
        return match
    }

    @Test func dotsMatchMatchCount() {
        let base = Date()
        let dots = DayCellDots.dots(for: [
            match(startedAt: base, mySets: 2, yourSets: 0),
            match(startedAt: base.addingTimeInterval(600), mySets: 0, yourSets: 2),
        ])

        #expect(dots == [.win, .loss])
    }

    /// 셀 폭이 40pt라 점 4개가 한계다. 넘으면 마지막이 회색 .more.
    @Test func dotsCapAtFour() {
        let base = Date()
        let matches = (0 ..< 7).map { index in
            match(startedAt: base.addingTimeInterval(Double(index) * 600), mySets: 2, yourSets: 0)
        }

        let dots = DayCellDots.dots(for: matches)

        #expect(dots.count == 4)
        #expect(dots == [.win, .win, .win, .more])
    }

    @Test func dotColorsFollowEachResult() {
        let base = Date()
        // 시간 순서가 뒤섞여 들어와도 시작 시각 순으로 정렬해 표시한다
        let dots = DayCellDots.dots(for: [
            match(startedAt: base.addingTimeInterval(1200), mySets: 2, yourSets: 1),
            match(startedAt: base, mySets: 0, yourSets: 2),
            match(startedAt: base.addingTimeInterval(600), mySets: 2, yourSets: 0),
        ])

        #expect(dots == [.loss, .win, .win])
    }

    @Test func noMatchesGivesNoDots() {
        #expect(DayCellDots.dots(for: []).isEmpty)
    }
}
