# Ralli 경기 저장 유실 재발 수정 — 워치 보관함(outbox) 플랜

작성일: 2026-11-13
상태: **검토 대기**
Linear: YJ-38 (관련: YJ-17 · YJ-22 · YJ-24)
브랜치: `fix/ralli-match-save-outbox`
선행 플랜: `docs/plans/2026/2026-10-25-watch-record-delivery.md` (PR #65)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워치에서 저장한 경기가 폰의 저장 확인을 받을 때까지 워치에 남아 다시 보내지게 하고, 늦게 저장된 경기가 폰 기록 탭에 바로 보이게 한다.

**Architecture:** 워치가 저장 요청을 `UserDefaults` 보관함에 먼저 적고 보낸다. 폰의 ACK 가 `matchId` 를 싣고 돌아오면 그 항목을 지운다. ACK 가 없으면 앱 시작·세션 활성화·연결 복귀 때 다시 보낸다 — 폰 저장이 `matchId` upsert 라 중복 배달은 안전하다. 폰은 저장이 일어날 때와 포그라운드 복귀 때 기록 탭을 다시 읽는다.

**Tech Stack:** WatchConnectivity · SwiftData · YJKit `ConnectivityCore` · Swift Testing

**Spec:** 없음. 이 문서의 "배경"과 "원인"이 근거다.

---

## 배경 — 실제로 겪은 일

2026-11 실사용 중, 워치 결과 화면에 **"전송됨"** 이 떴는데 폰에 경기 기록이 없었다. 10-21 에 이어 두 번째다.

"전송됨" 문구는 PR #65 다음 날(`e169583`) 처음 생겼다. 즉 **워치에는 10-25 수정이 들어 있었다.**
폰 앱 버전, 폰이 저장에 실패했는지, 같은 날의 세션 레코드가 남았는지는 확인되지 않았다.
최근 머지된 #76·#77 은 이 경로를 건드리지 않는다.

## 원인

**하나로 확정하지 못했다.** 코드 읽기로 확인한 것은 "전송됨이 떠도 기록이 사라질 수 있는 구조"다.

| # | 위치 | 조건 | 결과 |
|---|---|---|---|
| 1 | `ConnectivityService.swift:40` | 워치 `WCSession` 이 `.activated` 가 아님 | 아무것도 보내지 않고 리턴. 워치는 8초 뒤 "전송됨" |
| 2 | `ConnectivityService.swift:61` | `transferUserInfo` 가 시스템 단에서 실패 | 결과를 받는 코드가 없다. "전송됨" |
| 3 | 폰이 `4225f29` 이전 빌드 (1.1.9) | 폰에 경기 화면이 없음 | 받을 주체가 없다. "전송됨" |
| 4 | `WatchMatchSaver.swift:42-48` | 폰 `upsert` 실패 | 실패 ACK. 워치가 결과 화면을 떠났으면 무시되어 "전송됨" 으로 남는다 |
| 5 | `HistoryViewModel.swift:51-53` | 기록 탭이 이미 열린 뒤 저장 도착 | 저장은 됐지만 목록이 그대로다 |

공통 뿌리는 둘이다.

- **워치에 기록이 남지 않는다.** 한 번 보낸 뒤에는 되살릴 방법이 없고, "전송됨" 상태에서는 버튼이 비활성이라 재시도도 못 한다.
- **"전송됨" 이 사실을 말하지 않는다.** 8초가 지났다는 뜻일 뿐이다.

이 플랜은 원인이 1~4 중 무엇이든 기록이 살아남게 한다. 3번은 폰이 새 빌드로 올라온 뒤 재전송으로 구제된다.
5번은 Task 5 가 따로 고친다.

## 하지 않는 것

- **워치 "저장 실패" non-fatal 이 Crashlytics 콘솔에 안 올라오는 문제** (10-02, 원인 미확인). 별도 조사다.
- **"전송됨" 문구 변경.** 보관함이 생기면 "폰이 받을 때까지 워치가 갖고 있다"는 뜻이 되어 문구가 사실에 맞는다.
- **하루치 · 골프.** 같은 `ConnectivityService` 를 쓰지만 Task 1 의 변경은 반환값·발행값 추가라 두 앱 코드는 그대로 컴파일된다.
  보관함 도입 여부는 Ralli 실기기 확인 뒤 별도로 정한다.
- **요약 탭.** `@Query` 라 다른 컨텍스트의 저장을 따라오는지 실행으로 확인하지 못했다. Task 6 에서 보고, 안 따라오면 별도 이슈로 뺀다.
- **세션 레코드(`WorkoutEndMessage`) 보관.** 이번 증상은 경기 기록이다.

## Global Constraints

- 코어(`ConnectivityCore`)는 도메인을 모른다. 보관함은 앱 레이어(`WatchApp/Services/`)에 둔다.
- 와이어 포맷은 **추가만** 한다. 새 키는 전부 optional 이고, 키가 없는 구버전 페이로드를 계속 읽어야 한다.
- 폰 저장의 중복 제거 키는 `matchId` 다 (`MatchPersistenceService.swift:42-53`). 바꾸지 않는다.
- 보관함 `UserDefaults` 키: `"pendingMatchSaves"`.
- 재전송 최소 간격: **60초**. 보관 기한: **14일** (경기 `endedAt` 기준).
- ViewModel 은 UI 프레임워크를 import 하지 않는다. 테스트는 Swift Testing, `@MainActor`, WatchConnectivity 를 직접 호출하지 않는다.
- `Packages/YJKit` 을 고치므로 세 앱의 6개 앱 스킴이 모두 빌드돼야 한다.

## Review Focus

1. **구버전 폰(1.2.0)의 ACK 에는 `matchId` 가 없다** — 그 ACK 는 같은 `sessionId` 의 항목을 전부 지워야 한다. 안 그러면 14일 동안 계속 다시 보낸다 (Task 3 테스트).
2. **같은 경기가 폰에 두 번 도착한다** — 기록이 하나여야 한다 (기존 `WatchMatchSaverTests` 의 중복 배달 테스트가 덮는다. Task 2 에서 깨지지 않는지 본다).
3. **보관함에 읽을 수 없는 항목이 있다** (앱 업데이트로 형식이 바뀜, 손상) — 그 항목만 버리고 나머지는 보내야 한다. 크래시하면 안 된다 (Task 3 테스트).
4. **폰이 실패 ACK 를 보낸다** — 항목을 지우지 않고 다음 기회에 다시 보내야 한다 (Task 3 테스트).
5. **활성화 전에 보낸다** (앱 시작 직후) — 보낸 것으로 치지 않고, 활성화되면 바로 보내야 한다 (Task 3 테스트).

---

### Task 1: YJKit — `send` 가 결과를 돌려주고 활성화 여부를 발행한다

**Files:**
- Modify: `Packages/YJKit/Sources/ConnectivityCore/ConnectivityService.swift`
- Modify: `Packages/YJKit/README.md` (`send` 설명에 반환값 한 줄)

**Interfaces:**
- Produces: `@discardableResult public func send(_ message: some ConnectivityMessage, via delivery: Delivery) -> Bool`
  — WCSession API 를 실제로 호출했으면 `true`. 활성화 가드·`isWatchAppInstalled`·`isReachable` 가드에 걸려 아무것도 하지 않았으면 `false`.
- Produces: `@Published public private(set) var isActivated: Bool` — `activationDidCompleteWith` 가 `.activated` 면 main 큐에서 `true`. iOS `sessionDidDeactivate` 에서 `false`.

`ConnectivityService` 는 `WCSession.default` 에 직접 묶여 있어 단위 테스트가 없다. 이 Task 는 빌드로 확인하고, 동작은 Task 3 의 보관함 테스트(주입한 `send` 클로저)와 Task 6 실기기 확인이 덮는다.

- [ ] **Step 1: 위 두 인터페이스를 구현한다**

- [ ] **Step 2: 패키지 테스트와 세 앱 빌드**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
make kit-test KIT_DESTINATION="id=$IOS"
for s in GolfCounter TennisCounter HaruchiFit; do
  xcodebuild -workspace YJApps.xcworkspace -scheme "$s" -destination "id=$IOS" build
  xcodebuild -workspace YJApps.xcworkspace -scheme "$s Watch App" -destination "id=$WATCH" build
done
```

Expected: kit-test 통과, 6개 빌드 `** BUILD SUCCEEDED **`, 반환값 미사용 경고 없음.

- [ ] **Step 3: 커밋**

```bash
git commit -m "✨ feat: ConnectivityService.send 가 전송 여부를 돌려주고 활성화 상태를 발행한다"
```

---

### Task 2: 저장 ACK 에 `matchId` 를 싣는다

**Files:**
- Modify: `Apps/TennisCounter/Shared/Services/ConnectivityMessages.swift:293-320`
- Modify: `Apps/TennisCounter/Shared/Services/MatchConnectivity.swift`
- Modify: `Apps/TennisCounter/iOSApp/Services/WatchMatchSaver.swift:49`
- Test: `Apps/TennisCounter/iosTests/Shared/MatchSaveResultMessageTests.swift`
- Test: `Apps/TennisCounter/iosTests/Services/WatchMatchSaverTests.swift`

**Interfaces:**
- Produces: `MatchSaveResultMessage(sessionId: UUID, success: Bool, matchId: UUID? = nil)`, 프로퍼티 `let matchId: UUID?`, 와이어 키 `"matchId"` (uuidString, 값이 있을 때만 싣는다).
- Produces: `@discardableResult func sendMatchSave(_ msg: MatchEndMessage) -> Bool` (`MatchConnectivity`) — Task 1 의 `send` 결과를 그대로 돌려준다.
- Produces: `@Published var isActivated: Bool` (`MatchConnectivity`) — `service.$isActivated` 를 `isWatchReachable` 과 같은 방식으로 잇는다.
- `WatchMatchSaver.save` 는 `sendResult(MatchSaveResultMessage(sessionId: msg.sessionId, success: success, matchId: msg.matchId))` 를 보낸다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`MatchSaveResultMessageTests`:

```swift
@Test func roundTripCarriesMatchId() {
    let sid = UUID(), mid = UUID()
    let decoded = MatchSaveResultMessage(from: MatchSaveResultMessage(sessionId: sid, success: true, matchId: mid).toDictionary())
    #expect(decoded?.matchId == mid)
    #expect(decoded?.sessionId == sid)
}

@Test func legacyPayloadWithoutMatchIdDecodesWithNil() {
    let sid = UUID()
    let decoded = MatchSaveResultMessage(from: ["type": "matchSaveResult", "sessionId": sid.uuidString, "success": true])
    #expect(decoded != nil)
    #expect(decoded?.matchId == nil)
}

@Test func nilMatchIdIsNotWrittenToDictionary() {
    let dict = MatchSaveResultMessage(sessionId: UUID(), success: false).toDictionary()
    #expect(dict["matchId"] == nil)
}
```

`WatchMatchSaverTests` — 기존 테스트의 스파이 구성을 그대로 쓴다:

```swift
@Test @MainActor func ackCarriesMatchIdOfSavedMatch() {
    // matchId 를 가진 MatchEndMessage 를 save() 에 넣는다
    // 회신된 MatchSaveResultMessage.matchId == 그 matchId, success == true
}

@Test @MainActor func failedSaveAckAlsoCarriesMatchId() {
    // store 가 throw 한다 → 회신 success == false, matchId 는 그대로
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/MatchSaveResultMessageTests -only-testing:RalliTests/WatchMatchSaverTests test
```

Expected: 컴파일 실패 (`matchId` 없음).

- [ ] **Step 3: 구현한다** (위 Interfaces 그대로)

- [ ] **Step 4: 통과를 확인한다** — Step 2 명령. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: 커밋**

```bash
git commit -m "✨ feat: 경기 저장 ACK 에 matchId 를 싣는다"
```

---

### Task 3: 워치 보관함 `MatchSaveOutbox`

**Files:**
- Create: `Apps/TennisCounter/WatchApp/Services/MatchSaveOutbox.swift`
- Test: `Apps/TennisCounter/watchosTests/Services/MatchSaveOutboxTests.swift`

**Interfaces:**
- Consumes: Task 2 의 `MatchSaveResultMessage.matchId`, `MatchEndMessage.toSaveDictionary()` / `MatchEndMessage(from:)`.
- Produces:

```swift
@MainActor
protocol MatchSaveEnqueuing {
    func enqueue(_ message: MatchEndMessage)
}

@MainActor
final class MatchSaveOutbox: MatchSaveEnqueuing {
    init(defaults: UserDefaults,
         send: @escaping (MatchEndMessage) -> Bool,
         now: @escaping () -> Date = Date.init,
         resendInterval: TimeInterval = 60,
         maxAge: TimeInterval = 14 * 24 * 3600)

    /// 보관 중인 경기의 matchId. 테스트와 진단용.
    var pendingMatchIds: [UUID] { get }

    /// 보관함에 적고 바로 한 번 보낸다. matchId 가 없는 메시지는 보관하지 않고 보내기만 한다.
    func enqueue(_ message: MatchEndMessage)

    /// success 면 항목을 지운다 — matchId 가 있으면 그 경기 하나, 없으면 같은 sessionId 전부.
    /// 실패 ACK 는 항목을 남기고 마지막 전송 시각을 지워 다음 flush 에서 다시 보내게 한다.
    func acknowledge(_ result: MatchSaveResultMessage)

    /// endedAt 이 maxAge 를 넘긴 항목과 읽을 수 없는 항목을 버린다. 남은 것 중 한 번도 못 보냈거나
    /// 마지막 전송 후 resendInterval 이 지난 항목을 다시 보낸다.
    func flush()
}
```

- 저장 형식: `defaults` 의 `"pendingMatchSaves"` 키에 `[[String: Any]]`. 각 원소는 `"payload"`(= `toSaveDictionary()`)와
  `"lastSentAt"`(epoch 초, `send` 가 `true` 를 돌려줬을 때만 기록) 두 키를 갖는다.
- `send` 가 `false` 를 돌려주면 `lastSentAt` 을 적지 않는다.
- 같은 `matchId` 를 다시 `enqueue` 하면 항목을 교체한다 (재시도 버튼).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

테스트마다 `UserDefaults(suiteName: UUID().uuidString)` 를 새로 만들고, `send` 는 호출을 배열에 쌓는 클로저다.
아래 9개를 쓴다. 이름과 단언이 곧 요구사항이다.

| 테스트 | 준비 | 단언 |
|---|---|---|
| `enqueueStoresAndSendsOnce` | `send` → `true` | `pendingMatchIds == [mid]`, 전송 1회 |
| `enqueueSurvivesNewInstance` | enqueue 후 같은 `defaults` 로 새 인스턴스 | 새 인스턴스의 `pendingMatchIds == [mid]` |
| `successAckWithMatchIdRemovesOnlyThatMatch` | 같은 `sessionId` 로 두 경기 enqueue, 첫 경기 ACK | 둘째만 남는다 |
| `successAckWithoutMatchIdRemovesWholeSession` | 같은 세션 두 경기 + 다른 세션 한 경기, `matchId` 없는 ACK | 다른 세션 경기만 남는다 |
| `failedAckKeepsEntryAndResendsOnNextFlush` | enqueue, 실패 ACK, 시계 +1초, `flush()` | 항목 유지, 전송 총 2회 |
| `flushDoesNotResendWithinInterval` | enqueue, 시계 +59초, `flush()` | 전송 총 1회 |
| `flushResendsAfterInterval` | enqueue, 시계 +60초, `flush()` | 전송 총 2회 |
| `unsentEntryIsSentOnNextFlushImmediately` | `send` → `false` 로 enqueue, 이후 `send` → `true`, 시계 +1초, `flush()` | 전송 시도 총 2회, 항목 유지 |
| `flushDropsExpiredAndUnreadableEntries` | `endedAt` 이 15일 전인 경기 + `defaults` 에 `["payload": ["type": "matchSave"]]` 를 직접 넣음 + 정상 경기 | `flush()` 후 정상 경기만 남고 그것만 전송 |

- [ ] **Step 2: 실패를 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:RalliWatchTests/MatchSaveOutboxTests test
```

Expected: 컴파일 실패 (`MatchSaveOutbox` 없음).

- [ ] **Step 3: `MatchSaveOutbox` 를 구현한다**

- [ ] **Step 4: 통과를 확인한다** — Step 2 명령. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: 커밋**

```bash
git commit -m "✨ feat: 워치가 저장 확인을 받을 때까지 경기를 보관하는 MatchSaveOutbox 를 추가한다"
```

---

### Task 4: 보관함을 워치 앱에 잇는다

**Files:**
- Modify: `Apps/TennisCounter/WatchApp/Services/MatchSaveOutbox.swift` (`shared` · `bind`)
- Modify: `Apps/TennisCounter/WatchApp/WatchApp.swift`
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:44-49, 278-290`
- Test: `Apps/TennisCounter/watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`
- Modify: `Apps/TennisCounter/CLAUDE.md` (Architecture 트리에 `WatchApp/Services/MatchSaveOutbox.swift` 한 줄, 테스트 트리에 한 줄)

**Interfaces:**
- Consumes: Task 2 의 `MatchConnectivity.sendMatchSave(_:) -> Bool`, `$isActivated`; Task 3 의 `MatchSaveOutbox`, `MatchSaveEnqueuing`.
- Produces:
  - `static let shared` — `UserDefaults.standard` 와 `{ MatchConnectivity.shared.sendMatchSave($0) }` 로 만든다.
  - `func bind(to connectivity: MatchConnectivity)` — 세 가지를 구독한다:
    `$isActivated` 가 `true` → `flush()`, `$isWatchReachable` 이 `true` → `flush()`, `$receivedMatchSaveResult` 값 → `acknowledge(_:)`.
    **`receivedMatchSaveResult` 를 nil 로 지우지 않는다** — 결과 화면의 뷰모델이 같은 값을 소비한다.
  - `WorkoutSessionViewModel.init(..., saveOutbox: MatchSaveEnqueuing = MatchSaveOutbox.shared)`
- `WatchApp.swift` 의 `init` 이 `AppCrashReporter.start()` 다음에 `MatchSaveOutbox.shared.bind(to: .shared)` 를 부른다.
  앱 수명 내내 살아 있어야 운동 화면이 없을 때도 재전송한다 (폰의 `WatchMatchSaver` 와 같은 이유).
- `saveCurrentMatch()` 는 `connectivity.sendMatchSave(...)` 대신 `saveOutbox.enqueue(makeMatchEndMessage(session: session))` 를 부른다.
  `saveAckState` 전이(`.pending` → 8초 뒤 `.waiting`)와 `handleMatchSaveResult` 는 바꾸지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
@MainActor final class OutboxSpy: MatchSaveEnqueuing {
    private(set) var enqueued: [MatchEndMessage] = []
    func enqueue(_ message: MatchEndMessage) { enqueued.append(message) }
}

@Test @MainActor func saveCurrentMatchEnqueuesToOutbox() {
    // 기존 saveCurrentMatch 테스트와 같은 준비(경기 시작 → 종료)에 saveOutbox: spy 를 넣는다
    // vm.saveCurrentMatch() 뒤 spy.enqueued.count == 1
    // spy.enqueued[0].matchId == vm.currentSession()?.id
    // vm.saveAckState == .pending
}

@Test @MainActor func retryAfterFailureEnqueuesSameMatchIdAgain() {
    // 실패 ACK 로 .failed 를 만든 뒤 saveCurrentMatch() 재호출
    // spy.enqueued.count == 2, 두 메시지의 matchId 가 같다
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:RalliWatchTests/WorkoutSessionViewModelTests test
```

Expected: 컴파일 실패 (`saveOutbox:` 인자 없음).

- [ ] **Step 3: 구현한다** (위 Interfaces 그대로)

- [ ] **Step 4: 워치 전체 테스트 통과를 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: 커밋**

```bash
git commit -m "🐛 fix: 워치 경기 저장을 보관함을 거쳐 보내고 확인받을 때까지 재전송한다"
```

---

### Task 5: 폰 기록 탭이 저장 도착과 포그라운드 복귀 때 다시 읽는다

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Services/MatchPersistenceService.swift:42-53`
- Modify: `Apps/TennisCounter/iOSApp/Features/History/HistoryViewModel.swift:48-78`
- Modify: `Apps/TennisCounter/iOSApp/Features/History/HistoryView.swift:84-90`
- Test: `Apps/TennisCounter/iosTests/Services/MatchPersistenceServiceTests.swift`
- Test: `Apps/TennisCounter/iosTests/History/HistoryViewModelTests.swift`

**Interfaces:**
- Produces: `extension Notification.Name { static let matchStoreDidChange }` (`MatchPersistenceService.swift` 에 둔다).
  `upsert` 가 성공하면 `NotificationCenter.default.post(name: .matchStoreDidChange, object: self)`. 실패하면 보내지 않는다.
- Produces: `func reloadIfLoaded()` (`HistoryViewModel`) — `hasLoadedInitial` 이 true 일 때만 `refreshData()` 를 부른다.
  `selectedDate` · `viewMode` · `lastActivationID` 는 건드리지 않는다.
- `HistoryView` 는 `.matchStoreDidChange` 알림과 `scenePhase == .active` 전환에서 `viewModel.reloadIfLoaded()` 를 부른다.
  알림은 `object` 를 가리지 않고 받는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`MatchPersistenceServiceTests`:

```swift
@Test @MainActor func upsertPostsMatchStoreDidChange() async {
    // 자기 컨테이너에 묶인 service 를 만든다 (기존 테스트의 헬퍼)
    // confirmation { confirm in ... } 안에서 object == service 인 .matchStoreDidChange 를 관찰하고
    // service.upsert(match) 뒤 confirm 이 1회 불렸는지 본다
}
```

`HistoryViewModelTests`:

```swift
@Test @MainActor func reloadIfLoadedShowsMatchSavedAfterActivation() {
    // 빈 저장소로 vm.configure → vm.activate(1) → listMatches.isEmpty
    // matchStore.upsert(오늘 경기) 뒤 vm.reloadIfLoaded()
    // vm.listMatches.count == 1
}

@Test @MainActor func reloadIfLoadedBeforeFirstActivationDoesNothing() {
    // vm.configure 만 하고 reloadIfLoaded() → listMatches.isEmpty, 이후 activate(1) 이 true 를 돌려준다
}

@Test @MainActor func reloadIfLoadedKeepsSelectedDateAndViewMode() {
    // activate(1) 뒤 selectedDate 를 지난달로, viewMode 를 .list 로 바꾼다
    // reloadIfLoaded() 뒤 두 값이 그대로다
}
```

목록 프로퍼티 이름은 기존 테스트가 쓰는 것을 따른다.

- [ ] **Step 2: 실패를 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/MatchPersistenceServiceTests -only-testing:RalliTests/HistoryViewModelTests test
```

Expected: 컴파일 실패 (`reloadIfLoaded` · `matchStoreDidChange` 없음).

- [ ] **Step 3: 구현한다** (위 Interfaces 그대로)

- [ ] **Step 4: iOS 전체 테스트와 lint**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test
make lint && make format
```

Expected: `** TEST SUCCEEDED **`, 위반 0.

- [ ] **Step 5: 커밋**

```bash
git commit -m "🐛 fix: 경기가 저장되거나 앱이 앞으로 올 때 기록 탭을 다시 읽는다"
```

---

### Task 6: 실기기 확인 · PR

PR #65 의 실기기 항목은 자동 테스트로 대체된 채 닫혔고, 그 상태에서 재발했다. **이번에는 생략하지 않는다.**
워치와 폰 **둘 다** 이 브랜치 빌드를 Xcode 로 올린 뒤 확인하고, 결과를 PR 본문 체크박스에 적는다.

- [ ] 폰 앱 포그라운드: 워치에서 경기 저장 → 워치 "저장됨", 폰 기록 탭에 즉시 보인다 (탭을 옮기지 않고).
- [ ] 폰 앱 백그라운드: 저장 → 워치가 "전송됨" 이어도, 폰 앱을 열면 기록이 있다.
- [ ] 폰 앱 강제 종료: 경기 2건 저장 → 폰 앱을 열면 2건 모두 있다.
- [ ] 폰 비행기 모드: 저장 → "전송됨". 워치 앱을 종료했다 다시 연다. 비행기 모드를 끈다 → 폰에 기록이 생긴다 (보관함 재전송).
- [ ] 위 항목 뒤 워치를 다시 열어도 같은 경기가 폰에 중복으로 생기지 않는다.
- [ ] 폰 요약 탭이 새 경기를 반영하는지 본다. 반영하지 않으면 별도 이슈로 적는다.
- [ ] 폰 1.2.0(스토어 빌드) + 워치 새 빌드 조합: 저장 → 폰에 기록이 생기고, 워치가 같은 경기를 계속 다시 보내지 않는다.
- [ ] PR 생성. 본문에 `YJ-38` 과 위 체크 결과를 적는다. 선행 플랜(10-25)의 상태 줄은 고치지 않는다.
