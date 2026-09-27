/// 테스트·프리뷰·Firebase 미구성 환경용. 계약상 아무것도 하지 않는다.
public struct NoopCrashReporter: CrashReporting {
    public init() {}
    public func record(_: Error, context _: [String: String]) {}
    public func log(_: String) {}
}
