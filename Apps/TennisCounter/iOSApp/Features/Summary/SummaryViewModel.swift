import Foundation
import WorkoutCore

enum SummaryPeriod: String, CaseIterable {
    case today, week, month

    var localizedTitle: String {
        switch self {
        case .today: String(localized: "summary_period_today")
        case .week: String(localized: "summary_period_week")
        case .month: String(localized: "summary_period_month")
        }
    }

    func startDate(from now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .today: return calendar.startOfDay(for: now)
        case .week: return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: components)
        }
    }
}

struct SummaryStats {
    let totalMatches: Int
    let wins: Int
    let winRate: Double
    /// 활동 에너지 합계.
    let totalCalories: Double?
    /// 활동 + 휴식 합계. 총 칼로리 도입 이전 기록만 있으면 nil.
    let totalEnergy: Double?
    let totalDuration: Int?
    let avgHeartRate: Double?

    var formattedCalories: String {
        totalCalories.map { String(format: "%.0f", $0) } ?? "–"
    }

    var formattedTotalEnergy: String {
        totalEnergy.map { String(format: "%.0f", $0) } ?? "–"
    }

    var formattedDuration: String {
        totalDuration.map { WorkoutMetrics.formatSeconds($0) } ?? "–"
    }

    var formattedHeartRate: String {
        avgHeartRate.map { String(format: "%.0f", $0) } ?? "–"
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
        let totalEnergy = sumOfWorkoutMaxima(filtered) { $0.workoutTotalCaloriesBurned ?? $0.totalCaloriesBurned }
        let totalDuration = sumOfWorkoutMaxima(filtered) { match in
            if let cumulative = match.workoutElapsedSeconds { return cumulative }
            if let d = match.durationSeconds { return d }
            if let end = match.endedAt { return Int(end.timeIntervalSince(match.startedAt)) }
            return nil
        }

        let heartRates = filtered.compactMap(\.averageHeartRate)
        let avgHeartRate: Double? = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)

        return SummaryStats(
            totalMatches: total,
            wins: wins,
            winRate: winRate,
            totalCalories: totalCalories,
            totalEnergy: totalEnergy,
            totalDuration: totalDuration,
            avgHeartRate: avgHeartRate
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

    func recentMatches(from matches: [Match]) -> [Match] {
        Array(matches.prefix(2))
    }

    func filteredMatches(from matches: [Match]) -> [Match] {
        guard let start = selectedPeriod.startDate() else { return matches }
        return matches.filter { $0.startedAt >= start }
    }
}
