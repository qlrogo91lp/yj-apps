# RalliKit Plan 2: ConnectivityCore 추출 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `WatchConnectivityService`의 전송·폴백·콜드런치·staleness 인프라를 RalliKit의 `ConnectivityCore` 라이브러리로 추출하고, 테니스 양 타겟을 앱 레이어 래퍼(`MatchConnectivity`) 경유로 마이그레이션한다.

**Architecture:** 코어는 "무엇을 주고받는지 모른다" — `ConnectivityMessage` 프로토콜(라우팅 키 + dict 직렬화)과 `Delivery` 3종(realtimeOnly/reliable/context)만 안다. 수신은 sticky `@Published`가 아니라 타입별 1회성 핸들러(`onReceive`)로 배달하고, 앱 쪽 `MatchConnectivity` 래퍼가 기존 sticky `@Published received*` 시맨틱을 복원해 View/VM 마이그레이션을 이름 치환 수준으로 줄인다. 순수 로직(라우팅·staleness·envelope)은 플랫폼 독립 `MessageRouter`로 분리해 macOS `swift test`로 검증한다.

**Tech Stack:** WatchConnectivity(`#if canImport` 가드 — macOS 제외), Combine, Swift Testing, swift-tools-version 6.0 + Swift 5 language mode.

**연관 문서:** `docs/superpowers/ideas/workout-kit-spm-feasibility.md`(설계 확정본), `docs/superpowers/plans/2026-07-13-ralli-kit-workout-core.md`(Plan 1 — 실행 기록의 교훈 반영: Release 빌드 검증, watch destination id). 후속 Plan 3 = PersistenceCore.

## Global Constraints

- 패키지: `~/Workspace/Projects/ralli-kit` (원격 `git@github.com:qlrogo91lp/ralli-kit.git`). 신규 product/모듈명 `ConnectivityCore`. platforms는 기존 `[.iOS(.v17), .watchOS(.v10), .macOS(.v14)]` 유지.
- **macOS에는 WatchConnectivity가 없다** — `ConnectivityService`는 `#if canImport(WatchConnectivity)`로 파일 전체를 가드하고, 순수 로직(`MessageRouter`, `MessageEnvelope`, 프로토콜, enum)은 플랫폼 독립 파일로 분리해 `swift test`(macOS 호스트) 대상이 되게 한다.
- 신규 타겟 전부 `.swiftLanguageMode(.v5)`. 테스트는 Swift Testing.
- 싱글톤 금지는 **패키지에만** 적용. 앱 레이어 `MatchConnectivity.shared`는 기존 앱 관례(`WatchConnectivityService.shared` 자리 대체) 유지.
- **코어 원칙**: 패키지는 메시지 정의를 모른다. 전송·폴백·콜드런치·sentAt 기반 staleness만 담당. 메시지 struct와 도메인 staleness(workoutStartDate 6h)는 앱 몫. 코어에 테니스 도메인 문자열("scoreState" 등)이 들어가면 안 된다 (예외: 예약 타입 `"sessionCleared"`).
- **와이어 포맷 불변**: 기존 dict 키/값 그대로. `sentAt`은 additive. sentAt 없는 수신(구버전 발신)은 stale로 보지 않는다.
- **로직 불변 + 의도된 변경 4가지** (이외 동작 변화 금지):
  1. 모든 발신 dict에 코어가 `type`(덮어쓰기)과 `sentAt`을 자동 스탬프 — 기존엔 workoutEnd만 sentAt 수동 첨부.
  2. workoutEnd stale 필터(60초)가 앱 하드코딩 → 코어 `onReceive(maxAge: 60)` 선언으로 이동.
  3. sessionStart의 workoutStartDate 6시간 필터가 **콜드런치 컨텍스트 한정 → 모든 수신 경로로 일반화** (래퍼 핸들러에서 검사). 엣지: 6시간 초과 진행 중 세션의 sessionStart 재전송이 거부되나, 채택 가드(`isMatchActive`/`navigateToWorkout`)가 이미 진입을 막고 있어 실질 영향 없음 — 수용하고 문서화.
  4. 수신 구조가 sticky `@Published`(구 서비스) → 코어 1회성 핸들러 + 래퍼에서 sticky 복원으로 재배치. View/VM이 보는 표면(`received*` 프로퍼티, nil 대입 소비)은 불변.
- delivery별 iOS `isWatchAppInstalled` 가드 파리티는 원본 그대로: `.realtimeOnly`·`.context`·`clearSessionContext`에는 있고, **`.reliable`(구 sendReliably)에는 없다.**
- **핸들러 등록 시점 제약**: `ConnectivityService` 생성과 같은 main-queue turn 안에 `onReceive` 등록을 마쳐야 콜드런치 컨텍스트 배달이 유실되지 않는다 (활성화 콜백은 다음 turn에 main으로 들어옴). `MatchConnectivity.init`이 이를 보장한다.
- 검증: 각 태스크 종료 시 관련 타겟 빌드+테스트 그린. **스왑 태스크(5·6)는 Release 빌드 포함** (Plan 1 교훈 — Debug 전용 검증이 아카이브 실패를 숨겼다).
- watchOS destination: name 매칭이 이 머신에서 실패 → 항상 `id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1`.
- 커밋: gitmoji + 한국어. ralli-kit 커밋은 매번 `git push`까지. 이 계획 문서는 사용자 검토 전 미커밋.
- `Shared/`는 iOS·Watch 앱 타겟에만 컴파일된다 (pbxproj 확인 완료 — Complication·LiveActivity 익스텐션 제외). 따라서 ConnectivityCore 링크는 양 앱 타겟이면 충분.

**혼재 구간 참고 (Task 5~6 사이):** Watch만 신규 코어, iOS는 구 서비스인 상태가 잠시 존재한다. 와이어 포맷이 불변이라 상호운용된다 (신규→구: sentAt은 무시됨 / 구→신규: sentAt 없음 = stale 아님). 개발 중 전용 상태이며 Task 6에서 해소된다.

---

### Task 1: ConnectivityCore 스캐폴딩 — 프로토콜·Delivery·MessageRouter (TDD)

**Files:**
- Modify: `~/Workspace/Projects/ralli-kit/Package.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/ConnectivityCore/ConnectivityMessage.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/ConnectivityCore/Delivery.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/ConnectivityCore/MessageRouter.swift`
- Test: `~/Workspace/Projects/ralli-kit/Tests/ConnectivityCoreTests/MessageRouterTests.swift`

**Interfaces:**
- Consumes: 없음 (기존 WorkoutCore와 독립)
- Produces:
  - `public protocol ConnectivityMessage { static var messageType: String { get }; init?(from dictionary: [String: Any]); func toDictionary() -> [String: Any] }`
  - `public enum Delivery { case realtimeOnly, reliable, context }`
  - internal `MessageEnvelope.stamp(_:type:sentAt:) -> [String: Any]`, internal `MessageRouter`(`register(type:maxAge:deliver:)`, `route(_:now:)`) — Task 2의 서비스가 사용

- [x] **Step 1: Package.swift에 ConnectivityCore 추가**

