import FirebaseCore
import FirebaseCrashlytics

/// Firebase Crashlytics 구현. 앱이 진입점에서 `configureFirebase()` 를 먼저 불러야 동작한다 —
/// 호출 시점과 `GoogleService-Info.plist` 는 앱 소유다 (코어는 Firebase 프로젝트를 모른다).
public struct CrashlyticsReporter: CrashReporting {
    public init() {}

    /// `FirebaseApp.configure()` 래퍼. 앱이 `FirebaseCore` 를 직접 링크하지 않아도 되게 여기 둔다 —
    /// 앱은 `MonitoringCore` 하나만 링크한다. 번들의 `GoogleService-Info.plist` 를 읽으므로
    /// 앱 타깃마다 그 파일이 있어야 하고, 익스텐션에서는 부르지 않는다.
    public static func configureFirebase() {
        guard FirebaseApp.app() == nil else { return } // 중복 호출 방지
        FirebaseApp.configure()
    }

    /// `setCustomValue` 는 세션 전체에 남는다 — 같은 키를 다음 `record` 가 덮어쓴다.
    public func record(_ error: Error, context: [String: String]) {
        let crashlytics = Crashlytics.crashlytics()
        for (key, value) in context {
            crashlytics.setCustomValue(value, forKey: key)
        }
        crashlytics.record(error: error)
    }

    public func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
}
