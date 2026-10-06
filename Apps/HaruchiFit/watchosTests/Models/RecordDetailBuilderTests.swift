import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct RecordDetailBuilderTests {
    private let now = GrassFixture.date(2026, 10, 6)

    private func summary(_ record: WorkoutRecord) -> RecordDetailSummary {
        RecordDetailBuilder.summary(for: record, now: now, calendar: GrassFixture.seoul, locale: Locale(identifier: "ko_KR"))
    }

    @Test("헤더는 같은 시간대의 끝 이름을 생략한다")
    func headerOmitsRepeatedPeriod() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 19, 12), totalSeconds: 4320)
        record.endedAt = GrassFixture.date(2026, 9, 28, 20, 24)
        #expect(summary(record).dateTitle == "9월 28일 (월)")
        #expect(summary(record).timeRangeTitle == "저녁 7:12 – 8:24")
    }

    @Test("시간대가 바뀌면 끝에도 시간대 이름을 붙인다")
    func headerKeepsChangedPeriod() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 20, 30), totalSeconds: 4200)
        record.endedAt = GrassFixture.date(2026, 9, 28, 21, 40)
        #expect(summary(record).timeRangeTitle == "저녁 8:30 – 밤 9:40")
    }

    @Test("종료 시각이 없으면 시작에 총 시간을 더한다")
    func missingEndUsesTotalSeconds() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 7), totalSeconds: 3600)
        #expect(summary(record).timeRangeTitle == "오전 7:00 – 8:00")
    }

    @Test("다른 해의 기록은 날짜에 연도를 붙인다")
    func otherYearDateCarriesYear() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2025, 12, 30), totalSeconds: 600)
        #expect(summary(record).dateTitle == "2025년 12월 30일 (화)")
    }

    @Test("요약은 분과 반올림한 수치를 표시한다")
    func statsAreMinutesAndRoundedValues() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28), totalSeconds: 4320, totalCalories: 412.4)
        record.averageHeartRate = 127.6
        let result = summary(record)
        #expect(result.durationText == "72분")
        #expect(result.caloriesText == "412")
        #expect(result.heartRateText == "128")
    }

    @Test("없는 지표와 1분 미만 시간도 읽을 수 있게 표시한다")
    func missingMetricsAndSubMinuteDuration() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28), totalSeconds: 40)
        let result = summary(record)
        #expect(result.durationText == "1분 미만")
        #expect(result.caloriesText == "–")
        #expect(result.heartRateText == "–")
    }

    @Test("운동 구성은 구간 순서와 종류별 합계를 유지한다")
    func compositionFollowsSegmentOrder() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28), totalSeconds: 4320, segments: [(.strength, 0, 1800), (.cardio, 1800, 1080), (.strength, 2880, 1440)])
        let result = summary(record)
        #expect(result.spans.map(\.kind) == [.strength, .cardio, .strength])
        #expect(result.spans.map(\.seconds) == [1800, 1080, 1440])
        #expect(result.compositionText == "근력 54분 · 유산소 18분")
    }

    @Test("길이 0인 구간은 운동 구성을 만들지 않는다")
    func emptyCompositionHasNoBar() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28), totalSeconds: 600, segments: [(.strength, 0, 0)])
        let result = summary(record)
        #expect(result.spans.isEmpty)
        #expect(result.compositionText == nil)
    }
}
