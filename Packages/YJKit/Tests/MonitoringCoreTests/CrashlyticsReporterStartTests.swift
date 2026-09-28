import Foundation
@testable import MonitoringCore
import Testing

struct CrashlyticsReporterStartTests {
    /// plist 가 없는 번들 — 테스트 번들에는 `GoogleService-Info.plist` 가 없다.
    /// CI·새 체크아웃이 이 경우다. Firebase 를 건드리지 않고 Noop 이 와야 앱이 죽지 않는다.
    @Test func bundleWithoutPlistYieldsNoop() {
        let bundle = Bundle(for: CrashReportingSpy.self)
        #expect(bundle.path(forResource: "GoogleService-Info", ofType: "plist") == nil)

        let reporter = CrashlyticsReporter.start(bundle: bundle)

        #expect(reporter is NoopCrashReporter)
    }
}
