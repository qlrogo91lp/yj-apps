import Foundation

/// 구간의 종류. 외부 워크아웃을 가져올 때도 이 둘 중 하나로 분류한다 (아키텍처 4.2).
///
/// **세 타깃(iOS 앱·워치 앱·컴플리케이션)이 모두 쓰는 타입이라 `Common/` 에 있다.**
/// `Shared/` 에 두면 컴플리케이션이 못 본다 — 그쪽은 `ConnectivityCore` 에 의존한다.
enum SegmentKind: String, Codable, CaseIterable {
    case strength
    case cardio

    var title: String {
        switch self {
        case .strength: "근력"
        case .cardio: "유산소"
        }
    }
}
