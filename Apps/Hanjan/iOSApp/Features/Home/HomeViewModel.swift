import Foundation

struct MonthSummary {
    let count: Int
    let equivalent: Double
    let exceededCount: Int

    static func of(_ sessions: [SessionRecord], month: Date, calendar: Calendar = .current) -> MonthSummary {
        let records = sessions.filter { $0.endedAt != nil && calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
        return MonthSummary(count: records.count, equivalent: records.reduce(0) { $0 + $1.sojuEquivalent },
                            exceededCount: records.count(where: { $0.limitLevel == .exceeded }))
    }
}
