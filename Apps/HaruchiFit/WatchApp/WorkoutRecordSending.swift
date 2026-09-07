/// 워치가 폰으로 기록을 보내는 통로.
///
/// **테스트에 가짜를 끼우기 위한 좁은 이음매다.** `ConnectivityService` 는 `WCSession` 을
/// 직접 만지는 구체 타입이라 스파이를 만들 수 없는데, 이 한 곳 때문에 3개 앱이 공유하는
/// `ConnectivityCore` 를 키우지는 않는다. 그래서 앱 안에 둔다.
///
/// 배달 방식을 인자로 받지 않는 것은 의도다 — 기록 전송은 언제나 `.reliable` 이어야 하고
/// (폰이 꺼져 있어도 `transferUserInfo` 가 큐잉한다), 그 선택은 아래 conformance 한 줄에만
/// 산다. 테스트 타깃이 `ConnectivityCore` 를 링크하지 않아도 되는 부수 효과도 있다.
protocol WorkoutRecordSending: AnyObject {
    func sendReliably(_ message: WorkoutRecordMessage)
}
