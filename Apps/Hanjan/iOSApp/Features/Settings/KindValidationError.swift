import Foundation

nonisolated enum KindValidationError: Error, Equatable {
    case emptyName
    case abvOutOfRange
    case volumeOutOfRange

    /// 편집 화면에 그대로 보이는 안내.
    var message: String {
        switch self {
        case .emptyName: "이름을 입력해 주세요."
        case .abvOutOfRange: "도수는 0% 보다 크고 100% 이하로 입력해 주세요."
        case .volumeOutOfRange: "한 잔 용량은 0ml 보다 크고 2000ml 이하로 입력해 주세요."
        }
    }
}
