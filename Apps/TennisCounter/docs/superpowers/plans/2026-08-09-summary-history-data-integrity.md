# Summary·History 데이터 무결성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워크아웃 하나에서 경기를 여러 판 해도 모든 경기가 보존되고, Summary·History에 표시되는 시간·칼로리가 워크아웃 실제 값과 일치하게 만든다.

**Architecture:** 중복 제거 키를 워크아웃 단위(`workoutSessionId`)에서 경기 단위(`matchId`)로 내린다. `matchId`는 기존 `MatchSession.id`를 재사용하고 `SessionStartMessage`로 폰·워치가 공유한다 — `sessionId` 채택 로직과 같은 패턴이다. 지표는 레코드마다 "경기 구간"과 "워크아웃 누적"을 나란히 저장하고, 경기 상세는 구간값을, Summary는 누적값을 워크아웃별 최댓값으로 접어 합산한다.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData + CloudKit / WatchConnectivity / Swift Testing / RalliKit(SPM 로컬 참조)

**Spec:** [docs/superpowers/specs/2026-08-09-summary-history-data-integrity-design.md](../specs/2026-08-09-summary-history-data-integrity-design.md)

## Global Constraints

- **RalliKit(`../ralli-kit`)은 수정하지 않는다.** 모든 변경은 이 레포 안에서 끝난다.
- **SwiftData + CloudKit 요구사항: 새로 추가하는 모든 `@Model` 속성은 optional이거나 기본값을 가져야 한다.** 이 계획의 새 필드는 전부 optional이다.
- 테스트 프레임워크는 **Swift Testing** (`@Test`, `#expect`, `Issue.record`). XCTest 금지.
- ViewModel 테스트는 **`@MainActor` 필수**.
- 테스트명은 `대상_행위_예상결과` 의미를 담되 Swift 메서드명 형식(lowerCamelCase)을 따른다. 기존 파일들의 관례와 맞춘다.
- SwiftLint: line length 경고 150 / 오류 200. SwiftFormat: 4-space indent, max width 150, **imports 알파벳순**.
- 한 파일 = 한 타입. 파일 생성·삭제는 파일시스템 조작만으로 충분하다 (`PBXFileSystemSynchronizedRootGroup`).
- 각 태스크는 **실패하는 테스트 → 실패 확인 → 최소 구현 → 통과 확인 → 커밋** 순서로 진행한다.
- 커밋 메시지는 이 레포 관례대로 이모지 프리픽스를 쓴다 (`🐛` 버그 수정, `✨` 기능, `♻️` 리팩터링, `✅` 테스트).

**빌드·테스트 명령**

```bash
# iOS 테스트 전체
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Watch 테스트 전체
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'

# 린트·포맷 자동 수정
make fix
```

단일 테스트는 `-only-testing:iosTests/<SuiteName>/<testName>` (Watch는 `watchosTests/...`)를 덧붙인다.

**태스크 순서가 중요하다.** Task 4에서 중복 제거 키를 교체하기 전에 Task 2·3이 `matchId`를 채워 놓아야 한다. 순서를 바꾸면 중간 상태에서 중복 제거가 완전히 꺼진다.

---

### Task 1: 메시지에 `matchId`·누적 지표 필드 추가

폰·워치가 경기 식별자와 워크아웃 누적 지표를 주고받을 수 있게 와이어 포맷을 넓힌다. 동작 변화는 없다 — 아무도 아직 새 필드를 읽지 않는다.

**Files:**
- Modify: `Shared/Services/ConnectivityMessages.swift` (`SessionStartMessage` 6-46행, `MatchEndMessage` 111-190행)
- Test: `iosTests/Shared/ConnectivityMessagesTests.swift`, `iosTests/Shared/MatchEndMessageTests.swift`

**Interfaces:**
- Produces:
  - `SessionStartMessage.matchId: UUID?` — `init(sessionId:matchId:options:workoutStartDate:)`, `matchId`는 기본값 `nil`
  - `MatchEndMessage.matchId: UUID?`, `.workoutElapsedSeconds: Int?`, `.workoutCalories: Double?`, `.workoutTotalCalories: Double?` — 넷 다 `init` 끝에 기본값 `nil`로 추가
  - 딕셔너리 키: `"matchId"`(uuidString), `"workoutElapsedSeconds"`(Int), `"workoutCalories"`(Double), `"workoutTotalCalories"`(Double). 값이 nil이면 키 자체를 넣지 않는다.

- [ ] **Step 1: 실패하는 테스트 작성 — `SessionStartMessage`**

`iosTests/Shared/ConnectivityMessagesTests.swift`의 `struct ConnectivityMessagesTests { ... }` 안에 추가한다.

```swift
    @Test func sessionStartMessageRoundTripsMatchId() {
        let matchId = UUID()
        let original = SessionStartMessage(
            sessionId: UUID(),
            matchId: matchId,
            options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
            workoutStartDate: Date(timeIntervalSince1970: 1_000_000)
        )
        guard let decoded = SessionStartMessage(from: original.toDictionary()) else {
            Issue.record("SessionStartMessage 파싱 실패")
            return
        }
        #expect(decoded.matchId == matchId)
        #expect(decoded.sessionId == original.sessionId)
    }

    /// 구버전 워치는 matchId 키를 보내지 않는다. 이때 파싱이 실패하면 세션 미러링이
    /// 통째로 깨지므로, nil로 읽히되 메시지 자체는 살아 있어야 한다.
    @Test func sessionStartMessageFromLegacyPayloadHasNilMatchId() {
        let legacy: [String: Any] = [
            "type": "sessionStart",
            "sessionId": UUID().uuidString,
            "mode": "oneSet",
            "noAdRule": true,
            "noTieRule": false,
            "gameThreshold": 6,
            "workoutStartDate": 1_000_000.0,
        ]
        guard let decoded = SessionStartMessage(from: legacy) else {
            Issue.record("구버전 페이로드가 거부됨 — 세션 미러링이 깨진다")
            return
        }
        #expect(decoded.matchId == nil)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/ConnectivityMessagesTests
```

Expected: 컴파일 실패 — `extra argument 'matchId' in call`, `value of type 'SessionStartMessage' has no member 'matchId'`

- [ ] **Step 3: `SessionStartMessage`에 `matchId` 추가**

`Shared/Services/ConnectivityMessages.swift`의 `SessionStartMessage`를 통째로 아래로 교체한다.

