import Foundation

/// 달력 화면이 비어 보이는 이유. 표시 문자열로 분기하지 않도록 이유를 낸다.
enum RecordCalendarEmptyState: Equatable {
    case noRecords
    case emptyMonth
    case emptyDay
}
