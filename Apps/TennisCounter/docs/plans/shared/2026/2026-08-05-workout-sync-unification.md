# 워크아웃 동작 통일 Implementation Plan (Plan B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 폰과 워치가 같은 숫자를 보여주도록 칼로리 기준을 워크아웃 누적으로 통일하고, 경과시간을 앵커 동기화로 일원화하고, 미구현이던 pause 동기화를 추가한다.

**Architecture:** 워치가 유일한 진실 소스다. 워치는 `(경과초, isPaused, 누적 칼로리, BPM)` 앵커를 브로드캐스트하고, 폰은 `WorkoutAnchor` 순수 함수로 매초 로컬 보간한다. pause는 폰→워치 명령(`WorkoutPauseMessage`, 큐잉)으로 가고 워치가 실제 `HKWorkoutSession`을 제어하며, 결과는 다음 앵커의 `isPaused`로 폰에 되돌아온다(ack 기반, 낙관적 토글 없음).

**Tech Stack:** Swift 6 toolchain (language mode v5), Combine, SwiftUI, Swift Testing (`@Test`/`#expect`), SPM 멀티 product 패키지(RalliKit), WatchConnectivity

## Global Constraints

- **와이어 호환은 additive만.** 기존 키(`elapsed`/`calories`/`totalCalories`/`heartRate`)의 이름·의미를 바꾸지 않는다. 신규 키(`isPaused`)는 구버전이 무시하고, 구버전이 안 보내면 안전한 기본값으로 떨어진다.
- **칼로리 기준: 워크아웃 누적** (운동 시작~현재). 경기 구간 값은 저장 시점에 `종료값 - 시작값`으로만 만든다.
- **폰은 pause를 낙관적으로 토글하지 않는다.** 워치 ack(앵커의 `isPaused`)로만 `isPaused`를 갱신한다. pause 메시지를 모르는 구버전 워치에서는 아무 일도 일어나지 않아야 한다(오동작 대신 무동작).
- **표시 항목 4개 고정**: 경과시간·활동 kcal·총 kcal·BPM. 이 플랜은 항목을 추가·제거하지 않는다.
- ViewModel 테스트는 `@MainActor` 필수. Swift Testing(`@Test`/`#expect`) 사용. View는 테스트하지 않는다.
- 한 파일 = 한 타입. 패키지 문자열은 `String(localized:bundle: .module)`.
- `.xcodeproj` 직접 편집 금지. 이 플랜은 **새 패키지 product를 만들지 않으므로 Xcode GUI 수동 작업이 없다** (Plan A에서 `WorkoutUI`·`WorkoutCore` 링크 완료).
- 커밋: ralli-kit은 `feat/workout-anchor-pause`, tennis-counter는 `feature/workout-sync-unification` 브랜치. 각 Task 끝에서 커밋.

### 시작 상태

두 저장소 모두 `main`이 Plan A 머지 완료 상태다.

| 저장소 | 브랜치 시작점 |
|---|---|
| `~/Workspace/Projects/ralli-kit` | `main` @ `dfc3bb9` |
| `/Users/yj/Workspace/Projects/tennis-counter` | `main` @ `fa6d419` |

### 검증 명령

시뮬레이터 UDID는 **머신마다 다르다.** 매 세션 시작 시 다시 확인할 것:

```bash
xcrun simctl list devices available | grep -E "iPhone 17 Pro|Apple Watch Series 11"
```

작성 시점 값 — iPhone 17 Pro: `C29B5911-545A-4FD0-853B-9B219A300025`, Apple Watch Series 11 (46mm): `74666695-204D-45AC-8787-2CFEA2CE0C51`

```bash
# ralli-kit (스킴은 "RalliKit"이 아니라 "RalliKit-Package")
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package \
  -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025'

# 테니스 iOS
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 테니스 Watch (이름 매칭 실패함 — 반드시 UDID)
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51'
```

---

## File Structure

**ralli-kit** (`~/Workspace/Projects/ralli-kit`)

| 파일 | 책임 |
|---|---|
| `Sources/WorkoutCore/WorkoutAnchor.swift` | **신규** — 경과시간 보간 순수 함수 |
| `Sources/WorkoutCore/Messages/WorkoutMetricsMessage.swift` | `isPaused`·`sentAt` 추가 |
| `Sources/WorkoutCore/Messages/WorkoutPauseMessage.swift` | **신규** — 폰→워치 pause/resume 명령 |
| `README.md` | `## WorkoutUI 사용법` 섹션 추가 |

**tennis-counter**

| 파일 | 변경 |
|---|---|
| `Shared/Services/MatchConnectivity.swift` | `sendMetrics`에 `isPaused`, `receivedMetrics` 타입을 메시지로, pause 송수신 표면 추가 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 브로드캐스트 누적 전환·조건 완화, pause 수신 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 기준값 캡처, 앵커 기반 경과시간, pause 왕복 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` | `isPauseAvailable` 배선 |
| `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 델타·가드 검증 테스트 4건 갱신 + pause 수신 테스트 |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 칼로리 회귀 테스트, 앵커 테스트, pause 왕복 테스트 |

---

## Task 1: WorkoutAnchor 순수 함수

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutCore/WorkoutAnchor.swift`
- Test: `~/Workspace/Projects/ralli-kit/Tests/WorkoutCoreTests/WorkoutAnchorTests.swift`

**Interfaces:**
- Consumes: 없음 (순수 함수, 타입 의존 없음)
- Produces: `public enum WorkoutAnchor`
  - `static func interpolatedElapsed(anchorElapsed: TimeInterval, isPaused: Bool, sentAt: TimeInterval?, now: TimeInterval = Date().timeIntervalSince1970) -> TimeInterval`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/WorkoutCoreTests/WorkoutAnchorTests.swift`:

