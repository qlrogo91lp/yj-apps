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
  connectivity.$receivedMatchSave     →  saveFromWatch() → SwiftData 저장
  connectivity.$receivedWorkoutEnd    →  endSession()
```

### 저장 흐름 두 가지

**Watch가 저장 버튼 누른 경우 (receivedMatchSave)**

```
Watch → sendMatchSave(MatchEndMessage)
iOS   → saveFromWatch(msg)
        buildMatchFromMessage(msg) → Match 객체 생성
        MatchPersistenceService.shared.upsert(match)
```

**iOS에서 직접 저장하는 경우 (saveCurrentMatch)**

```
iOS 저장 버튼 탭
→ saveCurrentMatch()
   buildMatchFromSession(_currentSession) → Match 객체 생성
   MatchPersistenceService.shared.upsert(match)
```

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
