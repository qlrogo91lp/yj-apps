import Foundation

/// 홈 대시보드의 표시 규칙 (제품 스펙 02절). 잔디 규칙은 `GrassAggregator` · `GrassIntensity` 가 갖고,
/// 이 타입은 스탯 · 이번 주 구성 · 마일스톤만 낸다.
///
/// 주의 경계는 `calendar` 의 `.weekOfYear` 를 따른다 — 기록 목록의 `이번 주` · 잔디 그리드와 같은 규칙이다.
enum HomeDashboardBuilder {
    /// 이 횟수 미만이면 구성 바 대신 마일스톤을 보인다. 데이터 3개로 그린 비율 바는 노이즈다.
    static let compositionThreshold = 3

    static func dashboard(from records: [WorkoutRecord],
                          now: Date = Date(),
                          calendar: Calendar = .current,
                          locale: Locale = Locale(identifier: "ko_KR")) -> HomeDashboard
    {
        let monthFormatter = RecordListBuilder.formatter("M월 yyyy", calendar: calendar, locale: locale)
        let month = calendar.dateInterval(of: .month, for: now)
        let thisMonth = records.filter { month?.contains($0.startedAt) ?? false }

        var week: HomeDashboard.WeekComposition?
        var milestone: String?
        var emptyWeekText: String?
        if records.count < compositionThreshold {
            milestone = milestoneText(recordCount: records.count)
        } else {
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)
            let weekRecords = records.filter { thisWeek?.contains($0.startedAt) ?? false }
            if weekRecords.isEmpty {
                emptyWeekText = "이번 주는 아직 기록이 없어요"
            } else {
                week = composition(of: weekRecords)
            }
        }

        return HomeDashboard(monthTitle: monthFormatter.string(from: now),
                             monthStat: stat(of: thisMonth),
                             totalStat: stat(of: records),
                             week: week,
                             milestone: milestone,
                             emptyWeekText: emptyWeekText)
    }

    /// 오늘이 든 주를 오른쪽 끝에 두고 `weeks` 주를 거슬러 올라간다. 왼쪽 위가 가장 오래된 날이다.
    static func gridDays(weeks: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let start = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek)
        else { return [] }
        return (0 ..< weeks * 7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private static func milestoneText(recordCount: Int) -> String {
        if recordCount == 0 { return "워치에서 첫 운동을 기록해 보세요" }
        return "\(compositionThreshold)번째 운동을 기록하면 이번 주 구성이 보여요 · \(compositionThreshold - recordCount)회 남음"
    }

    private static func stat(of records: [WorkoutRecord]) -> HomeDashboard.Stat {
        .init(countText: "\(records.count)회",
              durationText: durationText(seconds: records.reduce(0) { $0 + $1.totalSeconds }))
    }

    /// 1시간 미만은 분, 이상은 소수 첫째 자리 시간 — 03a 달력 월 요약(`12회 · 9.2시간`)과 같은 표기다.
    private static func durationText(seconds: Int) -> String {
        seconds < 3600 ? "\(seconds / 60)분" : String(format: "%.1f시간", Double(seconds) / 3600)
    }

    private static func composition(of records: [WorkoutRecord]) -> HomeDashboard.WeekComposition {
        var strength = 0
        var cardio = 0
        for segment in records.flatMap(\.orderedSegments) {
            switch segment.kind {
            case .strength: strength += segment.durationSeconds
            case .cardio: cardio += segment.durationSeconds
            }
        }
        let legend = [(SegmentKind.strength, strength), (.cardio, cardio)]
            .filter { $0.1 > 0 }
            .map { HomeDashboard.Legend(kind: $0.0, text: "\($0.0.title) \(hoursText(seconds: $0.1))") }
        return .init(totalText: hoursText(seconds: records.reduce(0) { $0 + $1.totalSeconds }),
                     strengthSeconds: strength,
                     cardioSeconds: cardio,
                     legend: legend)
    }

    private static func hoursText(seconds: Int) -> String {
        String(format: "%.1fh", Double(seconds) / 3600)
    }
}
