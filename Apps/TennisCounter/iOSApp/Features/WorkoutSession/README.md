# WorkoutSession Feature (iOS)

iOS 워크아웃 세션 컨테이너 Feature. Watch에서 보내는 메시지를 수신해 화면을 전환하고, 자체 타이머로 경과 시간을 관리하며, SwiftData에 경기를 저장한다.

Watch 버전과 대칭 구조이지만 HealthKit을 직접 제어하지 않는다는 점이 핵심 차이다.

## 파일 구조

| 파일 | 역할 |
|------|------|
| `WorkoutSessionView.swift` | 2-탭 TabView 컨테이너 (Workout / Match) |
| `WorkoutSessionViewModel.swift` | 타이머 + MatchPhase + Watch 메시지 수신 + SwiftData 저장 |
| `Components/WorkoutIndicator.swift` | 경기 중 툴바에 표시되는 운동 경과 시간 |

---

## WorkoutSessionView

TabView로 2개 탭을 전환한다.

```
[Workout 탭]          [Match 탭 (기본)]
  칼로리/BPM/경과       phase에 따라
  일시정지/종료 버튼      ModeView / ScoreView / MatchResultView
```

`scoreTabContent`에서 `viewModel.phase`를 switch해 경기 화면을 전환한다.

```
phase = .modeSelection  →  ModeView
phase = .playing        →  ScoreView
phase = .finished       →  MatchResultView
```

`@StateObject`로 ViewModel을 직접 생성·소유한다.

### View가 직접 관리하는 상태 (@State)

ViewModel에 넣지 않고 View에 `@State`로 두는 값들 — 비즈니스 로직과 무관한 순수 UI 상태다.

| 프로퍼티 | 역할 |
|---------|------|
| `selectedTab` | 현재 선택된 탭 인덱스 |
| `showEndMatchConfirm` | 경기 중도 종료 확인 Alert 표시 여부 |
| `showEndWorkoutConfirm` | 워크아웃 종료 확인 Alert 표시 여부 |
| `hasMatchProgress` | 점수 진행이 있는지 여부 (뒤로가기 시 확인 Alert 조건) |

---

## WorkoutSessionViewModel

`@MainActor`와 `ObservableObject`를 함께 선언한다. 모든 `@Published` 값 변경이 메인 스레드에서 실행되도록 컴파일러가 보장한다.

### 핵심 상태 (@Published)

| 프로퍼티 | 역할 |
|---------|------|
| `phase: MatchPhase` | 화면 전환 기준 (modeSelection / playing / finished) |
| `elapsedSeconds: Int` | 자체 타이머로 계산한 경과 시간 (HealthKit 없이 iOS가 직접 측정) |
| `metrics: WorkoutMetrics` | Watch에서 받은 칼로리/BPM — 수신 즉시 반영 |
| `watchConnected: Bool` | Watch 연결 상태 |
| `isPaused: Bool` | 일시정지 상태 |
| `completedMatchCount: Int` | 이번 워크아웃 세션에서 완료한 경기 수 |
| `remoteWorkoutEnded: Bool` | Watch가 워크아웃 종료했을 때 View가 onExit() 트리거로 사용 |

### 내부 핵심 프로퍼티

| 프로퍼티 | 타입 | 역할 |
|---------|------|------|
| `sessionId` | `UUID` | 현재 세션 식별자. 원격 채택 시 상대 UUID로 덮어씀 |
| `isDriver` | `Bool` | iOS가 점수를 주도하면 true, Watch 주도 시 false (mirror) |
| `hasSyncedSession` | `Bool` | 세션을 한 번이라도 시작했는지 여부. workoutEnd·matchReset sessionId 가드의 전제 조건 |

### Watch vs iOS 역할 비교

| 역할 | Watch | iOS |
|------|-------|-----|
| HealthKit | 직접 제어 (startWorkout/stopWorkout) | 없음 |
| 경과 시간 | HealthKit.elapsedSeconds | 자체 Timer로 측정 |
| 칼로리/BPM | HealthKit에서 측정 후 iOS에 전송 | Watch에서 받아 표시 |
| 저장 | 불가 → iOS에 요청 | MatchPersistenceService로 직접 저장 |
| Live Activity | 없음 | LiveActivityService로 시작/업데이트/종료 |

