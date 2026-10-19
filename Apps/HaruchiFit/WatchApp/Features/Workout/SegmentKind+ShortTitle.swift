import Foundation

extension SegmentKind {
    /// 워치의 좁은 버튼용 짧은 표기. 영어 "Strength" 는 시작 토글 캡슐과 전환 행에서 잘린다.
    /// 다른 화면은 `title` 그대로다.
    var shortTitle: String {
        switch self {
        case .strength: String(localized: "start_kind_strength_short")
        case .cardio: String(localized: "start_kind_cardio_short")
        }
    }
}
