import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing
import WorkoutCore

@MainActor
struct RecordShareBuilderTests {
    private let start = GrassFixture.date(2026, 9, 28, 19, 12)

    @Test func strengthOnlyTitle() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 1800,
                                         segments: [(.strength, 0, 1800)])
        #expect(RecordShareBuilder.content(for: record).title == "근력")
    }

    @Test func mixedTitleKeepsFirstSeenOrder() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 1800,
                                         segments: [(.cardio, 0, 600), (.strength, 600, 1200)])
        #expect(RecordShareBuilder.content(for: record).title == "유산소 · 근력")
    }

    @Test func titleIgnoresSubMinuteKinds() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 1240,
                                         segments: [(.strength, 0, 1200), (.cardio, 1200, 40)])
        #expect(RecordShareBuilder.content(for: record).title == "근력")
    }

    @Test func noSegmentsTitleIsWorkout() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 600,
                                         segments: [(.strength, 0, 0)])
        #expect(RecordShareBuilder.content(for: record).title == "운동")
    }

    @Test func resultCarriesCumulativeValues() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 4320, totalCalories: 412)
        record.activeCalories = 300
        record.averageHeartRate = 128
        let result = RecordShareBuilder.content(for: record).result
        #expect(result.durationSeconds == 4320)
        #expect(result.caloriesBurned == 300)
        #expect(result.totalCaloriesBurned == 412)
        #expect(result.averageHeartRate == 128)
    }

    @Test func missingMetricsBecomeZeroOrNil() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 600)
        let result = RecordShareBuilder.content(for: record).result
        #expect(result.caloriesBurned == 0)
        #expect(result.totalCaloriesBurned == 0)
        #expect(result.averageHeartRate == nil)
    }

    @Test func missingEndUsesTotalSeconds() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 4320)
        #expect(RecordShareBuilder.content(for: record).endedAt == start.addingTimeInterval(4320))
    }

    @Test func endedAtIsKept() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 4320)
        let end = start.addingTimeInterval(4300)
        record.endedAt = end
        #expect(RecordShareBuilder.content(for: record).endedAt == end)
    }
}
