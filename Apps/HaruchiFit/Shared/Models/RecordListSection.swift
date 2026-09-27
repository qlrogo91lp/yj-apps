import Foundation

/// 기록 목록의 한 주. 레코드가 없는 주는 만들지 않는다.
struct RecordListSection: Identifiable {
    /// 그 주 첫날 0시. 섹션의 정렬 키이자 식별자다.
    let weekStart: Date
    let title: String
    let rows: [RecordListRow]

    var id: Date {
        weekStart
    }
}
