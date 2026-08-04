import Foundation

/// 카운터 입력 모드. 스윙은 타수만, 퍼팅은 타수와 퍼팅을 함께 센다 (spec §3).
enum StrokeInputMode: Equatable {
    case swing
    case putt
}
