import Foundation

enum SummaryPeriod: String, CaseIterable {
    case today, week, month, all

    var localizedTitle: String {
        switch self {
        case .today: String(localized: "summary_period_today")
        case .week: String(localized: "summary_period_week")
        case .month: String(localized: "summary_period_month")
        case .all: String(localized: "summary_period_all")
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
        case .all: return nil
        }
    }
}

struct SummaryStats {
    let totalMatches: Int
    let wins: Int
    let winRate: Double
    let totalCalories: Double?
    let totalDuration: Int?
    let avgHeartRate: Double?

    var formattedCalories: String {
        totalCalories.map { String(format: "%.0f", $0) } ?? "–"
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

        let calories = filtered.compactMap(\.caloriesBurned)
        let totalCalories: Double? = calories.isEmpty ? nil : calories.reduce(0, +)

        let durations: [Int] = filtered.compactMap { match in
            if let d = match.durationSeconds { return d }
            if let end = match.endedAt { return Int(end.timeIntervalSince(match.startedAt)) }
            return nil
        }
        let totalDuration: Int? = durations.isEmpty ? nil : durations.reduce(0, +)

        let heartRates = filtered.compactMap(\.averageHeartRate)
        let avgHeartRate: Double? = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)

        return SummaryStats(
            totalMatches: total,
            wins: wins,
            winRate: winRate,
            totalCalories: totalCalories,
            totalDuration: totalDuration,
            avgHeartRate: avgHeartRate
        )
    }

    func recentMatches(from matches: [Match]) -> [Match] {
        Array(matches.prefix(2))
    }

    func filteredMatches(from matches: [Match]) -> [Match] {
        guard let start = selectedPeriod.startDate() else { return matches }
        return matches.filter { $0.startedAt >= start }
    }
}