```swift
import Testing
@testable import WorkoutCore

struct WorkoutAnchorTests {
    @Test func addsElapsedSinceSentWhenRunning() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: false, sentAt: 1000, now: 1007
        )
        #expect(result == 107)
    }

    @Test func freezesWhenPaused() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: true, sentAt: 1000, now: 1007
        )
        #expect(result == 100)
    }

    /// 구버전 발신자는 sentAt 스탬프가 없다 — 보간 없이 앵커 값을 그대로 쓴다.
    @Test func returnsAnchorWhenSentAtMissing() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: false, sentAt: nil, now: 1007
        )
        #expect(result == 100)
    }

    /// 두 기기 시계가 어긋나 now < sentAt이면 시간이 거꾸로 가지 않도록 앵커 값을 유지한다.
    @Test func clampsNegativeDrift() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: false, sentAt: 1000, now: 995
        )
        #expect(result == 100)
    }

    @Test func returnsAnchorExactlyAtSentAt() {
        let result = WorkoutAnchor.interpolatedElapsed(
            anchorElapsed: 100, isPaused: false, sentAt: 1000, now: 1000
        )
        #expect(result == 100)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && git checkout -b feat/workout-anchor-pause
xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `cannot find 'WorkoutAnchor' in scope`

- [ ] **Step 3: 구현**

`Sources/WorkoutCore/WorkoutAnchor.swift`:

```swift
import Foundation

/// 폰이 워치의 경과시간을 매초 로컬 보간할 때 쓰는 계산.
///
/// 시간 "값"을 매초 전송하는 대신 기준점(앵커)만 이따금 동기화하고, 수신 이후 흐른 시간을
/// 더한다. 드리프트가 누적되지 않고(앵커 수신마다 리셋), 메시지가 유실돼도 다음 앵커로
/// 자동 복구되며, 폰이 백그라운드에서 돌아와도 재계산만으로 즉시 정확해진다.
public enum WorkoutAnchor {
    /// - Parameters:
    ///   - anchorElapsed: 앵커에 실려온 워치 기준 경과 초.
    ///   - isPaused: 앵커 시점의 일시정지 여부. true면 시간이 흐르지 않는다.
    ///   - sentAt: 앵커 발신 시각(Unix epoch). 스탬프를 안 붙이는 구버전 발신자면 nil.
    ///   - now: 현재 시각(Unix epoch).
    public static func interpolatedElapsed(anchorElapsed: TimeInterval,
                                           isPaused: Bool,
                                           sentAt: TimeInterval?,
                                           now: TimeInterval = Date().timeIntervalSince1970) -> TimeInterval
    {
        guard !isPaused, let sentAt else { return anchorElapsed }
        // 기기 시계가 어긋나 음수가 나오면 앵커 값을 유지한다 — 시간이 거꾸로 가는 것보다 낫다.
        return anchorElapsed + max(0, now - sentAt)
    }
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED

- [ ] **Step 5: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add Sources/WorkoutCore/WorkoutAnchor.swift Tests/WorkoutCoreTests/WorkoutAnchorTests.swift
git commit -m "✨ WorkoutAnchor — 경과시간 앵커 보간 순수 함수"
```

---

## Task 2: WorkoutMetricsMessage에 isPaused·sentAt 추가

**Files:**
- Modify: `~/Workspace/Projects/ralli-kit/Sources/WorkoutCore/Messages/WorkoutMetricsMessage.swift`
- Test: `~/Workspace/Projects/ralli-kit/Tests/WorkoutCoreTests/WorkoutMetricsMessageTests.swift` (기존 파일에 추가)

**Interfaces:**
- Consumes: `WorkoutMetrics`, `WorkoutAnchor` (Task 1)
- Produces: `WorkoutMetricsMessage`의 확장된 표면
  - `init(metrics: WorkoutMetrics, isPaused: Bool = false)`
  - `let isPaused: Bool`
  - `let sentAt: TimeInterval?` — 발신 시 nil, 수신 시 채워짐

> **`sentAt`은 발신자가 채우지 않는다.** `ConnectivityService.send()`가 `MessageEnvelope.stamp`로
> 모든 발신 dict에 `type`/`sentAt`을 찍고, 수신 시 그 dict가 통째로 `init?(from:)`에 전달된다.
> 따라서 `toDictionary()`에는 `sentAt`을 넣지 않고, `init?(from:)`에서만 읽는다.

> **기존 테스트 `wireKeysMatchLegacyFormat`은 키 4개의 값을 개별 검증**할 뿐 키 개수를 세지 않으므로,
> `isPaused` 키가 늘어도 그대로 통과해야 한다. 통과하지 않으면 그 테스트를 잘못 이해한 것이니 확인할 것.

- [ ] **Step 1: 실패하는 테스트 추가**

`Tests/WorkoutCoreTests/WorkoutMetricsMessageTests.swift`의 `struct WorkoutMetricsMessageTests { ... }` 안에 추가:

```swift
    @Test func roundTripsIsPaused() {
        let dict = WorkoutMetricsMessage(
            metrics: WorkoutMetrics(elapsedSeconds: 10), isPaused: true
        ).toDictionary()
        #expect(dict["isPaused"] as? Bool == true)
        #expect(WorkoutMetricsMessage(from: dict)?.isPaused == true)
    }

    @Test func isPausedDefaultsToFalseOnConstruction() {
        #expect(WorkoutMetricsMessage(metrics: WorkoutMetrics()).isPaused == false)
    }

    /// 구버전 워치 페이로드에는 isPaused 키가 없다 — 진행 중으로 본다.
    @Test func legacyPayloadWithoutIsPausedDefaultsToRunning() {
        let dict: [String: Any] = ["elapsed": 600.0, "calories": 120.0]
        #expect(WorkoutMetricsMessage(from: dict)?.isPaused == false)
    }

    /// sentAt은 ConnectivityService가 스탬프한다 — 발신 시엔 nil이고 수신 dict에서만 읽힌다.
    @Test func sentAtIsNilOnConstructionAndReadOnReceive() {
        #expect(WorkoutMetricsMessage(metrics: WorkoutMetrics()).sentAt == nil)
        let dict: [String: Any] = ["elapsed": 5.0, "sentAt": 1_700_000_000.0]
        #expect(WorkoutMetricsMessage(from: dict)?.sentAt == 1_700_000_000)
    }

