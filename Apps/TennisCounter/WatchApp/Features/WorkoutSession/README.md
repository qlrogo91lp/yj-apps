# WorkoutSession Feature (Watch)

워크아웃 세션 컨테이너 Feature. HealthKit 세션 생명주기를 관리하고, 경기 흐름(Mode → Score → Result)을 조율하며, iOS 앱과 실시간으로 동기화한다.

## 파일 구조

| 파일 | 역할 |
|------|------|
| `WorkoutSessionView.swift` | 3-탭 TabView 컨테이너 |
| `WorkoutSessionViewModel.swift` | HealthKit + MatchPhase + iOS 동기화 |

---

## WorkoutSessionView

TabView로 3개의 화면을 좌우 스와이프로 전환한다.

```
[← WorkoutControls] [Match 화면 (기본)] [WorkoutMetrics →]
     일시정지/종료        phase에 따라          칼로리/BPM
```

`centerView`에서 `viewModel.phase`를 switch해 경기 흐름을 전환한다.

```
phase = .modeSelection  →  ModeView
phase = .playing        →  ScoreView
phase = .finished       →  MatchResultView
```

`@StateObject`로 ViewModel을 직접 생성·소유한다. View가 재생성되어도 ViewModel 인스턴스는 유지된다.

---

## WorkoutSessionViewModel

`@MainActor`와 `ObservableObject`를 함께 선언한다. 모든 `@Published` 값 변경이 메인 스레드에서 실행되도록 컴파일러가 보장한다.

### 핵심 상태 (@Published)

| 프로퍼티 | 역할 |
|---------|------|
| `phase: MatchPhase` | 화면 전환 기준 (modeSelection / playing / finished) |
| `isPaused: Bool` | HealthKit 일시정지 상태 — View의 버튼 표시에 반영 |
| `lastMetrics: WorkoutMetrics?` | iOS로 전송하는 칼로리/BPM 스냅샷 |
| `remoteWorkoutEnded: Bool` | iOS가 워크아웃 종료했을 때 View가 dismiss 트리거로 사용 |
| `saveAckState: SaveAckState` | iOS 저장 ACK 상태 (idle / pending / succeeded / failed) |

### 소유 객체

| 프로퍼티 | 역할 |
|---------|------|
| `healthKit` | HealthKitService — 워크아웃 세션, 칼로리/BPM |
| `connectivity` | MatchConnectivity — iOS 통신 |
| `scoreVM` | ScoreViewModel — 점수 상태 (게임/세트 로직) |

### 내부 핵심 프로퍼티

| 프로퍼티 | 타입 | 역할 |
|---------|------|------|
| `workoutSessionId` | `UUID` | 이 기기의 워크아웃 세션 고정 식별자 |
| `activeSessionId` | `UUID` | 현재 진행 중 경기 식별자. 원격 채택 시 상대 UUID로 덮어씀 |
| `isDriver` | `Bool` | 이 Watch가 점수를 주도하면 true, iOS 주도 시 false (mirror) |
| `hasSyncedSession` | `Bool` | 세션을 한 번이라도 시작했는지 여부. workoutEnd·matchReset sessionId 가드의 전제 조건 |
| `saveAttemptToken` | `Int` | 재시도로 새 저장 시도가 시작된 뒤 이전 타임아웃이 상태를 덮어쓰지 못하게 막는 표식 |

### isDriver 패턴

```
isDriver = true  → 이 Watch가 점수를 주도
                   점수 변경 시 iOS에 ScoreState 전송
                   (scoreVM.onStateChanged → connectivity.sendScoreState)

isDriver = false → 상대(iOS)가 주도
                   받은 ScoreState를 applyRemoteState()로 적용만 함
                   점수 입력 버튼 비활성 (MirrorBadge 표시)
```

### 경기 흐름