### 타이머 동작 방식

```
startSession()
  startedAt = Date()  ←  기준 시각 저장

Timer (1초마다)
  elapsedSeconds = Date() - startedAt - totalPausedSeconds

pauseSession()
  pausedAt = Date()  ←  멈춘 시각 저장
  timer 무효화

resumeSession()
  totalPausedSeconds += Date() - pausedAt  ←  정지 시간 누적
  timer 재시작
```

### init에서 구성하는 Combine 바인딩

```
setupScoreSync()
  connectivity.$isWatchReachable (Watch 재연결)  →  sessionStart + scoreState 재전송
  scoreVM.onStateChanged + isDriver              →  LiveActivity 업데이트 + iOS→Watch 전송
  connectivity.$receivedScoreState               →  handleIncomingScoreState()

setupConnectivityBindings()
  connectivity.$isWatchReachable   →  watchConnected
  connectivity.$receivedMetrics    →  metrics 업데이트 (칼로리/BPM)

setupMatchLifecycleBindings()
  connectivity.$receivedSessionStart  →  handleIncomingSessionStart()
  connectivity.$receivedMatchEnd      →  phase = .finished (결과 화면)
  connectivity.$receivedMatchSave     →  saveFromWatch() → SwiftData 저장 + ACK 회신
  connectivity.$receivedWorkoutEnd    →  handleIncomingWorkoutEnd()
  connectivity.$receivedMatchReset    →  handleIncomingMatchReset()
```

### 경기 흐름

```
startMatch(options:, sessionId:, isRemote:)
  isDriver = !isRemote
  hasSyncedSession = true
  sessionId: 원격 채택(isRemote=true)이면 상대 UUID로 덮어씀  ← workoutEnd·matchReset 가드 연동
  scoreVM.resetAll(options:)  ←  명시적 초기화 (view 재생성에 의존하지 않음)
  phase = .playing
  liveActivity.start(mode:)
  (isDriver인 경우만) connectivity.sendSessionStart(...)

startNewMatch(notifyRemote:)
  (isDriver + .playing 상태인 경우) connectivity.sendMatchReset(sessionId:)
  phase = .modeSelection

endSession(notifyRemote:)
  timer 중지, 상태 초기화
  liveActivity.end()
  connectivity.clearSessionContext()  ←  상대 콜드 런치 시 stale 세션 채택 방지
  (notifyRemote=true인 경우) connectivity.sendWorkoutEnd(sessionId:)
```

### matchReset / workoutEnd 가드 패턴

driver가 진행 중 매치를 중간 종료(뒤로가기)하면 `sendMatchReset`을 전송한다. mirror(iOS)는 이 신호를 받아 모드선택으로 복귀한다.

```
handleIncomingMatchReset(id: UUID)
  guard !isDriver          ←  driver는 자기 신호 무시
  if hasSyncedSession, id != sessionId { return }  ←  다른 세션 신호 무시
  startNewMatch(notifyRemote: false)

handleIncomingWorkoutEnd(id: UUID)
  if hasSyncedSession, id != sessionId { return }  ←  다른 세션의 workoutEnd 무시
  endSession(notifyRemote: false)
  remoteWorkoutEnded = true  ←  View가 dismiss 트리거로 사용
```

`hasSyncedSession`이 false이면 (매치를 한 번도 시작하지 않아 sessionId가 아직 동기화 안 된 상태) 가드를 건너뛰고 무조건 수용한다.

### 동시 시작 race condition

두 기기가 동시에 경기를 시작할 때는 sessionId UUID 문자열 비교로 우선순위를 결정한다.

```swift
// handleIncomingSessionStart
if case .playing = phase {
    guard isDriver, msg.sessionId.uuidString < sessionId.uuidString else { return }
}
// → 더 작은 UUID를 가진 쪽이 driver를 유지. 나머지는 mirror로 전환.
```

