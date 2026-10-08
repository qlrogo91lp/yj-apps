import Foundation

/// 연도 통계의 모든 집계 규칙. 홈·통계 UI와 분리해 워치 테스트에서 검증한다.
enum StatisticsBuilder {
    private static let milestones = [10, 25, 50, 100, 200, 300, 500]
    private static let monthTitles = (1 ... 12).map { "\($0)월" }
    private static let weekdayTitles = ["월", "화", "수", "목", "금", "토", "일"]

    static func dashboard(from inputs: [StatisticsRecordInput],
                          aggregates: [DailyAggregate],
                          selectedYear: Int?,
                          now: Date,
                          calendar: Calendar) -> StatisticsDashboard
    {
        let today = calendar.startOfDay(for: now)
        let currentYear = calendar.component(.year, from: today)
        let pastYears = Set(inputs.filter { $0.startedAt <= now }.map { calendar.component(.year, from: $0.startedAt) })
            .filter { $0 < currentYear }
        let availableYears = [currentYear] + pastYears.sorted(by: >)
        let year = availableYears.contains(selectedYear ?? currentYear) ? (selectedYear ?? currentYear) : currentYear
        let yearInterval = calendar.dateInterval(of: .year, for: date(in: year, calendar: calendar))!
        let eligible = inputs.filter { $0.startedAt <= now && yearInterval.contains($0.startedAt) }
        let isCurrentYear = year == currentYear
        let end = isCurrentYear ? today : calendar.date(byAdding: .day, value: -1, to: yearInterval.end)!

        let grid = gridDays(for: yearInterval, calendar: calendar)
        let monthColumns = Dictionary(uniqueKeysWithValues: (1 ... 12).map { month in
            let first = date(in: year, month: month, day: 1, calendar: calendar)
            return (month, grid.firstIndex(of: first)! / 7)
        })

        let levels = Dictionary(uniqueKeysWithValues: aggregates
            .filter { $0.day >= yearInterval.start && $0.day <= end }
            .map { ($0.day, GrassIntensity.byTime.level(for: $0)) })
        let count = eligible.count
        let duration = eligible.reduce(0) { $0 + $1.totalSeconds }
        let periodDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: yearInterval.start), to: end).day! + 1
        let weeklyAverage = Double(count) / (Double(periodDays) / 7)

        return StatisticsDashboard(
            year: year,
            availableYears: availableYears,
            countText: "\(count)회",
            durationText: durationText(seconds: duration),
            weeklyAverageText: String(format: "주 %.1f회", weeklyAverage),
            weeklyAverageExplanation: isCurrentYear
                ? "1월 1일부터 오늘까지의 기록을 주 단위로 환산해요."
                : "선택한 연도 전체의 기록을 주 단위로 환산해요.",
            isCurrentYear: isCurrentYear,
            emptyMessage: emptyMessage(count: count, year: year, currentYear: currentYear, allInputs: inputs, now: now),
            months: monthFrequencies(eligible, year: year, currentYear: currentYear, now: now, calendar: calendar),
            weekdays: weekdayFrequencies(eligible, calendar: calendar),
            composition: composition(of: eligible),
            bodyParts: bodyPartFrequencies(eligible),
            milestones: milestoneValues(count: count),
            gridDays: grid,
            grassLevels: levels,
            monthColumns: monthColumns,
            initialColumn: isCurrentYear ? grid.firstIndex(of: today).map { $0 / 7 } ?? 0 : 0,
            today: today)
    }

    private static func emptyMessage(count: Int, year: Int, currentYear: Int,
                                     allInputs: [StatisticsRecordInput], now: Date) -> String?
    {
        guard count == 0 else { return nil }
        return allInputs.contains(where: { $0.startedAt <= now }) ? "\(year)년에는 아직 기록이 없어요" : "아직 운동 기록이 없어요"
    }

    private static func monthFrequencies(_ inputs: [StatisticsRecordInput], year: Int, currentYear: Int,
                                         now: Date, calendar: Calendar) -> [StatisticsDashboard.Frequency]
    {
        let counts = Dictionary(grouping: inputs, by: { calendar.component(.month, from: $0.startedAt) })
        let currentMonth = calendar.component(.month, from: now)
        return (1 ... 12).map { month in
            .init(id: month, title: monthTitles[month - 1], count: counts[month]?.count ?? 0,
                  isFuture: year == currentYear && month > currentMonth, isHighlighted: true)
        }
    }

    private static func weekdayFrequencies(_ inputs: [StatisticsRecordInput], calendar: Calendar) -> [StatisticsDashboard.Frequency] {
        let counts = inputs.reduce(into: Array(repeating: 0, count: 7)) { counts, input in
            counts[(calendar.component(.weekday, from: input.startedAt) + 5) % 7] += 1
        }
        let maximum = counts.max() ?? 0
        return counts.enumerated().map { index, count in
            .init(id: index + 1, title: weekdayTitles[index], count: count,
                  isFuture: false, isHighlighted: maximum > 0 && count == maximum)
        }
    }

    private static func composition(of inputs: [StatisticsRecordInput]) -> StatisticsDashboard.Composition? {
        let seconds = inputs.flatMap(\.segments).reduce(into: (strength: 0, cardio: 0)) { result, segment in
            switch segment.kind {
            case .strength: result.strength += segment.durationSeconds
            case .cardio: result.cardio += segment.durationSeconds
            }
        }
        let total = seconds.strength + seconds.cardio
        guard total > 0 else { return nil }
        let strengthPercent = Int((Double(seconds.strength) / Double(total) * 100).rounded())
        return .init(strengthSeconds: seconds.strength,
                     cardioSeconds: seconds.cardio,
                     strengthPercent: strengthPercent,
                     cardioPercent: 100 - strengthPercent,
                     strengthText: hoursText(seconds: seconds.strength),
                     cardioText: hoursText(seconds: seconds.cardio))
    }

    private static func bodyPartFrequencies(_ inputs: [StatisticsRecordInput]) -> [StatisticsDashboard.BodyFrequency] {
        let counts = inputs.reduce(into: [BodyPart: Int]()) { counts, input in
            Set(input.bodyParts).forEach { counts[$0, default: 0] += 1 }
        }
        return counts.map { .init(part: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return BodyPart.allCases.firstIndex(of: $0.part)! < BodyPart.allCases.firstIndex(of: $1.part)!
            }
    }

    private static func milestoneValues(count: Int) -> [StatisticsDashboard.Milestone] {
        milestones.map { target in
            .init(target: target, remaining: max(0, target - count), isAchieved: count >= target)
        }
    }

    private static func gridDays(for interval: DateInterval, calendar: Calendar) -> [Date] {
        let firstWeek = calendar.dateInterval(of: .weekOfYear, for: interval.start)!.start
        let finalDay = calendar.date(byAdding: .day, value: -1, to: interval.end)!
        let lastWeekEnd = calendar.dateInterval(of: .weekOfYear, for: finalDay)!.end
        let count = calendar.dateComponents([.day], from: firstWeek, to: lastWeekEnd).day!
        return (0 ..< count).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek) }
    }

    private static func date(in year: Int, month: Int = 1, day: Int = 1, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func durationText(seconds: Int) -> String {
        seconds < 3600 ? "\(seconds / 60)분" : String(format: "%.1f시간", Double(seconds) / 3600)
    }

    private static func hoursText(seconds: Int) -> String {
        String(format: "%.1fh", Double(seconds) / 3600)
    }
}