```swift
struct SessionStartMessage: ConnectivityMessage {
    static let messageType = "sessionStart"

    let sessionId: UUID
    /// 이 워크아웃 안에서 진행 중인 경기의 식별자. 구버전 워치 페이로드에는 없으므로 optional.
    /// nil이면 수신 측이 로컬에서 새로 발급한다 — 파싱을 실패시키면 미러링 자체가 깨진다.
    let matchId: UUID?
    let options: MatchOptions
    let workoutStartDate: Date

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": Self.messageType,
            "sessionId": sessionId.uuidString,
            "mode": options.mode.rawValue,
            "noAdRule": options.noAdRule,
            "noTieRule": options.noTieRule,
            "gameThreshold": options.gameThreshold,
            "workoutStartDate": workoutStartDate.timeIntervalSince1970,
        ]
        if let matchId { dict["matchId"] = matchId.uuidString }
        return dict
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == Self.messageType,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let modeRaw = dict["mode"] as? String,
              let mode = MatchFormat(rawValue: modeRaw) else { return nil }
        sessionId = id
        matchId = (dict["matchId"] as? String).flatMap(UUID.init(uuidString:))
        options = MatchOptions(
            mode: mode,
            noAdRule: dict["noAdRule"] as? Bool ?? true,
            noTieRule: dict["noTieRule"] as? Bool ?? false,
            gameThreshold: dict["gameThreshold"] as? Int ?? 6
        )
        let ts = dict["workoutStartDate"] as? Double ?? Date().timeIntervalSince1970
        workoutStartDate = Date(timeIntervalSince1970: ts)
    }

    init(sessionId: UUID, matchId: UUID? = nil, options: MatchOptions, workoutStartDate: Date = Date()) {
        self.sessionId = sessionId
        self.matchId = matchId
        self.options = options
        self.workoutStartDate = workoutStartDate
    }
}
```

`matchId`에 기본값 `nil`이 있으므로 기존 호출부(`SessionStartMessage(sessionId:options:workoutStartDate:)`)는 그대로 컴파일된다.

- [ ] **Step 4: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/ConnectivityMessagesTests
```

Expected: PASS

- [ ] **Step 5: 실패하는 테스트 작성 — `MatchEndMessage`**

`iosTests/Shared/MatchEndMessageTests.swift`의 `struct MatchEndMessageTests { ... }` 안에 추가한다.

```swift
    @Test func saveDictionaryRoundTripsMatchIdAndWorkoutMetrics() {
        let matchId = UUID()
        let original = MatchEndMessage(
            sessionId: UUID(),
            result: "win",
            completedSets: [[6, 4]],
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            endedAt: Date(timeIntervalSince1970: 1_000_900),
            durationSeconds: 900,
            calories: 250,
            averageHeartRate: 140,
            mode: "oneSet",
            noAdRule: true,
            totalCalories: 310,
            matchId: matchId,
            workoutElapsedSeconds: 2400,
            workoutCalories: 600,
            workoutTotalCalories: 780
        )
        guard let decoded = MatchEndMessage(from: original.toSaveDictionary()) else {
            Issue.record("save 페이로드가 MatchEndMessage로 파싱되지 않음")
            return
        }
        #expect(decoded.matchId == matchId)
        #expect(decoded.workoutElapsedSeconds == 2400)
        #expect(decoded.workoutCalories == 600)
        #expect(decoded.workoutTotalCalories == 780)
        #expect(decoded.durationSeconds == 900)
    }

    /// 구버전 워치 페이로드에는 새 키가 없다. 파싱은 성공하고 새 필드만 nil이어야 한다.
    @Test func fromLegacyPayloadHasNilMatchIdAndWorkoutMetrics() {
        let legacy: [String: Any] = [
            "type": "matchSave",
            "sessionId": UUID().uuidString,
            "result": "win",
            "sets": [[6, 4]],
            "startedAt": 1_000_000.0,
            "endedAt": 1_000_900.0,
            "durationSeconds": 900,
            "calories": 250.0,
            "mode": "oneSet",
            "noAdRule": true,
        ]
        guard let decoded = MatchEndMessage(from: legacy) else {
            Issue.record("구버전 페이로드가 거부됨")
            return
        }
        #expect(decoded.matchId == nil)
        #expect(decoded.workoutElapsedSeconds == nil)
        #expect(decoded.workoutCalories == nil)
        #expect(decoded.workoutTotalCalories == nil)
    }
```

- [ ] **Step 6: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/MatchEndMessageTests
```

Expected: 컴파일 실패 — `extra argument 'matchId' in call`

- [ ] **Step 7: `MatchEndMessage`에 필드 4개 추가**

`Shared/Services/ConnectivityMessages.swift`의 `MatchEndMessage`에서 아래 네 곳을 수정한다.

**(a) 프로퍼티 선언** — `let noAdRule: Bool` 바로 아래에 추가:

```swift
    /// 이 경기의 식별자. 저장 시 중복 제거 키로 쓴다. 구버전 페이로드에는 없으므로 optional.
    let matchId: UUID?
    /// 워크아웃 시작부터 이 경기 종료 시점까지의 누적값. Summary가 워크아웃별 최댓값으로 접어 합산한다.
    let workoutElapsedSeconds: Int?
    let workoutCalories: Double?
    let workoutTotalCalories: Double?
```

**(b) `dictionary(type:)`** — `if let hr = averageHeartRate { dict["heartRate"] = hr }` 아래에 추가:

```swift
        if let matchId { dict["matchId"] = matchId.uuidString }
        if let workoutElapsedSeconds { dict["workoutElapsedSeconds"] = workoutElapsedSeconds }
        if let workoutCalories { dict["workoutCalories"] = workoutCalories }
        if let workoutTotalCalories { dict["workoutTotalCalories"] = workoutTotalCalories }
```

**(c) `init?(from:)`** — `noAdRule = dict["noAdRule"] as? Bool ?? true` 아래에 추가:

```swift
        matchId = (dict["matchId"] as? String).flatMap(UUID.init(uuidString:))
        workoutElapsedSeconds = dict["workoutElapsedSeconds"] as? Int
        workoutCalories = dict["workoutCalories"] as? Double
        workoutTotalCalories = dict["workoutTotalCalories"] as? Double
```

**(d) 메모버와이즈 `init`** — 시그니처 끝(`totalCalories: Double? = nil` 뒤)에 파라미터를 추가하고 본문에서 대입한다:

```swift
    init(sessionId: UUID, result: String, completedSets: [[Int]], startedAt: Date,
         endedAt: Date, durationSeconds: Int, calories: Double, averageHeartRate: Double?,
         mode: String, noAdRule: Bool, totalCalories: Double? = nil,
         matchId: UUID? = nil, workoutElapsedSeconds: Int? = nil,
         workoutCalories: Double? = nil, workoutTotalCalories: Double? = nil)
    {
        // ... 기존 대입 그대로 ...
        self.matchId = matchId
        self.workoutElapsedSeconds = workoutElapsedSeconds
        self.workoutCalories = workoutCalories
        self.workoutTotalCalories = workoutTotalCalories
    }
```

기존 대입문(`self.sessionId = sessionId` … `self.totalCalories = totalCalories`)은 건드리지 않는다.

