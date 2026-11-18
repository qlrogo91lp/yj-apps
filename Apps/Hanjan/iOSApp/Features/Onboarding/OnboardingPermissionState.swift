import Foundation

/// 온보딩 권한 버튼의 상태. 거부해도 앱은 동작한다 — 표시만 바뀐다.
enum OnboardingPermissionState: Equatable {
    case notAsked, granted, denied
}
