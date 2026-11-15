import Foundation

/// 캘린더의 날짜별 점과 달 요약. 세션의 날짜는 **시작 시각** 기준이다.
enum CalendarMarks {
    enum Mark: Equatable { case none, drank, exceeded }

    struct Totals: Equatable {
        let count: Int
        let equivalent: Double
        let exceededCount: Int

        /// 달 위에 보이는 한 줄. "6회 · 41잔 · 한도 초과 2회"
        var line: String {
            "\(count)회 · \(SojuFormat.string(equivalent))잔 · 한도 초과 \(exceededCount)회"
        }
    }

    /// 그 달의 모든 날(자정)을 키로 갖는다. 마신 잔이 없는 날은 `.none`.
    /// 하루에 세션이 여럿이면 하나라도 한도를 넘었을 때 `.exceeded`.
    static func of(_ sessions: [SessionRecord], month: Date, calendar: Calendar) -> [Date: Mark] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        var marks: [Date: Mark] = [:]
        var day = interval.start
        while day < interval.end {
            marks[day] = Mark.none
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for session in sessions where interval.contains(session.startedAt) && session.totalGrams > 0 {
            let key = calendar.startOfDay(for: session.startedAt)
            if session.limitLevel == .exceeded {
                marks[key] = .exceeded
            } else if marks[key] != .exceeded {
                marks[key] = .drank
            }
        }
        return marks
    }

    static func totals(_ sessions: [SessionRecord], month: Date, calendar: Calendar) -> Totals {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            return Totals(count: 0, equivalent: 0, exceededCount: 0)
        }
        let inMonth = sessions.filter { interval.contains($0.startedAt) }
        let equivalent = inMonth.reduce(0) { $0 + ($1.sojuEquivalent.isFinite ? $1.sojuEquivalent : 0) }
        return Totals(
            count: inMonth.count,
            equivalent: equivalent,
            exceededCount: inMonth.count(where: { $0.limitLevel == .exceeded })
        )
    }
}
