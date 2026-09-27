import Combine
import Foundation
import SwiftData

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

    /// 앱 저장소에서만 지운다 — 건강 앱의 워크아웃은 남는다 (플랜 "결정").
    /// 구간은 `deleteRule: .cascade` 로 함께 지워진다. 실패하면 되돌리고 false.
    func delete(_ record: WorkoutRecord, in context: ModelContext) -> Bool {
        context.delete(record)
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            print("[HaruchiFit] 기록 삭제 실패 — \(error)")
            return false
        }
    }
}
