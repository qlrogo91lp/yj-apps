import Foundation

/// 발신 dict에 라우팅 키와 발신 시각을 스탬프한다.
enum MessageEnvelope {
    static func stamp(_ payload: [String: Any], type: String, sentAt: TimeInterval) -> [String: Any] {
        var dict = payload
        dict["type"] = type
        dict["sentAt"] = sentAt
        return dict
    }
}

/// type 키 기반 수신 라우팅 + sentAt 기반 staleness 필터.
/// 스레드 안전장치 없음 — ConnectivityService가 등록과 라우팅을 모두 main queue에서 수행한다.
final class MessageRouter {
    private struct Registration {
        let maxAge: TimeInterval?
        let deliver: ([String: Any]) -> Void
    }

    private var registrations: [String: [Registration]] = [:]

    func register(type: String, maxAge: TimeInterval?, deliver: @escaping ([String: Any]) -> Void) {
        registrations[type, default: []].append(Registration(maxAge: maxAge, deliver: deliver))
    }

    /// sentAt이 없는 메시지는 stale로 보지 않는다 (구버전 발신자 호환 — 기존 규칙 유지).
    func route(_ dict: [String: Any], now: TimeInterval = Date().timeIntervalSince1970) {
        guard let type = dict["type"] as? String,
              let matched = registrations[type] else { return }
        for registration in matched {
            if let maxAge = registration.maxAge,
               let sentAt = dict["sentAt"] as? Double,
               now - sentAt > maxAge { continue }
            registration.deliver(dict)
        }
    }
}
