import Foundation

/// 워치↔폰으로 오가는 메시지의 계약. 코어는 "무엇을 주고받는지 모른다" —
/// 메시지 정의(필드·직렬화)는 앱 몫이고, 코어는 type 키 라우팅과 전송만 담당한다.
public protocol ConnectivityMessage {
    /// 라우팅 키. 와이어 dict의 "type" 필드로 실려간다 (코어가 발신 시 덮어쓴다).
    static var messageType: String { get }
    init?(from dictionary: [String: Any])
    func toDictionary() -> [String: Any]
}
