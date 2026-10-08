import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct StatisticsBuilderTests {
    private let calendar = GrassFixture.seoul

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      _ hour: Int = 12, _ minute: Int = 0) -> Date
    {
        GrassFixture.date(year, month, day, hour, minute)
    }

    private func input(_ year: Int, _ month: Int, _ day: Int,
                       seconds: Int = 1800,
                       segments: [(SegmentKind, Int)] = [],
                       bodyParts: [BodyPart] = []) -> StatisticsRecordInput
    {
        .init(startedAt: date(year, month, day),
              totalSeconds: seconds,
              totalCalories: nil,
              bodyParts: bodyParts,
              segments: segments.map { .init(kind: $0.0, durationSeconds: $0.1) })
    }

    private func dashboard(_ inputs: [StatisticsRecordInput],
                           selectedYear: Int? = nil,
                           now: Date? = nil,
                           calendar: Calendar? = nil) -> StatisticsDashboard
    {
        StatisticsBuilder.dashboard(from: inputs, aggregates: [], selectedYear: selectedYear,
                                    now: now ?? date(2026, 10, 8), calendar: calendar ?? self.calendar)
    }

    @Test("같은 날 두 세션은 횟수 둘, 잔디 한 칸으로 집계한다")
    func sameDayCountsTwoSessionsAndOneGrassDay() {
        let records = [input(2026, 10, 6, seconds: 900), input(2026, 10, 6, seconds: 900)]
        let result = dashboard(records, selectedYear: 2026)
        #expect(result.countText == "2회")
        #expect(result.months[9].count == 2)
        #expect(result.weekdays[1].count == 2)
    }

    @Test("기록이 없으면 현재 연도와 빈 안내를 보여준다")
    func emptyHistory() {
        let result = dashboard([])
        #expect(result.availableYears == [2026])
        #expect(result.countText == "0회")
        #expect(result.durationText == "0분")
        #expect(result.weeklyAverageText == "주 0.0회")
        #expect(result.emptyMessage == "아직 운동 기록이 없어요")
    }

    @Test("과거 기록만 있으면 현재와 과거 연도를 선택할 수 있다")
    func emptyCurrentYearWithOlderHistory() {
        let result = dashboard([input(2025, 3, 1)])
        #expect(result.availableYears == [2026, 2025])
        #expect(result.year == 2026)
        #expect(result.emptyMessage == "2026년에는 아직 기록이 없어요")
    }

    @Test("기록 없는 중간 연도와 미래 연도는 선택지에서 뺀다")
    func yearsSkipGapsAndFuture() {
        let result = dashboard([input(2023, 1, 1), input(2025, 1, 1), input(2027, 1, 1)])
        #expect(result.availableYears == [2026, 2025, 2023])
    }

    @Test("없어진 선택 연도는 현재 연도로 되돌린다")
    func deletedYearFallsBack() {
        #expect(dashboard([], selectedYear: 2025).year == 2026)
    }

    @Test("유효한 과거 선택은 새해에도 유지한다")
    func newYearKeepsValidSelection() {
        let result = dashboard([input(2026, 12, 31)], selectedYear: 2026,
                               now: date(2027, 1, 1))
        #expect(result.year == 2026)
    }

    @Test("세션은 끝난 해가 아니라 시작한 해에 속한다")
    func crossYearUsesStart() {
        let result = dashboard([input(2025, 12, 31)], selectedYear: 2025)
        #expect(result.countText == "1회")
        #expect(dashboard([input(2025, 12, 31)], selectedYear: 2026).countText == "0회")
    }

    @Test("미래에 시작하는 기록은 모든 집계에서 제외한다")
    func futureStartsExcluded() {
        let future = StatisticsRecordInput(startedAt: date(2026, 10, 8, 18), totalSeconds: 3600,
                                           totalCalories: nil, bodyParts: [.chest],
                                           segments: [.init(kind: .strength, durationSeconds: 3600)])
        let result = dashboard([future], selectedYear: 2026, now: date(2026, 10, 8))
        #expect(result.countText == "0회")
        #expect(result.composition == nil)
        #expect(result.bodyParts.isEmpty)
    }

    @Test("주 평균은 현재 연도의 달력 날짜 수로 환산한다")
    func januaryFirstAverage() {
        let result = dashboard([input(2026, 1, 1)], selectedYear: 2026, now: date(2026, 1, 1))
        #expect(result.weeklyAverageText == "주 7.0회")
    }

    @Test("과거 윤년은 366일로 주 평균을 계산한다")
    func pastLeapYearAverage() {
        let inputs = (1 ... 52).map { input(2024, 1, $0 <= 31 ? $0 : 1) }
        let result = dashboard(inputs, selectedYear: 2024, now: date(2026, 10, 8))
        #expect(result.weeklyAverageText == "주 1.0회")
    }

    @Test("연간 잔디에는 윤년의 모든 날짜가 한 번씩 들어간다")
    func gridCoversLeapYear() {
        let result = dashboard([input(2024, 1, 1)], selectedYear: 2024)
        let days = result.gridDays.filter { calendar.component(.year, from: $0) == 2024 }
        #expect(days.count == 366)
        #expect(Set(days).count == 366)
        #expect(calendar.component(.weekday, from: result.gridDays[0]) == calendar.firstWeekday)
    }

    @Test("54열이 필요한 해는 잘리지 않는다")
    func gridAllows54Columns() {
        var sunday = calendar
        sunday.firstWeekday = 1
        let result = dashboard([input(2000, 1, 1)], selectedYear: 2000, calendar: sunday)
        #expect(result.gridDays.count / 7 == 54)
        #expect(result.gridDays.contains(sunday.startOfDay(for: date(2000, 1, 1))))
        #expect(result.gridDays.contains(sunday.startOfDay(for: date(2000, 12, 31))))
    }

    @Test("시간은 1시간 미만에서 분, 이상에서 시간으로 쓴다")
    func durationFormatting() {
        #expect(dashboard([]).durationText == "0분")
        #expect(dashboard([input(2026, 1, 1, seconds: 2400)]).durationText == "40분")
        #expect(dashboard([input(2026, 1, 1, seconds: 5400)]).durationText == "1.5시간")
    }

    @Test("구간이 없거나 0초면 구성은 만들지 않는다")
    func zeroAndMissingSegments() {
        #expect(dashboard([input(2026, 1, 1)]).composition == nil)
        #expect(dashboard([input(2026, 1, 1, segments: [(.strength, 0)])]).composition == nil)
    }

    @Test("한 유형과 반올림 구성 비율을 보존한다")
    func oneKindAndRounding() {
        let strength = dashboard([input(2026, 1, 1, segments: [(.strength, 60)])])
        #expect(strength.composition?.strengthPercent == 100)
        #expect(strength.composition?.cardioPercent == 0)
        let mixed = dashboard([input(2026, 1, 1, segments: [(.strength, 1), (.cardio, 2)])])
        #expect(mixed.composition?.strengthPercent == 33)
        #expect(mixed.composition?.cardioPercent == 67)
    }

    @Test("부위는 세션 단위로 중복 없이 센다")
    func bodyTagsCountSessions() {
        let result = dashboard([
            input(2026, 1, 1, bodyParts: [.chest, .chest, .back]),
            input(2026, 1, 2, bodyParts: [.chest])
        ])
        #expect(result.bodyParts == [
            .init(part: .chest, count: 2),
            .init(part: .back, count: 1)
        ])
    }

    @Test("동률 부위는 앱의 부위 순서로 정렬한다")
    func bodyTieUsesCaseOrder() {
        let result = dashboard([input(2026, 1, 1, bodyParts: [.back]), input(2026, 1, 2, bodyParts: [.chest])])
        #expect(result.bodyParts.map(\.part) == [.chest, .back])
    }

    @Test("요일 최다 동률은 모두 강조하고 빈 데이터는 강조하지 않는다")
    func weekdayTiesAndZero() {
        let result = dashboard([input(2026, 1, 5), input(2026, 1, 7)])
        #expect(result.weekdays.filter(\.isHighlighted).map(\.title) == ["월", "수"])
        #expect(dashboard([]).weekdays.allSatisfy { !$0.isHighlighted })
    }

    @Test(arguments: [(9, 10, 1), (10, 25, 15), (25, 50, 25), (142, 200, 58), (500, 0, 0)])
    func milestoneBoundaries(count: Int, next: Int, remaining: Int) {
        let inputs = (0 ..< count).map { _ in input(2026, 1, 1) }
        let milestones = dashboard(inputs).milestones
        if next == 0 {
            #expect(milestones.allSatisfy { $0.isAchieved })
        } else {
            let locked = milestones.first { !$0.isAchieved }
            #expect(locked?.target == next)
            #expect(locked?.remaining == remaining)
        }
    }

    @Test("값 스냅샷은 같은 영속 모델의 제자리 편집을 감지한다")
    func snapshotSeesInPlaceEdits() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: date(2026, 1, 1), totalSeconds: 1800,
                                         segments: [(.strength, 0, 1800)])
        let before = StatisticsRecordInput(record: record)
        record.totalSeconds = 3600
        record.bodyPartsRaw = [BodyPart.chest.rawValue]
        record.segments = [Segment(kind: .cardio, startOffset: 0, durationSeconds: 3600)]
        let after = StatisticsRecordInput(record: record)
        #expect(before != after)
    }
}
