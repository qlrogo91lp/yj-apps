/// 앱이 아는 유일한 모니터링 타입. 구현체(Crashlytics 등)는 이 패키지가 갖고, 앱은 주입만 한다.
public protocol CrashReporting: Sendable {
    /// 죽지 않은 오류. `context` 는 리포트에 커스텀 키로 붙어 대시보드에서 필터된다.
    /// 같은 종류의 오류는 같은 `MonitoringError(domain:code:)` 로 보내야 한 이슈로 묶인다.
    func record(_ error: Error, context: [String: String])

    /// 크래시 리포트에 딸려 가는 브레드크럼. 최근 것만 남는다 — 경기 시작·종료·저장 시도 정도.
    func log(_ message: String)
}
