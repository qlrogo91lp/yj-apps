/// 전송 경로. 원본 앱의 3가지 발신 함수(sendRealtimeOnly/sendReliably/send)를 일반화한 것.
public enum Delivery {
    /// sendMessage만, 미도달 시 드롭 — 실시간 메트릭용 (기존 sendMetrics 경로)
    case realtimeOnly
    /// sendMessage → 미도달 시 transferUserInfo 큐잉 (기존 sendReliably). sendMessage 가 실패하면 재전송하지 않는다
    case reliable
    /// 항상 transferUserInfo — 지연은 괜찮고 유실은 안 되는 기록용. 상대 앱이 꺼져 있어도 시스템이 보관했다가 순서대로 배달한다
    case queued
    /// sendMessage → 미도달 시 updateApplicationContext — "마지막 상태" 보존용 (기존 sessionStart 경로)
    case context
}
