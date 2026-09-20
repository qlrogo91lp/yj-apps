import Foundation

enum SummaryPeriod: String, CaseIterable {
    case week, month, all

    var localizedTitle: String {
        switch self {
        case .week: String(localized: "summary_period_week")
        case .month: String(localized: "summary_period_month")
        case .all: String(localized: "summary_period_all")
        }
    }

    func startDate(from now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .week: return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: components)
        // 시작점이 없으면 filteredMatches 가 전체를 돌려준다.
        case .all: return nil
        }
    }
}

struct SummaryStats {
    let totalMatches: Int
    let wins: Int
    let winRate: Double
    /// 활동 에너지 합계.
    let totalCalories: Double?
    let totalDuration: Int?
    let sessionCount: Int
    let averageSessionSeconds: Int?

    var formattedCalories: String {
        totalCalories.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "–"
    }

    /// 누적이라 스톱워치 포맷(WorkoutMetrics.formatSeconds)을 쓰지 않는다 — 470:00:00 은 카드에서 넘친다.
    var formattedDuration: String {
        totalDuration.map(CumulativeDuration.format) ?? "–"
    }

    var formattedAverageSessionDuration: String {
        averageSessionSeconds.map(CumulativeDuration.format) ?? "–"
    }
}

@MainActor
final class SummaryViewModel: ObservableObject {
    @Published var selectedPeriod: SummaryPeriod = .week

    func stats(from matches: [Match], records: [WorkoutSessionRecord]) -> SummaryStats {
        let filtered = filteredMatches(from: matches)
        let wins = filtered.count(where: { $0.myTotalSets > $0.yourTotalSets })
        let total = filtered.count
        let winRate = total > 0 ? Double(wins) / Double(total) : 0.0

        let sessions = selectedPeriodSessions(from: matches, records: records)
        let calories = sessions.compactMap { session -> Double? in
            if let record = session.record { return record.activeCalories }
            return session.matches.compactMap { $0.workoutCaloriesBurned ?? $0.caloriesBurned }.max()
        }
        let durations = sessions.compactMap { session -> Int? in
            if let record = session.record { return record.elapsedSeconds }
            return session.matches.compactMap { match -> Int? in
                if let cumulative = match.workoutElapsedSeconds { return cumulative }
                if let duration = match.durationSeconds { return duration }
                return match.endedAt.map { Int($0.timeIntervalSince(match.startedAt)) }
            }.max()
        }

        return SummaryStats(
            totalMatches: total,
            wins: wins,
            winRate: winRate,
            totalCalories: calories.isEmpty ? nil : calories.reduce(0, +),
            totalDuration: durations.isEmpty ? nil : durations.reduce(0, +),
            sessionCount: sessions.count,
            averageSessionSeconds: durations.isEmpty ? nil : durations.reduce(0, +) / durations.count
        )
    }

    /// 최근 세션 하나. 기간 필터를 탄다.
    func recentSession(from matches: [Match], records: [WorkoutSessionRecord]) -> MatchSessionGroup? {
        selectedPeriodSessions(from: matches, records: records).first
    }

    /// matches는 필터링되지 않은 전체 소스다. 기간에 걸친 세션도 전체 경기와 한 번만 묶는다.
    /// 선택된 경기와 연결된 레코드, 전체 소스에도 경기가 없는 기간 내 레코드만 포함한다.
    func selectedPeriodSessions(from matches: [Match], records: [WorkoutSessionRecord]) -> [MatchSessionGroup] {
        let filtered = filteredMatches(from: matches)
        let selectedSessionIds = Set(filtered.compactMap(\.workoutSessionId))
        let selectedMatchIds = Set(filtered.map(\.id))
        let sessionMatches = matches.filter { match in
            if let id = match.workoutSessionId { return selectedSessionIds.contains(id) }
            return selectedMatchIds.contains(match.id)
        }
        let groupingRecords = MatchSessionGroup.recordsForGrouping(
            records,
            displayedMatches: sessionMatches,
            sourceMatches: matches
        ) { [selectedPeriod] record in
            guard let start = selectedPeriod.startDate() else { return true }
            return record.startedAt >= start
        }
        return MatchSessionGroup.group(sessionMatches, records: groupingRecords)
    }

    /// 최근 10회 세션, 오래된 것부터. 기간 필터와 무관하게 항상 전체에서 뽑는다 —
    /// 차트는 "얼마나 오래 쳤나"만 맡는 독립 블록이다.
    /// 3개 미만이면 빈 배열을 돌려 뷰가 안내 문구를 띄우게 한다.
    func trendSessions(from matches: [Match], records: [WorkoutSessionRecord]) -> [MatchSessionGroup] {
        let groups = MatchSessionGroup.group(matches, records: records)
        guard groups.count >= 3 else { return [] }
        return Array(groups.prefix(10)).reversed()
    }

    /// 전체 기간의 월별 세션 수. 전체 소스를 먼저 묶어 월 경계를 넘는 세션도 한 번만 센다.
    func monthlySessionCounts(from matches: [Match], records: [WorkoutSessionRecord]) -> [(month: Date, count: Int)] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for session in MatchSessionGroup.group(matches, records: records) {
            guard let month = calendar.date(from: calendar.dateComponents([.year, .month], from: session.date)) else { continue }
            counts[month, default: 0] += 1
        }
        return counts.keys.sorted().map { (month: $0, count: counts[$0] ?? 0) }
    }

    func filteredMatches(from matches: [Match]) -> [Match] {
        guard let start = selectedPeriod.startDate() else { return matches }
        return matches.filter { $0.startedAt >= start }
    }
}
