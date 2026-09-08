/// 온보딩 노출 규칙. "봤나" 가 아니라 "몇 번째까지 봤나" 로 판단한다 —
/// 내용을 고치고 `version` 을 올리면 기존 사용자에게 다시 뜬다 (What's New 역할).
enum OnboardingGate {
    /// 온보딩 내용이 바뀌면 올린다. 1 = 2026-09 크라운·공유·햅틱 출시.
    static let version = 1

    static func shouldShow(seenVersion: Int) -> Bool {
        seenVersion < version
    }
}