### 저장 흐름 두 가지

**Watch가 저장 버튼 누른 경우 (receivedMatchSave)**

```
Watch → sendMatchSave(MatchEndMessage)
iOS   → saveFromWatch(msg)
        buildMatchFromMessage(msg) → Match 객체 생성
        MatchPersistenceService.shared.upsert(match)
        sendMatchSaveResult(sessionId:success:) → Watch에 ACK 회신
```

**iOS에서 직접 저장하는 경우 (saveCurrentMatch)**

```
iOS 저장 버튼 탭
→ saveCurrentMatch()
   buildMatchFromSession(_currentSession) → Match 객체 생성
   MatchPersistenceService.shared.upsert(match)
```

`upsert`는 `workoutSessionId`로 기존 Match를 조회해 있으면 삭제 후 insert, 없으면 insert. driver/mirror 양쪽에서 저장해도 History에 중복 기록되지 않는다.

---

## 점수 로직

### Score (Shared/Models/Score.swift)

게임 내 포인트 상태를 관리하는 `ObservableObject`. iOS·Watch 공유.

```
일반 모드 (NormalState):
  .zero → .fifteen → .thirty → .forty
  .forty + 상대도 .forty:
    noAdRule=true  → 즉시 승리 (no-ad 규칙)
    noAdRule=false → .advantage (어드밴티지)
  .advantage → 다음 포인트 승리 / 상대가 포인트 시 .forty(듀스)로 복귀

타이브레이크 모드 (myTieBreak / yourTieBreak 정수):
  한 쪽이 7점 이상 + 2점차 이상 → 게임 승리
```

| 메서드 | 역할 |
|-------|------|
| `addPoint(_ side:)` | 포인트 추가. 게임이 끝나면 승리 측(`PlayerSide?`) 반환. 호출 시 SnapShot 저장 |
| `undo()` | 마지막 `addPoint` 직전 상태로 복원. SnapShot은 1단계만 보관 |
| `reset()` | 0-0으로 초기화 (게임 승리 후 다음 게임 시작) |
| `setTieBreakMode()` | 타이브레이크 모드 전환 + 카운터 0-0 초기화 |
| `applyRemote(myScore:yourScore:isTieBreak:)` | 원격 상태를 직접 덮어쓰기. SnapShot 파기 |

표시값 (`myDisplayScore` / `yourDisplayScore`): 일반 모드는 "0"/"15"/"30"/"40"/"AD", 타이브레이크는 정수 그대로.

`myScore` / `yourScore`: WatchConnectivity 직렬화 호환용 정수 (`[0, 15, 30, 40, 50]` 매핑). 50은 게임 승리 직전 Advantage 상태가 아닌 구형 인덱스 호환용이며 실제로는 addPoint 반환값으로 게임 종료를 감지한다.

### ScoreViewModel (iOSApp/Features/Match/Score/ScoreViewModel.swift)

게임·세트 레벨 로직. `Score` 인스턴스를 소유한다. `WorkoutSessionViewModel`이 단일 인스턴스(`let scoreVM = ScoreViewModel()`)를 생성·관리한다.

```
addPoint(_ side:)
  guard !isMatchOver
  score.addPoint(side) → gameWon?
  gameWon:  myGameScore++ / yourGameScore++, score.resetData(), checkSetUpdate()
  항상:     onStateChanged?()  ←  WorkoutSessionViewModel이 여기서 LiveActivity 갱신 + 전송

checkSetUpdate()
  threshold (기본 6게임) 기준:
  1. tieBreakInProgress:
       (threshold+1) : threshold 이면 finalizeSet
  2. my == your == threshold:
       noTieRule=false → setTieBreakMode(), tieBreakInProgress=true
       noTieRule=true  → .draw 종료
  3. max >= threshold 이고 2점차 이상 → finalizeSet

finalizeSet(winner:)
  completedSets.append(현재 게임 스코어)
  승자 setScore++, 게임 0-0 초기화, currentSetNumber++
  setScore >= setsToWin → matchResult = .win / .loss
```

