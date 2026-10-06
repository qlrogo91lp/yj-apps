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

    private func dashboard(_ records: [WorkoutRecord], calendar: Calendar? = nil) -> HomeDashboard {
        HomeDashboardBuilder.dashboard(from: records, now: now,
                                       calendar: calendar ?? self.calendar, locale: locale)
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
        #expect(result.totalStat == .init(countText: "0회", durationText: "0분"))
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
        #expect(result.totalStat.countText == "2회")
    }

    @Test("전체 누적은 오래된 기록도 센다")
    func totalStatSpansAllHistory() throws {
        let context = try GrassFixture.makeContext()
        let records = [GrassFixture.record(in: context, startedAt: GrassFixture.date(2025, 10, 6), totalSeconds: 3600),
                       GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 1800)]
        let result = dashboard(records)
        #expect(result.totalStat == .init(countText: "2회", durationText: "1.5시간"))
        #expect(result.monthStat == .init(countText: "1회", durationText: "30분"))
    }

    @Test("1시간 미만은 분, 이상은 소수 첫째 자리 시간으로 쓴다")
    func hoursUnderOneShowMinutes() throws {
        let context = try GrassFixture.makeContext()
        let short = [GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 2400)]
        let long = [GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 5400)]
        #expect(dashboard(short).totalStat.durationText == "40분")
        #expect(dashboard(long).totalStat.durationText == "1.5시간")
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