`~/Workspace/Projects/ralli-kit/Package.swift` 전체를 다음으로 교체:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RalliKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WorkoutCore", targets: ["WorkoutCore"]),
        .library(name: "ConnectivityCore", targets: ["ConnectivityCore"]),
    ],
    targets: [
        .target(
            name: "WorkoutCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "ConnectivityCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "WorkoutCoreTests",
            dependencies: ["WorkoutCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ConnectivityCoreTests",
            dependencies: ["ConnectivityCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

- [x] **Step 2: 실패하는 테스트 작성**

`Tests/ConnectivityCoreTests/MessageRouterTests.swift`:

```swift
import Foundation
import Testing
@testable import ConnectivityCore

struct MessageRouterTests {
    @Test func routesToMatchingTypeOnly() {
        let router = MessageRouter()
        var scoreDelivered = false
        var endDelivered = false
        router.register(type: "a", maxAge: nil) { _ in scoreDelivered = true }
        router.register(type: "b", maxAge: nil) { _ in endDelivered = true }
        router.route(["type": "a"])
        #expect(scoreDelivered == true)
        #expect(endDelivered == false)
    }

    @Test func unknownOrMissingTypeIsIgnored() {
        let router = MessageRouter()
        var delivered = false
        router.register(type: "a", maxAge: nil) { _ in delivered = true }
        router.route(["type": "unknown"])
        router.route([:])
        #expect(delivered == false)
    }

    @Test func freshMessagePassesMaxAgeFilter() {
        let router = MessageRouter()
        var delivered = false
        router.register(type: "end", maxAge: 60) { _ in delivered = true }
        let now = 1_000_000.0
        router.route(["type": "end", "sentAt": now - 1], now: now)
        #expect(delivered == true)
    }

    @Test func staleMessageIsDroppedByMaxAgeFilter() {
        let router = MessageRouter()
        var delivered = false
        router.register(type: "end", maxAge: 60) { _ in delivered = true }
        let now = 1_000_000.0
        router.route(["type": "end", "sentAt": now - 120], now: now)
        #expect(delivered == false)
    }

    @Test func missingSentAtIsNotStale() {
        let router = MessageRouter()
        var delivered = false
        router.register(type: "end", maxAge: 60) { _ in delivered = true }
        router.route(["type": "end"], now: 1_000_000.0)
        #expect(delivered == true)
    }

    @Test func multipleHandlersForSameTypeAllReceive() {
        let router = MessageRouter()
        var first = false
        var second = false
        router.register(type: "a", maxAge: nil) { _ in first = true }
        router.register(type: "a", maxAge: nil) { _ in second = true }
        router.route(["type": "a"])
        #expect(first == true)
        #expect(second == true)
    }

    @Test func maxAgeAppliesPerRegistration() {
        let router = MessageRouter()
        var filtered = false
        var unfiltered = false
        router.register(type: "end", maxAge: 60) { _ in filtered = true }
        router.register(type: "end", maxAge: nil) { _ in unfiltered = true }
        let now = 1_000_000.0
        router.route(["type": "end", "sentAt": now - 120], now: now)
        #expect(filtered == false)
        #expect(unfiltered == true)
    }

    @Test func stampOverwritesTypeAndAddsSentAt() {
        let stamped = MessageEnvelope.stamp(["type": "wrong", "payload": 1], type: "right", sentAt: 42)
        #expect(stamped["type"] as? String == "right")
        #expect(stamped["sentAt"] as? Double == 42)
        #expect(stamped["payload"] as? Int == 1)
    }
}
```

- [x] **Step 3: 테스트 실패 확인**

Run: `cd ~/Workspace/Projects/ralli-kit && swift test`
Expected: FAIL — `cannot find 'MessageRouter' in scope` (WorkoutCore 8개는 계속 PASS)

- [x] **Step 4: 구현**

`Sources/ConnectivityCore/ConnectivityMessage.swift`:

```swift
import Foundation

/// 워치↔폰으로 오가는 메시지의 계약. 코어는 "무엇을 주고받는지 모른다" —
/// 메시지 정의(필드·직렬화)는 앱 몫이고, 코어는 type 키 라우팅과 전송만 담당한다.
public protocol ConnectivityMessage {
    /// 라우팅 키. 와이어 dict의 "type" 필드로 실려간다 (코어가 발신 시 덮어쓴다).
    static var messageType: String { get }
    init?(from dictionary: [String: Any])
    func toDictionary() -> [String: Any]
}
```

`Sources/ConnectivityCore/Delivery.swift`:

```swift
/// 전송 경로. 기존 WatchConnectivityService의 3가지 발신 함수를 일반화한 것.
public enum Delivery {
    /// sendMessage만, 미도달 시 드롭 — 실시간 메트릭용 (기존 sendMetrics 경로)
    case realtimeOnly
    /// sendMessage → 미도달 시 transferUserInfo 큐잉 (기존 sendReliably)
    case reliable
    /// sendMessage → 미도달 시 updateApplicationContext — "마지막 상태" 보존용 (기존 sessionStart 경로)
    case context
}
```

`Sources/ConnectivityCore/MessageRouter.swift`:

```swift
import Foundation

/// 발신 dict에 라우팅 키와 발신 시각을 스탬프한다.
enum MessageEnvelope {
    static func stamp(_ payload: [String: Any], type: String, sentAt: TimeInterval) -> [String: Any] {
        var dict = payload
        dict["type"] = type
        dict["sentAt"] = sentAt
        return dict
    }
}

/// type 키 기반 수신 라우팅 + sentAt 기반 staleness 필터.
/// 스레드 안전장치 없음 — ConnectivityService가 등록과 라우팅을 모두 main queue에서 수행한다.
final class MessageRouter {
    private struct Registration {
        let maxAge: TimeInterval?
        let deliver: ([String: Any]) -> Void
    }

    private var registrations: [String: [Registration]] = [:]

    func register(type: String, maxAge: TimeInterval?, deliver: @escaping ([String: Any]) -> Void) {
        registrations[type, default: []].append(Registration(maxAge: maxAge, deliver: deliver))
    }

    /// sentAt이 없는 메시지는 stale로 보지 않는다 (구버전 발신자 호환 — 기존 규칙 유지).
    func route(_ dict: [String: Any], now: TimeInterval = Date().timeIntervalSince1970) {
        guard let type = dict["type"] as? String,
              let matched = registrations[type] else { return }
        for registration in matched {
            if let maxAge = registration.maxAge,
               let sentAt = dict["sentAt"] as? Double,
               now - sentAt > maxAge { continue }
            registration.deliver(dict)
        }
    }
}
```

- [x] **Step 5: 테스트 통과 확인**

Run: `cd ~/Workspace/Projects/ralli-kit && swift test`
Expected: PASS — 16 tests (WorkoutCore 8 + ConnectivityCore 8)

- [x] **Step 6: 커밋 + 푸시**

```bash
cd ~/Workspace/Projects/ralli-kit
git add -A
git commit -m "✨ ConnectivityCore 스캐폴딩 — 메시지 프로토콜·Delivery·라우터

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push
```

---

### Task 2: ConnectivityService — WCSession 래퍼 이식

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/Sources/ConnectivityCore/ConnectivityService.swift`
- 원본 참조(읽기만): `tennis-counter/Shared/Services/WatchConnectivityService.swift:220-413` (서비스 부분)

**Interfaces:**
- Consumes: Task 1의 `ConnectivityMessage`, `Delivery`, `MessageRouter`, `MessageEnvelope`
- Produces (모두 `#if canImport(WatchConnectivity)` 안 — iOS·watchOS에서만 존재):
  - `public final class ConnectivityService: NSObject, ObservableObject`
  - `@Published public private(set) var isCounterpartReachable: Bool`
  - `override public init()` — WCSession activate
  - `public func onReceive<M: ConnectivityMessage>(_: M.Type, maxAge: TimeInterval? = nil, handler: @escaping @MainActor (M) -> Void)`
  - `public func send(_ message: some ConnectivityMessage, via delivery: Delivery)`
  - `public func clearSessionContext()`

**단위 테스트 없음에 대한 노트**: 이 파일은 WCSession 델리게이트 배선이 전부고, 분리 가능한 순수 로직은 이미 Task 1의 router로 빠져 테스트됐다. WCSession은 시뮬레이터 단위 테스트로 검증 불가(기존 서비스도 동일) — 이 태스크의 게이트는 iOS·watchOS 컴파일 체크와 macOS `swift test`(제외 확인)이며, 동작 검증은 Task 5~6의 기존 앱 테스트 스위트와 Task 8 실기기 회귀가 담당한다.

- [x] **Step 1: 구현**

`Sources/ConnectivityCore/ConnectivityService.swift`:

```swift
#if canImport(WatchConnectivity)
    import Combine
    import Foundation
    import WatchConnectivity

    /// WCSession 래퍼. 전송(3가지 Delivery)·수신 라우팅·콜드런치 컨텍스트 채택·sentAt 스탬프만 담당한다.
    /// 메시지 정의는 앱 몫. macOS에는 WatchConnectivity가 없어 이 파일 전체가 제외된다.
    public final class ConnectivityService: NSObject, ObservableObject {
        @Published public private(set) var isCounterpartReachable: Bool = false

        /// clearSessionContext가 쓰는 예약 타입. 수신 측엔 등록이 없으므로 라우터가 자연히 무시한다.
        static let sessionClearedType = "sessionCleared"

        private let router = MessageRouter()

        override public init() {
            super.init()
            guard WCSession.isSupported() else { return }
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        /// 핸들러는 main queue에서 호출된다.
        /// ⚠️ 서비스를 생성한 그 main-queue turn 안에서 등록을 마칠 것 — 활성화 콜백(콜드런치
        /// 컨텍스트 배달)은 다음 turn에 main으로 들어오므로, 그 전에 등록되어 있으면 유실이 없다.
        public func onReceive<M: ConnectivityMessage>(
            _: M.Type,
            maxAge: TimeInterval? = nil,
            handler: @escaping @MainActor (M) -> Void
        ) {
            router.register(type: M.messageType, maxAge: maxAge) { dict in
                guard let message = M(from: dict) else { return }
                MainActor.assumeIsolated { handler(message) }
            }
        }

        public func send(_ message: some ConnectivityMessage, via delivery: Delivery) {
            guard WCSession.default.activationState == .activated else { return }
            let dict = MessageEnvelope.stamp(
                message.toDictionary(),
                type: type(of: message).messageType,
                sentAt: Date().timeIntervalSince1970
            )
            switch delivery {
            case .realtimeOnly:
                #if os(iOS)
                    guard WCSession.default.isWatchAppInstalled else { return }
                #endif
                guard WCSession.default.isReachable else { return }
                WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
            case .reliable:
                // 원본 sendReliably와 가드 파리티 유지 — iOS isWatchAppInstalled 가드 없음
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
                } else {
                    WCSession.default.transferUserInfo(dict)
                }
            case .context:
                #if os(iOS)
                    guard WCSession.default.isWatchAppInstalled else { return }
                #endif
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
                } else {
                    try? WCSession.default.updateApplicationContext(dict)
                }
            }
        }

        /// 드라이버가 운동/매치를 끝낼 때 자기 outgoing applicationContext를 비운다.
        /// 상대가 콜드 런치할 때 끝난 세션의 sessionStart를 읽어 잘못 진입하지 않게 한다.
        public func clearSessionContext() {
            guard WCSession.default.activationState == .activated else { return }
            #if os(iOS)
                guard WCSession.default.isWatchAppInstalled else { return }
            #endif
            try? WCSession.default.updateApplicationContext(["type": Self.sessionClearedType])
        }

        private func routeOnMain(_ dict: [String: Any]) {
            DispatchQueue.main.async { self.router.route(dict) }
        }
    }

    extension ConnectivityService: WCSessionDelegate {
        public func session(_ session: WCSession,
                            activationDidCompleteWith _: WCSessionActivationState,
                            error _: Error?)
        {
            DispatchQueue.main.async { self.isCounterpartReachable = session.isReachable }
            // 콜드 런치 함정: 앱이 꺼져 있는 동안 updateApplicationContext로 도착한 값은
            // didReceiveApplicationContext가 불리지 않고 receivedApplicationContext에만 남는다.
            // 활성화 직후 직접 읽어 같은 라우팅으로 배달한다. staleness는 등록된 maxAge와
            // 앱 핸들러(sessionStart의 workoutStartDate 검사)가 거른다.
            let context = session.receivedApplicationContext
            guard !context.isEmpty else { return }
            routeOnMain(context)
        }

        public func sessionReachabilityDidChange(_ session: WCSession) {
            DispatchQueue.main.async { self.isCounterpartReachable = session.isReachable }
        }

        public func session(_: WCSession, didReceiveMessage message: [String: Any]) {
            routeOnMain(message)
        }

        public func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
            routeOnMain(applicationContext)
        }

        public func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
            routeOnMain(userInfo)
        }

        #if os(iOS)
            public func sessionDidBecomeInactive(_: WCSession) {}
            public func sessionDidDeactivate(_: WCSession) {
                WCSession.default.activate()
            }
        #endif
    }
#endif
```

- [x] **Step 2: macOS 테스트 그린 확인 (파일 제외 검증 겸)**

Run: `cd ~/Workspace/Projects/ralli-kit && swift test`
Expected: PASS — 16 tests (ConnectivityService는 macOS에서 컴파일 제외)

- [x] **Step 3: watchOS·iOS 컴파일 확인**

Run: `cd ~/Workspace/Projects/ralli-kit && xcodebuild -scheme ConnectivityCore -destination 'generic/platform=watchOS Simulator' build && xcodebuild -scheme ConnectivityCore -destination 'generic/platform=iOS Simulator' build`
Expected: 두 번 모두 BUILD SUCCEEDED

- [x] **Step 4: 커밋 + 푸시**

```bash
cd ~/Workspace/Projects/ralli-kit
git add -A
git commit -m "✨ ConnectivityService 이식 — WCSession 전송·라우팅·콜드런치 코어

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push
```

---

### Task 3: [사용자 수동] ConnectivityCore를 테니스 양 타겟에 링크

**⚠️ Xcode GUI 작업 — 사용자가 직접 수행. 에이전트는 안내 후 대기하고 Step 3만 수행한다.**

**Files:**
- Modify: `tennis-counter/TennisCounter.xcodeproj/project.pbxproj` (Xcode 자동 수정, 커밋은 Task 4에서)

**Interfaces:**
- Consumes: Task 2까지의 ralli-kit (로컬 패키지는 Plan 1에서 이미 프로젝트에 등록됨)
- Produces: "TennisCounter"와 "TennisCounter Watch App" 두 타겟에서 `import ConnectivityCore` 가능

- [x] **Step 1: [사용자] 두 타겟에 product 추가**

RalliKit 패키지는 이미 프로젝트에 있으므로 File → Add Package가 아니라 **타겟별 Frameworks 추가**만 하면 된다:

1. 프로젝트 네비게이터 최상단 파란 **TennisCounter 프로젝트 아이콘** 클릭
2. TARGETS → **"TennisCounter"** → General → **Frameworks, Libraries, and Embedded Content** → `+` → *Workspace → RalliKit* 아래 `ConnectivityCore` 선택 → Add
3. TARGETS → **"TennisCounter Watch App"** 에 같은 과정 반복

- [x] **Step 2: [사용자] 완료 알림**

- [x] **Step 3: 링크 상태 빌드 확인 (에이전트)**

Run:
```bash
cd ~/Workspace/Projects/tennis-counter
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1' build
```
Expected: 둘 다 BUILD SUCCEEDED

---

### Task 4: 테니스 — 메시지 conformance + MatchConnectivity 래퍼 (스왑 없음)

이 태스크는 **추가만** 한다. 구 `WatchConnectivityService`는 그대로 동작하고, `MatchConnectivity.shared`는 lazy static이라 참조 전까지 WCSession을 건드리지 않는다. 앱 런타임 스왑은 Task 5·6.

**Files:**
- Create: `tennis-counter/Shared/Services/ConnectivityMessages.swift` (구조체 이동 + conformance + 신규 3종)
- Modify: `tennis-counter/Shared/Services/WatchConnectivityService.swift` — 구조체 정의 4개(19-216행: `SessionStartMessage`, `ScoreState`, `MatchEndMessage`, `MatchSaveResultMessage`) 삭제. `private enum WCMessageType`(7-17행)과 서비스 클래스는 유지 (Task 7에서 파일째 삭제).
- Create: `tennis-counter/Shared/Services/MatchConnectivity.swift`
- Test: `tennis-counter/iosTests/Shared/ConnectivityMessagesTests.swift` (신규)
- Test: `tennis-counter/iosTests/Shared/MatchConnectivityTests.swift` (신규)
- Commit 포함: `TennisCounter.xcodeproj/project.pbxproj` (Task 3에서 Xcode가 수정)

**Interfaces:**
- Consumes: `ConnectivityCore`의 `ConnectivityMessage`, `Delivery`, `ConnectivityService`(`onReceive`/`send`/`clearSessionContext`/`$isCounterpartReachable`)
- Produces (Task 5·6이 사용):
  - `MatchConnectivity.shared` — 구 서비스와 동일 표면: `@Published var isWatchReachable: Bool`, `@Published var receivedSessionStart/ScoreState/MatchEnd/MatchSave/MatchSaveResult/Metrics/WorkoutEnd/MatchReset`(전부 settable — nil 대입 소비 패턴 유지), `sendSessionStart/ScoreState/MatchEnd/MatchSave/MatchSaveResult/Metrics(_:)`, `sendWorkoutEnd(sessionId:)`, `sendMatchReset(sessionId:)`, `clearSessionContext()`, `static isSessionStartStale(workoutStartDate:now:)`, `static let workoutEndStalenessThreshold/sessionStartStalenessThreshold`
  - 메시지 타입: 기존 4종 + `MatchSaveMessage(base:)`, `WorkoutEndMessage(sessionId:)`, `MatchResetMessage(sessionId:)`, `WorkoutMetrics: ConnectivityMessage`

- [x] **Step 1: 실패하는 테스트 작성**

`iosTests/Shared/ConnectivityMessagesTests.swift`:

```swift
import Foundation
@testable import TennisCounter
import Testing

struct ConnectivityMessagesTests {
    @Test func workoutEndMessageRoundTrips() {
        let id = UUID()
        let decoded = WorkoutEndMessage(from: WorkoutEndMessage(sessionId: id).toDictionary())
        #expect(decoded?.sessionId == id)
    }

    @Test func matchResetMessageRoundTrips() {
        let id = UUID()
        let decoded = MatchResetMessage(from: MatchResetMessage(sessionId: id).toDictionary())
        #expect(decoded?.sessionId == id)
    }

    @Test func workoutEndMessageRejectsMalformedSessionId() {
        #expect(WorkoutEndMessage(from: ["sessionId": "not-a-uuid"]) == nil)
    }

    @Test func matchSaveMessageRoundTripsThroughSaveDictionary() {
        let base = MatchEndMessage(
            sessionId: UUID(), result: "win", completedSets: [[6, 3]],
            startedAt: Date(timeIntervalSince1970: 1000), endedAt: Date(timeIntervalSince1970: 2000),
            durationSeconds: 1000, calories: 120, averageHeartRate: 130, mode: "oneSet", noAdRule: true
        )
        let decoded = MatchSaveMessage(from: MatchSaveMessage(base: base).toDictionary())
        #expect(decoded?.base.sessionId == base.sessionId)
        #expect(decoded?.base.result == "win")
        #expect(decoded?.base.completedSets == [[6, 3]])
    }

    @Test func matchSaveMessageRejectsMatchEndDictionary() {
        let base = MatchEndMessage(
            sessionId: UUID(), result: "win", completedSets: [],
            startedAt: Date(), endedAt: Date(),
            durationSeconds: 0, calories: 0, averageHeartRate: nil, mode: "oneSet", noAdRule: true
        )
        // toDictionary()는 type=matchEnd — matchSave 라우팅용 디코드는 거부해야 한다
        #expect(MatchSaveMessage(from: base.toDictionary()) == nil)
    }

    @Test func workoutMetricsConformsWithMetricsType() {
        #expect(WorkoutMetrics.messageType == "metrics")
        let decoded = WorkoutMetrics(from: WorkoutMetrics(elapsedSeconds: 10, calories: 5, heartRate: 120, steps: 0).toDictionary())
        #expect(decoded?.heartRate == 120)
    }
}
```

`iosTests/Shared/MatchConnectivityTests.swift` (구 `WatchConnectivityStalenessTests`의 sessionStart 절반을 계승 — workoutEnd staleness는 패키지 `MessageRouterTests`가 담당):

```swift
import Foundation
@testable import TennisCounter
import Testing

struct MatchConnectivityTests {
    @Test func recentSessionStartIsNotStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: now - 60, now: now) == false)
    }

    @Test func veryOldSessionStartIsStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: now - 7 * 3600, now: now) == true)
    }

    @Test func missingSessionStartDateIsNotStale() {
        let now = 1_000_000.0
        #expect(MatchConnectivity.isSessionStartStale(workoutStartDate: nil, now: now) == false)
    }
}
```

- [x] **Step 2: 테스트 컴파일 실패 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: FAIL — `cannot find 'WorkoutEndMessage' in scope`, `cannot find 'MatchConnectivity' in scope`

- [x] **Step 3: ConnectivityMessages.swift 생성 (구조체 이동 + conformance)**

기존 4개 struct를 `WatchConnectivityService.swift`에서 **그대로 옮기되**: ① `ConnectivityMessage` 채택 선언, ② `static let messageType` 추가, ③ `WCMessageType.x.rawValue` → 문자열 리터럴/`Self.messageType`으로 치환 (이동한 파일에서는 private enum이 안 보이므로). 필드·직렬화 로직 불변.

`Shared/Services/ConnectivityMessages.swift` 전체:

```swift
import ConnectivityCore
import Foundation

// MARK: - 세션 시작

struct SessionStartMessage: ConnectivityMessage {
    static let messageType = "sessionStart"

    let sessionId: UUID
    let options: MatchOptions
    let workoutStartDate: Date

    func toDictionary() -> [String: Any] {
        [
            "type": Self.messageType,
            "sessionId": sessionId.uuidString,
            "mode": options.mode.rawValue,
            "noAdRule": options.noAdRule,
            "noTieRule": options.noTieRule,
            "gameThreshold": options.gameThreshold,
            "workoutStartDate": workoutStartDate.timeIntervalSince1970,
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == Self.messageType,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let modeRaw = dict["mode"] as? String,
              let mode = MatchFormat(rawValue: modeRaw) else { return nil }
        sessionId = id
        options = MatchOptions(
            mode: mode,
            noAdRule: dict["noAdRule"] as? Bool ?? true,
            noTieRule: dict["noTieRule"] as? Bool ?? false,
            gameThreshold: dict["gameThreshold"] as? Int ?? 6
        )
        let ts = dict["workoutStartDate"] as? Double ?? Date().timeIntervalSince1970
        workoutStartDate = Date(timeIntervalSince1970: ts)
    }

    init(sessionId: UUID, options: MatchOptions, workoutStartDate: Date = Date()) {
        self.sessionId = sessionId
        self.options = options
        self.workoutStartDate = workoutStartDate
    }
}

// MARK: - 점수 상태

struct ScoreState: ConnectivityMessage {
    static let messageType = "scoreState"

    let myScore: Int
    let yourScore: Int
    let myGameScore: Int
    let yourGameScore: Int
    let mySetScore: Int
    let yourSetScore: Int
    let completedSets: [[Int]]
    let isTieBreak: Bool

    func toDictionary() -> [String: Any] {
        [
            "type": Self.messageType,
            "myScore": myScore,
            "yourScore": yourScore,
            "myGame": myGameScore,
            "yourGame": yourGameScore,
            "mySet": mySetScore,
            "yourSet": yourSetScore,
            "sets": completedSets,
            "tieBreak": isTieBreak,
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == Self.messageType,
              let myScore = dict["myScore"] as? Int,
              let yourScore = dict["yourScore"] as? Int,
              let myGame = dict["myGame"] as? Int,
              let yourGame = dict["yourGame"] as? Int,
              let mySet = dict["mySet"] as? Int,
              let yourSet = dict["yourSet"] as? Int else { return nil }
        self.myScore = myScore
        self.yourScore = yourScore
        myGameScore = myGame
        yourGameScore = yourGame
        mySetScore = mySet
        yourSetScore = yourSet
        completedSets = dict["sets"] as? [[Int]] ?? []
        isTieBreak = dict["tieBreak"] as? Bool ?? false
    }

    init(myScore: Int, yourScore: Int, myGameScore: Int, yourGameScore: Int,
         mySetScore: Int, yourSetScore: Int, completedSets: [[Int]], isTieBreak: Bool)
    {
        self.myScore = myScore
        self.yourScore = yourScore
        self.myGameScore = myGameScore
        self.yourGameScore = yourGameScore
        self.mySetScore = mySetScore
        self.yourSetScore = yourSetScore
        self.completedSets = completedSets
        self.isTieBreak = isTieBreak
    }
}

// MARK: - 경기 종료/저장

struct MatchEndMessage: ConnectivityMessage {
    static let messageType = "matchEnd"

    let sessionId: UUID
    let result: String
    let completedSets: [[Int]]
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let calories: Double
    let averageHeartRate: Double?
    let mode: String
    let noAdRule: Bool

    func toDictionary() -> [String: Any] {
        dictionary(type: Self.messageType)
    }

    /// 사용자가 저장 버튼을 눌렀을 때 전송하는 페이로드 (iOS가 이때만 persist)
    func toSaveDictionary() -> [String: Any] {
        dictionary(type: MatchSaveMessage.messageType)
    }

    private func dictionary(type: String) -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "sessionId": sessionId.uuidString,
            "result": result,
            "sets": completedSets,
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "durationSeconds": durationSeconds,
            "calories": calories,
            "mode": mode,
            "noAdRule": noAdRule,
        ]
        if let hr = averageHeartRate { dict["heartRate"] = hr }
        return dict
    }

    init?(from dict: [String: Any]) {
        let type = dict["type"] as? String
        guard type == Self.messageType || type == MatchSaveMessage.messageType,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let result = dict["result"] as? String,
              let startTs = dict["startedAt"] as? Double,
              let endTs = dict["endedAt"] as? Double,
              let mode = dict["mode"] as? String else { return nil }
        sessionId = id
        self.result = result
        completedSets = dict["sets"] as? [[Int]] ?? []
        startedAt = Date(timeIntervalSince1970: startTs)
        endedAt = Date(timeIntervalSince1970: endTs)
        durationSeconds = dict["durationSeconds"] as? Int ?? Int(endTs - startTs)
        calories = dict["calories"] as? Double ?? 0
        averageHeartRate = dict["heartRate"] as? Double
        self.mode = mode
        noAdRule = dict["noAdRule"] as? Bool ?? true
    }

    init(sessionId: UUID, result: String, completedSets: [[Int]], startedAt: Date,
         endedAt: Date, durationSeconds: Int, calories: Double, averageHeartRate: Double?, mode: String, noAdRule: Bool)
    {
        self.sessionId = sessionId
        self.result = result
        self.completedSets = completedSets
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.mode = mode
        self.noAdRule = noAdRule
    }
}

/// MatchEndMessage와 같은 페이로드를 "matchSave" 타입으로 실어 나르는 래퍼.
/// 결과 표시(matchEnd)와 저장 요청(matchSave)을 타입 라우팅으로 구분하기 위해 존재한다.
struct MatchSaveMessage: ConnectivityMessage {
    static let messageType = "matchSave"

    let base: MatchEndMessage

    init(base: MatchEndMessage) {
        self.base = base
    }

    init?(from dictionary: [String: Any]) {
        guard dictionary["type"] as? String == Self.messageType,
              let base = MatchEndMessage(from: dictionary) else { return nil }
        self.base = base
    }

    func toDictionary() -> [String: Any] {
        base.toSaveDictionary()
    }
}

struct MatchSaveResultMessage: ConnectivityMessage {
    static let messageType = "matchSaveResult"

    let sessionId: UUID
    let success: Bool

    func toDictionary() -> [String: Any] {
        [
            "type": Self.messageType,
            "sessionId": sessionId.uuidString,
            "success": success,
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == Self.messageType,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let success = dict["success"] as? Bool else { return nil }
        sessionId = id
        self.success = success
    }

    init(sessionId: UUID, success: Bool) {
        self.sessionId = sessionId
        self.success = success
    }
}

// MARK: - 신호 메시지 (구 서비스에서는 raw dict였던 것들 — type/sentAt은 코어가 스탬프)

struct WorkoutEndMessage: ConnectivityMessage {
    static let messageType = "workoutEnd"

    let sessionId: UUID

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    init?(from dictionary: [String: Any]) {
        guard let idStr = dictionary["sessionId"] as? String,
              let id = UUID(uuidString: idStr) else { return nil }
        sessionId = id
    }

    func toDictionary() -> [String: Any] {
        ["sessionId": sessionId.uuidString]
    }
}

/// 드라이버가 진행 중 매치를 중간에 버릴 때(뒤로가기) 미러도 모드선택으로 돌아가게 하는 신호.
struct MatchResetMessage: ConnectivityMessage {
    static let messageType = "matchReset"

    let sessionId: UUID

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    init?(from dictionary: [String: Any]) {
        guard let idStr = dictionary["sessionId"] as? String,
              let id = UUID(uuidString: idStr) else { return nil }
        sessionId = id
    }

    func toDictionary() -> [String: Any] {
        ["sessionId": sessionId.uuidString]
    }
}

// MARK: - 기존 모델 conformance

extension WorkoutMetrics: ConnectivityMessage {
    static let messageType = "metrics"
}
```

- [x] **Step 4: WatchConnectivityService.swift에서 구조체 삭제**

`Shared/Services/WatchConnectivityService.swift`에서 `SessionStartMessage`(19-58행), `ScoreState`(60-114행), `MatchEndMessage`(116-189행), `MatchSaveResultMessage`(191-216행) 정의를 삭제한다. 남는 것: import 3줄, `private enum WCMessageType`, `// MARK: - Service`부터 파일 끝까지 (서비스 클래스 + WCSessionDelegate extension). 서비스 본문은 한 줄도 바꾸지 않는다 — 이동한 구조체들을 같은 모듈에서 계속 참조한다.

- [x] **Step 5: MatchConnectivity.swift 생성**

`Shared/Services/MatchConnectivity.swift` 전체:

```swift
import Combine
import ConnectivityCore
import Foundation

/// ConnectivityCore 위의 앱 레이어. 코어의 1회성 핸들러 배달을 기존 sticky @Published 시맨틱으로
/// 복원하고(소비자가 nil 대입으로 소비), 테니스 메시지별 send/receive 표면을 제공한다.
/// init에서 모든 onReceive 등록을 마치므로 콜드런치 컨텍스트 배달 제약(같은 main turn 등록)을 만족한다.
final class MatchConnectivity: ObservableObject {
    static let shared = MatchConnectivity(service: ConnectivityService())

    @Published var isWatchReachable: Bool = false
    @Published var receivedSessionStart: SessionStartMessage?
    @Published var receivedScoreState: ScoreState?
    @Published var receivedMatchEnd: MatchEndMessage?
    @Published var receivedMatchSave: MatchEndMessage?
    @Published var receivedMatchSaveResult: MatchSaveResultMessage?
    @Published var receivedMetrics: WorkoutMetrics?
    @Published var receivedWorkoutEnd: UUID?
    @Published var receivedMatchReset: UUID?

    private let service: ConnectivityService

    init(service: ConnectivityService) {
        self.service = service

        service.$isCounterpartReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWatchReachable)

        service.onReceive(SessionStartMessage.self) { [weak self] msg in
            // 죽은 세션 채택 방지: workoutStartDate가 비현실적으로 오래된 sessionStart는 버린다.
            // (기존에는 콜드런치 컨텍스트 읽기에서만 걸렀으나 모든 수신 경로로 일반화)
            guard !Self.isSessionStartStale(workoutStartDate: msg.workoutStartDate.timeIntervalSince1970) else { return }
            self?.receivedSessionStart = msg
        }
        service.onReceive(ScoreState.self) { [weak self] in self?.receivedScoreState = $0 }
        service.onReceive(MatchEndMessage.self) { [weak self] in self?.receivedMatchEnd = $0 }
        service.onReceive(MatchSaveMessage.self) { [weak self] in self?.receivedMatchSave = $0.base }
        service.onReceive(MatchSaveResultMessage.self) { [weak self] in self?.receivedMatchSaveResult = $0 }
        service.onReceive(WorkoutMetrics.self) { [weak self] in self?.receivedMetrics = $0 }
        service.onReceive(WorkoutEndMessage.self, maxAge: Self.workoutEndStalenessThreshold) { [weak self] in
            self?.receivedWorkoutEnd = $0.sessionId
        }
        service.onReceive(MatchResetMessage.self) { [weak self] in self?.receivedMatchReset = $0.sessionId }
    }

    // MARK: - Send

    func sendSessionStart(_ msg: SessionStartMessage) {
        service.send(msg, via: .context)
    }

    func sendScoreState(_ state: ScoreState) {
        service.send(state, via: .reliable)
    }

    func sendMatchEnd(_ msg: MatchEndMessage) {
        service.send(msg, via: .reliable)
    }

    /// 저장 버튼 전용. iOS가 이 메시지를 받을 때만 히스토리에 persist 한다.
    func sendMatchSave(_ msg: MatchEndMessage) {
        service.send(MatchSaveMessage(base: msg), via: .reliable)
    }

    /// iOS가 저장 요청을 처리한 뒤 실제 persist 성공/실패를 Watch에 회신한다.
    func sendMatchSaveResult(_ msg: MatchSaveResultMessage) {
        service.send(msg, via: .reliable)
    }

    func sendMetrics(_ metrics: WorkoutMetrics) {
        service.send(metrics, via: .realtimeOnly)
    }

    func sendWorkoutEnd(sessionId: UUID) {
        service.send(WorkoutEndMessage(sessionId: sessionId), via: .reliable)
    }

    func sendMatchReset(sessionId: UUID) {
        service.send(MatchResetMessage(sessionId: sessionId), via: .reliable)
    }

    func clearSessionContext() {
        service.clearSessionContext()
    }

    // MARK: - Staleness (구 WatchConnectivityService에서 이동)

    static let workoutEndStalenessThreshold: TimeInterval = 60

    /// applicationContext는 마지막 값을 계속 보관하므로, 운동 종료 시 비우지 못한 채(워치 크래시 등)
    /// 한참 뒤 수신하면 죽은 세션을 채택할 수 있다. workoutStartDate가 비현실적으로 오래된
    /// sessionStart는 채택에서 제외한다. (정상 종료는 clearSessionContext가 비운다)
    static let sessionStartStalenessThreshold: TimeInterval = 6 * 3600

    static func isSessionStartStale(workoutStartDate: Double?, now: Double = Date().timeIntervalSince1970) -> Bool {
        guard let workoutStartDate else { return false }
        return now - workoutStartDate > sessionStartStalenessThreshold
    }
}
```

- [x] **Step 6: 양 타겟 테스트 통과 확인**

Run:
```bash
cd ~/Workspace/Projects/tennis-counter
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'
```
Expected: 둘 다 TEST SUCCEEDED (신규 9개 테스트 포함, 기존 스위트 그린 — 구 서비스 여전히 동작)

- [x] **Step 7: 린트 + 커밋**

```bash
cd ~/Workspace/Projects/tennis-counter
make fix && make lint
git add Shared iosTests TennisCounter.xcodeproj/project.pbxproj
git commit -m "✨ ConnectivityCore 도입 준비 — 메시지 conformance + MatchConnectivity 래퍼

- 메시지 구조체를 ConnectivityMessages.swift로 이동, ConnectivityMessage 채택
- 신규: MatchSaveMessage·WorkoutEndMessage·MatchResetMessage (raw dict → 타입)
- MatchConnectivity: 코어 핸들러 → 기존 sticky @Published 표면 복원 (스왑은 다음 커밋)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Watch 타겟 스왑

**Files:**
- Modify: `tennis-counter/WatchApp/WatchApp.swift:12`
- Modify: `tennis-counter/WatchApp/Features/Home/HomeView.swift:6`
- Modify: `tennis-counter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:15`
- Modify: `tennis-counter/watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift:90,106`

**Interfaces:**
- Consumes: Task 4의 `MatchConnectivity.shared` (구 서비스와 동일 표면이므로 프로퍼티·메서드 호출부는 무변경)
- Produces: Watch 프로세스에서 WCSession 소유자가 신규 `ConnectivityService`로 교체된 상태

- [x] **Step 1: 네 파일에서 타입 치환**

`WatchApp/WatchApp.swift:12`:
```swift
// 변경 전
private let watchConnectivity = WatchConnectivityService.shared
// 변경 후
private let watchConnectivity = MatchConnectivity.shared
```

`WatchApp/Features/Home/HomeView.swift:6`:
```swift
// 변경 전
private let connectivity = WatchConnectivityService.shared
// 변경 후
private let connectivity = MatchConnectivity.shared
```

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:15`:
```swift
// 변경 전
private let connectivity = WatchConnectivityService.shared
// 변경 후
private let connectivity = MatchConnectivity.shared
```

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` 90행과 106행 (두 곳):
```swift
// 변경 전
let service = WatchConnectivityService.shared
// 변경 후
let service = MatchConnectivity.shared
```

이외 변경 없음 — `received*`/`send*`/`clearSessionContext`/`isWatchReachable` 표면이 동일해서 나머지 코드는 그대로 컴파일된다.

- [x] **Step 2: Watch 테스트 통과 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'`
Expected: TEST SUCCEEDED

- [x] **Step 3: Watch Release 빌드 확인 (Plan 1 교훈)**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1' -configuration Release build`
Expected: BUILD SUCCEEDED

- [x] **Step 4: 커밋**

```bash
cd ~/Workspace/Projects/tennis-counter
git add WatchApp watchosTests
git commit -m "♻️ Watch 타겟을 MatchConnectivity로 스왑

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: iOS 타겟 스왑

**Files:**
- Modify: `tennis-counter/iOSApp/iOSApp.swift:7,46`
- Modify: `tennis-counter/iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:23`
- Modify: `tennis-counter/iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift:198,214`

**Interfaces:**
- Consumes: Task 4의 `MatchConnectivity.shared`
- Produces: 양 타겟 모두 신규 코어 사용 — 구 `WatchConnectivityService`는 어느 프로세스에서도 인스턴스화되지 않음 (Task 7에서 삭제 가능)

- [x] **Step 1: 세 파일에서 타입 치환**

`iOSApp/iOSApp.swift:7` (TennisCounterApp):
```swift
// 변경 전
private let watchConnectivity = WatchConnectivityService.shared
// 변경 후
private let watchConnectivity = MatchConnectivity.shared
```

`iOSApp/iOSApp.swift:46` (MainTabView):
```swift
// 변경 전
private let connectivity = WatchConnectivityService.shared
// 변경 후
private let connectivity = MatchConnectivity.shared
```

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:23`:
```swift
// 변경 전
private let connectivity = WatchConnectivityService.shared
// 변경 후
private let connectivity = MatchConnectivity.shared
```

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` 198행과 214행 (두 곳):
```swift
// 변경 전
let service = WatchConnectivityService.shared
// 변경 후
let service = MatchConnectivity.shared
```

- [x] **Step 2: iOS 테스트 통과 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: TEST SUCCEEDED

- [x] **Step 3: iOS Release 빌드 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Release build`
Expected: BUILD SUCCEEDED

- [x] **Step 4: 커밋**

```bash
cd ~/Workspace/Projects/tennis-counter
git add iOSApp iosTests
git commit -m "♻️ iOS 타겟을 MatchConnectivity로 스왑

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: 구 서비스 삭제 + README 갱신

**Files:**
- Delete: `tennis-counter/Shared/Services/WatchConnectivityService.swift` (남아 있는 것은 서비스 클래스 + private WCMessageType뿐)
- Delete: `tennis-counter/iosTests/Shared/WatchConnectivityStalenessTests.swift` (sessionStart 절반은 Task 4의 `MatchConnectivityTests`가, workoutEnd 절반은 패키지 `MessageRouterTests`가 계승)
- Modify: `~/Workspace/Projects/ralli-kit/README.md`

**Interfaces:**
- Consumes: Task 5·6 완료 상태 (구 서비스 참조 0이어야 삭제 가능)
- Produces: `WatchConnectivityService` 심볼 소멸. README에 ConnectivityCore ✅.

- [x] **Step 1: 파일 2개 삭제**

```bash
rm ~/Workspace/Projects/tennis-counter/Shared/Services/WatchConnectivityService.swift
rm ~/Workspace/Projects/tennis-counter/iosTests/Shared/WatchConnectivityStalenessTests.swift
```

- [x] **Step 2: 참조 0건 확인**

Run: `grep -rn "WatchConnectivityService" --include="*.swift" ~/Workspace/Projects/tennis-counter ~/Workspace/Projects/ralli-kit`
Expected: 0 hits (exit code 1)

- [x] **Step 3: 양 타겟 최종 테스트**

Run:
```bash
cd ~/Workspace/Projects/tennis-counter
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'
```
Expected: 둘 다 TEST SUCCEEDED

- [x] **Step 4: README 갱신**

`~/Workspace/Projects/ralli-kit/README.md`에서 product 표의 ConnectivityCore 행을 `✅`로 바꾸고, WorkoutCore 사용법 섹션 아래에 다음 섹션을 추가:

```markdown
## ConnectivityCore 사용법

```swift
import ConnectivityCore

// 메시지 정의는 앱 몫 — 프로토콜만 채택하면 된다
struct RoundRecordMessage: ConnectivityMessage {
    static let messageType = "roundRecord"
    let holeScores: [Int]
    init?(from dictionary: [String: Any]) { ... }
    func toDictionary() -> [String: Any] { ... }
}

let connectivity = ConnectivityService()
// ⚠️ onReceive 등록은 서비스를 생성한 그 main-queue turn 안에서 마칠 것 —
//    콜드런치 applicationContext 배달이 등록 전에 도착하면 유실된다.
connectivity.onReceive(RoundRecordMessage.self, maxAge: 60) { record in ... }

// 전송: .realtimeOnly(미도달 드롭) / .reliable(transferUserInfo 큐잉) / .context(마지막 상태 보존)
connectivity.send(RoundRecordMessage(...), via: .reliable)
```

- 코어가 모든 발신에 `type`·`sentAt`을 스탬프한다. `maxAge`는 sentAt 기준이며, sentAt 없는 수신(구버전)은 stale로 보지 않는다.
- sticky 값이 필요하면(SwiftUI `@Published` 구독) 앱 레이어에서 얇은 래퍼로 복원할 것 — 테니스 앱의 `MatchConnectivity` 참조.
```

- [x] **Step 5: 커밋 (양 레포) + 푸시**

```bash
cd ~/Workspace/Projects/ralli-kit
git add README.md
git commit -m "📝 README — ConnectivityCore 사용법·등록 시점 주의 추가

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push

cd ~/Workspace/Projects/tennis-counter
git add Shared iosTests
git commit -m "🔥 WatchConnectivityService 삭제 — ConnectivityCore 전환 완료

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: [사용자 수동] 실기기 2대 회귀

**⚠️ 시뮬레이터로는 WC 연동 버그를 재현할 수 없다 (타당성 문서 명시). iPhone + Apple Watch 실기기로 수행.**

체크리스트 (각 항목이 기존 버그 픽스 하나씩을 회귀 검증한다):

- [ ] **1. 실시간 미러링**: 워치에서 운동+매치 시작 → 폰이 자동으로 매치 화면 진입(sessionStart), 워치 점수 입력이 폰에 즉시 반영
- [ ] **2. 큐잉 폴백**: 폰을 잠그거나 멀리 둔 상태(미도달)에서 워치 점수 진행 → 폰 복귀 시 최신 점수 반영 (reliable → transferUserInfo)
- [ ] **3. 저장 왕복**: 워치에서 경기 종료 → 저장 버튼 → 폰 히스토리에 기록 + 워치에 저장 완료 표시(saveAckState succeeded)
- [ ] **4. workoutEnd stale 필터**: 워치 운동 종료 → 폰도 세션 종료. 이후 폰 앱을 종료했다가 61초+ 뒤 재실행 → 종료 신호가 다시 적용되지 않음
- [ ] **5. 콜드런치 채택**: 폰에서 매치 진행 중 워치 앱 강제 종료 → 워치 앱 재실행 → 진행 중 세션 자동 재진입 (applicationContext + 콜드런치 라우팅)
- [ ] **6. matchReset**: 드라이버 쪽 뒤로가기 → 미러가 모드 선택으로 복귀
- [ ] **7. 주변부**: Complication 점수 표시, iOS Live Activity 갱신 정상

문제 발견 시: 증상을 기록하고 `superpowers:systematic-debugging`으로 진입. 커밋 롤백 단위는 Task 5/6(스왑 커밋)이다.

---

## 완료 기준 (Plan 2 Definition of Done)

1. ralli-kit `swift test` 16/16 그린 (WorkoutCore 8 + ConnectivityCore 8), ConnectivityCore iOS·watchOS 컴파일 그린
2. 테니스 양 타겟: 테스트 스위트 그린 + **Release 빌드 그린**
3. `grep -rn "WatchConnectivityService"` 양 레포 0건
4. 코어에 테니스 도메인 문자열 없음 (`grep -rn '"scoreState"\|"matchEnd"\|"sessionStart"' ~/Workspace/Projects/ralli-kit/Sources` → 0건; "sessionCleared"만 예외)
5. ralli-kit `main` 푸시 완료
6. 실기기 회귀 체크리스트 7항목 통과 (사용자)

---

## 실행 기록 (2026-07-16 완료 — Task 8 제외)

- 실행 방식: subagent-driven-development. Task 1~7 리뷰 통과, 최종 전체 브랜치 리뷰(fable) **"Ready to merge: Yes"** (크로스 레포 종단 추적: 전 메시지 타입의 라이브·큐잉·콜드런치 동등성, 구버전 와이어 양방향 호환, 등록 타이밍 안전성 검증).
- 커밋: ralli-kit `0ed0df1`(스캐폴딩) → `5185996`(서비스) → `00f23c0`(README) → `1f8ccbd`(독스트링) → `b989145`(하드닝) / tennis `b6b6687`(래퍼) → `dedc862`(Watch 스왑) → `1cfd30a`(iOS 스왑) → `be12030`(구 서비스 삭제) → `140654d`(주석·CLAUDE.md) → `90385c0`(init private).
- 검증: 패키지 16/16, 양 타겟 테스트 그린, **양 타겟 Release 빌드 그린**, 구 서비스 참조 0건, 코어 도메인 문자열 0건.

### 계획과 달랐던 점

1. **의도된 변경 5번째 (사후 발견·수용)**: malformed 페이로드 처리 — 구 서비스는 알려진 타입의 파싱 실패 시 `received* = nil`을 발행(대기 중 sticky 값을 지울 수 있었음), 신규 코어는 드롭. 도달 불가 경로이고 신규 동작이 더 안전해 의도적 개선으로 수용.
2. **Task 4는 사용자가 직접 반영** — 계획 코드를 수기 반영, 컨트롤러가 검증·커밋, 리뷰어가 브리프와 byte-identical 확인.
3. **최종 리뷰 하드닝 3건 (계획에 없던 커밋)**: `dispatchPrecondition(.onQueue(.main))`을 init/onReceive에 추가(b989145), README 단일 인스턴스 경고, `MatchConnectivity.init` private화(90385c0) — 이중 인스턴스가 WCSession delegate를 탈취하는 footgun 봉쇄.
4. **문서 스코프 확장**: 양 앱 WorkoutSession README + CLAUDE.md 트리의 구 서비스 언급 갱신 (Task 7 리뷰 픽스 포함).

### Defer 확정 (후속 하이지니 커밋 후보)

- MessageRouter maxAge 경계값(== maxAge) 테스트 / sentAt `as? Double` 캐스트 노트 / clearSessionContext sentAt 미스탬프 / `override public` 수식어 순서 / WorkoutEnd·MatchReset init의 type 자체 검사 없음 / isWatchReachable 이중 홉 — 전부 defer 근거 확인됨 (Plan 1 이월분: timerPausedAt 제거, Sendable/Equatable 부여와 함께 처리 권장).

### 남은 것

- **Task 8: 실기기 2대 회귀 (사용자)** — 최종 리뷰 판단: 브랜치 머지 게이트가 아니라 **릴리즈 게이트**. 와이어 양방향 호환 + 롤백 단위(스왑 커밋 dedc862/1cfd30a) 명확.
- Plan 3(PersistenceCore) 착수 전 권장: 하이지니 커밋 1개로 defer 목록 일괄 처리.
