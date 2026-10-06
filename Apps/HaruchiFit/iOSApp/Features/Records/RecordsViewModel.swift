import Combine
import Foundation

/// 기록 탭의 배선. **표시 규칙은 `RecordListBuilder` 에 있다** — 이 자리는 iOS 테스트 타깃이
/// 없어 유닛 테스트가 닿지 않는다 (`GrassViewModel` 과 같은 이유).
@MainActor
final class RecordsViewModel: ObservableObject {
    @Published private(set) var sections: [RecordListSection] = []

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// View 가 `@Query` 로 읽은 결과를 밀어넣는다. `이번 주` 는 부른 시각 기준이다.
    func rebuild(from records: [WorkoutRecord]) {
        sections = RecordListBuilder.sections(from: records, now: Date(), calendar: calendar)
    }
}
