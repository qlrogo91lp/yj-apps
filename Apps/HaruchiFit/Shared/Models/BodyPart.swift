import Foundation

/// 근력 대상 부위 6개 (제품 스펙 D1). 유산소는 세그먼트로 이미 기록되므로 넣지 않는다.
///
/// **케이스 순서가 화면 순서다** — 칩 배치와 `가슴 · 팔` 같은 표기가 모두 `allCases` 를 따른다.
/// 저장은 rawValue 라 순서를 바꿔도 기존 기록은 깨지지 않는다.
enum BodyPart: String, Codable, CaseIterable {
    case chest
    case back
    case shoulders
    case arms
    case legs
    case core

    var title: String {
        switch self {
        case .chest: "가슴"
        case .back: "등"
        case .shoulders: "어깨"
        case .arms: "팔"
        case .legs: "하체"
        case .core: "코어"
        }
    }
}
