# 워치 기록 전송 유실 수정 (하루치 · 골프 · Ralli) · 하루치 칼로리 표기 통일 플랜

작성일: 2026-10-25
상태: **승인 (10-25) · PR 1 머지 (#63) · PR 2 머지 (#64) · PR 3 구현 완료 — 머지 대기 · 실기기 확인 남음 (하루치·골프·Ralli)**

| PR | 브랜치 | 범위 | 출시 |
|---|---|---|---|
| 1 | `fix/watch-record-delivery` | YJKit `.queued` · 하루치 · 골프 | 하루치 **1.0.1** (1.0.0 심사 통과 직후) · 골프 다음 출시 |
| 2 | `fix/haruchi-active-calories` | 하루치 칼로리 · 루트 `CLAUDE.md` 계약 한 줄 | 하루치 1.0.1 |
| 3 | `fix/ralli-match-save-delivery` | Ralli 경기 저장 | Ralli 다음 출시 |

순서: PR 1 → PR 3 (PR 1 의 `.queued` 를 쓴다). PR 2 는 겹치는 파일이 없어 아무 때나.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워치에서 저장한 기록이 폰에 도착하지 못하고 사라지는 일을 세 앱에서 없앤다.
하루치는 폰 칼로리 표기를 워치 요약 · 골프 · Ralli 와 같은 **활동 칼로리**로 맞춘다.

**Tech Stack:** WatchConnectivity · SwiftData · YJKit `ConnectivityCore` · Swift Testing

---

## 배경 — 실제로 겪은 일

**하루치 (10-25 TestFlight, 1.0.0 심사 중 빌드)** — 근력·유산소를 번갈아 기록했는데 폰에는 **전체 시간이 근력 하나**로 저장됐다.
폰 상세 `kcal` 이 워치 요약의 활동 칼로리와 **같았다**. 워치가 보낸 기록이면 폰 `kcal` 은 활동 + 기본 소모라 더 커야 한다.
같다는 것은 이 기록이 **HealthKit import 로 만들어졌다**는 뜻이다. import 는 `totalCalories` 에 active 를 넣고, 세션 타입이 근력 고정(D-M8)이라
전체를 근력 구간 하나로 덮는다 (`WorkoutRecord+Import.swift`). 즉 **워치 메시지가 폰에 저장되지 못했다.**

**Ralli (10-21 실기기)** — 워치에서 경기 저장을 여러 번 재시도했지만 계속 "저장 실패"가 떴다. 폰 기록 탭에 경기가 **한 개도 없다**.
같은 날 워크아웃(피트니스 앱·심박)은 저장됐다.

두 기록 모두 되살릴 수 없다. 워치 메모리에만 있었다.

## 원인

### 보내는 쪽 — `.reliable` 이 실패해도 다시 보내지 않는다

세 앱 모두 기록을 `.reliable` 로 보낸다 (`ConnectivityService.swift:53-59`).

```swift
if WCSession.default.isReachable {
    WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
} else {
    WCSession.default.transferUserInfo(dict)
}
```

워치에서 `isReachable` 은 **폰이 근처에 연결돼 있으면 true** 다. 폰 앱이 꺼져 있어도 그렇다.
`sendMessage` 가 폰 앱을 백그라운드로 깨워서 전달하기 때문이다. 그래서 운동이 끝날 때는 대부분 `sendMessage` 경로를 탄다.
이 경로가 실패하면(블루투스 끊김·시간 초과) `errorHandler: nil` 이라 **그대로 사라진다.**
골프 스펙(`round-transmission-design.md` 185행)과 `RoundTransmitter` 주석은 "실패 시 `transferUserInfo` 로 큐잉된다"고 적었지만 코드는 그렇게 동작하지 않는다.

### 받는 쪽 — 저장이 화면에 묶여 있다

| 앱 | 저장하는 곳 | 화면이 없을 때 |
|---|---|---|
| 하루치 | `iOSApp.swift` 의 `.onReceive(connectivity.$receivedRecord…)` — **뷰 수정자** | 백그라운드로 깨어난 앱에는 화면이 없어 저장이 돌지 않는다. 한 칸짜리 `@Published` 에 남았다가 앱이 다음에 열릴 때 저장된다. 그 전에 iOS 가 앱을 종료하면 **유실**. 앱을 열기 전에 두 번 운동하면 **앞의 것이 유실** |
| Ralli | iOS `WorkoutSessionViewModel.saveFromWatch` (122행 구독) — **경기 화면의 VM** | 폰에 경기 화면(`isMatchActive`)이 없으면 VM 이 없어 저장도 ACK 회신도 없다 → 워치가 8초 뒤 "저장 실패". 재시도해도 같은 경로라 결과가 같다. 게다가 `iOSApp.swift:64`(HomeView `onMatchStart`) · `:99`(`onReceive receivedSessionStart`)가 `receivedMatchSave = nil` 로 **대기 중인 요청을 지운다** |
| 골프 | `RoundReceiveService` — 앱 루트에서 받는 즉시 저장 | 문제없다 |

폰 앱을 잘 열지 않는 사용 패턴에서는 하루치 경로가 **자주** 일어난다. 앱이 며칠씩 백그라운드에 있으면 iOS 가 정리할 확률이 높다.

A(화면 없는 백그라운드 실행에서 `WindowGroup` 내용이 만들어지지 않는다는 전제)는 실기기 검증 2 로 확인한다.

## 고치는 방향

1. **보내는 쪽 — 기록은 항상 큐(`transferUserInfo`)로 보낸다.** 시스템이 보관했다가 순서대로 배달한다.
   폰 앱이 켜져 있으면 몇 초 안에, 꺼져 있으면 다음에 폰 앱이 실행될 때 도착한다
2. **받는 쪽 — 앱 루트에서 받는 즉시 저장한다.** 골프 `RoundReceiveService` · Ralli `WorkoutSessionRecorder` 와 같은 구조로 맞춘다
3. 하루치는 폰 앱을 늦게 열면 HealthKit import 가 먼저 근력 하나로 기록을 만들 수 있다. 그 뒤 워치 기록이 도착하면 `updateWorkoutData` 가
   같은 `healthKitUUID` 의 기록을 제자리에서 바로잡는다 — 지금도 그렇게 동작한다. 테스트로 묶는다

### 결정

| # | 결정 | 이유 |
|---|---|---|
| D1 | `.reliable` 을 고치지 않고 **`.queued` 를 새로 추가**한다 | Ralli 가 일시정지 명령·점수 상태 같은 실시간 메시지에 `.reliable` 을 쓴다. 이것을 큐로 보내면 늦게 도착한 명령이 엉뚱한 때에 적용된다 (README 66~67행이 이미 경고하는 문제) |
| D2 | `.queued` 는 `isReachable` 과 무관하게 **항상 `transferUserInfo`** | `sendMessage` 를 먼저 쓰면 "폰 앱을 깨웠지만 저장 전에 종료" 경로가 남는다. 기록은 몇 초 늦어도 되지만 사라지면 안 된다 |
| D3 | 하루치 수신 저장 로직을 `Shared/Persistence/ModelContext+WatchRecord.swift` 로 옮긴다 | `Shared/` 에 두어야 워치 테스트가 닿는다. 워치 타깃은 `PersistenceCore` 를 링크하지 않으므로 `PersistenceService` 대신 `ModelContext` 를 직접 쓴다 (`ModelContext+RecordDeletion.swift` 와 같은 형태) |
| D4 | 칼로리는 **활동 칼로리로 통일**하고 루트 `CLAUDE.md` 워크아웃 계약에 적는다 | 골프·Ralli 는 이미 목록·요약이 활동 칼로리다. 하루치만 총 칼로리이고, 하루치 안에서도 import 기록은 활동이라 같은 칸이 출처마다 다른 뜻이다 |
| D5 | 하루치 잔디 집계(`GrassAggregator`)의 칼로리 입력은 **이번에 바꾸지 않는다** | 칼로리 기준 농도는 아직 쓰지 않는다 (컷 미정, 잔디 스펙 9절). 칼로리 기준을 켤 때 함께 정한다 |
| D6 | Ralli `WorkoutEndMessage` 는 **워치 → 폰만 `.queued`**, 폰 → 워치는 `.reliable` 유지 | 워치 → 폰 종료 메시지는 세션 기록의 유일한 운반체다 (Ralli 9/21 작업 기록). 폰 → 워치는 "운동을 끝내라"는 명령이라 늦게 도착하면 안 된다. 미러 화면이 몇 초 늦게 닫힐 수 있다 — 검증에서 본다 |
| D7 | Ralli 워치는 ACK 시간 초과를 **"실패"가 아니라 "폰 대기"** 로 보인다 | 큐로 보내면 폰 앱이 꺼져 있을 때 8초 안에 ACK 가 올 수 없다. 워치 `handleMatchSaveResult` 가 늦은 ACK 도 받아 "저장됨"으로 바꾸므로 화면 재설계 없이 상태 하나만 더한다. 폰이 실제로 저장에 실패해 `success: false` 를 보낸 경우만 "실패" |

## Global Constraints

- **`.reliable` · `.realtimeOnly` · `.context` 동작은 한 줄도 바뀌지 않는다**
- 메시지 와이어 형식은 그대로 — 구버전 워치가 보낸 메시지도 새 폰 앱이 받는다
- 워치 `WorkoutRecordSending` · `RoundTransmitting` 프로토콜 시그니처는 그대로 — 기존 ViewModel 테스트와 스파이 무수정
- 하루치 실패 알림(`alerts.report(.saveFailed)`)과 `rollback()` 동작은 유지한다
- Ralli upsert 는 `matchId` 기준이라 중복 배달은 안전하다 — 재시도·큐 중복을 따로 막지 않는다
- `.xcodeproj` 는 수정하지 않는다 (파일 추가만 — `PBXFileSystemSynchronizedRootGroup`)
- 새 문자열은 String Catalog 의미 키로 ko · en 둘 다 넣는다

## Review Focus

1. **폰 앱이 꺼진 상태에서 끝낸 운동·경기** — 이번 버그의 주 경로. 실기기에서만 확인된다 → 각 PR 검증
2. **하루치: import 가 먼저 만든 근력 기록이 워치 기록으로 바로잡히는가** — 큐 배달은 늦을 수 있어 이 순서가 흔해진다 → Task 3 `importedRecordIsCorrectedByWatchRecord`
3. **밀린 기록 여러 개가 한꺼번에 도착** — 하나도 빠지지 않는가 → Task 3 `consecutiveMessagesAreAllSaved` · 검증
4. **Ralli: 대기 중 저장 요청이 새 경기 시작에 지워지지 않는가** — `iOSApp.swift:64` · `:99` 제거 → Task 6 · 검증
5. **`activationState` 가드** — `send` 는 세션이 활성화 전이면 조용히 버린다. 저장은 운동 시작 후 수 분 뒤라 실제로는 활성화돼 있지만, `.queued` 에서도 같은 가드를 둔다는 것을 알고 간다

---

## PR 1 — 하루치 · 골프 전송 유실 수정 (`fix/watch-record-delivery`)

### Task 1 — YJKit: `.queued` 전송 추가

**Files:**
- Modify: `Packages/YJKit/Sources/ConnectivityCore/Delivery.swift` — `case queued` 추가. 주석: "항상 `transferUserInfo`. 지연은 괜찮고 유실은 안 되는 기록용"
- Modify: `Packages/YJKit/Sources/ConnectivityCore/ConnectivityService.swift` — `switch delivery` 에 `.queued: WCSession.default.transferUserInfo(dict)`. iOS `isWatchAppInstalled` 가드는 `.reliable` 과 같이 두지 않는다
- Modify: `Packages/YJKit/README.md` — 전송 방식 설명(222행 부근)에 `.queued` 추가, 예시의 `RoundRecordMessage` 를 `.queued` 로. "완료 기록은 `.queued`, 실시간 명령은 `.reliable`" 기준 한 줄

- [ ] Step 1: 위 세 파일 수정
- [ ] Step 2: `make kit-test KIT_DESTINATION="id=$IOS"` 통과 (WCSession 은 단위 테스트 대상이 아니다 — 기존 `MessageRouterTests` 회귀만 본다)
- [ ] Step 3: 커밋 `✨ feat: ConnectivityCore 에 항상 큐로 보내는 .queued 전송을 더한다`

### Task 2 — 하루치 · 골프 워치가 `.queued` 로 보낸다

**Files:**
- Modify: `Apps/HaruchiFit/WatchApp/Services/ConnectivityService+WorkoutRecord.swift` — `.reliable` → `.queued`, 주석 갱신
- Modify: `Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift` — 177행 주석 갱신 (전송 방식 설명만)
- Modify: `Apps/HaruchiFit/Shared/Services/WorkoutRecordMessage.swift` — 머리 주석의 `.reliable` 표기 갱신
- Modify: `Apps/GolfCounter/WatchApp/Services/RoundTransmitter.swift` — `.reliable` → `.queued`, 틀린 주석 교체
- Modify: `Apps/GolfCounter/docs/specs/watch/2026/2026-08-14-round-transmission-design.md` — 14·180·185행의 `.reliable` 설명을 실제 동작과 `.queued` 로 고친다 (개정 날짜 표기)

- [ ] Step 1: 위 파일 수정
- [ ] Step 2: `HaruchiFitWatchTests` · 골프 워치 테스트(`GolfCounter` 스킴 `-only-testing`) 통과 — 스파이 기반이라 그대로 통과해야 한다
- [ ] Step 3: 커밋 `🐛 fix: 하루치·골프 워치 기록을 항상 큐로 보내 전송 중 유실을 막는다`

### Task 3 — 하루치 폰이 받은 기록을 즉시 저장한다

**Files:**
- Create: `Apps/HaruchiFit/Shared/Persistence/ModelContext+WatchRecord.swift` — `func saveWatchRecord(_ message: WorkoutRecordMessage) throws`.
  `iOSApp.swift` 의 `save(_:)` 규칙을 그대로 옮긴다: `healthKitUUID` 가 있고 기존 기록이 있으면 `updateWorkoutData` 후 `save()`, 없으면 새 기록 `insert` 후 `save()`.
  실패 시 `rollback()` 은 호출부가 한다 (알림과 묶여 있어서)
- Modify: `Apps/HaruchiFit/iOSApp/Services/HaruchiFitConnectivity.swift` — `@Published receivedRecord` 제거. `init(service:onRecord:)` 로 받아 `onReceive` 핸들러에서 바로 호출. `ObservableObject` 를 떼고 골프 `RoundReceiveService` 처럼 일반 클래스로
- Modify: `Apps/HaruchiFit/iOSApp/iOSApp.swift` — `.onReceive(connectivity.$receivedRecord…)` 와 `save(_:)` 제거.
  `init` 에서 `context` · `alerts` 를 먼저 만든 뒤 `HaruchiFitConnectivity(service:onRecord:)` 를 만든다 (`@StateObject` → `private let`).
  핸들러: `do { try context.saveWatchRecord(message) } catch { context.rollback(); print(...); alerts.report(.saveFailed) }`
- Create: `Apps/HaruchiFit/watchosTests/Models/WatchRecordSaveTests.swift`
  - `newRecordIsInserted` — 새 UUID 면 기록 1건 · 구간 그대로
  - `resendKeepsAnnotations` — 같은 UUID 재전송 시 부위·메모·영속 ID 유지 (저장 함수 경로로)
  - `importedRecordIsCorrectedByWatchRecord` — `WorkoutRecord.make(from:)` 로 근력 1구간 기록을 먼저 넣고, 같은 UUID 의 근력·유산소 메시지를 저장하면 구간이 메시지대로 바뀌고 `source == .watch`, `totalCalories` 가 메시지 값
  - `consecutiveMessagesAreAllSaved` — 서로 다른 UUID 두 개를 연달아 저장하면 둘 다 남는다
  - `recordWithoutUUIDIsInserted` — UUID 가 nil 이면 중복 검사 없이 추가

- [ ] Step 1: 테스트 먼저 작성 → 실패 확인
- [ ] Step 2: 저장 함수 작성 → 테스트 통과
- [ ] Step 3: `HaruchiFitConnectivity` · `iOSApp.swift` 연결 → `HaruchiFit` iOS 빌드 통과
- [ ] Step 4: 커밋 `🐛 fix: 하루치 폰이 워치 기록을 화면과 무관하게 받는 즉시 저장한다`

### PR 1 검증

1. 자동 — `make kit-test` · `HaruchiFitWatchTests` · 골프·Ralli 테스트 · 세 앱 iOS·워치 빌드 · `make lint` · `make format`
2. **실기기 (하루치)** — 근력·유산소를 번갈아 넣은 운동을 아래 세 상태에서 끝내고 저장한다. 각각 폰 기록에 **구간이 나뉘어 있는지**,
   폰 `kcal` 이 **워치 요약보다 큰지** 본다 (PR 2 전에는 총 칼로리 표기라서)
   - [ ] 폰 앱을 켜 둔 채
   - [ ] 폰 앱을 백그라운드로 둔 채
   - [ ] 폰 앱을 완전히 종료한 채 → 운동 2개를 연달아 끝낸 뒤 폰 앱을 연다 (밀린 기록 2건이 다 들어오는지)
3. **실기기 (골프)** — 폰 앱을 종료한 채 라운드를 끝내고 저장 → 폰 앱을 열면 라운드가 있다

PR: 일반 merge commit (`gh pr merge <n> --merge --delete-branch`)

---

## PR 2 — 하루치 칼로리를 활동 칼로리로 통일 (`fix/haruchi-active-calories`)

지금 상태:

| 앱 | 목록·요약의 대표 칼로리 |
|---|---|
| 골프 | 활동 (`RoundMetrics+WorkoutResult.swift:10`) |
| Ralli | 활동 (`SessionCard.swift:85` · `SummaryViewModel.swift:72`). 상세는 활동·총을 라벨 붙여 둘 다 |
| 하루치 | **총** — 하루치만 다르다 |

### Task 4 — 목록 · 상세의 `kcal` 을 활동 칼로리로 · 계약에 적는다

**Files:**
- Modify: `Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift` — 92행 `record.totalCalories` → `record.activeCalories`. "잔디 칼로리 기준과 같은 값" 주석은 D5 에 맞게 고친다
- Modify: `Apps/HaruchiFit/Shared/Models/RecordDetailBuilder.swift` — 16행 `record.totalCalories` → `record.activeCalories`
- Modify: `Apps/HaruchiFit/watchosTests/Models/RecordListBuilderTests.swift` · `RecordDetailBuilderTests.swift` — 활동 ≠ 총 인 픽스처로 **활동 값이 나오는지** 기대값 갱신
- Modify: `CLAUDE.md` (루트) — "워크아웃 동작 계약"에 한 줄: "목록·요약의 대표 칼로리는 **활동 칼로리**. 총 칼로리는 상세에서 라벨을 붙여 따로 보인다"
- 바꾸지 않음: `GrassAggregator` (D5) · `RecordShareBuilder` (이미 활동·총을 따로 넘긴다) · 저장 모델 (두 값 모두 계속 저장한다) · 골프·Ralli (이미 맞다)

- [ ] Step 1: 테스트 기대값 먼저 바꿈 → 실패 확인
- [ ] Step 2: 두 빌더 수정 · `CLAUDE.md` 한 줄 → `HaruchiFitWatchTests` 통과 · iOS 빌드 · lint
- [ ] Step 3: 실기기 — 폰 `kcal` 이 워치 요약 숫자와 같다
- [ ] Step 4: 커밋 `🐛 fix: 하루치 기록 칼로리를 워치 요약과 같은 활동 칼로리로 보여 준다`

PR: 일반 merge commit

---

## PR 3 — Ralli 경기 저장 유실 수정 (`fix/ralli-match-save-delivery`)

PR 1 머지 뒤 착수 (`.queued` 가 필요하다).

### Task 5 — 워치가 저장·종료 기록을 큐로 보내고, 시간 초과를 "폰 대기"로 보인다

**Files:**
- Modify: `Apps/TennisCounter/Shared/Services/MatchConnectivity.swift`
  - `sendMatchSave` — `.reliable` → `.queued` (워치만 부른다)
  - `sendWorkoutEnd` — `#if os(watchOS)` 이면 `.queued`, iOS 는 `.reliable` 유지 (D6)
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
  - `SaveAckState` 에 `case waiting` 추가 (D7). ACK 시간 초과 → `.failed` 대신 `.waiting`
  - `handleMatchSaveResult` 가드에 `.waiting` 추가 — 늦은 ACK 가 "저장됨"으로 바꾼다
  - 시간 초과 non-fatal(`Ralli.Save` code 3) 기록은 유지한다 — 폰이 얼마나 자주 늦는지 보는 신호다
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionView.swift` — 96~97행 매핑에 `.waiting` → `SaveButtonState.waiting`
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/Match/Result/Components/SaveButton.swift` — `case waiting`: 아이콘 `iphone.radiowaves.left.and.right` · 회색 · 비활성 · 문구 `result_save_waiting`
- Modify: `Apps/TennisCounter/WatchApp/Localizable.xcstrings` — `result_save_waiting` (ko "폰에서 저장 대기" · en "Saving on iPhone")
- Modify: `Apps/TennisCounter/watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`
  - `ackTimeoutShowsWaiting` — 시간 초과 시 `.waiting`
  - `lateAckAfterTimeoutShowsSucceeded` — `.waiting` 에서 성공 ACK → `.succeeded`
  - `failureAckShowsFailed` — `success: false` ACK → `.failed` (기존 테스트 갱신)

- [ ] Step 1: 테스트 먼저 → 실패 확인
- [ ] Step 2: 구현 → `TennisCounter Watch App` 스킴 테스트 통과
- [ ] Step 3: 커밋 `🐛 fix: Ralli 워치가 경기 저장을 큐로 보내고 응답이 늦으면 폰 대기로 보인다`

### Task 6 — 폰이 앱 루트에서 경기 저장을 받는다

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Services/WatchMatchSaver.swift` — `WorkoutSessionRecorder` 와 같은 구조.
  `init(connectivity: MatchConnectivity = .shared, store: MatchUpserting = MatchPersistenceService.shared, crashReporter:, sendResult: (MatchSaveResultMessage) -> Void = { MatchConnectivity.shared.sendMatchSaveResult($0) })`.
  `$receivedMatchSave` 구독 → `receivedMatchSave = nil` → `save(_:)`.
  `save(_:)` 는 `Match` 를 만들어 upsert 하고, 실패하면 `Ralli.Save` code 2 를 기록하고, 결과 ACK 를 보낸다. 테스트가 직접 부른다
  - `buildMatchFromMessage` 를 iOS VM 에서 이리로 옮긴다
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` — `$receivedMatchSave` 구독(122~128행) · `saveFromWatch` · `buildMatchFromMessage` · `saveFromWatchForTest` 제거
- Modify: `Apps/TennisCounter/iOSApp/iOSApp.swift`
  - `init` 에서 `MatchPersistenceService.shared.configure` 뒤에 `matchSaver = WatchMatchSaver()` 를 만들어 잡아 둔다
  - 64행 · 99행의 `connectivity.receivedMatchSave = nil` 제거 — 대기 중 저장 요청을 지우지 않는다
- Create: `Apps/TennisCounter/iosTests/Services/WatchMatchSaverTests.swift`
  - `saveFromWatchPersistsMatch` · (Code 2 기록 테스트) — `WorkoutSessionViewModelTests.swift` 422행 · 766행 테스트를 이리로 옮긴다
  - `saveSendsSuccessAck` — 저장 성공 시 `success: true` ACK 1건
  - `saveFailureSendsFailureAck` — upsert 실패 시 `success: false` ACK
  - `duplicateDeliveryKeepsOneMatch` — 같은 `matchId` 를 두 번 저장해도 1건
- Modify: `Apps/TennisCounter/iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` — 옮긴 두 테스트 제거

- [ ] Step 1: 테스트 먼저 → 실패 확인
- [ ] Step 2: `WatchMatchSaver` 작성 · VM · `iOSApp.swift` 정리 → `TennisCounter` 스킴 테스트 통과 · 워치·Live Activity·컴플리케이션 빌드
- [ ] Step 3: 커밋 `🐛 fix: Ralli 폰이 경기 화면과 무관하게 워치 경기 저장을 받는다`

### PR 3 검증

1. 자동 — `TennisCounter` · `TennisCounter Watch App` 테스트 · 네 스킴 빌드 · `make lint` · `make format`
2. **실기기 (Ralli)** — 워치 드라이버로 경기를 끝내고 저장한다
   - [ ] 폰 앱 경기 화면이 열린 채 → 워치 "저장됨" · 폰 기록 탭에 1건
   - [ ] 폰 앱을 백그라운드로 둔 채 → 워치 "저장됨" 또는 "폰에서 저장 대기" → 폰 앱을 열면 기록 1건 (워치 결과 화면이 떠 있으면 "저장됨"으로 바뀐다)
   - [ ] 폰 앱을 완전히 종료한 채 → 경기 2개 저장 → 폰 앱을 열고 **바로 새 경기를 시작**해도 2건 다 남는다 (Review Focus 4)
   - [ ] 운동 종료 시 폰 미러 화면이 닫히는 지연이 견딜 만한지 (D6)
3. **빌드 구분** — Ralli 는 `CURRENT_PROJECT_VERSION = 1` 고정이라 App Store 1.1.9 와 Xcode 설치본이 둘 다 "1.1.9 (1)"로 보인다. 검증 전에 Xcode 설치본인지 확인한다

PR: 일반 merge commit

---

## 범위 밖 — 별도 플랜

### 워크아웃 종료 순서 (YJKit `WorkoutCore`, 세 앱 공통)

- `Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift:134` 의 `stopWorkout()` 은 `session.end()` 를 **먼저** 부른다.
  그다음에 `endCollection` · 통계 수집 · `finishWorkout()`(152행, `try?`)을 await 한다
- 세션이 끝나면 워치 앱은 백그라운드 실행 권한을 잃는다. 손목을 내리면 앱이 멈췄다가 다음 활성화 때 마저 실행된다.
  Ralli 9/23 종료 시각이 약 1.5시간 밀린 것([작업 기록](../../../Apps/TennisCounter/docs/logs/2026/2026-09-28-crown-focus-and-session-end-time.md))과 10-21 저장 지연이 이것이다
- 앱이 다시 깨어나기 전에 시스템이 종료하면 **HealthKit 운동과 폰 기록이 둘 다 사라질 수 있다.** 하루치는 이 경우 건강 앱 import 기록조차 생기지 않는다
- 고치는 방향: `session.stopActivity(with:)` 를 먼저 부른다 (`.stopped` 상태에서는 앱이 계속 돈다) → `endCollection` · `finishWorkout` · 종료 메시지 전송을 마친다 → `session.end()`.
  함께 볼 것: `didFailWithError`(250행)가 비어 있고, `startWorkout` 의 `catch {}`(103행)가 오류를 삼키고, 워크아웃 복구(`handleActiveWorkoutRecovery`)가 없다
- 세 앱의 종료 흐름을 다 바꾸고 실기기 확인이 많아 이 플랜에서 뺐다

### 그 밖

- 하루치 1.0.1 · 골프 · Ralli 출시 작업(버전 올림 · `APPSTORE.md` 출시 노트)은 이 플랜이 아니라 각 출시 커밋에서 한다