- [ ] **Step 8: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/MatchEndMessageTests -only-testing:iosTests/ConnectivityMessagesTests
```

Expected: PASS (기존 테스트 포함 전부)

- [ ] **Step 9: 린트 후 커밋**

```bash
make fix
git add Shared/Services/ConnectivityMessages.swift iosTests/Shared/ConnectivityMessagesTests.swift iosTests/Shared/MatchEndMessageTests.swift
git commit -m "✨ 메시지에 matchId·워크아웃 누적 지표 필드 추가"
```

---

### Task 2: Watch — 워크아웃 id 유지 + `matchId` 발급·전파

워치가 로컬로 새 경기를 시작할 때 `activeSessionId`를 버리고 자기 `workoutSessionId`로 되돌아가는 문제(스펙 1-4)를 고치고, 경기마다 `matchId`를 발급해 메시지에 싣는다.

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (선언부 13-24행, `startMatch` 187-216행, `handleIncomingSessionStart` 310-317행, `makeMatchEndMessage` 342-356행, `init`)
- Test: `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `SessionStartMessage(sessionId:matchId:options:workoutStartDate:)`, `MatchEndMessage(... matchId:)` (Task 1)
- Produces:
  - `startMatch(options:sessionId:matchId:isRemote:)` — `matchId` 기본값 `nil`(= 새로 발급)
  - `currentSession()?.id`가 현재 경기의 `matchId`다 (`MatchSession.id` 재사용, 새 필드 없음)
  - 불변식: 워크아웃이 끝날 때까지 `activeSessionId`는 바뀌지 않는다

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`의 `struct WorkoutSessionViewModelTests { ... }` 안에 추가한다.

```swift
    /// 스펙 1-4 재현: 폰이 driver로 1경기를 진행한 뒤 워치에서 2경기를 시작하면,
    /// 워치가 폰에서 채택한 워크아웃 id를 버리고 자기 것으로 되돌아갔다.
    /// 이 id는 Summary의 워크아웃 그룹핑 키라 갈리면 누적 지표가 과대 집계된다.
    @Test @MainActor func startMatchAfterRemoteDrivenMatchKeepsActiveSessionId() {
        let vm = WorkoutSessionViewModel()
        let phoneSessionId = UUID()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

        vm.startMatch(options: options, sessionId: phoneSessionId, isRemote: true)
        #expect(vm.activeSessionIdForTest == phoneSessionId)

        vm.startNewMatch(notifyRemote: false)
        vm.startMatch(options: options)

        #expect(vm.activeSessionIdForTest == phoneSessionId)
    }

    @Test @MainActor func startNewMatchIssuesNewMatchId() {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

        vm.startMatch(options: options)
        let first = vm.currentSession()?.id

        vm.startNewMatch(notifyRemote: false)
        vm.startMatch(options: options)
        let second = vm.currentSession()?.id

        #expect(first != nil)
        #expect(second != nil)
        #expect(first != second)
    }

    @Test @MainActor func restartMatchIssuesNewMatchIdButKeepsSessionId() {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

        vm.startMatch(options: options)
        let firstMatchId = vm.currentSession()?.id
        let sessionId = vm.activeSessionIdForTest
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])

        vm.restartMatch()

        #expect(vm.currentSession()?.id != firstMatchId)
        #expect(vm.activeSessionIdForTest == sessionId)
    }

    @Test @MainActor func startMatchAdoptsRemoteMatchId() {
        let vm = WorkoutSessionViewModel()
        let remoteMatchId = UUID()

        vm.startMatch(
            options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false),
            sessionId: UUID(),
            matchId: remoteMatchId,
            isRemote: true
        )

        #expect(vm.currentSession()?.id == remoteMatchId)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1' -only-testing:watchosTests/WorkoutSessionViewModelTests
```

Expected: 컴파일 실패 — `extra argument 'matchId' in call`. `matchId` 인자를 뺀 나머지 세 테스트도 `startMatchAfterRemoteDrivenMatchKeepsActiveSessionId`는 FAIL해야 한다.

- [ ] **Step 3: `activeSessionId` 초기값을 `workoutSessionId`에 맞춘다**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` 24행을 교체한다.

```swift
    /// 워크아웃 식별자. 상대 기기의 id를 채택하면 그 값으로 바뀌고, 워크아웃이 끝날 때까지 유지된다.
    /// 초기값은 workoutSessionId — 채택 전에도 313행의 동시 시작 race 가드가 같은 값을 비교해야 한다.
    private(set) lazy var activeSessionId: UUID = workoutSessionId
```

**`lazy`가 필요한 이유:** 클래스 init의 1단계에서는 모든 저장 프로퍼티가 초기화되기 전까지 `self`의 다른 프로퍼티를 읽을 수 없다. `private(set) var activeSessionId: UUID`로 선언하고 init 본문에서 `activeSessionId = workoutSessionId`를 쓰면 *"'self' used in property access 'workoutSessionId' before all stored properties are initialized"* 컴파일 오류가 난다. `lazy`는 첫 접근 시점까지 평가를 미뤄 이 문제를 피한다. 이 VM은 `@MainActor`라 `lazy`의 동시성 문제도 없다.

`init(healthKit:metricsThrottle:ackTimeoutSeconds:)`는 수정하지 않는다.

- [ ] **Step 4: `startMatch`에서 id 유지 + `matchId` 발급**

187-216행 `startMatch`를 아래로 교체한다.

```swift
    func startMatch(options: MatchOptions, sessionId: UUID? = nil, matchId: UUID? = nil, isRemote: Bool = false) {
        isDriver = !isRemote
        hasSyncedSession = true
        saveAckState = .idle
        saveAttemptToken += 1
        // 워크아웃 도중에는 id가 바뀌면 안 된다 — Summary가 이 값으로 워크아웃을 그룹핑한다.
        // workoutSessionId로 되돌아가면 폰이 driver였던 워크아웃이 두 그룹으로 갈린다.
        let id = sessionId ?? activeSessionId
        activeSessionId = id
        let mid = matchId ?? UUID()
        let session = MatchSession(
            id: mid,
            workoutSessionId: id,
            options: options,
            kcalAtStart: healthKit.currentCalories,
            totalKcalAtStart: healthKit.currentCalories + healthKit.currentBasalCalories
        )
        _currentSession = session

        if !isRemote {
            connectivity.receivedScoreState = nil
        }

        scoreVM.resetAll(options: options)
        phase = .playing(options)

        if !isRemote {
            connectivity.sendSessionStart(SessionStartMessage(
                sessionId: id,
                matchId: mid,
                options: options,
                workoutStartDate: healthKit.startDate ?? Date()
            ))
        }
    }
```

- [ ] **Step 5: mirror가 `matchId`를 채택하게 한다**

310-317행 `handleIncomingSessionStart`의 마지막 줄을 교체한다.

```swift
        startMatch(options: msg.options, sessionId: msg.sessionId, matchId: msg.matchId, isRemote: true)
```

`msg.matchId`가 nil(구버전 폰)이면 `startMatch`가 로컬에서 새로 발급한다.

- [ ] **Step 6: `makeMatchEndMessage`에 `matchId`를 싣는다**

342-356행 `makeMatchEndMessage`의 `totalCalories:` 인자 뒤에 추가한다.

```swift
            totalCalories: session.totalKcalAtEnd.map { $0 - session.totalKcalAtStart },
            matchId: session.id
        )
```