| 메서드 | 역할 |
|-------|------|
| `resetAll(options:)` | 새 경기 시작 시 모든 상태 명시적 초기화. options(noAdRule, gameThreshold)도 갱신 |
| `makeScoreState()` | 현재 상태를 `ScoreState`로 직렬화. 타이브레이크이면 `myTieBreak`/`yourTieBreak` 사용 |
| `applyRemoteState(_ state:)` | Watch(driver)에서 받은 `ScoreState`를 덮어씀. mirror(iOS)만 호출 |

### driver / mirror 권한 모델

```
isDriver = true  (iOS가 경기를 시작한 경우)
  onStateChanged → connectivity.sendScoreState(makeScoreState())
  receivedScoreState → 무시 (handleIncomingScoreState의 isDriver 가드)
  점수 입력 → 정상 작동

isDriver = false  (Watch가 경기를 시작, iOS가 mirror인 경우)
  onStateChanged → LiveActivity 갱신만 (전송 안 함)
  receivedScoreState → scoreVM.applyRemoteState(state)
  점수 입력 버튼 → isDriver 가드로 비활성 (long-press 수동 수정도 차단)
```

driver가 보내고 mirror가 받는 단방향 구조라 echo(받은 상태를 다시 되쏘는 현상)가 구조적으로 차단된다. 이전에는 양방향 송수신 + 무조건 덮어쓰기 구조여서 Watch 진행 중 점수가 0으로 리셋되는 버그가 반복 재발했다.

---

## Connectivity 로직

### MatchConnectivity (Shared/Services/MatchConnectivity.swift)

iOS·Watch 공유 싱글턴. RalliKit `ConnectivityCore` 기반으로 메시지를 타입별로 `@Published` 프로퍼티에 파싱·발행한다. ViewModel은 Combine으로 이 프로퍼티를 구독한다.

### 메시지 타입

| 타입 | 방향 | 전송 방식 | 역할 |
|------|------|----------|------|
| `sessionStart` | driver → mirror | `send` | 세션 시작, 포맷 정보 전달 |
| `scoreState` | driver → mirror | `sendReliably` | 포인트마다 전체 점수 스냅샷 |
| `matchEnd` | Watch → iOS | `sendReliably` | 경기 자연 종료 결과 |
| `matchSave` | Watch → iOS | `sendReliably` | 저장 버튼 → iOS persist 요청 |
| `matchSaveResult` | iOS → Watch | `sendReliably` | 저장 성공/실패 ACK |
| `metrics` | Watch → iOS | `sendRealtimeOnly` | 칼로리/BPM 실시간 (reachable 시에만) |
| `workoutEnd` | driver → mirror | `sendReliably` | 워크아웃 전체 종료 신호 |
| `matchReset` | driver → mirror | `sendReliably` | 매치 중간 종료(뒤로가기) 알림 |
| `sessionCleared` | driver (applicationContext) | `updateApplicationContext` | 세션 종료 후 컨텍스트 비우기 |

### 전송 메서드 세 가지

```
send(_:)
  reachable → sendMessage  (즉시 전달)
  아니면    → updateApplicationContext  (마지막 값만 보관, 덮어씀)
  ↑ sessionStart에만 사용. applicationContext가 콜드 런치 채택 경로를 제공한다.

sendReliably(_:)
  reachable → sendMessage  (즉시)
  아니면    → transferUserInfo  (큐잉, 순서 보장, 재시도)
  ↑ 점수·결과·종료 등 유실되면 안 되는 신호에 사용.

sendRealtimeOnly(_:)
  reachable인 경우에만 sendMessage. 아니면 드롭.
  ↑ 칼로리/BPM 실시간 메트릭에만 사용. 유실 무방.
```

### 콜드 런치 채택

앱이 꺼져 있는 동안 `updateApplicationContext`로 도착한 `sessionStart`는 `didReceiveApplicationContext` 델리게이트가 불리지 않고 `session.receivedApplicationContext`에만 남는다. `activationDidCompleteWith`에서 이 프로퍼티를 직접 읽어 대기 중인 sessionStart를 처리한다.

