@testable import TennisCounter
import Foundation
import Testing

@MainActor
struct SummaryViewModelTests {
    @Test func statsWithNoWorkoutData_returnNilFitnessStats() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .all

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
        vm.selectedPeriod = .all

        let match1 = Match()
        match1.myTotalSets = 2
        match1.yourTotalSets = 0
        match1.startedAt = Date()
        match1.caloriesBurned = 300
        match1.averageHeartRate = 140
        match1.durationSeconds = 3600

        let match2 = Match()
        match2.myTotalSets = 0
        match2.yourTotalSets = 2
        match2.startedAt = Date()
        match2.caloriesBurned = 200
        match2.averageHeartRate = 160
        match2.durationSeconds = 1800

        let stats = vm.stats(from: [match1, match2])

        #expect(stats.totalCalories == 500)
        #expect(stats.totalDuration == 5400)
        #expect(stats.avgHeartRate == 150)
    }

    @Test func statsWithMixedWorkoutData_onlyAggregatesAvailableData() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .all

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
}
