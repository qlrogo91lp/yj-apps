import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing
import WorkoutCore

@MainActor
struct RecordShareBuilderTests {
    private let start = GrassFixture.date(2026, 9, 28, 19, 12)

    @Test func titleIsBrand() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 1800,
                                         segments: [(.strength, 0, 1800)])
        #expect(RecordShareBuilder.content(for: record).title == "Haruchi Fit")
    }

    @Test func compositionKeepsRecordOrder() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 2100,
                                         segments: [(.strength, 0, 1200), (.cardio, 1200, 600), (.strength, 1800, 300)])
        let composition = try #require(RecordShareBuilder.content(for: record).composition)
        #expect(composition.spans.map(\.kind) == [.strength, .cardio, .strength])
        #expect(composition.spans.map(\.seconds) == [1200, 600, 300])
        #expect(composition.text == "근력 25분 · 유산소 10분")
    }

    @Test func compositionTextIgnoresSubMinuteKinds() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 1240,
                                         segments: [(.strength, 0, 1200), (.cardio, 1200, 40)])
        let composition = try #require(RecordShareBuilder.content(for: record).composition)
        #expect(composition.spans.count == 2)
        #expect(composition.text == "근력 20분")
    }

    @Test func compositionIsNilWithoutMinuteKinds() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 40,
                                         segments: [(.cardio, 0, 40)])
        #expect(RecordShareBuilder.content(for: record).composition == nil)
    }

    @Test func spansSkipZeroSeconds() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 1200,
                                         segments: [(.strength, 0, 1200), (.strength, 1200, 0)])
        #expect(RecordShareBuilder.content(for: record).composition?.spans.count == 1)
    }

    @Test func compositionMatchesDetail() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: start, totalSeconds: 1800,
                                         segments: [(.strength, 0, 1200), (.cardio, 1200, 600)])
        let composition = try #require(RecordShareBuilder.content(for: record).composition)
        let detail = RecordDetailBuilder.summary(for: record)
        #expect(composition.spans == detail.spans)
        #expect(composition.text == detail.compositionText)
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
