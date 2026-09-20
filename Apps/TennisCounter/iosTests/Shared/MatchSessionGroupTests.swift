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

    @Test func recordWinsOverMatchMaximum() {
        let sessionId = UUID()
        let match = Match()
        match.workoutSessionId = sessionId
        match.workoutElapsedSeconds = 1000
        match.workoutCaloriesBurned = 100
        match.workoutTotalCaloriesBurned = 140

        let record = WorkoutSessionRecord()
        record.workoutSessionId = sessionId
        record.elapsedSeconds = 1500 // 마지막 경기 이후 구간까지 포함
        record.activeCalories = 160
        record.totalCalories = 210
        record.averageHeartRate = 142

        let groups = MatchSessionGroup.group([match], records: [record])
        #expect(groups.count == 1)
        #expect(groups[0].elapsedSeconds == 1500)
        #expect(groups[0].activeCalories == 160)
        #expect(groups[0].totalCalories == 210)
        #expect(groups[0].averageHeartRate == 142)
    }

    @Test func fallsBackToMatchMaximumWhenNoRecord() {
        let sessionId = UUID()
        let first = Match()
        first.workoutSessionId = sessionId
        first.workoutElapsedSeconds = 600
        first.workoutTotalCaloriesBurned = 80
        first.averageHeartRate = 120
        let second = Match()
        second.workoutSessionId = sessionId
        second.workoutElapsedSeconds = 1000
        second.workoutTotalCaloriesBurned = 140
        second.averageHeartRate = 155

        let groups = MatchSessionGroup.group([first, second], records: [])
        #expect(groups[0].elapsedSeconds == 1000)
        #expect(groups[0].totalCalories == 140)
        // 경기 평균은 세션 평균이 아니므로 폴백하지 않는다
        #expect(groups[0].averageHeartRate == nil)
    }

    @Test func nilRecordMetricFallsBackToMatchMaximum() {
        let sessionId = UUID()
        let match = Match()
        match.workoutSessionId = sessionId
        match.workoutElapsedSeconds = 1000
        match.workoutCaloriesBurned = 120
        match.workoutTotalCaloriesBurned = 160

        let record = WorkoutSessionRecord()
        record.workoutSessionId = sessionId

        let group = MatchSessionGroup.group([match], records: [record])[0]
        #expect(group.elapsedSeconds == 1000)
        #expect(group.activeCalories == 120)
        #expect(group.totalCalories == 160)
    }

    @Test func recordsForGroupingKeepsOvernightSessionJoinAndOnlyAddsMatchlessInScopeRecords() {
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDay = firstDay.addingTimeInterval(24 * 60 * 60)
        let overnightSession = UUID()
        let otherSession = UUID()

        let overnightMatch = match(session: overnightSession, startedAt: firstDay)
        let otherMatch = match(session: otherSession, startedAt: firstDay)

        let overnightRecord = WorkoutSessionRecord()
        overnightRecord.workoutSessionId = overnightSession
        overnightRecord.startedAt = secondDay
        let otherRecord = WorkoutSessionRecord()
        otherRecord.workoutSessionId = otherSession
        otherRecord.startedAt = secondDay
        let matchlessRecord = WorkoutSessionRecord()
        matchlessRecord.workoutSessionId = UUID()
        matchlessRecord.startedAt = secondDay

        let records = MatchSessionGroup.recordsForGrouping(
            [overnightRecord, otherRecord, matchlessRecord],
            displayedMatches: [overnightMatch],
            sourceMatches: [overnightMatch, otherMatch]
        ) { record in
            calendar.isDate(record.startedAt, inSameDayAs: secondDay)
        }

        #expect(records.map(\.workoutSessionId) == [overnightSession, matchlessRecord.workoutSessionId])
    }

    @Test func recordsForGroupingDoesNotShowUnloadedMatchRecordAsFirstPageEmptySession() {
        let base = Date()
        let unloadedSession = UUID()
        let matchlessSession = UUID()
        let loadedMatches = (0 ..< 20).map { index in
            match(session: UUID(), startedAt: base.addingTimeInterval(TimeInterval(-index * 3600)))
        }
        let unloadedMatch = match(session: unloadedSession, startedAt: base.addingTimeInterval(-20 * 3600))

        let unloadedRecord = WorkoutSessionRecord()
        unloadedRecord.workoutSessionId = unloadedSession
        let matchlessRecord = WorkoutSessionRecord()
        matchlessRecord.workoutSessionId = matchlessSession

        let records = MatchSessionGroup.recordsForGrouping(
            [unloadedRecord, matchlessRecord],
            displayedMatches: loadedMatches,
            sourceMatches: loadedMatches + [unloadedMatch]
        ) { _ in true }

        #expect(records.map(\.workoutSessionId) == [matchlessSession])
    }

    @Test func recordWithoutMatchesBecomesEmptySession() {
        let record = WorkoutSessionRecord()
        record.workoutSessionId = UUID()
        record.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        record.elapsedSeconds = 2890

        let groups = MatchSessionGroup.group([], records: [record])
        #expect(groups.count == 1)
        #expect(groups[0].matches.isEmpty)
        #expect(groups[0].matchCount == 0)
        #expect(groups[0].elapsedSeconds == 2890)
    }

    @Test func countsWinsAndLosses() {
        let sessionId = UUID()
        let win = Match()
        win.workoutSessionId = sessionId
        win.myTotalSets = 2
        win.yourTotalSets = 0
        let loss = Match()
        loss.workoutSessionId = sessionId
        loss.myTotalSets = 0
        loss.yourTotalSets = 2

        let groups = MatchSessionGroup.group([win, loss], records: [])
        #expect(groups[0].wins == 1)
        #expect(groups[0].losses == 1)
        #expect(groups[0].matchCount == 2)
    }
}
