import Combine
import Foundation

/// 홈 잔디의 배선. **규칙은 하나도 들고 있지 않다** — 전부 `GrassAggregator` 와
/// `GrassIntensity` 에 있다 (스펙 2절). 이 타입은 유닛 테스트가 닿지 않는 자리라
/// (iOS 테스트 타깃이 없다) 규칙을 여기 두면 아무도 검증하지 못한다.
///
/// 계산을 View `body` 밖에 두는 것이 존재 이유다. 비용이 작아도 `body` 안에서 접으면
/// 잔디와 무관한 이유로(스탯 갱신, 최근 기록 스크롤) 딸려 돈다. `@StateObject` 로 살아
/// 있으면 `body` 가 몇 번 재평가되든 결과는 배열 읽기다 (스펙 3절).
///
/// **영속 캐시가 아니다.** `@Model` 캐시는 CloudKit 스키마에 올라가 기기 간 충돌 대상이
/// 되고, 무효화 시점이 이미 넷이라 진실과 어긋나면 사용자에겐 "잔디가 틀렸다" 로 보인다.
@MainActor
final class GrassViewModel: ObservableObject {
    /// 날짜 오름차순. 레코드가 없는 날은 들어 있지 않다.
    @Published private(set) var days: [DailyAggregate] = []

    private let calendar: Calendar
    private let intensity: GrassIntensity
    private var records: [WorkoutRecord] = []
    private var byDay: [Date: DailyAggregate] = [:]

    init(calendar: Calendar = .current, intensity: GrassIntensity = .byTime) {
        self.calendar = calendar
        self.intensity = intensity
    }

    /// View 가 `@Query` 로 읽은 결과를 밀어넣는다.
    func rebuild(from records: [WorkoutRecord]) {
        self.records = records
        refresh()
    }

    /// 들고 있는 레코드로 다시 접는다.
    ///
    /// **원소 집합이 그대로인 채 값만 바뀌는 경우**를 위해 공개해 둔다 — `@Query` 는
    /// `persistentModelID` 로 비교하므로 그런 변경을 못 잡는다. 구멍은 그 하나뿐이고
    /// 그걸 여는 화면이 아직 없다. Phase 5 의 08 수동 기록이 편집 저장 직후 이걸 부른다
    /// (스펙 5절).
    func refresh() {
        let folded = GrassAggregator.fold(records, calendar: calendar)
        byDay = Dictionary(folded.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        days = folded
    }

    /// 그 날 칸의 값. 레코드가 없는 날은 nil 이다.
    func aggregate(on day: Date) -> DailyAggregate? {
        byDay[calendar.startOfDay(for: day)]
    }

    /// 그 날 칸의 농도. 레코드가 없으면 `.none` — 빈 칸으로 그린다.
    func level(on day: Date) -> GrassLevel {
        guard let aggregate = aggregate(on: day) else { return .none }
        return intensity.level(for: aggregate)
    }
}
