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
        #expect(stats.avgHeartRate == nil)
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
        #expect(stats.avgHeartRate == 150)
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
        #expect(stats.avgHeartRate == 150)
        #expect(stats.totalMatches == 2)
    }

    @Test func statsAggregatesTotalEnergy() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let match1 = Match()
        match1.startedAt = Date()
        match1.caloriesBurned = 300
        match1.totalCaloriesBurned = 385

        let match2 = Match()
        match2.startedAt = Date()
        match2.caloriesBurned = 200
        match2.totalCaloriesBurned = 265

        let stats = vm.stats(from: [match1, match2])

        #expect(stats.totalCalories == 500)
        #expect(stats.totalEnergy == 650)
        #expect(stats.formattedTotalEnergy == "650")
    }

    /// 총 칼로리 도입 이전 기록은 totalCaloriesBurned가 nil이다 — 그런 기록만 있으면
    /// 0이 아니라 "값 없음"이어야 사용자가 오해하지 않는다.
    @Test func statsTotalEnergyIsNilForLegacyRecords() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let legacy = Match()
        legacy.startedAt = Date()
        legacy.caloriesBurned = 300

        let stats = vm.stats(from: [legacy])

        #expect(stats.totalCalories == 300)
        #expect(stats.totalEnergy == nil)
        #expect(stats.formattedTotalEnergy == "–")
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
}