- [ ] **Step 7: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1' -only-testing:watchosTests/WorkoutSessionViewModelTests
```

Expected: PASS (기존 테스트 포함 전부)

- [ ] **Step 8: 린트 후 커밋**

```bash
make fix
git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "🐛 Watch 워크아웃 id 유지 + 경기별 matchId 발급"
```

---

### Task 3: iOS — `matchId` 발급·채택 + 경기 시작 시각 수정

폰이 driver일 때 경기 시작 시각 자리에 워크아웃 시작 시각을 넣던 문제(스펙 1-3)를 고치고, 워치와 같은 방식으로 `matchId`를 발급·채택한다.

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (재동기화 sink 42-50행, `startMatch` 167-196행, `handleIncomingSessionStart` 269-277행)
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `SessionStartMessage(sessionId:matchId:options:workoutStartDate:)` (Task 1)
- Produces:
  - `startMatch(options:sessionId:matchId:isRemote:)` — `matchId` 기본값 `nil`
  - `currentSessionForTest?.id`가 현재 경기의 `matchId` (기존 DEBUG 훅 재사용)
  - `MatchSession.startedAt`이 **경기** 시작 시각이 된다 (워크아웃 시작 시각 아님)

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`의 `struct WorkoutSessionViewModelTests { ... }` 안에 추가한다.

```swift
    /// 스펙 1-3 재현: 폰의 startedAt 프로퍼티는 워크아웃 시작 시각인데 이를 그대로
    /// MatchSession.startedAt에 넣고 있었다. 워치 경로는 경기 시작 시각을 넣어 서로 어긋났다.
    /// startedAt은 History 정렬·캘린더 날짜·Summary 기간 필터에 모두 쓰인다.
    @Test @MainActor func startMatchUsesMatchStartTimeNotWorkoutStartTime() {
        let vm = WorkoutSessionViewModel()
        let workoutStart = Date(timeIntervalSince1970: 1_000_000)
        vm.startSession(startDate: workoutStart)

        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        guard let session = vm.currentSessionForTest else {
            Issue.record("currentSession이 없음")
            return
        }
        #expect(session.startedAt != workoutStart)
        #expect(session.startedAt.timeIntervalSinceNow > -5)
    }

    @Test @MainActor func startNewMatchKeepsSessionIdAndIssuesNewMatchId() {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

        vm.startMatch(options: options)
        let firstMatchId = vm.currentSessionForTest?.id
        let sessionId = vm.currentSessionIdForTest

        vm.startNewMatch(notifyRemote: false)
        vm.startMatch(options: options)

        #expect(vm.currentSessionIdForTest == sessionId)
        #expect(firstMatchId != nil)
        #expect(vm.currentSessionForTest?.id != firstMatchId)
    }

    @Test @MainActor func restartMatchIssuesNewMatchIdButKeepsSessionId() {
        let vm = WorkoutSessionViewModel()
        let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

        vm.startMatch(options: options)
        let firstMatchId = vm.currentSessionForTest?.id
        let sessionId = vm.currentSessionIdForTest
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])

        vm.restartMatch()

        #expect(firstMatchId != nil)
        #expect(vm.currentSessionForTest?.id != firstMatchId)
        #expect(vm.currentSessionIdForTest == sessionId)
    }

    @Test @MainActor func remoteSessionStartAdoptsMatchId() {
        let vm = WorkoutSessionViewModel()
        let remoteMatchId = UUID()

        vm.applyIncomingSessionStartForTest(SessionStartMessage(
            sessionId: UUID(),
            matchId: remoteMatchId,
            options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false),
            workoutStartDate: Date()
        ))

        #expect(vm.currentSessionForTest?.id == remoteMatchId)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests
```

Expected: `startMatchUsesMatchStartTimeNotWorkoutStartTime` FAIL (`session.startedAt == workoutStart`), 나머지 두 개는 컴파일 실패 또는 FAIL

- [ ] **Step 3: `startMatch` 수정**

167-196행 `startMatch`를 아래로 교체한다.

```swift
    func startMatch(options: MatchOptions, sessionId: UUID? = nil, matchId: UUID? = nil, isRemote: Bool = false) {
        isDriver = !isRemote
        hasSyncedSession = true
        // 원격 채택 시 자기 sessionId를 상대 것으로 맞춘다. 안 그러면 workoutEnd·matchReset
        // 같은 sessionId 가드가 걸린 신호를 init UUID와 불일치로 모두 무시해버린다.
        if let sessionId { self.sessionId = sessionId }
        let mid = matchId ?? UUID()
        _currentSession = MatchSession(
            id: mid,
            workoutSessionId: self.sessionId,
            options: options,
            // 워크아웃 시작 시각(self.startedAt)이 아니라 경기 시작 시각이다.
            // mirror 경로에서도 수신 시각이 driver의 경기 시작 시각에 근사한다.
            startedAt: Date(),
            kcalAtStart: metrics.activeCalories,
            totalKcalAtStart: metrics.totalCalories
        )

        if !isRemote {
            connectivity.receivedScoreState = nil
        }

        scoreVM.resetAll(options: options)
        phase = .playing(options)
        liveActivity.start(mode: options.mode)

        if !isRemote {
            connectivity.sendSessionStart(SessionStartMessage(
                sessionId: self.sessionId,
                matchId: mid,
                options: options,
                workoutStartDate: startedAt ?? Date()
            ))
        }
    }
```

`workoutStartDate:`에는 **워크아웃** 시작 시각인 `startedAt`을 그대로 넘긴다 — 이 필드의 의미는 바뀌지 않는다.

- [ ] **Step 4: mirror가 `matchId`를 채택하게 한다**

269-277행 `handleIncomingSessionStart`의 마지막 줄을 교체한다.

```swift
        startMatch(options: msg.options, matchId: msg.matchId, isRemote: true)
```

바로 위의 `sessionId = msg.sessionId`와 `startSession(startDate: msg.workoutStartDate)`는 그대로 둔다.

- [ ] **Step 5: 콜드런치 재동기화에도 현재 `matchId`를 싣는다**

42-50행 `setupScoreSync()`의 `isWatchReachable` sink 안 `sendSessionStart` 호출을 교체한다.

```swift
                connectivity.sendSessionStart(SessionStartMessage(
                    sessionId: sessionId,
                    matchId: _currentSession?.id,
                    options: options,
                    workoutStartDate: startedAt ?? Date()
                ))
```

- [ ] **Step 6: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests
```

Expected: PASS (기존 테스트 포함 전부)

- [ ] **Step 7: 린트 후 커밋**

```bash
make fix
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "🐛 iOS 경기 시작 시각 수정 + matchId 발급·채택"
```

---

### Task 4: 중복 제거 키를 `matchId`로 교체 — 🔴 데이터 손실 수정

이 태스크가 스펙 1-1을 해결한다. Task 2·3이 `matchId`를 채워 놓았으므로 이제 안전하게 키를 내릴 수 있다.

**Files:**
- Modify: `Shared/Persistence/Match.swift`
- Modify: `iOSApp/Services/MatchPersistenceService.swift` (`upsert` 32-43행)
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (`buildMatchFromMessage` 324-342행, `buildMatchFromSession` 344-361행)
- Test: `iosTests/Services/MatchPersistenceServiceTests.swift` (전면 개정)

**Interfaces:**
- Consumes: `MatchEndMessage.matchId` (Task 1), `MatchSession.id` (Task 2·3에서 matchId로 확정됨)
- Produces: `Match.matchId: UUID?` — nil이면 중복 제거 대상이 아니다

- [ ] **Step 1: 기존 테스트 중 버그를 못박은 것을 제거하고 재현 테스트를 넣는다**

`iosTests/Services/MatchPersistenceServiceTests.swift`를 아래 내용으로 **전체 교체**한다. 기존 `upsertSameSessionKeepsSingleRecord`와 `upsertReplacesOnlyMatchingSession`은 "같은 워크아웃이면 덮어쓴다"를 올바른 동작으로 못박고 있어 그대로 두면 수정이 막힌다.

```swift
import Foundation
import SwiftData
@testable import TennisCounter
import Testing