    @Test func toDictionaryOmitsSentAt() {
        let dict = WorkoutMetricsMessage(metrics: WorkoutMetrics()).toDictionary()
        #expect(dict["sentAt"] == nil)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `WorkoutMetricsMessage`에 `isPaused`/`sentAt` 멤버 없음

- [ ] **Step 3: 구현**

`Sources/WorkoutCore/Messages/WorkoutMetricsMessage.swift` 전체를 다음으로 교체:

```swift
import ConnectivityCore
import Foundation

/// 워치 → 폰 워크아웃 메트릭 브로드캐스트 겸 경과시간 앵커.
/// 와이어 키는 앱에 있던 시절 포맷을 그대로 유지한다 (구버전 앱과 호환).
public struct WorkoutMetricsMessage: ConnectivityMessage {
    public static let messageType = "metrics"

    public let metrics: WorkoutMetrics
    /// 앵커 시점의 일시정지 여부. 구버전 워치는 이 키를 안 보내 false(진행 중)로 떨어진다.
    public let isPaused: Bool
    /// 발신 시각(Unix epoch). ConnectivityService가 스탬프하므로 발신 시엔 nil이고,
    /// 수신 시에만 값이 채워진다. 폰의 경과시간 보간(WorkoutAnchor)에 쓰인다.
    public let sentAt: TimeInterval?

    public init(metrics: WorkoutMetrics, isPaused: Bool = false) {
        self.metrics = metrics
        self.isPaused = isPaused
        sentAt = nil
    }

    public init?(from dictionary: [String: Any]) {
        guard let elapsed = dictionary["elapsed"] as? TimeInterval else { return nil }
        let active = dictionary["calories"] as? Double ?? 0
        // 구버전 워치는 totalCalories를 안 보낸다 — 활동 칼로리로 폴백.
        let total = dictionary["totalCalories"] as? Double ?? active
        metrics = WorkoutMetrics(elapsedSeconds: elapsed,
                                 activeCalories: active,
                                 totalCalories: total,
                                 heartRate: dictionary["heartRate"] as? Double ?? 0)
        isPaused = dictionary["isPaused"] as? Bool ?? false
        sentAt = dictionary["sentAt"] as? Double
    }

    public func toDictionary() -> [String: Any] {
        ["elapsed": metrics.elapsedSeconds,
         "calories": metrics.activeCalories,
         "totalCalories": metrics.totalCalories,
         "heartRate": metrics.heartRate,
         "isPaused": isPaused]
    }
}
```

- [ ] **Step 4: 통과 확인 (기존 테스트 포함 전부)**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED (기존 `wireKeysMatchLegacyFormat`·`roundTripsThroughDictionary` 등 포함)

- [ ] **Step 5: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add Sources/WorkoutCore/Messages/WorkoutMetricsMessage.swift Tests/WorkoutCoreTests/WorkoutMetricsMessageTests.swift
git commit -m "✨ WorkoutMetricsMessage에 isPaused·sentAt 앵커 필드 추가"
```

---

## Task 3: WorkoutPauseMessage 신설

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutCore/Messages/WorkoutPauseMessage.swift`
- Test: `~/Workspace/Projects/ralli-kit/Tests/WorkoutCoreTests/WorkoutPauseMessageTests.swift`

**Interfaces:**
- Consumes: `ConnectivityCore.ConnectivityMessage`
- Produces: `public struct WorkoutPauseMessage: ConnectivityMessage`
  - `static let messageType = "workoutPause"`
  - `init(sessionId: UUID, shouldPause: Bool)`
  - `let sessionId: UUID`, `let shouldPause: Bool`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/WorkoutCoreTests/WorkoutPauseMessageTests.swift`:

```swift
import Foundation
import Testing
@testable import WorkoutCore

struct WorkoutPauseMessageTests {
    @Test func roundTripsThroughDictionary() {
        let id = UUID()
        let dict = WorkoutPauseMessage(sessionId: id, shouldPause: true).toDictionary()
        let restored = WorkoutPauseMessage(from: dict)
        #expect(restored?.sessionId == id)
        #expect(restored?.shouldPause == true)
    }

    @Test func roundTripsResumeCommand() {
        let id = UUID()
        let dict = WorkoutPauseMessage(sessionId: id, shouldPause: false).toDictionary()
        #expect(WorkoutPauseMessage(from: dict)?.shouldPause == false)
    }

    @Test func messageTypeIsWorkoutPause() {
        #expect(WorkoutPauseMessage.messageType == "workoutPause")
    }

    @Test func missingSessionIdFailsInit() {
        #expect(WorkoutPauseMessage(from: ["shouldPause": true]) == nil)
    }

    @Test func missingShouldPauseFailsInit() {
        #expect(WorkoutPauseMessage(from: ["sessionId": UUID().uuidString]) == nil)
    }

    @Test func malformedSessionIdFailsInit() {
        let dict: [String: Any] = ["sessionId": "not-a-uuid", "shouldPause": true]
        #expect(WorkoutPauseMessage(from: dict) == nil)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `cannot find 'WorkoutPauseMessage' in scope`

- [ ] **Step 3: 구현**

`Sources/WorkoutCore/Messages/WorkoutPauseMessage.swift`:

```swift
import ConnectivityCore
import Foundation

/// 폰 → 워치 일시정지/재개 명령.
///
/// 폰에는 실제 워크아웃 세션이 없다 — 워치만 HKWorkoutSession을 소유한다. 따라서 폰의
/// pause 버튼은 상태를 직접 바꾸는 대신 이 명령을 보내고, 워치가 세션을 제어한 결과가
/// 다음 WorkoutMetricsMessage의 isPaused로 되돌아온다(ack).
public struct WorkoutPauseMessage: ConnectivityMessage {
    public static let messageType = "workoutPause"

    public let sessionId: UUID
    /// true면 일시정지, false면 재개.
    public let shouldPause: Bool

    public init(sessionId: UUID, shouldPause: Bool) {
        self.sessionId = sessionId
        self.shouldPause = shouldPause
    }

    public init?(from dictionary: [String: Any]) {
        guard let idString = dictionary["sessionId"] as? String,
              let id = UUID(uuidString: idString),
              let shouldPause = dictionary["shouldPause"] as? Bool else { return nil }
        sessionId = id
        self.shouldPause = shouldPause
    }

    public func toDictionary() -> [String: Any] {
        ["sessionId": sessionId.uuidString, "shouldPause": shouldPause]
    }
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED

- [ ] **Step 5: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add Sources/WorkoutCore/Messages/WorkoutPauseMessage.swift Tests/WorkoutCoreTests/WorkoutPauseMessageTests.swift
git commit -m "✨ WorkoutPauseMessage — 폰→워치 일시정지/재개 명령"
```

---

## Task 4: 칼로리 누적 전환 + 저장 회귀 수정 ⭐

**Files:**
- Modify: `Shared/Services/MatchConnectivity.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` (기존 4건 갱신)
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` (회귀 테스트 추가)

**Interfaces:**
- Consumes: `WorkoutMetricsMessage(metrics:isPaused:)` (Task 2)
- Produces:
  - `MatchConnectivity.sendMetrics(_ metrics: WorkoutMetrics, isPaused: Bool)`
  - iOS `WorkoutSessionViewModel`의 DEBUG 헬퍼 `currentSessionForTest: MatchSession?`, `buildMatchForTest(_:) -> Match`

> **이 태스크가 이 플랜에서 가장 위험하다.** 브로드캐스트를 누적으로 바꾸는 것과 iOS 기준값
> 캡처는 한 몸이다 — 하나만 하면 저장되는 경기 칼로리가 워크아웃 전체 값으로 망가진다.
> 그래서 한 태스크로 묶고, 회귀 테스트를 먼저 쓴다.

> **왜 `broadcastMetrics()`가 `currentMetrics`(파이프라인 값)를 안 쓰는가**: `currentMetrics`는
> `CombineLatest4 → receive(on: .main)`으로 **비동기** 갱신된다. 테스트가
> `setLiveMetricsForTesting` 직후 `broadcastMetrics()`를 동기 호출하면 아직 갱신 전 값을 읽는다.
> 그래서 양쪽이 같은 매핑을 쓰되 브로드캐스트는 **동기 스냅샷**을 읽도록 `snapshot(of:)`로 뽑는다.

- [ ] **Step 1: iOS 회귀 테스트 작성 (실패해야 함)**

먼저 iOS VM에 DEBUG 헬퍼를 추가한다. `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` 맨 아래 `#if DEBUG` 블록 안, `saveFromWatchForTest` 아래에 추가:

```swift
        var currentSessionForTest: MatchSession? {
            _currentSession
        }

        func buildMatchForTest(_ session: MatchSession) -> Match {
            buildMatchFromSession(session)
        }
```

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가:

```swift
    /// 워치가 누적 칼로리를 보내는 체제에서, 폰 드라이버로 진행한 경기의 저장 칼로리는
    /// 워크아웃 전체가 아니라 경기 구간이어야 한다. (kcalAtStart=0 고정이면 전체가 저장된다)
    @Test @MainActor func phoneDriverSavesMatchSegmentCaloriesNotWorkoutTotal() throws {
        let vm = WorkoutSessionViewModel()
        // 경기 시작 전 이미 워크아웃에서 200/260 kcal 태운 상태
        vm.metrics = WorkoutMetrics(elapsedSeconds: 600, activeCalories: 200, totalCalories: 260, heartRate: 120)

        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        // 경기 중 50/60 kcal 추가 소모 → 누적 250/320
        vm.metrics = WorkoutMetrics(elapsedSeconds: 1200, activeCalories: 250, totalCalories: 320, heartRate: 140)
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 3)])

        let session = try #require(vm.currentSessionForTest)
        let match = vm.buildMatchForTest(session)
        #expect(match.caloriesBurned == 50)
        #expect(match.totalCaloriesBurned == 60)
    }

    /// 경기 시작 시점의 누적값이 기준선으로 잡혀야 한다.
    @Test @MainActor func startMatchCapturesCalorieBaseline() throws {
        let vm = WorkoutSessionViewModel()
        vm.metrics = WorkoutMetrics(activeCalories: 200, totalCalories: 260)

        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        let session = try #require(vm.currentSessionForTest)
        #expect(session.kcalAtStart == 200)
        #expect(session.totalKcalAtStart == 260)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|failed|Testing failed"
```

Expected: FAIL — `startMatchCapturesCalorieBaseline`에서 `kcalAtStart == 0`, `phoneDriver...`에서 `caloriesBurned == 250`

- [ ] **Step 3: iOS 기준값 캡처 수정**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 `startMatch` 안 `MatchSession` 생성부를 교체:

```swift
        _currentSession = MatchSession(
            workoutSessionId: self.sessionId,
            options: options,
            startedAt: startedAt ?? Date(),
            kcalAtStart: metrics.activeCalories,
            totalKcalAtStart: metrics.totalCalories
        )
```

> `buildSession(from msg:)` 쪽의 `kcalAtStart: 0`은 **그대로 둔다.** 그 경로는 워치가 보낸
> `MatchEndMessage.calories`(이미 경기 구간 델타)를 종료값으로 쓰므로 기준선이 0이어야 맞다.

- [ ] **Step 4: iOS 테스트 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED

- [ ] **Step 5: 워치 테스트 4건 갱신 (실패해야 함)**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에서 네 개를 교체한다.

`metricsNotBroadcastWhenNotPlaying` → 조건 완화로 의미가 뒤집힌다:

```swift
    /// 경기 중이 아니어도 브로드캐스트한다 — 폰이 모드 선택·결과 화면에서도 수치를 유지하도록.
    @Test @MainActor func metricsBroadcastEvenWhenNotPlaying() {
        let vm = WorkoutSessionViewModel()
        vm.broadcastMetrics()
        #expect(vm.lastMetrics != nil)
    }
```

`metricsCaloriesAreNetOfStart` → 누적으로:

```swift
    /// 칼로리는 경기 구간 델타가 아니라 워크아웃 누적값을 그대로 싣는다.
    /// 경기 구간 값은 저장 시점에 종료값 - 시작값으로 만든다.
    @Test @MainActor func metricsCaloriesAreWorkoutCumulative() {
        let healthKit = WorkoutSessionService(configuration: .tennis)
        healthKit.setLiveMetricsForTesting(calories: 100)
        let vm = WorkoutSessionViewModel(healthKit: healthKit)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        healthKit.setLiveMetricsForTesting(calories: 150)
        vm.broadcastMetrics()
        #expect(vm.lastMetrics?.activeCalories == 150)
    }
```

`metricsTotalCaloriesIncludeBasalNetOfStart` → 누적으로:

```swift
    /// 총 칼로리 = 활동 + 휴식, 역시 누적값.
    @Test @MainActor func metricsTotalCaloriesIncludeBasalCumulative() {
        let healthKit = WorkoutSessionService(configuration: .tennis)
        healthKit.setLiveMetricsForTesting(calories: 100, basalCalories: 20)
        let vm = WorkoutSessionViewModel(healthKit: healthKit)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        healthKit.setLiveMetricsForTesting(calories: 150, basalCalories: 40)
        vm.broadcastMetrics()
        #expect(vm.lastMetrics?.totalCalories == 190)
    }
```

`metricsNotBroadcastAfterMatchFinished` → 역시 뒤집힌다:

```swift
    /// 경기가 끝난 뒤에도 워크아웃이 살아있으면 계속 브로드캐스트한다.
    @Test @MainActor func metricsBroadcastAfterMatchFinished() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 3)])
        vm.broadcastMetrics()
        #expect(vm.lastMetrics != nil)
    }
```

- [ ] **Step 6: 워치 테스트 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|failed|Testing failed"
```

Expected: FAIL — 4건 모두 (아직 델타 계산 + `.playing` 가드가 살아있음)

- [ ] **Step 7: MatchConnectivity의 sendMetrics에 isPaused 추가**

`Shared/Services/MatchConnectivity.swift`의 `sendMetrics`를 교체:

```swift
    func sendMetrics(_ metrics: WorkoutMetrics, isPaused: Bool) {
        service.send(WorkoutMetricsMessage(metrics: metrics, isPaused: isPaused), via: .realtimeOnly)
    }
```

- [ ] **Step 8: 워치 브로드캐스트 누적 전환**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

(a) `init` 안의 `CombineLatest4` 블록을 교체 (매핑을 `snapshot(of:)`으로 일원화):

```swift
        Publishers.CombineLatest4(
            healthKit.$elapsedSeconds,
            healthKit.$currentCalories,
            healthKit.$currentBasalCalories,
            healthKit.$currentHeartRate
        )
        .receive(on: DispatchQueue.main)
        .map { [healthKit] _, _, _, _ in Self.snapshot(of: healthKit) }
        .assign(to: &$currentMetrics)
```

(b) `broadcastMetrics()`를 교체:

```swift
    func broadcastMetrics() {
        let metrics = Self.snapshot(of: healthKit)
        lastMetrics = metrics
        connectivity.sendMetrics(metrics, isPaused: healthKit.isPaused)
    }

    /// healthKit의 현재 값을 즉시 읽는 동기 스냅샷.
    /// currentMetrics 파이프라인(비동기)과 broadcastMetrics(동기)가 같은 매핑을 쓰도록 한 곳에 둔다.
    private static func snapshot(of healthKit: WorkoutSessionService) -> WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
                       activeCalories: healthKit.currentCalories,
                       totalCalories: healthKit.currentCalories + healthKit.currentBasalCalories,
                       heartRate: healthKit.currentHeartRate)
    }
```

(c) `init` 안 심박 스로틀 sink의 phase 가드를 제거:

```swift
        healthKit.$currentHeartRate
            .dropFirst()
            .throttle(for: .seconds(metricsThrottle), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.broadcastMetrics() }
            .store(in: &cancellables)
```

- [ ] **Step 9: 양쪽 타겟 테스트 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: 둘 다 TEST SUCCEEDED

- [ ] **Step 10: 커밋**

```bash
git checkout -b feature/workout-sync-unification 2>/dev/null || true
git add -A
git commit -m "🐛 칼로리 기준을 워크아웃 누적으로 통일 + 경기 구간 저장 회귀 수정"
```

---

## Task 5: 워치 pause 명령 수신 + 브로드캐스트 트리거 확장

**Files:**
- Modify: `Shared/Services/MatchConnectivity.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `WorkoutPauseMessage` (Task 3), `Self.snapshot(of:)` (Task 4)
- Produces:
  - `MatchConnectivity.receivedPauseCommand: WorkoutPauseMessage?` (`@Published`)
  - 워치 `WorkoutSessionViewModel`의 DEBUG 헬퍼 `handleIncomingPauseCommandForTest(_ msg: WorkoutPauseMessage)`

> pause 상태가 바뀌면 스로틀(5초)을 기다리지 않고 **즉시** 앵커를 보내야 폰 UI가 곧바로 반응한다.
> 그래서 `healthKit.$isPaused` 변화에도 브로드캐스트를 건다.

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가:

> **`healthKit.isPaused`를 검증하지 않는 이유**: `WorkoutSessionService.pauseWorkout()`은
> `guard let session = workoutSession else { return }`로 시작한다 — 유닛 테스트에는 실제
> `HKWorkoutSession`이 없어 no-op이고, `isPaused`도 `DispatchQueue.main.async`로 비동기 설정된다.
> 따라서 테스트는 **VM의 라우팅 결정**(세션 가드 통과 여부)만 검증하고, 실제 HK 세션 정지는
> 문서 맨 아래 실기기 회귀 체크리스트가 담당한다.

```swift
    // MARK: - Pause 명령 수신

    /// 자기 세션의 명령이면 적용한다.
    @Test @MainActor func pauseCommandAppliedWhenSessionMatches() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        let applied = vm.handleIncomingPauseCommandForTest(
            WorkoutPauseMessage(sessionId: vm.activeSessionIdForTest, shouldPause: true)
        )

        #expect(applied == true)
    }

    /// 재개 명령도 같은 경로로 적용된다.
    @Test @MainActor func resumeCommandAppliedWhenSessionMatches() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        let applied = vm.handleIncomingPauseCommandForTest(
            WorkoutPauseMessage(sessionId: vm.activeSessionIdForTest, shouldPause: false)
        )

        #expect(applied == true)
    }

    /// 다른 세션의 pause 명령은 무시한다 (죽은 세션·경합 방지).
    @Test @MainActor func pauseCommandIgnoredWhenSessionIdMismatch() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        let applied = vm.handleIncomingPauseCommandForTest(
            WorkoutPauseMessage(sessionId: UUID(), shouldPause: true)
        )

        #expect(applied == false)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `handleIncomingPauseCommandForTest` 없음

- [ ] **Step 3: MatchConnectivity에 pause 송수신 표면 추가**

`Shared/Services/MatchConnectivity.swift`에서:

(a) `@Published` 프로퍼티 목록에 추가 (`receivedMatchReset` 아래):

```swift
    @Published var receivedPauseCommand: WorkoutPauseMessage?
```

(b) `init`의 `onReceive` 등록부에 추가 (`MatchResetMessage` 줄 아래):

```swift
        service.onReceive(WorkoutPauseMessage.self) { [weak self] in self?.receivedPauseCommand = $0 }
```

(c) `// MARK: - Send` 구역에 추가:

```swift
    /// 폰에는 워크아웃 세션이 없다 — 워치에 pause/resume을 명령하고 결과는 앵커로 되돌아온다.
    func sendPauseCommand(sessionId: UUID, shouldPause: Bool) {
        service.send(WorkoutPauseMessage(sessionId: sessionId, shouldPause: shouldPause), via: .reliable)
    }
```

- [ ] **Step 4: 워치 VM에 수신 처리 구현**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

(a) `setupConnectivityBindings()` 안에 추가:

```swift
        connectivity.$receivedPauseCommand
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handleIncomingPauseCommand(msg) }
            .store(in: &cancellables)
```

(b) `handleIncomingWorkoutEnd` 근처에 추가 — 적용 여부를 반환해 테스트가 가드 로직을 검증할 수 있게 한다:

```swift
    /// - Returns: 명령을 적용했으면 true, 다른 세션 것이라 무시했으면 false.
    @discardableResult
    private func handleIncomingPauseCommand(_ msg: WorkoutPauseMessage) -> Bool {
        guard msg.sessionId == activeSessionId else { return false }
        connectivity.receivedPauseCommand = nil
        if msg.shouldPause {
            healthKit.pauseWorkout()
        } else {
            healthKit.resumeWorkout()
        }
        return true
    }
```

(c) `init`에 pause 변화 시 즉시 브로드캐스트 추가 (`healthKit.$isPaused` `assign` 블록 **아래**):

```swift
        healthKit.$isPaused
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.broadcastMetrics() }
            .store(in: &cancellables)
```

(d) `#if DEBUG` 블록에 테스트 헬퍼 추가:

```swift
        func handleIncomingPauseCommandForTest(_ msg: WorkoutPauseMessage) -> Bool {
            handleIncomingPauseCommand(msg)
        }
```

- [ ] **Step 5: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED

- [ ] **Step 6: 커밋**

```bash
git add -A
git commit -m "✨ 워치가 폰의 pause 명령을 수신해 HK 세션을 제어"
```

---

## Task 6: iOS 앵커 기반 경과시간

**Files:**
- Modify: `Shared/Services/MatchConnectivity.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `WorkoutAnchor.interpolatedElapsed(...)` (Task 1), `WorkoutMetricsMessage.isPaused`/`.sentAt` (Task 2)
- Produces: iOS `WorkoutSessionViewModel`의 DEBUG 헬퍼 `applyIncomingMetricsForTest(_ msg: WorkoutMetricsMessage)`, `recomputeElapsedForTest(now:)`

> **`MatchConnectivity.receivedMetrics`의 타입이 바뀐다** — `WorkoutMetrics?` → `WorkoutMetricsMessage?`.
> 폰이 `isPaused`/`sentAt`을 봐야 보간할 수 있기 때문이다. 이 프로퍼티의 유일한 소비자는 iOS VM이다.

> **폰 단독(워치 미연결) 폴백**: 앵커를 한 번도 못 받았으면 기존처럼 `startedAt` 기준
> 로컬 시간을 쓴다. 워치 없이 시작한 워크아웃은 HK 세션이 없어 pause도 불가능하고(Task 7에서
> 버튼 비활성화), 따라서 `totalPausedSeconds`/`pausedAt`은 더 이상 필요 없어 삭제한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가:

```swift
    // MARK: - 경과시간 앵커

    /// 앵커 수신 후에는 워치가 보낸 경과초 + 그 뒤 흐른 시간으로 계산한다.
    @Test @MainActor func elapsedInterpolatesFromWatchAnchor() {
        let vm = WorkoutSessionViewModel()
        let dict: [String: Any] = [
            "elapsed": 100.0, "calories": 10.0, "totalCalories": 12.0,
            "heartRate": 130.0, "isPaused": false, "sentAt": 1000.0,
        ]
        vm.applyIncomingMetricsForTest(WorkoutMetricsMessage(from: dict)!)

        vm.recomputeElapsedForTest(now: 1007)

        #expect(vm.elapsedSeconds == 107)
    }

    /// 일시정지 앵커를 받으면 시간이 멈춘다.
    @Test @MainActor func elapsedFreezesOnPausedAnchor() {
        let vm = WorkoutSessionViewModel()
        let dict: [String: Any] = [
            "elapsed": 100.0, "isPaused": true, "sentAt": 1000.0,
        ]
        vm.applyIncomingMetricsForTest(WorkoutMetricsMessage(from: dict)!)

        vm.recomputeElapsedForTest(now: 1007)

        #expect(vm.elapsedSeconds == 100)
    }

    /// 앵커의 isPaused가 폰 isPaused에 반영된다 (ack 경로).
    @Test @MainActor func anchorIsPausedUpdatesViewModel() {
        let vm = WorkoutSessionViewModel()
        let dict: [String: Any] = ["elapsed": 10.0, "isPaused": true, "sentAt": 1000.0]
        vm.applyIncomingMetricsForTest(WorkoutMetricsMessage(from: dict)!)
        #expect(vm.isPaused == true)
    }

    /// 앵커를 한 번도 못 받은 폰 단독 상태면 로컬 시작 시각 기준으로 센다.
    @Test @MainActor func elapsedFallsBackToLocalClockWithoutAnchor() {
        let vm = WorkoutSessionViewModel()
        vm.startSession(startDate: Date(timeIntervalSince1970: 1000))

        vm.recomputeElapsedForTest(now: 1042)

        #expect(vm.elapsedSeconds == 42)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `applyIncomingMetricsForTest`·`recomputeElapsedForTest` 없음

- [ ] **Step 3: MatchConnectivity.receivedMetrics 타입 변경**

`Shared/Services/MatchConnectivity.swift`에서:

```swift
    @Published var receivedMetrics: WorkoutMetricsMessage?
```

`init`의 등록부:

```swift
        service.onReceive(WorkoutMetricsMessage.self) { [weak self] in self?.receivedMetrics = $0 }
```

- [ ] **Step 4: iOS VM을 앵커 기반으로 전환**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

(a) 저장 프로퍼티 교체 — `pausedAt`·`totalPausedSeconds` 삭제하고 앵커 보관용 추가:

```swift
    private var startedAt: Date?
    private var anchor: WorkoutMetricsMessage?
```

(b) `receivedMetrics` sink 교체:

```swift
        connectivity.$receivedMetrics
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] received in
                guard let self else { return }
                anchor = received
                metrics = received.metrics
                isPaused = received.isPaused
                recomputeElapsed()
            }
            .store(in: &cancellables)
```

(c) `startSession` 교체:

```swift
    func startSession(startDate: Date = Date()) {
        startedAt = startDate
        anchor = nil
        startTimer()
    }
```

(d) `startTimer()` 교체 — 표시 갱신용 1초 틱만 남긴다:

```swift
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recomputeElapsed() }
        }
    }

    /// 워치 앵커가 있으면 그 기준으로 보간하고, 없으면(폰 단독) 로컬 시작 시각으로 센다.
    private func recomputeElapsed(now: TimeInterval = Date().timeIntervalSince1970) {
        let seconds: TimeInterval
        if let anchor {
            seconds = WorkoutAnchor.interpolatedElapsed(
                anchorElapsed: anchor.metrics.elapsedSeconds,
                isPaused: anchor.isPaused,
                sentAt: anchor.sentAt,
                now: now
            )
        } else if let startedAt {
            seconds = now - startedAt.timeIntervalSince1970
        } else {
            seconds = 0
        }
        elapsedSeconds = Int(seconds)
        metrics = WorkoutMetrics(elapsedSeconds: seconds,
                                 activeCalories: metrics.activeCalories,
                                 totalCalories: metrics.totalCalories,
                                 heartRate: metrics.heartRate)
    }
```

(e) `endSession`에서 삭제된 프로퍼티 정리부를 교체 (`totalPausedSeconds = 0`·`pausedAt = nil` 두 줄을 삭제하고 그 자리에):

```swift
        anchor = nil
```

(f) `#if DEBUG` 블록에 테스트 헬퍼 추가:

```swift
        func applyIncomingMetricsForTest(_ msg: WorkoutMetricsMessage) {
            anchor = msg
            metrics = msg.metrics
            isPaused = msg.isPaused
            recomputeElapsed()
        }

        func recomputeElapsedForTest(now: TimeInterval) {
            recomputeElapsed(now: now)
        }
```

> `pauseSession()`/`resumeSession()`은 이 태스크에서 아직 손대지 않는다 — Task 7에서 교체한다.
> 다만 `totalPausedSeconds`/`pausedAt`을 삭제했으므로 **컴파일이 깨진다.** 임시로 두 메서드의
> 본문에서 삭제된 프로퍼티 참조만 걷어낸다:
>
> ```swift
>     func pauseSession() {
>         isPaused = true
>         timer?.invalidate()
>         timer = nil
>     }
>
>     func resumeSession() {
>         isPaused = false
>         startTimer()
>     }
> ```

- [ ] **Step 5: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED

- [ ] **Step 6: 커밋**

```bash
git add -A
git commit -m "♻️ iOS 경과시간을 워치 앵커 기반 보간으로 전환"
```

---

## Task 7: iOS pause 왕복 + isPauseAvailable 배선

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `MatchConnectivity.sendPauseCommand(sessionId:shouldPause:)` (Task 5), `applyIncomingMetricsForTest` (Task 6)
- Produces: `WorkoutSessionViewModel.requestPause()`, `requestResume()`

> **핵심 계약: 낙관적 토글 금지.** `requestPause()`는 명령만 보내고 `isPaused`를 건드리지 않는다.
> pause 메시지를 모르는 구버전 워치라면 아무 앵커도 안 바뀌고 폰 UI도 그대로다 — 오동작 대신 무동작.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가:

```swift
    // MARK: - Pause 왕복

    /// 폰은 pause를 낙관적으로 토글하지 않는다 — 워치 ack(앵커)가 와야 바뀐다.
    @Test @MainActor func requestPauseDoesNotToggleLocallyBeforeAck() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()

        vm.requestPause()

        #expect(vm.isPaused == false)
    }

    /// 워치 ack가 도착하면 그때 isPaused가 바뀐다.
    @Test @MainActor func pauseAppliesWhenWatchAckArrives() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.requestPause()

        let dict: [String: Any] = ["elapsed": 50.0, "isPaused": true, "sentAt": 1000.0]
        vm.applyIncomingMetricsForTest(WorkoutMetricsMessage(from: dict)!)

        #expect(vm.isPaused == true)
    }

    /// 재개도 같은 경로 — 명령만 보내고 ack로 풀린다.
    @Test @MainActor func resumeAppliesWhenWatchAckArrives() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        let paused: [String: Any] = ["elapsed": 50.0, "isPaused": true, "sentAt": 1000.0]
        vm.applyIncomingMetricsForTest(WorkoutMetricsMessage(from: paused)!)

        vm.requestResume()
        #expect(vm.isPaused == true) // 아직 ack 전

        let running: [String: Any] = ["elapsed": 50.0, "isPaused": false, "sentAt": 1010.0]
        vm.applyIncomingMetricsForTest(WorkoutMetricsMessage(from: running)!)
        #expect(vm.isPaused == false)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `requestPause`/`requestResume` 없음

- [ ] **Step 3: VM에 요청 메서드 구현**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서 `pauseSession()`/`resumeSession()` 두 메서드를 다음으로 교체:

```swift
    /// 폰에는 워크아웃 세션이 없다 — 워치에 명령만 보낸다.
    /// isPaused는 워치가 보낸 앵커(ack)로만 바뀐다. 명령을 모르는 구버전 워치면 아무 일도 안 일어난다.
    func requestPause() {
        connectivity.sendPauseCommand(sessionId: sessionId, shouldPause: true)
    }

    func requestResume() {
        connectivity.sendPauseCommand(sessionId: sessionId, shouldPause: false)
    }
```

- [ ] **Step 4: View 배선 교체**

`iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`의 `WorkoutDashboardView(...)` 호출을 교체:

```swift
            WorkoutDashboardView(
                metrics: viewModel.metrics,
                isPaused: viewModel.isPaused,
                isPauseAvailable: viewModel.watchConnected,
                onPauseResume: {
                    viewModel.isPaused ? viewModel.requestResume() : viewModel.requestPause()
                },
                onEnd: { showEndWorkoutConfirm = true }
            )
```

- [ ] **Step 5: 남은 참조 확인**

```bash
grep -rn "pauseSession\|resumeSession\|totalPausedSeconds\|pausedAt" --include="*.swift" iOSApp/ iosTests/ | grep -v .worktrees
```

Expected: 결과 없음

- [ ] **Step 6: 통과 확인 + Release 빌드 + 린트**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
xcodebuild build -project TennisCounter.xcodeproj -scheme "TennisCounter" -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
xcodebuild build -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -configuration Release -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
make fix && make lint
```

Expected: 테스트 2건 TEST SUCCEEDED, Release 빌드 2건 BUILD SUCCEEDED, 린트는 기존 `type_body_length` 경고 외 신규 위반 없음

- [ ] **Step 7: 커밋**

```bash
git add -A
git commit -m "✨ 폰 pause를 워치 왕복 명령으로 전환 + 미연결 시 버튼 비활성화"
```

---

## Task 8: ralli-kit README에 WorkoutUI 소비자 가이드

**Files:**
- Modify: `~/Workspace/Projects/ralli-kit/README.md`

**Interfaces:**
- Consumes: Task 1~3의 공개 API 전부
- Produces: 골프·헬스 앱 세션이 참조할 소비자 문서

> 골프·헬스 앱은 ralli-kit을 의존성으로 갖지만 테니스 레포는 체크아웃하지 않는다.
> 소비자가 알아야 할 계약은 전부 이 README에 있어야 한다.

- [ ] **Step 1: README에 섹션 추가**

`README.md`의 `## ConnectivityCore 사용법` 섹션 **앞에** 다음을 삽입:

````markdown
## WorkoutUI 사용법

세 앱(테니스·골프·헬스)이 공유하는 워크아웃 화면. 표시 항목은 **경과시간·활동 kcal·총 kcal·BPM 4개 고정**이다.

```swift
import WorkoutUI

// Watch — 메트릭 탭
WorkoutMetricsView(metrics: viewModel.currentMetrics, isPaused: viewModel.isPaused)

// Watch — 컨트롤 탭
WorkoutControlsView(isPaused: viewModel.isPaused,
                    onPauseResume: { ... },
                    onEnd: { ... })

// iOS — 대시보드 (링 + 지표 3칸 + 컨트롤)
WorkoutDashboardView(metrics: viewModel.metrics,
                     isPaused: viewModel.isPaused,
                     isPauseAvailable: viewModel.watchConnected,
                     onPauseResume: { ... },
                     onEnd: { ... })
```

화면은 값과 콜백만 받는다 — 서비스나 ViewModel을 모른다. 라벨·색은 패키지가 소유하므로 앱이 문자열을 관리하지 않는다.

### 소비자 책임 (패키지가 대신 못 해주는 것)

- [ ] **칼로리는 워크아웃 누적값으로 넘긴다.** 경기/라운드 구간 값이 필요하면 저장 시점에 `종료값 - 시작값`으로 계산한다. 화면에 구간 델타를 넘기면 세 앱의 숫자 의미가 갈린다.
- [ ] **경과시간은 워치가 단일 소스.** 폰은 `WorkoutAnchor.interpolatedElapsed(anchorElapsed:isPaused:sentAt:now:)`로 매초 보간한다. 폰이 자체 타이머로 시간을 세면 pause 한 번에 두 기기가 어긋난다.
- [ ] **pause는 폰→워치 명령이다.** 폰은 `WorkoutPauseMessage(sessionId:shouldPause:)`를 `.reliable`로 보내고, `isPaused`는 워치가 보낸 앵커로만 갱신한다 — **낙관적 토글 금지**. 명령을 모르는 구버전 워치에서 오동작 대신 무동작이 되도록 하는 장치다.
- [ ] **워치 미연결 시 `isPauseAvailable: false`.** 폰에는 HKWorkoutSession이 없어 누를 대상이 없다.
- [ ] `WorkoutMetricsMessage`의 `sentAt`은 `ConnectivityService`가 스탬프한다 — 발신 시 채우지 말 것.

### 와이어 포맷 (구버전 호환)

`WorkoutMetricsMessage`의 키는 `elapsed`/`calories`/`totalCalories`/`heartRate`/`isPaused`.
앞 넷은 초기 버전부터의 계약이라 이름을 바꾸지 않는다. 구버전이 `totalCalories`를 안 보내면
`calories`로, `isPaused`를 안 보내면 `false`로 폴백한다.
````

- [ ] **Step 2: 렌더링 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && grep -n "^## " README.md
```

Expected: `## WorkoutUI 사용법`이 `## WorkoutCore 사용법`과 `## ConnectivityCore 사용법` 사이에 위치

- [ ] **Step 3: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add README.md
git commit -m "📝 README에 WorkoutUI 소비자 가이드 추가"
```

---

## 완료 후 확인

- [ ] ralli-kit `feat/workout-anchor-pause`에 4개 커밋 (Task 1·2·3·8)
- [ ] tennis-counter `feature/workout-sync-unification`에 4개 커밋 (Task 4·5·6·7)
- [ ] 두 앱 타겟 Debug 테스트 + Release 빌드 통과
- [ ] **실기기 2대 회귀** (시뮬레이터로 재현 불가):
  - [ ] 폰에서 pause → 워치 타이머·심박 수집이 실제로 멈춤 → 폰 UI도 정지 표시
  - [ ] 폰에서 resume → 양쪽 재개, 경과시간이 서로 어긋나지 않음
  - [ ] 워치에서 pause → 폰 UI가 5초 안에 정지 표시
  - [ ] 폰을 잠갔다 켜도 경과시간이 워치와 일치 (앵커 재계산)
  - [ ] 경기 종료 후 모드 선택 화면에서도 폰 수치가 계속 갱신됨
  - [ ] 경기 저장 후 히스토리의 칼로리가 **경기 구간** 값 (워크아웃 전체가 아님)
  - [ ] 워치 미연결 상태에서 폰 pause 버튼이 비활성화
- [ ] **구버전 호환**: 구버전 워치 ↔ 신버전 폰에서 메트릭 표시 정상, pause 버튼 눌러도 오동작 없음
