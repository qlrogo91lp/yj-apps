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

### 소유 객체

| 프로퍼티 | 역할 |
|---------|------|
| `healthKit` | HealthKitService — 워크아웃 세션, 칼로리/BPM |
| `connectivity` | WatchConnectivityService — iOS 통신 |
| `scoreVM` | ScoreViewModel — 점수 상태 (게임/세트 로직) |

### isDriver 패턴

```
isDriver = true  → 이 Watch가 점수를 주도
                   점수 변경 시 iOS에 ScoreState 전송
                   (scoreVM.onStateChanged → connectivity.sendScoreState)

isDriver = false → 상대(iOS 또는 다른 Watch)가 주도
                   받은 ScoreState를 applyRemoteState()로 적용만 함
```

### 경기 흐름

```
startWorkout()
  HealthKit 세션 시작, AppGroup defaults에 isWorkoutActive = true, Widget 갱신

startMatch(options:)
  isDriver 결정, phase = .playing, iOS에 SessionStartMessage 전송

(scoreVM.onMatchFinished 콜백)
  finishMatch()
    phase = .finished
    HealthKit에서 averageHeartRate 비동기 조회 후 iOS에 MatchEndMessage 전송

saveCurrentMatch()
  Watch엔 로컬 저장소 없음 → iOS에 matchSave 요청

endWorkout()
  HealthKit 세션 종료, AppGroup defaults 초기화, Widget 갱신, iOS에 workoutEnd 전송
```

### init에서 구성하는 Combine 바인딩

```
1. healthKit.$isPaused  →  self.$isPaused (assign)

2. setupConnectivityBindings()
   connectivity.$receivedSessionStart  →  handleIncomingSessionStart()
   connectivity.$receivedWorkoutEnd    →  handleIncomingWorkoutEnd()

3. setupScoreSync()
   scoreVM.onStateChanged + isDriver   →  connectivity.sendScoreState()
   connectivity.$receivedScoreState    →  scoreVM.applyRemoteState()
   connectivity.$isWatchReachable      →  재연결 시 현재 상태 재전송

4. healthKit.$currentHeartRate (5초 throttle)  →  broadcastMetrics()  →  iOS 전송
```

`.receive(on: DispatchQueue.main)`을 Combine 체인마다 붙이는 이유: WatchConnectivity 콜백이 백그라운드 스레드에서 오기 때문에 `@Published` 값을 바꾸기 전 메인 스레드로 전환한다.

### 동시 시작 race condition

두 기기가 동시에 경기를 시작하면 sessionId UUID 문자열 비교로 우선순위를 결정한다.

```swift
// 더 작은 UUID를 가진 쪽이 driver를 유지. 나머지는 follower로 전환.
guard isDriver, msg.sessionId.uuidString < workoutSessionId.uuidString else { return }
```

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
