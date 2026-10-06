import Combine
import Foundation

/// 홈 대시보드의 배선. **규칙은 하나도 들고 있지 않다** — 전부 `HomeDashboardBuilder` 와
/// `RecordListBuilder` 에 있다 (iOS 테스트 타깃이 없어 여기 둔 규칙은 검증되지 않는다).
/// 잔디 농도는 `GrassViewModel` 이 따로 맡는다.
@MainActor
final class HomeViewModel: ObservableObject {
    static let grassWeeks = 26
    private static let recentCount = 2

    @Published private(set) var dashboard: HomeDashboard
    @Published private(set) var recentRows: [RecordListRow] = []
    /// 잔디 칸 날짜. 오늘이 든 주가 오른쪽 끝이다.
    @Published private(set) var gridDays: [Date] = []
    /// 오늘 칸 — 펄스를 줄 자리.
    @Published private(set) var today: Date

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        today = calendar.startOfDay(for: Date())
        dashboard = HomeDashboardBuilder.dashboard(from: [], calendar: calendar)
    }

    /// View 가 `@Query` 로 읽은 **전체** 기록을 밀어넣는다. `이번 주` · 오늘 칸은 부른 시각 기준이다.
    func rebuild(from records: [WorkoutRecord]) {
        let now = Date()
        today = calendar.startOfDay(for: now)
        dashboard = HomeDashboardBuilder.dashboard(from: records, now: now, calendar: calendar)
        gridDays = HomeDashboardBuilder.gridDays(weeks: Self.grassWeeks, now: now, calendar: calendar)
        let recent = records.sorted { $0.startedAt > $1.startedAt }.prefix(Self.recentCount)
        recentRows = RecordListBuilder.rows(for: Array(recent), calendar: calendar)
    }
}