/// MatchPersistenceService는 싱글턴이라 테스트마다 컨텍스트를 갈아끼운다. 병렬 실행 시
/// 서로의 컨텍스트를 덮어쓰므로 직렬 실행이 필요하다.
@Suite(.serialized)
@MainActor
struct MatchPersistenceServiceTests {
    private func makeService() throws -> MatchPersistenceService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        let service = MatchPersistenceService.shared
        service.configure(with: ModelContext(container))
        return service
    }

    /// 스펙 1-1 재현: 중복 제거 키가 워크아웃 단위라 같은 워크아웃의 두 번째 경기를
    /// 저장하면 첫 경기가 삭제됐다. 워크아웃 하나에 경기 여러 판은 정상 사용 경로다.
    @Test func upsertSameWorkoutDifferentMatchIdKeepsBoth() throws {
        let service = try makeService()
        let workoutId = UUID()

        let first = Match()
        first.workoutSessionId = workoutId
        first.matchId = UUID()
        first.myTotalSets = 1
        try service.upsert(first)

        let second = Match()
        second.workoutSessionId = workoutId
        second.matchId = UUID()
        second.myTotalSets = 2
        try service.upsert(second)

        let all = try service.fetchByWorkoutSession(workoutId)
        #expect(all.count == 2)
        #expect(Set(all.map(\.myTotalSets)) == [1, 2])
    }

    /// 폰·워치 양쪽 저장과 워치의 저장 재시도를 흡수하는 경로.
    @Test func upsertSameMatchIdReplaces() throws {
        let service = try makeService()
        let matchId = UUID()

        let first = Match()
        first.matchId = matchId
        first.myTotalSets = 1
        try service.upsert(first)

        let retry = Match()
        retry.matchId = matchId
        retry.myTotalSets = 2
        try service.upsert(retry)

        let all = try service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.myTotalSets == 2)
    }

    /// 구버전 워치 페이로드에는 matchId가 없다. 이때는 중복 제거를 하지 않는다.
    @Test func upsertWithoutMatchIdAlwaysInserts() throws {
        let service = try makeService()
        let workoutId = UUID()

        let first = Match()
        first.workoutSessionId = workoutId
        first.myTotalSets = 1
        try service.upsert(first)

        let second = Match()
        second.workoutSessionId = workoutId
        second.myTotalSets = 2
        try service.upsert(second)

        #expect(try service.fetchAll().count == 2)
    }

    @Test func upsertReplacesOnlyMatchingMatchId() throws {
        let service = try makeService()
        let untouched = UUID()
        let replaced = UUID()

        let other = Match()
        other.matchId = untouched
        other.myTotalSets = 9
        try service.upsert(other)

        let first = Match()
        first.matchId = replaced
        first.myTotalSets = 1
        try service.upsert(first)

        let second = Match()
        second.matchId = replaced
        second.myTotalSets = 2
        try service.upsert(second)

        let all = try service.fetchAll()
        #expect(all.count == 2)
        #expect(all.first(where: { $0.matchId == untouched })?.myTotalSets == 9)
        #expect(all.first(where: { $0.matchId == replaced })?.myTotalSets == 2)
    }

    @Test func fetchAllSortsByStartedAtDescending() throws {
        let service = try makeService()

        let older = Match()
        older.matchId = UUID()
        older.startedAt = Date(timeIntervalSince1970: 1000)
        try service.upsert(older)

        let newer = Match()
        newer.matchId = UUID()
        newer.startedAt = Date(timeIntervalSince1970: 2000)
        try service.upsert(newer)

        let all = try service.fetchAll()
        #expect(all.map(\.startedAt) == [newer.startedAt, older.startedAt])
    }

    @Test func fetchByWorkoutSessionIgnoresOtherSessions() throws {
        let service = try makeService()
        let target = UUID()

        let mine = Match()
        mine.matchId = UUID()
        mine.workoutSessionId = target
        try service.upsert(mine)

        let others = Match()
        others.matchId = UUID()
        others.workoutSessionId = UUID()
        try service.upsert(others)

        #expect(try service.fetchByWorkoutSession(target).count == 1)
        #expect(try service.fetchByWorkoutSession(UUID()).isEmpty)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/MatchPersistenceServiceTests
```

Expected: 컴파일 실패 — `value of type 'Match' has no member 'matchId'`

- [ ] **Step 3: `Match`에 `matchId` 추가**

`Shared/Persistence/Match.swift`의 `var workoutSessionId: UUID?` 바로 위에 추가한다.

```swift
    /// 이 경기의 고유 식별자. 폰·워치가 SessionStartMessage로 공유한다. 저장 시 중복 제거 키.
    /// CloudKit 요구사항상 optional이며, matchId 도입 전 기록은 nil이다.
    var matchId: UUID?
```

- [ ] **Step 4: 중복 제거 키 교체**

`iOSApp/Services/MatchPersistenceService.swift`의 `upsert(_:)`를 아래로 교체한다.

```swift
    /// 같은 경기의 기존 기록을 지우고 삽입한다 — 폰·워치 양쪽 저장 요청과 워치의 저장
    /// 재시도가 중복 레코드를 만들지 않게 하는 규칙. matchId가 없으면 그냥 삽입한다.
    /// workoutSessionId는 워크아웃 식별자라 키로 쓰면 같은 워크아웃의 다른 경기까지 지운다.
    func upsert(_ match: Match) throws {
        guard let store else { throw PersistenceError.notConfigured }
        do {
            if let mid = match.matchId {
                try store.upsert(match, replacing: #Predicate<Match> { $0.matchId == mid })
            } else {
                try store.upsert(match)
            }
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }
```

파일 상단의 클래스 doc comment도 함께 고친다 — `/// 테니스 규칙 — workoutSessionId 기준 중복 제거, startedAt 정렬 — 은 여기가 소유한다.`를 `/// 테니스 규칙 — matchId 기준 중복 제거, startedAt 정렬 — 은 여기가 소유한다.`로.

- [ ] **Step 5: 저장 경로가 `matchId`를 채우게 한다**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`:

`buildMatchFromMessage(_:)`의 `match.workoutSessionId = msg.sessionId` 바로 위에 추가:

```swift
        match.matchId = msg.matchId
```

`buildMatchFromSession(_:)`의 `match.workoutSessionId = session.workoutSessionId` 바로 위에 추가:

```swift
        match.matchId = session.id
```

- [ ] **Step 6: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: PASS — iOS 테스트 전체를 돌린다. 중복 제거 규칙이 바뀌었으므로 다른 스위트에 회귀가 없는지 확인해야 한다.

- [ ] **Step 7: 린트 후 커밋**

```bash
make fix
git add Shared/Persistence/Match.swift iOSApp/Services/MatchPersistenceService.swift iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/Services/MatchPersistenceServiceTests.swift
git commit -m "🐛 중복 제거 키를 워크아웃에서 경기 단위로 교체 — 같은 워크아웃 경기 삭제 수정"
```

---

### Task 5: 경기 구간 시간 + 워크아웃 누적 지표 기록

`durationSeconds`만 워크아웃 누적값이던 문제(스펙 1-2)의 저장 측을 고친다. 경기 시작 시점의 elapsed 스냅샷을 추가해 차분을 내고, 버리고 있던 누적값을 함께 저장한다.

**Files:**
- Modify: `Shared/Models/MatchSession.swift`
- Modify: `Shared/Persistence/Match.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (`startMatch`, `finishMatch` 222-241행, `makeMatchEndMessage`)
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (`startMatch`, `finishMatch` 198-216행, `buildMatchFromMessage`, `buildMatchFromSession`)
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`, `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `MatchEndMessage.workoutElapsedSeconds/.workoutCalories/.workoutTotalCalories` (Task 1)
- Produces:
  - `MatchSession.elapsedAtStart: Int` (init 기본값 `0`), `MatchSession.elapsedAtEnd: Int?`
  - `Match.workoutElapsedSeconds: Int?`, `Match.workoutCaloriesBurned: Double?`, `Match.workoutTotalCaloriesBurned: Double?`
  - `Match.durationSeconds`의 의미가 **경기 구간**으로 확정된다

- [ ] **Step 1: 실패하는 테스트 작성 — iOS**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가한다.

```swift
    /// 스펙 1-2 재현: durationSeconds에 워크아웃 누적 경과시간을 넣고 있었다.
    /// 칼로리는 경기 구간 차분인데 시간만 누적이라 한 레코드 안에서 기준이 갈렸다.
    @Test @MainActor func buildMatchFromSessionDurationIsMatchIntervalNotWorkoutTotal() {
        let vm = WorkoutSessionViewModel()
        // startSession()은 1초 타이머를 돌려 elapsedSeconds를 덮어쓴다. 여기선 값을 직접 주입한다.
        vm.elapsedSeconds = 600
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.elapsedSeconds = 1500
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])

        guard case let .finished(session) = vm.phase else {
            Issue.record("Expected .finished phase")
            return
        }
        let match = vm.buildMatchForTest(session)

        #expect(match.durationSeconds == 900)
        #expect(match.workoutElapsedSeconds == 1500)
    }

    @Test @MainActor func buildMatchFromSessionRecordsCumulativeWorkoutCalories() {
        let vm = WorkoutSessionViewModel()
        vm.metrics = WorkoutMetrics(elapsedSeconds: 600, activeCalories: 350, totalCalories: 420, heartRate: 130)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.metrics = WorkoutMetrics(elapsedSeconds: 1500, activeCalories: 600, totalCalories: 730, heartRate: 140)
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])

        guard case let .finished(session) = vm.phase else {
            Issue.record("Expected .finished phase")
            return
        }
        let match = vm.buildMatchForTest(session)

        #expect(match.caloriesBurned == 250)              // 경기 구간
        #expect(match.workoutCaloriesBurned == 600)       // 누적
        #expect(match.totalCaloriesBurned == 310)         // 경기 구간
        #expect(match.workoutTotalCaloriesBurned == 730)  // 누적
    }
```

- [ ] **Step 2: 실패하는 테스트 작성 — Watch**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가한다.

```swift
    @Test @MainActor func matchEndMessageCarriesMatchIntervalAndCumulativeMetrics() {
        let vm = WorkoutSessionViewModel()
        vm.healthKit.setLiveMetricsForTesting(calories: 350, basalCalories: 70, elapsedSeconds: 600)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        vm.healthKit.setLiveMetricsForTesting(calories: 600, basalCalories: 130, elapsedSeconds: 1500)
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])

        guard let session = vm.currentSession() else {
            Issue.record("currentSession이 없음")
            return
        }
        #expect(session.elapsedAtStart == 600)
        #expect(session.elapsedAtEnd == 1500)
        #expect(session.kcalAtEnd == 600)
        #expect(session.totalKcalAtEnd == 730)
    }
```

- [ ] **Step 3: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1' -only-testing:watchosTests/WorkoutSessionViewModelTests
```

Expected: 컴파일 실패 — `value of type 'Match' has no member 'workoutElapsedSeconds'`, `value of type 'MatchSession' has no member 'elapsedAtStart'`

- [ ] **Step 4: `MatchSession`에 elapsed 스냅샷 추가**

`Shared/Models/MatchSession.swift`의 `var averageHeartRate: Double?` 바로 위에 추가한다.

```swift
    /// 경기 구간 시간 = elapsedAtEnd - elapsedAtStart. elapsed는 일시정지를 제외한 값이라
    /// 차분을 내면 일시정지 제외가 그대로 따라온다.
    let elapsedAtStart: Int
    var elapsedAtEnd: Int?
```

`init`을 아래로 교체한다.

```swift
    init(id: UUID = UUID(), workoutSessionId: UUID, options: MatchOptions,
         startedAt: Date = Date(), kcalAtStart: Double, totalKcalAtStart: Double = 0,
         elapsedAtStart: Int = 0)
    {
        self.id = id
        self.workoutSessionId = workoutSessionId
        self.options = options
        self.startedAt = startedAt
        self.kcalAtStart = kcalAtStart
        self.totalKcalAtStart = totalKcalAtStart
        self.elapsedAtStart = elapsedAtStart
    }
```

기본값 `0` 덕분에 `buildSession(from:)` 같은 기존 호출부는 그대로 컴파일된다.

- [ ] **Step 5: `Match`에 누적 필드 3개 추가**

`Shared/Persistence/Match.swift`의 `var durationSeconds: Int?` 아래에 추가한다. 기존 `durationSeconds` 주석도 함께 손본다.

```swift
    /// 이 경기 구간의 활동 시간(일시정지 제외). 워크아웃 누적값이 아니다.
    var durationSeconds: Int?
    /// 워크아웃 시작부터 이 경기 종료 시점까지의 누적값. Summary가 workoutSessionId로
    /// 그룹핑해 그룹당 최댓값만 합산한다 — 단순 합산하면 같은 값을 여러 번 세게 된다.
    /// 누적값 도입 전 기록은 nil이다.
    var workoutElapsedSeconds: Int?
    var workoutCaloriesBurned: Double?
    var workoutTotalCaloriesBurned: Double?
```

- [ ] **Step 6: Watch 기록 규칙 적용**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`:

**(a) `startMatch`**의 `MatchSession(...)` 생성에 인자 추가:

```swift
        let session = MatchSession(
            id: mid,
            workoutSessionId: id,
            options: options,
            kcalAtStart: healthKit.currentCalories,
            totalKcalAtStart: healthKit.currentCalories + healthKit.currentBasalCalories,
            elapsedAtStart: healthKit.elapsedSeconds
        )
```

**(b) `finishMatch`**의 `session.totalKcalAtEnd = ...` 아래에 추가:

```swift
        session.elapsedAtEnd = healthKit.elapsedSeconds
```

**(c) `makeMatchEndMessage`**의 `durationSeconds:` 인자를 교체하고 누적 3종을 추가:

```swift
            durationSeconds: (session.elapsedAtEnd ?? session.elapsedAtStart) - session.elapsedAtStart,
            calories: (session.kcalAtEnd ?? 0) - session.kcalAtStart,
            averageHeartRate: session.averageHeartRate,
            mode: session.options.mode.rawValue,
            noAdRule: session.options.noAdRule,
            totalCalories: session.totalKcalAtEnd.map { $0 - session.totalKcalAtStart },
            matchId: session.id,
            workoutElapsedSeconds: session.elapsedAtEnd,
            workoutCalories: session.kcalAtEnd,
            workoutTotalCalories: session.totalKcalAtEnd
        )
```

- [ ] **Step 7: iOS 기록 규칙 적용**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`:

**(a) `startMatch`**의 `MatchSession(...)` 생성에 인자 추가 (`totalKcalAtStart:` 다음 줄):

```swift
            totalKcalAtStart: metrics.totalCalories,
            elapsedAtStart: elapsedSeconds
        )
```

**(b) `finishMatch`**의 `session.totalKcalAtEnd = metrics.totalCalories` 아래에 추가:

```swift
        session.elapsedAtEnd = elapsedSeconds
```

**(c) `buildMatchFromSession`**의 `match.durationSeconds = elapsedSeconds` 줄을 교체하고 누적 3종을 추가:

```swift
        match.durationSeconds = (session.elapsedAtEnd ?? session.elapsedAtStart) - session.elapsedAtStart
        match.workoutElapsedSeconds = session.elapsedAtEnd
        match.caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
        match.workoutCaloriesBurned = session.kcalAtEnd
        match.totalCaloriesBurned = session.totalKcalAtEnd.map { $0 - session.totalKcalAtStart }
        match.workoutTotalCaloriesBurned = session.totalKcalAtEnd
```

기존 `match.caloriesBurned` / `match.totalCaloriesBurned` 줄은 위 블록에 흡수되므로 중복해서 남기지 않는다.

**(d) `buildMatchFromMessage`**의 `match.caloriesBurned = msg.calories` 아래에 추가:

```swift
        match.workoutElapsedSeconds = msg.workoutElapsedSeconds
        match.workoutCaloriesBurned = msg.workoutCalories
        match.workoutTotalCaloriesBurned = msg.workoutTotalCalories
```

`match.durationSeconds = msg.durationSeconds`는 그대로 둔다 — Task 1에서 이 필드의 의미가 경기 구간으로 바뀌었다.

- [ ] **Step 8: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'
```

Expected: 양쪽 PASS

- [ ] **Step 9: 린트 후 커밋**

```bash
make fix
git add Shared/Models/MatchSession.swift Shared/Persistence/Match.swift WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "🐛 경기 구간 시간 계산 + 워크아웃 누적 지표 저장"
```

---

### Task 6: Summary 워크아웃 그룹 집계

누적 지표를 워크아웃별 최댓값으로 접어 합산한다. 이 태스크가 스펙 1-2의 집계 측을 완성한다.

**Files:**
- Modify: `iOSApp/Features/Summary/SummaryViewModel.swift` (`stats(from:)` 59-90행)
- Test: `iosTests/Summary/SummaryViewModelTests.swift`

**Interfaces:**
- Consumes: `Match.workoutElapsedSeconds/.workoutCaloriesBurned/.workoutTotalCaloriesBurned`, `Match.workoutSessionId` (Task 5)
- Produces: `SummaryStats`의 필드·타입은 변하지 않는다. 계산 방식만 바뀐다.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Summary/SummaryViewModelTests.swift`에 추가한다.

```swift
    private func workoutMatch(
        workoutId: UUID,
        startedAt: Date = Date(),
        matchDuration: Int,
        workoutElapsed: Int,
        matchCalories: Double,
        workoutCalories: Double
    ) -> Match {
        let match = Match()
        match.matchId = UUID()
        match.workoutSessionId = workoutId
        match.startedAt = startedAt
        match.myTotalSets = 1
        match.durationSeconds = matchDuration
        match.workoutElapsedSeconds = workoutElapsed
        match.caloriesBurned = matchCalories
        match.workoutCaloriesBurned = workoutCalories
        return match
    }

    /// 스펙 1-2 재현: 워크아웃 하나에서 경기를 3판 하면 누적값 3개가 단순 합산돼
    /// 운동 시간이 실제의 몇 배로 부풀었다. 그룹당 최댓값 하나만 세야 한다.
    @Test func statsSameWorkoutMultipleMatchesDoesNotDoubleCountDuration() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week
        let workoutId = UUID()

        let matches = [
            workoutMatch(workoutId: workoutId, matchDuration: 1200, workoutElapsed: 1200,
                         matchCalories: 300, workoutCalories: 300),
            workoutMatch(workoutId: workoutId, matchDuration: 1200, workoutElapsed: 2700,
                         matchCalories: 250, workoutCalories: 650),
            workoutMatch(workoutId: workoutId, matchDuration: 1200, workoutElapsed: 3600,
                         matchCalories: 130, workoutCalories: 780),
        ]

        let stats = vm.stats(from: matches)

        #expect(stats.totalMatches == 3)
        #expect(stats.totalDuration == 3600)
        #expect(stats.totalCalories == 780)
    }

    @Test func statsDifferentWorkoutsSumEachWorkoutMaximum() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let first = UUID()
        let second = UUID()
        let matches = [
            workoutMatch(workoutId: first, matchDuration: 900, workoutElapsed: 900,
                         matchCalories: 200, workoutCalories: 200),
            workoutMatch(workoutId: first, matchDuration: 900, workoutElapsed: 1800,
                         matchCalories: 180, workoutCalories: 380),
            workoutMatch(workoutId: second, matchDuration: 600, workoutElapsed: 600,
                         matchCalories: 150, workoutCalories: 150),
        ]

        let stats = vm.stats(from: matches)

        #expect(stats.totalDuration == 2400)   // 1800 + 600
        #expect(stats.totalCalories == 530)    // 380 + 150
    }

    /// 누적 필드 도입 전 기록은 workoutElapsedSeconds가 nil이고 durationSeconds가 마침
    /// 누적값이다. 폴백이 이를 그대로 쓰므로 기존 기록의 표시값에 회귀가 없어야 한다.
    @Test func statsLegacyRecordsWithoutWorkoutFieldsFallBackToExistingValues() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let legacy = Match()
        legacy.workoutSessionId = UUID()
        legacy.startedAt = Date()
        legacy.myTotalSets = 1
        legacy.durationSeconds = 3600
        legacy.caloriesBurned = 500

        let stats = vm.stats(from: [legacy])

        #expect(stats.totalDuration == 3600)
        #expect(stats.totalCalories == 500)
    }

    /// workoutSessionId가 없는 레코드는 서로 그룹핑할 수 없으므로 각자 한 워크아웃으로 센다.
    @Test func statsMatchesWithoutWorkoutSessionIdSumIndependently() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let first = Match()
        first.startedAt = Date()
        first.durationSeconds = 600
        first.caloriesBurned = 100

        let second = Match()
        second.startedAt = Date()
        second.durationSeconds = 900
        second.caloriesBurned = 150

        let stats = vm.stats(from: [first, second])

        #expect(stats.totalDuration == 1500)
        #expect(stats.totalCalories == 250)
    }
