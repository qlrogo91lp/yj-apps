import Foundation

enum SummaryPeriod: String, CaseIterable {
    case today
    case week
    case month
    case all

    var localizedTitle: String {
        switch self {
        case .today: return String(localized: "summary_period_today")
        case .week: return String(localized: "summary_period_week")
        case .month: return String(localized: "summary_period_month")
        case .all: return String(localized: "summary_period_all")
        }
    }

    func startDate(from now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: components)
        case .all:
            return nil
        }
    }
}
