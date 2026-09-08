import Foundation
@testable import TennisCounter
import Testing

struct MatchSessionGroupTests {
    private func match(
        session: UUID?,
        startedAt: Date,
        elapsed: Int? = nil,
        calories: Double? = nil
    ) -> Match {
        let match = Match()
        match.workoutSessionId = session
        match.startedAt = startedAt
        match.workoutElapsedSeconds = elapsed
        match.workoutCaloriesBurned = calories
        return match
    }

    @Test func matchesGroupIntoSessions() {
        let session = UUID()
        let base = Date()
        let groups = MatchSessionGroup.group([
            match(session: session, startedAt: base),
            match(session: session, startedAt: base.addingTimeInterval(600)),
        ])

        #expect(groups.count == 1)
        #expect(groups.first?.id == session)
        #expect(groups.first?.matches.count == 2)
    }

    @Test func nilSessionIdBecomesOwnSession() {
        let base = Date()
        let groups = MatchSessionGroup.group([
            match(session: nil, startedAt: base),
            match(session: nil, startedAt: base.addingTimeInterval(600)),
        ])

        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.matches.count == 1 })
    }

    @Test func sessionsSortedByLatestMatch() {
        let older = UUID()
        let newer = UUID()
        let base = Date()
        let groups = MatchSessionGroup.group([
            match(session: older, startedAt: base),
            match(session: newer, startedAt: base.addingTimeInterval(7200)),
            match(session: older, startedAt: base.addingTimeInterval(600)),
            match(session: newer, startedAt: base.addingTimeInterval(3600)),
        ])

        // 세션은 최근 순, 세션 안의 경기는 오래된 순
        #expect(groups.map(\.id) == [newer, older])
        #expect(groups[0].matches.map(\.startedAt) == [
            base.addingTimeInterval(3600), base.addingTimeInterval(7200),
        ])
        #expect(groups[1].matches.map(\.startedAt) == [base, base.addingTimeInterval(600)])
    }

    @Test func cumulativeTakesMaximumPerGroup() {
        let session = UUID()
        let base = Date()
        let groups = MatchSessionGroup.group([
            match(session: session, startedAt: base, elapsed: 600, calories: 50),
            match(session: session, startedAt: base.addingTimeInterval(600), elapsed: 1800, calories: 140),
            match(session: session, startedAt: base.addingTimeInterval(1800), elapsed: 3000, calories: 220),
        ])

        // 합산(5400 / 410)이 아니라 최댓값이어야 한다
        #expect(groups.first?.elapsedSeconds == 3000)
        #expect(groups.first?.activeCalories == 220)
    }

    @Test func cumulativeIsNilWhenNoRecordHasIt() {
        let groups = MatchSessionGroup.group([match(session: UUID(), startedAt: Date())])

        #expect(groups.first?.elapsedSeconds == nil)
        #expect(groups.first?.activeCalories == nil)
    }
}
