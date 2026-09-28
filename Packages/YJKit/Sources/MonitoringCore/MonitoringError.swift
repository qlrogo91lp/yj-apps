import Foundation

/// non-fatal 리포트용 오류. Crashlytics 는 `NSError` 의 domain+code 로 이슈를 묶으므로
/// 두 값을 고정하고 메시지만 바꿔 보낸다.
public struct MonitoringError: Error, CustomNSError {
    public let domain: String
    public let code: Int
    public let message: String

    public init(domain: String, code: Int, message: String) {
        self.domain = domain
        self.code = code
        self.message = message
    }

    /// 인스턴스 값이 우선한다 — 아래 `_domain` 참고.
    public static var errorDomain: String {
        "MonitoringError"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: message]
    }
}

// `CustomNSError.errorDomain` 은 static 이라 인스턴스별 domain 을 못 준다.
// NSError 브리징 시 domain 을 인스턴스 값으로 바꾸기 위해 `_domain` 을 재정의한다.
// 이름은 `Error` 프로토콜이 정한 것이라 바꿀 수 없다.
// swiftlint:disable identifier_name
public extension MonitoringError {
    var _domain: String {
        domain
    }

    var _code: Int {
        code
    }
}

// swiftlint:enable identifier_name
