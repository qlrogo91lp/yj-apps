import Foundation

/// 홈 대시보드가 그대로 찍을 값 (제품 스펙 02절). 문자열까지 `HomeDashboardBuilder` 가 끝낸다 —
/// View 에 규칙을 두면 iOS 테스트 타깃이 없어 아무도 검증하지 못한다.
struct HomeDashboard: Equatable {
    /// `10월 2026`. 오늘이 속한 달이다.
    let monthTitle: String
    let monthStat: Stat
    let totalStat: Stat
    /// 이번 주 운동 구성. 전체 기록이 3회 미만이거나 이번 주 기록이 없으면 nil.
    let week: WeekComposition?
    /// 전체 기록이 3회 미만일 때 구성 바 자리에 나오는 한 줄.
    let milestone: String?
    /// 기록은 3회 이상인데 이번 주에는 없을 때 구성 바 자리에 나오는 한 줄.
    let emptyWeekText: String?

    /// 축적 스탯 한 칸 — 횟수가 크고 시간이 작다.
    struct Stat: Equatable {
        let countText: String
        let durationText: String
    }

    struct WeekComposition: Equatable {
        /// 기록 시간(`totalSeconds`) 합. 구간 합과 다를 수 있다 — 구간이 없는 기록이 섞이면 더 작다.
        let totalText: String
        let strengthSeconds: Int
        let cardioSeconds: Int
        /// 0 이 아닌 종류만, 근력 → 유산소 순.
        let legend: [Legend]
    }

    struct Legend: Equatable {
        let kind: SegmentKind
        let text: String
    }
}
