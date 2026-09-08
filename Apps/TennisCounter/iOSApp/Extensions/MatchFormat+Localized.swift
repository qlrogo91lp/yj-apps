import Foundation

/// 경기 방식의 화면 표기. iOS 만 쓰므로 `Shared/Models` 가 아니라 여기에 둔다 —
/// `Shared` 에 두면 워치 타깃에도 컴파일돼 쓰이지 않는 키가 카탈로그에 추출된다.
extension MatchFormat {
    var localizedTitle: String {
        switch self {
        case .oneSet: String(localized: "match_format_one_set")
        case .bestOfThree: String(localized: "match_format_best_of_3")
        }
    }

    var localizedDescription: String {
        switch self {
        case .oneSet: String(localized: "match_format_one_set_desc")
        case .bestOfThree: String(localized: "match_format_best_of_3_desc")
        }
    }
}
