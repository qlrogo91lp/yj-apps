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
    let streak: Int
}

@MainActor
final class SummaryViewModel: ObservableObject {
    @Published var selectedPeriod: SummaryPeriod = .week
    @Published var selectedMatch: Match?

    func stats(from matches: [Match]) -> SummaryStats {
        let filtered = filteredMatches(from: matches)
        let wins = filtered.count(where: { $0.myTotalSets > $0.yourTotalSets })
        let total = filtered.count
        let winRate = total > 0 ? Double(wins) / Double(total) : 0.0
        return SummaryStats(totalMatches: total, wins: wins, winRate: winRate, streak: calculateStreak(from: matches))
    }

    func recentMatches(from matches: [Match]) -> [Match] {
        Array(matches.prefix(2))
    }

    func filteredMatches(from matches: [Match]) -> [Match] {
        guard let start = selectedPeriod.startDate() else { return matches }
        return matches.filter { $0.startedAt >= start }
    }

    private func calculateStreak(from matches: [Match]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        for match in matches {
            let matchDay = calendar.startOfDay(for: match.startedAt)
            let currentDay = calendar.startOfDay(for: checkDate)
            let diff = calendar.dateComponents([.day], from: matchDay, to: currentDay).day ?? 0
            if diff == 0 || diff == streak {
                streak = max(streak, diff + 1)
                checkDate = match.startedAt
            } else {
                break
            }
        }
        return streak
    }
}