```

- [ ] **Step 2: 기존 테스트를 새 의미에 맞게 고친다**

`statsWithWorkoutData_aggregatesCorrectly`는 두 경기에 `workoutSessionId`가 없어 지금도 통과하지만, 의도가 "서로 다른 워크아웃"임을 명시해야 나중에 오독되지 않는다. `match1`·`match2`에 각각 다른 `workoutSessionId`와 누적값을 넣도록 수정한다.

```swift
    @Test func statsWithWorkoutData_aggregatesCorrectly() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        // 서로 다른 워크아웃 두 개 — 누적값이 각각 독립적으로 합산돼야 한다.
        let match1 = Match()
        match1.workoutSessionId = UUID()
        match1.myTotalSets = 2
        match1.yourTotalSets = 0
        match1.startedAt = Date()
        match1.caloriesBurned = 300
        match1.workoutCaloriesBurned = 300
        match1.averageHeartRate = 140
        match1.durationSeconds = 3600
        match1.workoutElapsedSeconds = 3600

        let match2 = Match()
        match2.workoutSessionId = UUID()
        match2.myTotalSets = 0
        match2.yourTotalSets = 2
        match2.startedAt = Date()
        match2.caloriesBurned = 200
        match2.workoutCaloriesBurned = 200
        match2.averageHeartRate = 160
        match2.durationSeconds = 1800
        match2.workoutElapsedSeconds = 1800

        let stats = vm.stats(from: [match1, match2])

        #expect(stats.totalCalories == 500)
        #expect(stats.totalDuration == 5400)
        #expect(stats.avgHeartRate == 150)
    }
