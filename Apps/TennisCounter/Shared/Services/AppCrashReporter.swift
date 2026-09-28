import Foundation
import MonitoringCore

/// 앱이 쓰는 크래시 리포터 한 곳. 코어는 싱글톤을 두지 않으므로 어디에 들고 있을지는 앱이 정한다.
/// 진입점이 `start()` 를 부르기 전과 테스트 실행 중에는 Noop 이다.
enum AppCrashReporter {
    private(set) static var current: CrashReporting = NoopCrashReporter()

    /// 테스트 실행 중이면 건너뛴다 — 로컬엔 plist 가 있어 테스트가 실제 Firebase 로 브레드크럼을 보내게 된다.
    static func start() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        current = CrashlyticsReporter.start()
    }
}
