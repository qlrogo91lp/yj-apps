import Foundation
import SwiftData

/// 기록 목록의 한 행. 화면이 그대로 찍을 문자열까지 여기서 끝낸다 — View 에 규칙을 두면
/// iOS 테스트 타깃이 없어 아무도 검증하지 못한다.
struct RecordListRow: Identifiable {
    let id: PersistentIdentifier
    /// 삭제가 이 객체를 넘긴다.
    let record: WorkoutRecord
    let dateTitle: String
    let chips: [Chip]
    /// 칼로리 값이 없는 기록은 nil — 화면이 자리를 비운다.
    let caloriesText: String?
    /// `가슴 · 팔`. 태그가 없으면 nil 이며, 태깅을 유도하는 문구는 두지 않는다.
    let bodyPartsText: String?

    /// 구간 종류 하나의 합계. 전환 횟수는 담지 않는다 (D7).
    struct Chip: Hashable {
        let kind: SegmentKind
        let minutes: Int

        var text: String {
            "\(kind.title) \(minutes)분"
        }
    }
}
