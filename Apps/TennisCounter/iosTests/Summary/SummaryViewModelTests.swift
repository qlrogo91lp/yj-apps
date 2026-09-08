import Foundation
@testable import TennisCounter
import Testing

@MainActor
struct SummaryViewModelTests {
    @Test func statsWithNoWorkoutData_returnNilFitnessStats() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let match = Match()
        match.myTotalSets = 2
        match.yourTotalSets = 1
        match.startedAt = Date()

        let stats = vm.stats(from: [match])

        #expect(stats.totalCalories == nil)
        #expect(stats.totalDuration == nil)
    }

    @Test func statsWithWorkoutData_aggregatesCorrectly() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        // 서로 다른 워크아웃 두 개 — 누적값이 각각 독립적으로 합산돼야 한다.
        let match1 = Match()
        match1.workoutSessionId = UUID()
        match1.myTotalSets = 2
        match1.yourTotalSets = 0
        match1.startedAt = Date()
        match1.caloriesBurned = 300
        match1.workoutCaloriesBurned = 300
        match1.averageHeartRate = 140
        match1.durationSeconds = 3600
        match1.workoutElapsedSeconds = 3600

        let match2 = Match()
        match2.workoutSessionId = UUID()
        match2.myTotalSets = 0
        match2.yourTotalSets = 2
        match2.startedAt = Date()
        match2.caloriesBurned = 200
        match2.workoutCaloriesBurned = 200
        match2.averageHeartRate = 160
        match2.durationSeconds = 1800
        match2.workoutElapsedSeconds = 1800

        let stats = vm.stats(from: [match1, match2])

        #expect(stats.totalCalories == 500)
        #expect(stats.totalDuration == 5400)
    }

    @Test func statsWithMixedWorkoutData_onlyAggregatesAvailableData() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let matchWithData = Match()
        matchWithData.myTotalSets = 2
        matchWithData.yourTotalSets = 0
        matchWithData.startedAt = Date()
        matchWithData.caloriesBurned = 400
        matchWithData.averageHeartRate = 150
        matchWithData.durationSeconds = 2700

        let matchWithoutData = Match()
        matchWithoutData.myTotalSets = 1
        matchWithoutData.yourTotalSets = 2
        matchWithoutData.startedAt = Date()

        let stats = vm.stats(from: [matchWithData, matchWithoutData])

        #expect(stats.totalCalories == 400)
        #expect(stats.totalDuration == 2700)
        #expect(stats.totalMatches == 2)
    }

    private func workoutMatch(
        workoutId: UUID,
        startedAt: Date = Date(),
        matchDuration: Int,
        workoutElapsed: Int,
        matchCalories: Double,
        workoutCalories: Double
    ) -> Match {
        let match = Match()
        match.matchId = UUID()
        match.workoutSessionId = workoutId
        match.startedAt = startedAt
        match.myTotalSets = 1
        match.durationSeconds = matchDuration
        match.workoutElapsedSeconds = workoutElapsed
        match.caloriesBurned = matchCalories
        match.workoutCaloriesBurned = workoutCalories
        return match
    }

    /// 스펙 1-2 재현: 워크아웃 하나에서 경기를 3판 하면 누적값 3개가 단순 합산돼
    /// 운동 시간이 실제의 몇 배로 부풀었다. 그룹당 최댓값 하나만 세야 한다.
    @Test func statsSameWorkoutMultipleMatchesDoesNotDoubleCountDuration() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week
        let workoutId = UUID()

        let matches = [
            workoutMatch(workoutId: workoutId, matchDuration: 1200, workoutElapsed: 1200,
                         matchCalories: 300, workoutCalories: 300),
            workoutMatch(workoutId: workoutId, matchDuration: 1200, workoutElapsed: 2700,
                         matchCalories: 250, workoutCalories: 650),
            workoutMatch(workoutId: workoutId, matchDuration: 1200, workoutElapsed: 3600,
                         matchCalories: 130, workoutCalories: 780),
        ]

        let stats = vm.stats(from: matches)

        #expect(stats.totalMatches == 3)
        #expect(stats.totalDuration == 3600)
        #expect(stats.totalCalories == 780)
    }

    @Test func statsDifferentWorkoutsSumEachWorkoutMaximum() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let first = UUID()
        let second = UUID()
        let matches = [
            workoutMatch(workoutId: first, matchDuration: 900, workoutElapsed: 900,
                         matchCalories: 200, workoutCalories: 200),
            workoutMatch(workoutId: first, matchDuration: 900, workoutElapsed: 1800,
                         matchCalories: 180, workoutCalories: 380),
            workoutMatch(workoutId: second, matchDuration: 600, workoutElapsed: 600,
                         matchCalories: 150, workoutCalories: 150),
        ]

        let stats = vm.stats(from: matches)

        #expect(stats.totalDuration == 2400) // 1800 + 600
        #expect(stats.totalCalories == 530) // 380 + 150
    }

    /// 누적 필드 도입 전 기록은 workoutElapsedSeconds가 nil이고 durationSeconds가 마침
    /// 누적값이다. 폴백이 이를 그대로 쓰므로 기존 기록의 표시값에 회귀가 없어야 한다.
    @Test func statsLegacyRecordsWithoutWorkoutFieldsFallBackToExistingValues() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let legacy = Match()
        legacy.workoutSessionId = UUID()
        legacy.startedAt = Date()
        legacy.myTotalSets = 1
        legacy.durationSeconds = 3600
        legacy.caloriesBurned = 500

        let stats = vm.stats(from: [legacy])

        #expect(stats.totalDuration == 3600)
        #expect(stats.totalCalories == 500)
    }

    /// workoutSessionId가 없는 레코드는 서로 그룹핑할 수 없으므로 각자 한 워크아웃으로 센다.
    @Test func statsMatchesWithoutWorkoutSessionIdSumIndependently() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let first = Match()
        first.startedAt = Date()
        first.durationSeconds = 600
        first.caloriesBurned = 100

        let second = Match()
        second.startedAt = Date()
        second.durationSeconds = 900
        second.caloriesBurned = 150

        let stats = vm.stats(from: [first, second])

        #expect(stats.totalDuration == 1500)
        #expect(stats.totalCalories == 250)
    }

    // MARK: - 기간

    @Test func allPeriodIncludesEveryMatch() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .all

        let old = Match()
        old.startedAt = Date().addingTimeInterval(-400 * 24 * 3600)
        let recent = Match()
        recent.startedAt = Date()

        #expect(vm.filteredMatches(from: [old, recent]).count == 2)
    }

    @Test func weekPeriodExcludesOlderMatches() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let old = Match()
        old.startedAt = Date().addingTimeInterval(-30 * 24 * 3600)
        let recent = Match()
        recent.startedAt = Date()

        let filtered = vm.filteredMatches(from: [old, recent])

        #expect(filtered.count == 1)
        #expect(filtered.first === recent)
    }

    /// 심박·총 에너지는 요약에서 빠졌다. 그 값이 들어 있는 기록이라도 남은 지표에는 영향이 없어야 한다.
    @Test func statsExcludeRemovedMetrics() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let match = Match()
        match.startedAt = Date()
        match.caloriesBurned = 400
        match.totalCaloriesBurned = 520
        match.averageHeartRate = 150
        match.durationSeconds = 2700

        let stats = vm.stats(from: [match])

        #expect(stats.totalCalories == 400)
        #expect(stats.totalDuration == 2700)
        #expect(stats.totalMatches == 1)
    }

    // MARK: - 추이

    private func trendMatch(session: UUID, startedAt: Date, elapsed: Int) -> Match {
        let match = Match()
        match.workoutSessionId = session
        match.startedAt = startedAt
        match.workoutElapsedSeconds = elapsed
        return match
    }

    @Test func trendReturnsAtMostTenSessions() throws {
        let vm = SummaryViewModel()
        let base = Date()
        let matches = (0 ..< 14).map { index in
            trendMatch(session: UUID(), startedAt: base.addingTimeInterval(Double(index) * 3600), elapsed: 1800)
        }

        let trend = vm.trendSessions(from: matches)

        #expect(trend.count == 10)
        // 오래된 것부터 — 차트의 x축 순서다
        #expect(try #require(trend.first?.date) < trend.last!.date)
    }

    @Test func trendGroupsBySession() {
        let vm = SummaryViewModel()
        let session = UUID()
        let base = Date()
        let matches = [
            trendMatch(session: session, startedAt: base, elapsed: 900),
            trendMatch(session: session, startedAt: base.addingTimeInterval(900), elapsed: 2400),
            trendMatch(session: UUID(), startedAt: base.addingTimeInterval(7200), elapsed: 600),
            trendMatch(session: UUID(), startedAt: base.addingTimeInterval(10800), elapsed: 1200),
        ]

        let trend = vm.trendSessions(from: matches)

        #expect(trend.count == 3)
        #expect(trend.first?.elapsedSeconds == 2400)
    }

    /// 세션이 3개 미만이면 추이를 그리지 않는다 — 막대 둘로는 추세가 안 보인다.
    @Test func trendHiddenBelowThreeSessions() {
        let vm = SummaryViewModel()
        let base = Date()
        let matches = [
            trendMatch(session: UUID(), startedAt: base, elapsed: 900),
            trendMatch(session: UUID(), startedAt: base.addingTimeInterval(3600), elapsed: 1200),
        ]

        #expect(vm.trendSessions(from: matches).isEmpty)
    }

    /// 기간 필터를 타지 않는다 — 차트는 "얼마나 오래 쳤나"만 맡는 독립 블록이다.
    @Test func trendIgnoresSelectedPeriod() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let old = Date().addingTimeInterval(-90 * 24 * 3600)
        let matches = (0 ..< 3).map { index in
            trendMatch(session: UUID(), startedAt: old.addingTimeInterval(Double(index) * 3600), elapsed: 1800)
        }

        #expect(vm.trendSessions(from: matches).count == 3)
    }
}