```
startWorkout()
  HealthKit 권한 요청 후 세션 시작
  AppGroup defaults: isWorkoutActive = true
  WidgetCenter 갱신 (Complication 업데이트)

startMatch(options:, sessionId:, isRemote:)
  isDriver = !isRemote
  hasSyncedSession = true
  saveAckState = .idle
  activeSessionId: 원격 채택이면 상대 UUID로 맞춤  ← workoutEnd·matchReset 가드 연동
  scoreVM.resetAll(options:)  ←  명시적 초기화
  phase = .playing
  (isDriver인 경우만) connectivity.sendSessionStart(...)

(scoreVM.onMatchFinished 콜백)
  finishMatch(result:completedSets:)
    phase = .finished
    HealthKit.averageHeartRate 비동기 조회 후 sendMatchEndToiOS()

saveCurrentMatch()
  Watch엔 로컬 저장소 없음 → iOS에 matchSave 요청 (sendReliably)
  saveAckState = .pending
  ackTimeoutSeconds(8초) 후 ACK 없으면 .failed

startNewMatch(notifyRemote:)
  (isDriver + .playing 상태인 경우) connectivity.sendMatchReset(sessionId: activeSessionId)
  phase = .modeSelection
  saveAckState = .idle

endWorkout(notifyRemote:)
  _currentSession = nil
  AppGroup defaults: isWorkoutActive = false
  WidgetCenter 갱신
  connectivity.clearSessionContext()  ←  상대 콜드 런치 시 stale 세션 채택 방지
  (notifyRemote=true인 경우) connectivity.sendWorkoutEnd(sessionId: activeSessionId)
  healthKit.stopWorkout()
```

### init에서 구성하는 Combine 바인딩

```
1. healthKit.$isPaused  →  self.$isPaused (assign)

2. setupConnectivityBindings()
   connectivity.$receivedSessionStart    →  handleIncomingSessionStart()
   connectivity.$receivedWorkoutEnd      →  handleIncomingWorkoutEnd()
   connectivity.$receivedMatchReset      →  handleIncomingMatchReset()
   connectivity.$receivedMatchSaveResult →  handleMatchSaveResult()

3. setupScoreSync()
   scoreVM.onMatchFinished               →  finishMatch(result:completedSets:)
   scoreVM.onStateChanged + isDriver     →  connectivity.sendScoreState()
   connectivity.$receivedScoreState      →  scoreVM.applyRemoteState()
   connectivity.$isWatchReachable        →  재연결 시 현재 scoreState 재전송

4. healthKit.$currentHeartRate (5초 throttle)  →  broadcastMetrics()  →  iOS 전송
```

`.receive(on: DispatchQueue.main)`을 Combine 체인마다 붙이는 이유: WatchConnectivity 콜백이 백그라운드 스레드에서 오기 때문에 `@Published` 값을 바꾸기 전 메인 스레드로 전환한다.

### matchReset / workoutEnd 가드 패턴

```
handleIncomingMatchReset(id: UUID)
  guard !isDriver          ←  driver는 자기 신호 무시
  if hasSyncedSession, id != activeSessionId { return }  ←  다른 세션 신호 무시
  startNewMatch(notifyRemote: false)

handleIncomingWorkoutEnd(id: UUID)
  if hasSyncedSession, id != activeSessionId { return }  ←  다른 세션의 workoutEnd 무시
  endWorkout(notifyRemote: false)
  remoteWorkoutEnded = true  ←  View가 dismiss 트리거로 사용
```

`hasSyncedSession`이 false이면 (매치를 한 번도 시작하지 않아 sessionId가 아직 동기화 안 된 상태) 가드를 건너뛰고 무조건 수용한다.

### 저장 ACK 패턴 (SaveAckState)

Watch는 로컬 저장소가 없으므로 iOS에 `matchSave`를 보내고 ACK(`matchSaveResult`)를 기다린다.

```
saveCurrentMatch()
  saveAttemptToken++
  saveAckState = .pending
  connectivity.sendMatchSave(...)
  DispatchQueue.main.asyncAfter(+8초) {
      if saveAttemptToken == token, saveAckState == .pending → .failed
  }

handleMatchSaveResult(result:)
  guard result.sessionId == activeSessionId  ←  다른 세션 ACK 무시
  guard saveAckState == .pending || .failed
  saveAckState = result.success ? .succeeded : .failed
```

`saveAttemptToken`이 필요한 이유: 재시도로 `saveAttemptToken`이 증가한 뒤, 이전 시도의 지연된 타임아웃 클로저가 새 pending 상태를 `.failed`로 덮어쓰지 않도록 막는다.

### 동시 시작 race condition

두 기기가 동시에 경기를 시작하면 sessionId UUID 문자열 비교로 우선순위를 결정한다.

```swift
// handleIncomingSessionStart
guard isDriver, msg.sessionId.uuidString < workoutSessionId.uuidString else { return }
// → 더 작은 UUID를 가진 쪽이 driver를 유지. 나머지는 mirror로 전환.
```

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

### ScoreViewModel (WatchApp/Features/Match/Score/ScoreViewModel.swift)