```

- [ ] **Step 3: 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/SummaryViewModelTests
```

Expected: `statsSameWorkoutMultipleMatchesDoesNotDoubleCountDuration` FAIL — `totalDuration`이 3600이 아니라 7500(1200+2700+3600)으로 나온다

- [ ] **Step 4: 그룹 집계 구현**

`iOSApp/Features/Summary/SummaryViewModel.swift`의 `stats(from:)`를 아래로 교체하고, 그 아래에 헬퍼를 추가한다.

```swift
    func stats(from matches: [Match]) -> SummaryStats {
        let filtered = filteredMatches(from: matches)
        let wins = filtered.count(where: { $0.myTotalSets > $0.yourTotalSets })
        let total = filtered.count
        let winRate = total > 0 ? Double(wins) / Double(total) : 0.0

        let totalCalories = sumOfWorkoutMaxima(filtered) { $0.workoutCaloriesBurned ?? $0.caloriesBurned }
        let totalEnergy = sumOfWorkoutMaxima(filtered) { $0.workoutTotalCaloriesBurned ?? $0.totalCaloriesBurned }
        let totalDuration = sumOfWorkoutMaxima(filtered) { match in
            if let cumulative = match.workoutElapsedSeconds { return cumulative }
            if let d = match.durationSeconds { return d }
            if let end = match.endedAt { return Int(end.timeIntervalSince(match.startedAt)) }
            return nil
        }

        let heartRates = filtered.compactMap(\.averageHeartRate)
        let avgHeartRate: Double? = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)

        return SummaryStats(
            totalMatches: total,
            wins: wins,
            winRate: winRate,
            totalCalories: totalCalories,
            totalEnergy: totalEnergy,
            totalDuration: totalDuration,
            avgHeartRate: avgHeartRate
        )
    }

    /// 워크아웃 누적 지표는 그룹당 최댓값 하나만 취한다 — 같은 워크아웃의 경기들이 하나의
    /// 누적 축을 공유하므로 단순 합산하면 같은 칼로리·시간을 여러 번 세게 된다.
    /// workoutSessionId가 없는 레코드는 서로 묶을 근거가 없어 각자 한 워크아웃으로 본다.
    private func sumOfWorkoutMaxima<T: Comparable & AdditiveArithmetic>(
        _ matches: [Match], _ value: (Match) -> T?
    ) -> T? {
        var maxByWorkout: [UUID: T] = [:]
        var ungrouped: [T] = []
        for match in matches {
            guard let v = value(match) else { continue }
            if let sid = match.workoutSessionId {
                maxByWorkout[sid] = Swift.max(maxByWorkout[sid] ?? v, v)
            } else {
                ungrouped.append(v)
            }
        }
        let all = Array(maxByWorkout.values) + ungrouped
        return all.isEmpty ? nil : all.reduce(.zero, +)
    }
```

