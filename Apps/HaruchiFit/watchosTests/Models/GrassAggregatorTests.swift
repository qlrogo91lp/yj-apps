import Foundation
import SwiftData
@testable import HaruchiFit_Watch_App
import Testing

/// 레코드를 하루 한 칸으로 접는 규칙.
///
/// **하루의 경계는 시작 시각이다** — 통계가 세션 카운트 기준(D2)이고 기록 목록도 세션
/// 단위라, 한 세션을 날짜별로 쪼개면 잔디만 다른 수를 갖게 된다 (스펙 4.1).
@MainActor
struct GrassAggregatorTests {
    @Test("같은 날 두 세션은 한 칸으로 합쳐진다")
    func sameDaySessionsCollapseIntoOneCell() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14, 7), totalSeconds: 1800)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14, 19), totalSeconds: 2400)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.count == 1)
        #expect(days.first?.totalSeconds == 4200) // 70분
        #expect(days.first?.sessionCount == 2)
        // 스펙 8절이 이 케이스에 농도까지 못박았다 — 70분은 60 컷을 넘고 90 컷에 못 닿는다
        #expect(GrassIntensity.byTime.level(for: try #require(days.first)) == .heavy)
    }

    @Test("자정을 넘긴 세션은 전부 시작한 날 칸에 들어간다")
    func sessionCrossingMidnightLandsOnStartDay() throws {
        let context = try GrassFixture.makeContext()
        // 23:40 에 시작해 50분 — 00:30 에 끝난다
        GrassFixture.record(in: context,
                            startedAt: GrassFixture.date(2026, 9, 14, 23, 40),
                            totalSeconds: 3000)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.count == 1)
        #expect(days.first?.day == GrassFixture.seoul.startOfDay(for: GrassFixture.date(2026, 9, 14)))
        #expect(days.first?.totalSeconds == 3000) // 50분 전부
    }

    @Test("구간이 종목별로 갈려 담긴다")
    func segmentsSplitByKind() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context,
                            startedAt: GrassFixture.date(2026, 9, 14),
                            totalSeconds: 1800,
                            segments: [(.strength, 0, 1200), (.cardio, 1200, 600)])

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.first?.strengthSeconds == 1200)
        #expect(days.first?.cardioSeconds == 600)
    }

    @Test("세그먼트가 없는 레코드도 총 시간은 그대로 센다 — 수동 기록과 import 가 그렇다")
    func recordWithoutSegmentsStillCountsTotal() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14), totalSeconds: 2700)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.first?.totalSeconds == 2700)
        #expect(days.first?.strengthSeconds == 0)
        #expect(days.first?.cardioSeconds == 0)
    }

    @Test("칼로리는 값을 가진 레코드만 더한다. 하나도 없으면 nil 이다")
    func caloriesSumOnlyWhenPresent() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14, 7),
                            totalSeconds: 1800, totalCalories: 120)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14, 19),
                            totalSeconds: 1800, totalCalories: nil)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 15),
                            totalSeconds: 1800, totalCalories: nil)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.first?.totalCalories == 120)
        #expect(days.last?.totalCalories == nil)
    }

    @Test("레코드가 없는 날은 칸이 아예 없다")
    func daysWithoutRecordsAreAbsent() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14), totalSeconds: 1800)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 17), totalSeconds: 1800)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.count == 2) // 15·16일 칸은 없다
    }

    @Test("결과는 날짜 오름차순이다")
    func resultIsSortedByDayAscending() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 17), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 15), totalSeconds: 600)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.map(\.day) == days.map(\.day).sorted())
    }

    @Test("빈 입력은 빈 결과다. 크래시하지 않는다")
    func emptyInputGivesEmptyResult() {
        #expect(GrassAggregator.fold([], calendar: GrassFixture.seoul).isEmpty)
    }
}
