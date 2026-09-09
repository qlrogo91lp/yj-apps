# MonitoringCore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** YJKit 에 `MonitoringCore` 프로덕트를 만든다 — `CrashReporting` 프로토콜, non-fatal 용 `MonitoringError`, Firebase Crashlytics 구현, 테스트·프리뷰용 Noop. 이 플랜이 끝나도 **앱은 아무것도 바뀌지 않는다.**

**Architecture:** 앱은 `CrashReporting` 프로토콜만 안다. Firebase 의존은 이 타깃이 갖고, `FirebaseApp.configure()`·plist·dSYM 은 앱 소유다. 첫 태스크는 스파이크 — 로컬 SPM 패키지가 원격 바이너리 의존(Firebase xcframework)을 끄는 구성이 이 워크스페이스·CI 에서 처음이라 빈 타깃으로 먼저 확인한다.

**Tech Stack:** Swift 6 (language mode 5) / SPM / firebase-ios-sdk `FirebaseCrashlytics` / Swift Testing

**Spec:** [docs/specs/shared/2026/2026-09-07-crash-reporting-design.md](../../../specs/shared/2026/2026-09-07-crash-reporting-design.md)

## Global Constraints

- **앱 코드는 건드리지 않는다.** `Apps/` 아래 변경은 Ralli 연동 플랜 소관.
- Firebase 프로덕트는 **`FirebaseCrashlytics` 하나만** 의존한다. Analytics 등 추가 금지.
- `MonitoringCore` 는 iOS·watchOS 양쪽에서 컴파일돼야 한다. `#if os(iOS)` 로 감싸지 않는다.
- 다른 타깃(`WorkoutCore` 등)은 `MonitoringCore` 에 의존하지 않는다 — Firebase 가 전 앱 빌드에 끌려 들어가면 안 된다.
- 기존 규약대로 `swiftSettings: [.swiftLanguageMode(.v5)]`.
- 메인 체크아웃에서 작업한다. PR 은 Kit 만 따로 (CI 에서 Firebase 해석이 도는지가 리뷰 포인트).
- 각 태스크는 **실패하는 테스트 → 실패 확인 → 최소 구현 → 통과 확인 → 커밋**.

**빌드·테스트 명령** (루트에서)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

make kit-test KIT_DESTINATION="id=$IOS"                       # YJKit 전체 테스트
# 단일 테스트 타깃
cd Packages/YJKit && xcodebuild -scheme YJKit-Package -destination "id=$IOS" \
  -only-testing:MonitoringCoreTests test

# 앱 스킴이 여전히 빌드되는지 (MonitoringCore 를 링크하지 않아도 패키지 해석은 탄다)
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build
```

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `Package.swift` | 수정 | 원격 의존 `firebase-ios-sdk`, 프로덕트·타깃·테스트타깃 `MonitoringCore` |
| `Sources/MonitoringCore/CrashReporting.swift` | 생성 | 프로토콜 |
| `Sources/MonitoringCore/MonitoringError.swift` | 생성 | domain·code 고정 non-fatal Error |
| `Sources/MonitoringCore/NoopCrashReporter.swift` | 생성 | 아무것도 안 함 |
| `Sources/MonitoringCore/CrashlyticsReporter.swift` | 생성 | Firebase 구현 |
| `Tests/MonitoringCoreTests/MonitoringErrorTests.swift` | 생성 | NSError 브리징 |
| `Tests/MonitoringCoreTests/CrashReportingSpy.swift` | 생성 | 앱 테스트가 가져다 쓸 수 있게 `public` 은 아니지만 형태를 보여준다 |
| `README.md` | 수정 | 프로덕트 표 + 사용법 + 소비자 책임 |

---

### Task 0: 스파이크 — Firebase 의존이 이 구성에서 빌드되는가

**Files:**
- Modify: `Packages/YJKit/Package.swift`
- Create: `Packages/YJKit/Sources/MonitoringCore/MonitoringCore.swift` (임시 — Task 1 에서 교체)

- [ ] **Step 1: 최신 Firebase 버전 확인**

Run: `gh api repos/firebase/firebase-ios-sdk/releases/latest --jq .tag_name`
Expected: `12.x.x` 또는 그 이상. 아래 `from:` 에 그 메이저를 쓴다.

- [ ] **Step 2: `Package.swift` 에 의존·타깃 추가**

`products` 에:
```swift
        .library(name: "MonitoringCore", targets: ["MonitoringCore"]),
```

`platforms` 다음, `products` 앞에:
```swift
    dependencies: [
        // Crashlytics 만 쓴다. 다른 Firebase 프로덕트는 Phase 2.
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
    ],
