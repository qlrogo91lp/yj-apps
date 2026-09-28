import Foundation
@testable import MonitoringCore
import Testing

struct MonitoringErrorTests {
    @Test func bridgesToNSErrorWithStableDomainAndCode() {
        let error = MonitoringError(domain: "Ralli.Save", code: 1, message: "ack timeout")
        let ns = error as NSError

        // Crashlytics 는 domain+code 로 non-fatal 을 묶는다 — 메시지가 달라도 같은 이슈여야 한다.
        #expect(ns.domain == "Ralli.Save")
        #expect(ns.code == 1)
        #expect(ns.localizedDescription == "ack timeout")
    }

    @Test func sameDomainAndCodeDifferentMessageStillGroups() {
        let a = MonitoringError(domain: "Ralli.Save", code: 1, message: "첫 번째") as NSError
        let b = MonitoringError(domain: "Ralli.Save", code: 1, message: "두 번째") as NSError

        #expect(a.domain == b.domain && a.code == b.code)
    }

    @Test func noopReporterAcceptsCallsWithoutSideEffects() {
        let reporter = NoopCrashReporter()
        reporter.log("breadcrumb")
        reporter.record(MonitoringError(domain: "x", code: 0, message: "y"), context: ["k": "v"])
        // 죽지 않으면 통과 — Noop 은 계약상 아무것도 하지 않는다
    }
}
