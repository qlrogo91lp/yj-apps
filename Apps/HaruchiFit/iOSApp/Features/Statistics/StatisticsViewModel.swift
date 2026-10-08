import Combine
import Foundation

/// 통계 화면 상태의 배선. 집계 규칙은 `StatisticsBuilder`가 소유한다.
@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var dashboard: StatisticsDashboard

    init(calendar: Calendar = .current) {
        dashboard = StatisticsBuilder.dashboard(from: [], aggregates: [], selectedYear: nil,
                                                now: Date(), calendar: calendar)
    }

    func rebuild(from records: [WorkoutRecord], now: Date = Date(), calendar: Calendar = .current) {
        rebuild(from: records, selectedYear: dashboard.year, now: now, calendar: calendar)
    }

    func select(year: Int, from records: [WorkoutRecord], now: Date = Date(), calendar: Calendar = .current) {
        rebuild(from: records, selectedYear: year, now: now, calendar: calendar)
    }

    private func rebuild(from records: [WorkoutRecord], selectedYear: Int?, now: Date, calendar: Calendar) {
        let eligible = records.filter { $0.startedAt <= now }
        dashboard = StatisticsBuilder.dashboard(from: eligible.map(StatisticsRecordInput.init(record:)),
                                                aggregates: GrassAggregator.fold(eligible, calendar: calendar),
                                                selectedYear: selectedYear, now: now, calendar: calendar)
    }
}