`avgHeartRate`는 의도적으로 그대로 둔다 — 시간 가중 평균은 스펙의 Non-goal이다.

- [ ] **Step 5: 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: PASS — iOS 테스트 전체

- [ ] **Step 6: 린트 후 커밋**

```bash
make fix
git add iOSApp/Features/Summary/SummaryViewModel.swift iosTests/Summary/SummaryViewModelTests.swift
git commit -m "🐛 Summary 누적 지표를 워크아웃 단위로 집계"
```

---

## 실기기 검증 (자동화 불가 — 전체 태스크 완료 후)

시뮬레이터에는 HealthKit 워크아웃이 없어 아래는 실기기(iPhone + Apple Watch)에서만 확인할 수 있다.

- [ ] 워크아웃 1개에서 경기 3판을 저장 → History 목록에 **3건**이 남는다
- [ ] Summary "운동 시간"이 워크아웃 실제 경과 시간과 일치한다 (경기 수만큼 부풀지 않는다)
- [ ] Summary "총 칼로리"가 애플 피트니스 앱의 같은 워크아웃 값과 근사하다
- [ ] 경기 상세 시트의 시간이 **해당 경기 길이**다 (워크아웃 전체가 아니다)
- [ ] 폰 driver로 1경기 → 워치에서 2경기 시작 → 두 경기가 **한 워크아웃으로** 집계된다 (스펙 1-4)
- [ ] 워치에서 저장 버튼을 누르고 ack 재시도가 발생해도 History에 중복이 생기지 않는다
- [ ] 기존에 저장돼 있던 경기들의 Summary 수치가 업데이트 전과 동일하다 (회귀 없음)

## 작업 기록

- [ ] 전체 완료 후 `docs/superpowers/logs/2026-08-09-summary-history-data-integrity.md`에 재현 경로·근본 원인·before/after를 기록한다 (CLAUDE.md의 logs 관례)