```
activationDidCompleteWith
  context = session.receivedApplicationContext
  비어있으면 종료
  sessionStart이고 workoutStartDate가 6시간+ 오래됐으면 (isSessionStartStale) 종료  ← stale 방어
  handle(context)
```

### clearSessionContext

운동 종료 시 `updateApplicationContext(["type": "sessionCleared"])`로 outgoing 컨텍스트를 비운다. 상대가 이후 콜드 런치해도 종료된 세션을 채택하지 않도록 보장. 워치 크래시 등으로 `clearSessionContext`가 실행되지 못한 경우를 대비해 `isSessionStartStale`(6시간 기준)로 추가 방어선을 확보한다.

### workoutEnd staleness 가드

`transferUserInfo`로 큐잉된 `workoutEnd`는 앱 재실행 후 뒤늦게 배달될 수 있다. `sentAt` 타임스탬프와 현재 시각을 비교해 60초 이상 지났으면 stale로 판단하고 드롭한다 (`isWorkoutEndStale`).

---

## 핵심 개념

### @MainActor

```swift
@MainActor
class WorkoutSessionViewModel: ObservableObject { ... }
```

클래스 전체에 `@MainActor`를 붙이면 모든 프로퍼티·메서드 접근이 메인 스레드에서 실행된다.  
WatchConnectivity 콜백, Timer 콜백은 백그라운드 스레드에서 오기 때문에 Combine 체인에서 `.receive(on: DispatchQueue.main)`으로 전환한 뒤 `@Published` 값을 바꾼다.  
타이머 내부에서 `Task { @MainActor in ... }` 을 쓰는 것도 같은 이유다.

### @Published vs @StateObject

| | `@Published` | `@StateObject` |
|--|-------------|---------------|
| **위치** | ViewModel 클래스 내부 | SwiftUI View 내부 |
| **역할** | 값이 바뀌면 구독자에게 알림 발행 | ViewModel 인스턴스를 생성하고 소유 |
| **생명주기** | ViewModel과 동일 | View가 처음 렌더링될 때 생성, 해제될 때 파괴 |

```swift
// ViewModel: @Published로 변화를 알린다
@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    //           ↑ phase가 바뀌면 objectWillChange 발행 → View 재렌더링
    @Published var elapsedSeconds: Int = 0
}

// View: @StateObject로 ViewModel 인스턴스를 소유한다
struct WorkoutSessionView: View {
    @StateObject private var viewModel = WorkoutSessionViewModel()
    //            ↑ View가 인스턴스를 직접 생성·보유. View가 재생성되어도 유지됨.
}
```

`@State`와의 차이:

| | `@State` | `@StateObject` |
|--|---------|---------------|
| **대상** | `Int`, `Bool`, `String` 등 값 타입 | `ObservableObject` 클래스 인스턴스 (참조 타입) |
| **변화 감지** | 값 자체 교체 | 내부 `@Published` 프로퍼티 변화 |
| **용도** | 순수 UI 상태 (탭 인덱스, Alert 표시 여부) | 비즈니스 로직을 가진 ViewModel |

```swift
// @State: 단순 값, View 전용 UI 상태
@State private var selectedTab: Int = 1
@State private var showEndMatchConfirm = false

// @StateObject: 복잡한 비즈니스 로직을 가진 ViewModel
@StateObject private var viewModel = WorkoutSessionViewModel()
```

`@ObservedObject`와의 차이:
- `@StateObject` — 이 View가 인스턴스를 직접 생성·소유한다.
- `@ObservedObject` — 외부(부모 View 등)에서 주입받는다. 소유권이 없어 View가 재생성되면 교체될 수 있다.

```swift
// 부모가 소유한 ViewModel을 자식에게 넘길 때는 @ObservedObject
WorkoutTabView(
    metrics: viewModel.metrics,     // 값만 전달하는 경우
    onEnd: { ... }                  // 또는 클로저만 전달
)
// 이 프로젝트는 ViewModel 직접 주입 대신 값/클로저를 분리해서 넘기는 방식을 선택함
```
