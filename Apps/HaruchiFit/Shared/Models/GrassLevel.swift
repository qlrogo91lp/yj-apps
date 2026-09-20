import Foundation

/// 잔디 칸의 농도.
///
/// **`.none` 은 그날 레코드가 아예 없다는 뜻이라 집계 결과에 나타나지 않는다** —
/// 칸이 없는 날을 화면이 `.none` 으로 그린다 (스펙 4.3). 스펙은 1~4단계만 정의했고
/// 0단계는 그 문서에서 채웠다.
enum GrassLevel: Int, CaseIterable, Comparable {
    case none = 0
    case light = 1
    case medium = 2
    case heavy = 3
    case peak = 4

    static func < (lhs: GrassLevel, rhs: GrassLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
