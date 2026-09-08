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

    var formattedCalories: String {
        totalCalories.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "–"
    }

    /// 누적이라 스톱워치 포맷(WorkoutMetrics.formatSeconds)을 쓰지 않는다 — 470:00:00 은 카드에서 넘친다.
    var formattedDuration: String {
        totalDuration.map(CumulativeDuration.format) ?? "–"
    }
}

@MainActor
final class SummaryViewModel: ObservableObject {
    @Published var selectedPeriod: SummaryPeriod = .week

    func stats(from matches: [Match]) -> SummaryStats {
        let filtered = filteredMatches(from: matches)
        let wins = filtered.count(where: { $0.myTotalSets > $0.yourTotalSets })
        let total = filtered.count
        let winRate = total > 0 ? Double(wins) / Double(total) : 0.0

        let totalCalories = sumOfWorkoutMaxima(filtered) { $0.workoutCaloriesBurned ?? $0.caloriesBurned }
        let totalDuration = sumOfWorkoutMaxima(filtered) { match in
            if let cumulative = match.workoutElapsedSeconds { return cumulative }
            if let d = match.durationSeconds { return d }
            if let end = match.endedAt { return Int(end.timeIntervalSince(match.startedAt)) }
            return nil
        }

        return SummaryStats(
            totalMatches: total,
            wins: wins,
            winRate: winRate,
            totalCalories: totalCalories,
            totalDuration: totalDuration
        )
    }

    /// 워크아웃 누적 지표는 그룹당 최댓값 하나만 취한다 — 같은 워크아웃의 경기들이 하나의
    /// 누적 축을 공유하므로 단순 합산하면 같은 칼로리·시간을 여러 번 세게 된다.
    /// workoutSessionId가 없는 레코드는 서로 묶을 근거가 없어 각자 한 워크아웃으로 본다.
    private func sumOfWorkoutMaxima<T: Comparable & AdditiveArithmetic>(
        _ matches: [Match], _ value: (Match) -> T?
    ) -> T? {
        var maxByWorkout: [UUID: T] = [:]
        var ungrouped: [T] = []
        for match in matches {
            guard let v = value(match) else { continue }
            if let sid = match.workoutSessionId {
                maxByWorkout[sid] = Swift.max(maxByWorkout[sid] ?? v, v)
            } else {
                ungrouped.append(v)
            }
        }
        let all = Array(maxByWorkout.values) + ungrouped
        return all.isEmpty ? nil : all.reduce(.zero, +)
    }

    /// 최근 세션 하나. 기간 필터를 탄다.
    func recentSession(from matches: [Match]) -> MatchSessionGroup? {
        MatchSessionGroup.group(filteredMatches(from: matches)).first
    }

    /// 최근 10회 세션, 오래된 것부터. 기간 필터와 무관하게 항상 전체에서 뽑는다 —
    /// 차트는 "얼마나 오래 쳤나"만 맡는 독립 블록이다.
    /// 3개 미만이면 빈 배열을 돌려 뷰가 안내 문구를 띄우게 한다.
    func trendSessions(from matches: [Match]) -> [MatchSessionGroup] {
        let groups = MatchSessionGroup.group(matches)
        guard groups.count >= 3 else { return [] }
        return Array(groups.prefix(10)).reversed()
    }

    func filteredMatches(from matches: [Match]) -> [Match] {
        guard let start = selectedPeriod.startDate() else { return matches }
        return matches.filter { $0.startedAt >= start }
    }
}
