/// 온보딩 노출 규칙. "봤나" 가 아니라 "몇 번째까지 봤나" 로 판단한다 —
/// 내용을 고치고 `version` 을 올리면 기존 사용자에게 다시 뜬다 (What's New 역할).
enum OnboardingGate {
    /// 온보딩 내용이 바뀌면 올린다. 1 = 2.1.2 (모드 전환·스코어카드·컴플리케이션 3장).
    static let version = 1

    static func shouldShow(seenVersion: Int) -> Bool {
        seenVersion < version
    }
}