```

`targets` 에 (`PersistenceCore` 타깃 다음):
```swift
        .target(
            name: "MonitoringCore",
            dependencies: [
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
```

- [ ] **Step 3: 빈 소스 하나**

`Sources/MonitoringCore/MonitoringCore.swift`:
```swift
import FirebaseCrashlytics

// 스파이크 — Firebase 가 이 패키지 구성에서 해석·링크되는지만 본다. Task 1 에서 교체.
enum MonitoringCoreSpike {}
```

- [ ] **Step 4: 패키지 해석 + 앱 두 스킴 빌드**

Run:
```bash
cd Packages/YJKit && swift package resolve && cd ../..
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -2
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build 2>&1 | tail -2
```
Expected: 둘 다 `BUILD SUCCEEDED`. 앱이 `MonitoringCore` 를 링크하지 않아도 워크스페이스가 패키지 그래프를 해석하므로, 여기서 실패하면 Firebase 가 문제다. `Package.resolved` 가 갱신된다 — 커밋한다.

- [ ] **Step 5: `make kit-test` 로 시뮬레이터에서 패키지 자체 빌드**

Run: `make kit-test KIT_DESTINATION="id=$IOS" 2>&1 | grep -E "BUILD|TEST|error:" | tail -5`
Expected: 기존 테스트 전부 통과. Firebase xcframework 가 시뮬레이터 슬라이스로 링크된다.

- [ ] **Step 6: 커밋 → 푸시 → CI 확인**

```bash
git add Packages/YJKit/Package.swift Packages/YJKit/Package.resolved Packages/YJKit/Sources/MonitoringCore
git commit -m "🔧 MonitoringCore 스파이크 — FirebaseCrashlytics 의존이 패키지·앱·CI 에서 해석되는지"
git push
gh run watch   # YJKit 테스트 job + 3앱 빌드 job 전부 초록인지
```

CI 에서 Firebase 해석에 걸리는 시간을 기록해 둔다 (Package.resolved 캐시가 없으면 첫 실행이 느리다). 여기서 실패하면 **멈추고** 스펙 §검증 순서 1 대로 구조를 다시 본다.

---

### Task 1: `CrashReporting` 프로토콜 + `NoopCrashReporter` + `MonitoringError`

**Files:**
- Create: `Sources/MonitoringCore/CrashReporting.swift`
- Create: `Sources/MonitoringCore/MonitoringError.swift`
- Create: `Sources/MonitoringCore/NoopCrashReporter.swift`
- Delete: `Sources/MonitoringCore/MonitoringCore.swift` (스파이크)
- Create: `Tests/MonitoringCoreTests/MonitoringErrorTests.swift`
- Create: `Tests/MonitoringCoreTests/CrashReportingSpy.swift`
- Modify: `Package.swift` (테스트 타깃)

**Interfaces:**
- Produces:
  - `public protocol CrashReporting: Sendable { func record(_ error: Error, context: [String: String]); func log(_ message: String) }`
  - `public struct MonitoringError: Error, CustomNSError { public init(domain: String, code: Int, message: String) }`
  - `public struct NoopCrashReporter: CrashReporting { public init() }`

- [ ] **Step 1: 테스트 타깃 추가**

`Package.swift` `targets` 끝에:
```swift
        .testTarget(
            name: "MonitoringCoreTests",
            dependencies: ["MonitoringCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
```

- [ ] **Step 2: 실패하는 테스트**

`Tests/MonitoringCoreTests/MonitoringErrorTests.swift`:
```swift
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
```

`Tests/MonitoringCoreTests/CrashReportingSpy.swift` — 앱 테스트가 같은 모양으로 스파이를 만들 수 있게 여기 둔다:
```swift
@testable import MonitoringCore

/// 기록된 호출을 순서대로 보관한다. 앱 테스트는 이 파일을 복사해 쓴다 (테스트 타깃은 export 되지 않는다).
final class CrashReportingSpy: CrashReporting, @unchecked Sendable {
    enum Call: Equatable {
        case record(domain: String, code: Int, context: [String: String])
        case log(String)
    }

    private(set) var calls: [Call] = []

    func record(_ error: Error, context: [String: String]) {
        let ns = error as NSError
        calls.append(.record(domain: ns.domain, code: ns.code, context: context))
    }

    func log(_ message: String) {
        calls.append(.log(message))
    }
}
```

- [ ] **Step 3: 실패 확인**

Run: `cd Packages/YJKit && xcodebuild -scheme YJKit-Package -destination "id=$IOS" -only-testing:MonitoringCoreTests test 2>&1 | grep error: | head -3`
Expected: `cannot find 'MonitoringError' in scope`.

- [ ] **Step 4: 구현**

`Sources/MonitoringCore/CrashReporting.swift`:
```swift
/// 앱이 아는 유일한 모니터링 타입. 구현체(Crashlytics 등)는 이 패키지가 갖고, 앱은 주입만 한다.
public protocol CrashReporting: Sendable {
    /// 죽지 않은 오류. `context` 는 리포트에 커스텀 키로 붙어 대시보드에서 필터된다.
    /// 같은 종류의 오류는 같은 `MonitoringError(domain:code:)` 로 보내야 한 이슈로 묶인다.
    func record(_ error: Error, context: [String: String])

    /// 크래시 리포트에 딸려 가는 브레드크럼. 최근 것만 남는다 — 경기 시작·종료·저장 시도 정도.
    func log(_ message: String)
}
```

`Sources/MonitoringCore/MonitoringError.swift`:
```swift
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

    public static var errorDomain: String { "MonitoringError" } // 인스턴스 값이 우선한다 — 아래 참고
    public var errorCode: Int { code }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: message] }
}

// `CustomNSError.errorDomain` 은 static 이라 인스턴스별 domain 을 못 준다.
// NSError 브리징 시 domain 을 인스턴스 값으로 바꾸기 위해 `_domain` 을 재정의한다.
extension MonitoringError {
    public var _domain: String { domain }
    public var _code: Int { code }
}
```

`Sources/MonitoringCore/NoopCrashReporter.swift`:
```swift
/// 테스트·프리뷰·Firebase 미구성 환경용. 계약상 아무것도 하지 않는다.
public struct NoopCrashReporter: CrashReporting {
    public init() {}
    public func record(_: Error, context _: [String: String]) {}
    public func log(_: String) {}
}
```

스파이크 파일 `MonitoringCore.swift` 는 지운다.

- [ ] **Step 5: 통과 확인**

Run: Step 3 명령에서 `grep -E "passed|failed"`.
Expected: 3 tests passed. `bridgesToNSErrorWithStableDomainAndCode` 가 실패하면 `_domain` 재정의가 안 먹은 것 — `Swift.Error` 의 `_domain` 은 언더스코어 API 라 Swift 버전에 따라 동작이 다를 수 있다. 그 경우 `MonitoringError` 를 `struct` 대신 **`NSError` 서브클래스가 아닌 `NSError` 인스턴스를 만드는 팩토리**로 바꾼다:
```swift
public enum MonitoringError {
    public static func make(domain: String, code: Int, message: String) -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
```
테스트의 생성자 호출을 `MonitoringError.make(...)` 로 바꾸고 다시 돈다. 어느 쪽이든 **domain+code 가 보존되는 것**이 계약이다.

- [ ] **Step 6: 커밋**

```bash
git add Packages/YJKit/Package.swift Packages/YJKit/Sources/MonitoringCore Packages/YJKit/Tests/MonitoringCoreTests
git commit -m "✨ MonitoringCore — CrashReporting 프로토콜·MonitoringError·Noop"
```

---

### Task 2: `CrashlyticsReporter`

**Files:**
- Create: `Sources/MonitoringCore/CrashlyticsReporter.swift`

**Interfaces:**
- Consumes: `CrashReporting` (Task 1), `FirebaseCrashlytics.Crashlytics`
- Produces: `public struct CrashlyticsReporter: CrashReporting { public init(); public static func configureFirebase() }`

Firebase 는 유닛 테스트에서 `configure()` 없이 호출하면 경고만 내고 무시하므로, 이 구현은 테스트하지 않는다 — 검증은 Ralli 연동 플랜의 실기기 non-fatal 확인이다.

- [ ] **Step 1: 구현**

```swift
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
```

`setCustomValue` 는 세션 전체에 남는다 — 같은 키를 다음 `record` 가 덮어쓴다. 지금 용도(경기 저장 실패)에선 마지막 값이 맞는 값이다.

- [ ] **Step 2: 빌드 확인 (iOS·watchOS 양쪽)**

Run:
```bash
make kit-test KIT_DESTINATION="id=$IOS" 2>&1 | grep -E "BUILD|passed|failed|error:" | tail -4
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build 2>&1 | tail -2
```
Expected: 테스트 통과, 워치 빌드 성공. (워치 스킴이 `MonitoringCore` 를 링크하진 않지만 패키지 그래프에 watchOS 슬라이스가 있는지 여기서 걸러진다 — 확실히 하려면 Ralli 플랜 Task 1 에서 링크 후 다시 본다.)

- [ ] **Step 3: 커밋**

```bash
git add Packages/YJKit/Sources/MonitoringCore/CrashlyticsReporter.swift
git commit -m "✨ CrashlyticsReporter — Firebase 구현"
```

---

### Task 3: README — 프로덕트 표 + 사용법 + 소비자 책임

**Files:**
- Modify: `Packages/YJKit/README.md`

- [ ] **Step 1: 프로덕트 표에 행 추가**

기존 표(`WorkoutShareUI` 행 아래):
```markdown
| `MonitoringCore` | 크래시 리포팅 — `CrashReporting` 프로토콜 + Firebase Crashlytics 구현 | ✅ |
```

- [ ] **Step 2: 사용법 절 추가** (`## WorkoutShareUI 사용법` 절 다음)

````markdown
## MonitoringCore 사용법

크래시는 SDK 가 알아서 잡는다. 이 프로덕트는 **non-fatal 과 브레드크럼** 을 앱이 프로토콜로 보내게 한다.

```swift
import MonitoringCore

// 앱 진입점 — 초기화 시점은 앱이 정한다. 앱은 FirebaseCore 를 직접 링크하지 않는다
CrashlyticsReporter.configureFirebase()

// 리포터를 만들어 주입. 싱글톤 없음
let reporter: CrashReporting = CrashlyticsReporter()
let vm = SomeViewModel(crashReporter: reporter)

// non-fatal — 같은 종류는 같은 domain+code 로. 메시지는 자유
reporter.record(
    MonitoringError(domain: "Ralli.Save", code: 1, message: "ack timeout"),
    context: ["sessionId": id.uuidString]
)

// 브레드크럼 — 크래시 직전 맥락. 자주 부르지 않는다
reporter.log("match started")
```

테스트·프리뷰는 `NoopCrashReporter()`.

### 소비자 책임 (패키지가 대신 못 해주는 것)

- [ ] Firebase 콘솔에서 프로젝트를 만들고 **앱(번들 ID)마다** `GoogleService-Info.plist` 를 받아 타깃에 넣는다. iOS·워치는 별개 앱이다.
- [ ] 각 앱 진입점 `init` 에서 `CrashlyticsReporter.configureFirebase()`. 익스텐션에서는 부르지 않는다.
- [ ] 타깃마다 dSYM 업로드 Build Phase (`upload-symbols`). `ENABLE_USER_SCRIPT_SANDBOXING = YES` 면 **조용히 실패**한다.
- [ ] App Privacy 라벨에 Crash Data · Other Diagnostic Data.
- [ ] 수집 끄기 UI 를 둔다면 `Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)`.
````

- [ ] **Step 3: 커밋 → PR**

```bash
git add Packages/YJKit/README.md
git commit -m "📝 MonitoringCore 사용법과 소비자 책임"
git push
gh pr create --title "✨ MonitoringCore — CrashReporting 프로토콜 + Crashlytics 구현" \
  --body "$(cat <<'EOF'
YJKit 에 크래시 리포팅 프로덕트를 추가한다. 앱 변경 없음 — Ralli 연동은 다음 PR.

- Task 0 스파이크: firebase-ios-sdk 원격 의존이 로컬 패키지·앱 스킴·CI 에서 해석됨 (CI 소요 기록: __분)
- `CrashReporting` 프로토콜 · `MonitoringError`(domain+code 고정) · `NoopCrashReporter` · `CrashlyticsReporter`
- README 사용법 + 소비자 책임

스펙: Packages/YJKit/docs/specs/shared/2026/2026-09-07-crash-reporting-design.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

리뷰 포인트는 하나 — **CI 의 YJKit 테스트 job 과 3앱 빌드 job 이 Firebase 해석을 포함해 초록인가.** 머지 후 Ralli 연동 플랜으로.

---

## Self-Review

- 스펙 커버리지 — 구조 4파일(Task 1·2), Firebase 프로덕트 하나만(Task 0 Step 2), iOS·watchOS 양쪽(Task 2 Step 2), 앱 소유 항목(README 소비자 책임), 스파이크 선행(Task 0), 하지 않는 것(제약) ✅
- 타입 일관성 — `CrashReporting.record(_:context:)`/`log(_:)` 가 프로토콜·Noop·Crashlytics·Spy·README 에서 같은 시그니처 ✅. `MonitoringError(domain:code:message:)` 테스트·README 일치 ✅ (Step 5 폴백 시 `make(...)` 로 함께 바꾼다)
- 플레이스홀더 — PR 본문의 "CI 소요 기록: __분" 은 실행 시 채우는 값. Firebase `from:` 버전은 Step 1 에서 확인.