게임·세트 레벨 로직. `Score` 인스턴스를 소유한다. `WorkoutSessionViewModel.init()`에서 `onMatchFinished` 콜백을 연결하고, 단일 인스턴스(`let scoreVM = ScoreViewModel(...)`)로 유지한다.

```
addPoint(_ side:)
  score.addPoint(side) → gameWon?
  gameWon:  withAnimation { myGameScore++ / yourGameScore++ }, score.reset(), checkSetUpdate()
  항상:     onStateChanged?()  ←  WorkoutSessionViewModel이 여기서 sendScoreState 전송

checkSetUpdate()
  threshold (기본 6게임) 기준:
  1. tieBreakInProgress:
       (threshold+1) : threshold 이면 finalizeSet
  2. my == your == threshold:
       noTieRule=false → setTieBreakMode(), tieBreakInProgress=true
       noTieRule=true  → onMatchFinished(.draw, ...)
  3. max >= threshold 이고 2점차 이상 → finalizeSet

finalizeSet(winner:)
  completedSets.append(현재 게임 스코어)
  승자 setScore++, 게임 0-0 초기화
  setScore >= setsToWin → onMatchFinished(.win/.loss, completedSets)
```

| 메서드 | 역할 |
|-------|------|
| `resetAll(options:)` | 새 경기 시작 시 모든 상태 명시적 초기화. options(noAdRule, gameThreshold)도 갱신 |
| `makeScoreState()` | 현재 상태를 `ScoreState`로 직렬화. 타이브레이크이면 `myTieBreak`/`yourTieBreak` 사용 |
| `applyRemoteState(_ state:)` | iOS(driver)에서 받은 `ScoreState`를 덮어씀. mirror(Watch)만 호출 |

**전송 타이밍 주의:** `onStateChanged`는 반드시 `score.reset()` → `checkSetUpdate()` 순서 이후에 호출해야 한다. 이전에 `sendScoreState`가 `score.reset()` 직후(`checkSetUpdate` 전)에 있어 인게임 점수가 항상 0으로 전송되는 버그가 있었다 (2026-06-24 분석).

### driver / mirror 권한 모델

```
isDriver = true  (이 Watch가 경기를 시작한 경우)
  onStateChanged → connectivity.sendScoreState(makeScoreState())
  receivedScoreState → 무시 (handleIncomingScoreState의 isDriver 가드)
  점수 입력 → 정상 작동

isDriver = false  (iOS가 경기를 시작, Watch가 mirror인 경우)
  onStateChanged → 전송 안 함 (isDriver 가드)
  receivedScoreState → scoreVM.applyRemoteState(state)
  점수 입력 버튼 → isDriver 가드로 비활성 (MirrorBadge 표시)
```

driver가 보내고 mirror가 받는 단방향 구조라 echo(받은 상태를 다시 되쏘는 현상)가 구조적으로 차단된다.

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
SwiftUI View 업데이트(`@Published` 값 변경 → View 재렌더링)는 반드시 메인 스레드에서 해야 한다.

### @Published vs @StateObject

두 개념은 역할이 완전히 다르다. 같은 계층이 아니라 ViewModel 내부와 View 내부로 위치도 다르다.

| | `@Published` | `@StateObject` |
|--|-------------|---------------|
| **위치** | ViewModel 클래스 내부 | SwiftUI View 내부 |
| **역할** | 값이 바뀌면 구독자에게 알림 발행 | ViewModel 인스턴스를 생성하고 소유 |
| **생명주기** | ViewModel과 동일 | View가 처음 렌더링될 때 생성, 해제될 때 파괴 |
| **누가 만드나** | `ObservableObject` 채택 클래스 | SwiftUI View |

```swift
// ViewModel: @Published로 변화를 알린다
@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    //           ↑ 값이 바뀌면 objectWillChange 발행 → View 재렌더링
}

// View: @StateObject로 ViewModel 인스턴스를 소유한다
struct WorkoutSessionView: View {
    @StateObject private var viewModel: WorkoutSessionViewModel
    //            ↑ View가 인스턴스를 직접 생성·보유. View가 재생성되어도 유지됨.
}
```

`@ObservedObject`와의 차이:
- `@StateObject` — View가 인스턴스를 직접 생성. 소유권이 이 View에 있음.
- `@ObservedObject` — 외부(부모 View 등)에서 주입받음. 소유권 없음. View가 재생성되면 외부 인스턴스를 다시 받음.

```swift
// 부모 View가 소유한 ViewModel을 자식에게 넘길 때
WorkoutControlsView(viewModel: viewModel)  // 자식은 @ObservedObject로 받음
```
