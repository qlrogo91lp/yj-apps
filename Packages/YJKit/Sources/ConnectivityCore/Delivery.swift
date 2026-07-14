/// 전송 경로. 기존 WatchConnectivityService의 3가지 발신 함수를 일반화한 것.
public enum Delivery {
    /// sendMessage만, 미도달 시 드롭 — 실시간 메트릭용 (기존 sendMetrics 경로)
    case realtimeOnly
    /// sendMessage → 미도달 시 transferUserInfo 큐잉 (기존 sendReliably)
    case reliable
    /// sendMessage → 미도달 시 updateApplicationContext — "마지막 상태" 보존용 (기존 sessionStart 경로)
    case context
}
