import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct HomeDashboardBuilderTests {
    /// 2026-10-06 (화). 서울 달력은 일요일 시작이라 이 주는 10/4 ~ 10/10 이다.
    private let now = GrassFixture.date(2026, 10, 6)
    private let calendar = GrassFixture.seoul
    private let locale = Locale(identifier: "ko_KR")

    private func dashboard(_ records: [WorkoutRecord], calendar: Calendar? = nil, now: Date? = nil) -> HomeDashboard {
        HomeDashboardBuilder.dashboard(from: records, now: now ?? self.now,
                                       calendar: calendar ?? self.calendar, locale: locale)
    }

    /// 날짜마다 30분짜리 기록 하나.
    private func records(on dates: [Date], in context: ModelContext) -> [WorkoutRecord] {
        dates.map { GrassFixture.record(in: context, startedAt: $0, totalSeconds: 1800) }
    }

    /// 이번 주(10/5·10/6)에 구간이 있는 두 건 + 구간 없는 한 건 = 3회.
    private func thisWeekRecords(in context: ModelContext) -> [WorkoutRecord] {
        [GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 5), totalSeconds: 4200,
                             segments: [(.strength, 0, 3000), (.cardio, 3000, 1200)]),
         GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 1800,
                             segments: [(.strength, 0, 1800)]),
         GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6, 18), totalSeconds: 3600)]
    }

    @Test("월 제목은 오늘이 속한 달이다")
    func monthTitleIsCurrentMonth() {
        #expect(dashboard([]).monthTitle == "10월 2026")
    }

    @Test("기록이 없으면 스탯은 0이고 첫 운동 안내가 나온다")
    func emptyHistoryShowsFirstMilestone() {
        let result = dashboard([])
        #expect(result.monthStat == .init(countText: "0회", durationText: "0분"))
        #expect(result.streak == .init(countText: "0주", detailText: "이번 주에 시작해 보세요"))
        #expect(result.week == nil)
        #expect(result.emptyWeekText == nil)
        #expect(result.milestone == "워치에서 첫 운동을 기록해 보세요")
    }

    @Test("2회까지는 구성 바 대신 남은 횟수를 안내한다")
    func twoRecordsStillShowMilestone() throws {
        let context = try GrassFixture.makeContext()
        let records = [GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 5), totalSeconds: 1800),
                       GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 1800)]
        let result = dashboard(records)
        #expect(result.milestone == "3번째 운동을 기록하면 이번 주 구성이 보여요 · 1회 남음")
        #expect(result.week == nil)
        #expect(result.emptyWeekText == nil)
    }

    @Test("3회가 되면 안내가 사라지고 구성 바가 나온다")
    func threeRecordsShowComposition() throws {
        let context = try GrassFixture.makeContext()
        let result = dashboard(thisWeekRecords(in: context))
        #expect(result.milestone == nil)
        #expect(result.week != nil)
    }

    @Test("이번 달은 1일 0시부터 센다")
    func monthStatCountsFromFirstOfMonth() throws {
        let context = try GrassFixture.makeContext()
        let records = [GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 30, 23, 50), totalSeconds: 1800),
                       GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 1, 0, 10), totalSeconds: 1800)]
        let result = dashboard(records)
        #expect(result.monthStat.countText == "1회")
    }

    @Test("1시간 미만은 분, 이상은 소수 첫째 자리 시간으로 쓴다")
    func hoursUnderOneShowMinutes() throws {
        let context = try GrassFixture.makeContext()
        let short = [GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 2400)]
        let long = [GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 5400)]
        #expect(dashboard(short).monthStat.durationText == "40분")
        #expect(dashboard(long).monthStat.durationText == "1.5시간")
    }

    // MARK: - 연속 (주 단위). 서울 달력은 일요일 시작 — 이번 주 10/4~10/10, 지난주 9/27~10/3.

    @Test("이번 주까지 채운 주를 거슬러 센다")
    func streakCountsThroughThisWeek() throws {
        let context = try GrassFixture.makeContext()
        let result = dashboard(records(on: [GrassFixture.date(2026, 9, 15), GrassFixture.date(2026, 9, 29),
                                            GrassFixture.date(2026, 10, 5)], in: context))
        // 9/13 주 · (9/20 주 비어 있음) · 9/27 주 · 10/4 주 → 지금 2주, 최장 2주
        #expect(result.streak == .init(countText: "2주", detailText: "최장 2주"))
    }

    @Test("이번 주를 아직 안 채웠으면 지난주까지 센다 — 주가 끝나기 전에는 끊지 않는다")
    func streakKeepsLastWeekUntilThisWeekEnds() throws {
        let context = try GrassFixture.makeContext()
        let result = dashboard(records(on: [GrassFixture.date(2026, 9, 22), GrassFixture.date(2026, 9, 29)], in: context))
        #expect(result.streak.countText == "2주")
    }

    @Test("지난주와 이번 주가 모두 비면 0주이고 시작 안내가 나온다")
    func streakBreaksAfterAnEmptyWeek() throws {
        let context = try GrassFixture.makeContext()
        let result = dashboard(records(on: [GrassFixture.date(2026, 9, 1), GrassFixture.date(2026, 9, 8),
                                            GrassFixture.date(2026, 9, 15)], in: context))
        #expect(result.streak == .init(countText: "0주", detailText: "이번 주에 시작해 보세요"))
    }

    @Test("최장 기록은 지금 연속과 따로 센다")
    func streakBestIsLongestRun() throws {
        let context = try GrassFixture.makeContext()
        // 8/2 · 8/9 · 8/16 · 8/23 주 4주 연속, 끊기고, 10/4 주 1주
        let result = dashboard(records(on: [GrassFixture.date(2026, 8, 3), GrassFixture.date(2026, 8, 10),
                                            GrassFixture.date(2026, 8, 17), GrassFixture.date(2026, 8, 24),
                                            GrassFixture.date(2026, 10, 6)], in: context))
        #expect(result.streak == .init(countText: "1주", detailText: "최장 4주"))
    }

    @Test("한 주에 여러 번 운동해도 한 주로 센다")
    func streakCountsWeeksNotWorkouts() throws {
        let context = try GrassFixture.makeContext()
        #expect(dashboard(thisWeekRecords(in: context)).streak.countText == "1주")
    }

    @Test("미래 기록은 연속에 넣지 않는다")
    func streakIgnoresFutureRecords() throws {
        let context = try GrassFixture.makeContext()
        let result = dashboard(records(on: [GrassFixture.date(2026, 10, 12)], in: context))
        #expect(result.streak.countText == "0주")
    }

    @Test("연말연시를 넘어도 이어진다")
    func streakCrossesYearBoundary() throws {
        let context = try GrassFixture.makeContext()
        // 12/21 주 · 12/28 주(1/3 까지) · 1/4 주
        let result = dashboard(records(on: [GrassFixture.date(2025, 12, 23), GrassFixture.date(2025, 12, 30),
                                            GrassFixture.date(2026, 1, 5)], in: context),
                               now: GrassFixture.date(2026, 1, 6))
        #expect(result.streak == .init(countText: "3주", detailText: "최장 3주"))
    }

    @Test("주간 구성은 이번 주 구간을 종류별로 합친다")
    func weekCompositionSumsSegments() throws {
        let context = try GrassFixture.makeContext()
        let week = try #require(dashboard(thisWeekRecords(in: context)).week)
        #expect(week.strengthSeconds == 4800)
        #expect(week.cardioSeconds == 1200)
        #expect(week.legend == [.init(kind: .strength, text: "근력 1.3h"),
                                .init(kind: .cardio, text: "유산소 0.3h")])
    }

    @Test("주간 총시간은 구간이 아니라 기록 시간 합이다")
    func weekTotalUsesTotalSecondsNotSegments() throws {
        let context = try GrassFixture.makeContext()
        let week = try #require(dashboard(thisWeekRecords(in: context)).week)
        // 4200 + 1800 + 3600 = 9600초. 구간 없는 한 건도 들어간다
        #expect(week.totalText == "2.7h")
        #expect(week.strengthSeconds + week.cardioSeconds < 9600)
    }

    @Test("0인 종류는 범례에서 뺀다")
    func zeroKindIsDroppedFromLegend() throws {
        let context = try GrassFixture.makeContext()
        let records = (4 ... 6).map {
            GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, $0), totalSeconds: 3600,
                                segments: [(.strength, 0, 3600)])
        }
        let week = try #require(dashboard(records).week)
        #expect(week.legend == [.init(kind: .strength, text: "근력 3.0h")])
    }

    @Test("기록은 많은데 이번 주가 비면 구성 바 대신 안내 문구를 낸다")
    func emptyWeekHasNoComposition() throws {
        let context = try GrassFixture.makeContext()
        let records = (22 ... 24).map {
            GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, $0), totalSeconds: 3600)
        }
        let result = dashboard(records)
        #expect(result.week == nil)
        #expect(result.milestone == nil)
        #expect(result.emptyWeekText == "이번 주는 아직 기록이 없어요")
    }

    @Test("주의 경계는 달력의 시작 요일을 따른다")
    func weekFollowsCalendarFirstWeekday() throws {
        let context = try GrassFixture.makeContext()
        // 10/4 는 일요일. 일요일 시작이면 이번 주, 월요일 시작이면 지난 주다
        let records = [GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 4), totalSeconds: 3600),
                       GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 3600),
                       GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6, 18), totalSeconds: 3600)]
        var monday = GrassFixture.seoul
        monday.firstWeekday = 2
        #expect(dashboard(records).week?.totalText == "3.0h")
        #expect(dashboard(records, calendar: monday).week?.totalText == "2.0h")
    }

    @Test("잔디 칸은 이번 주를 오른쪽 끝에 두고 26주를 거슬러 올라간다")
    func gridDaysEndOnThisWeek() {
        let days = HomeDashboardBuilder.gridDays(weeks: 26, now: now, calendar: calendar)
        #expect(days.count == 182)
        #expect(calendar.component(.weekday, from: days[0]) == calendar.firstWeekday)
        #expect(days.contains(calendar.startOfDay(for: now)))
        #expect(days.last == calendar.startOfDay(for: GrassFixture.date(2026, 10, 10)))
        #expect(days.first == calendar.startOfDay(for: GrassFixture.date(2026, 4, 12)))
    }
}
