import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

/// 기록 목록의 주 섹션과 행 표기 (제품 스펙 03b).
///
/// **주의 첫 요일을 일요일로 고정한다.** 식별자로 만든 달력의 `firstWeekday` 는 기계 로케일을 따라가서,
/// 고정하지 않으면 주 경계 테스트가 기계마다 다른 답을 낸다.
@MainActor
struct RecordListBuilderTests {
    private static let calendar: Calendar = {
        var calendar = GrassFixture.seoul
        calendar.firstWeekday = 1
        return calendar
    }()

    /// 2026-09-28 은 월요일이다. 이번 주 = 9/27(일) – 10/3(토).
    private let now = GrassFixture.date(2026, 9, 28)

    private func sections(_ context: ModelContext, now: Date? = nil) throws -> [RecordListSection] {
        try RecordListBuilder.sections(from: context.fetch(FetchDescriptor<WorkoutRecord>()),
                                       now: now ?? self.now,
                                       calendar: Self.calendar,
                                       locale: Locale(identifier: "ko_KR"))
    }

    @Test("레코드가 없으면 섹션도 없다")
    func emptyRecordsGiveNoSections() throws {
        let context = try GrassFixture.makeContext()
        #expect(try sections(context).isEmpty)
    }

    @Test("이번 주와 지난 주는 이름으로, 그 전은 날짜 범위로 부른다")
    func weekTitles() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 26), totalSeconds: 600)

        #expect(try sections(context).map(\.title) == ["이번 주", "지난 주", "9월 13일 – 9월 19일"])
    }

    @Test("주의 경계는 일요일 0시다")
    func weekStartsOnSunday() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 26, 23, 30), totalSeconds: 600) // 토
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 27, 0, 30), totalSeconds: 600) // 일

        let result = try sections(context)
        #expect(result.map(\.title) == ["이번 주", "지난 주"])
        #expect(result.map { $0.rows.map(\.dateTitle) } == [["9월 27일 (일)"], ["9월 26일 (토)"]])
    }

    @Test("섹션 안의 행은 최신이 위다")
    func rowsAreNewestFirst() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 27, 19), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 7), totalSeconds: 600)

        let rows = try #require(try sections(context).first).rows
        #expect(rows.map(\.dateTitle) == ["9월 28일 (월)", "9월 27일 (일)"])
    }

    @Test("시작일이 다른 해면 연도를 붙이고, 해를 넘는 주는 끝에도 붙인다")
    func otherYearTitlesCarryYear() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2025, 12, 22), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2025, 12, 30), totalSeconds: 600)

        // 2026-01-20(화) 기준 — 두 주 모두 "지난 주" 보다 앞이다
        let titles = try sections(context, now: GrassFixture.date(2026, 1, 20)).map(\.title)
        #expect(titles == ["2025년 12월 28일 – 2026년 1월 3일", "2025년 12월 21일 – 12월 27일"])
    }

    @Test("칩은 종류별 합계를 처음 나온 순서로 보여준다")
    func chipsSumByKindInFirstAppearanceOrder() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context,
                            startedAt: GrassFixture.date(2026, 9, 28),
                            totalSeconds: 4320,
                            segments: [(.strength, 0, 1800), (.cardio, 1800, 1080), (.strength, 2880, 1440)])

        let row = try #require(try sections(context).first?.rows.first)
        #expect(row.chips.map(\.text) == ["근력 54분", "유산소 18분"])
    }

    @Test("1분 미만인 종류는 칩을 만들지 않는다")
    func subMinuteKindHasNoChip() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context,
                            startedAt: GrassFixture.date(2026, 9, 28),
                            totalSeconds: 3040,
                            segments: [(.strength, 0, 3000), (.cardio, 3000, 40)])

        let row = try #require(try sections(context).first?.rows.first)
        #expect(row.chips.map(\.text) == ["근력 50분"])
    }

    @Test("kcal 은 반올림해 붙이고, 값이 없으면 비운다")
    func caloriesText() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 7),
                            totalSeconds: 600, totalCalories: 412.6)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 6),
                            totalSeconds: 600, totalCalories: nil)

        let rows = try #require(try sections(context).first).rows
        #expect(rows.map(\.caloriesText) == ["413 kcal", nil])
    }

    @Test("달력 날짜별 행은 시작 시각을 함께 보여 준다")
    func calendarRowsIncludeStartTime() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 19, 30), totalSeconds: 600)

        let row = try #require(RecordListBuilder.rows(for: [record], calendar: Self.calendar,
                                                      locale: Locale(identifier: "ko_KR"), includeStartTime: true).first)

        #expect(row.dateTitle == "9월 28일 (월) · 오후 7:30")
    }

    @Test("부위는 고정 순서로 한 줄에 잇고, 태그가 없으면 비운다")
    func bodyPartsText() throws {
        let context = try GrassFixture.makeContext()
        let tagged = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 7), totalSeconds: 600)
        tagged.toggle(.arms)
        tagged.toggle(.chest)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 6), totalSeconds: 600)

        let rows = try #require(try sections(context).first).rows
        #expect(rows.map(\.bodyPartsText) == ["가슴 · 팔", nil])
    }
}
