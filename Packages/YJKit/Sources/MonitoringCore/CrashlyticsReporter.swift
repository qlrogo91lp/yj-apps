import FirebaseCore
import FirebaseCrashlytics
import Foundation

/// Firebase Crashlytics 구현. 인스턴스는 `start(bundle:)` 로만 얻는다 —
/// Firebase 를 초기화하지 않은 채 만들어지면 첫 호출에서 앱이 죽기 때문이다.
/// 자동 생성 `init` 이 `internal` 이라 패키지 밖에서는 만들 수 없다 — `public init` 을 추가하지 않는다.
public struct CrashlyticsReporter: CrashReporting {
    /// 번들에 `GoogleService-Info.plist` 가 있으면 Firebase 를 초기화하고 Crashlytics 리포터를,
    /// 없으면 아무것도 건드리지 않고 `NoopCrashReporter` 를 돌려준다.
    ///
    /// plist 는 git 에 넣지 않는다(공개 저장소). CI·새 체크아웃은 plist 가 없어 Noop 으로 돈다.
    /// 출시 빌드에서 plist 가 빠지면 수집이 **조용히 꺼지므로**, Release 에서 plist 존재를
    /// 검사하는 일은 앱의 dSYM 업로드 스크립트가 맡는다. 익스텐션에서는 부르지 않는다.
    public static func start(bundle: Bundle = .main) -> CrashReporting {
        guard let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path)
        else { return NoopCrashReporter() }

        if FirebaseApp.app() == nil { // 중복 호출 방지
            FirebaseApp.configure(options: options)
        }
        return CrashlyticsReporter()
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
