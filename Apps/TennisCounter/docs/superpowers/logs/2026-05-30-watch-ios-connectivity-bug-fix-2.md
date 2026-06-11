# Watch↔iPhone 연동 버그 수정 2차

## 작업일: 2026-05-30

## 증상

앱 출시 후 실사용 중 발견. 전날 수정(2026-05-29)으로도 남아있던 신규 버그 3종:

1. **iOS에서 운동 시작 → 점수 기록 → Watch 앱 접속 → Watch에서 운동이 시작 안 됨**
2. **Watch에서 "운동 시작" 누르면 Match 화면 나왔다가 바로 홈으로 돌아감**
3. **Watch에서 새 경기 시작 시 iOS의 이전 점수가 그대로 남아 표시됨**

---

## 공통 배경: `updateApplicationContext` 단일 슬롯 문제

`WatchConnectivityService.send()` 는 Watch가 비활성(unreachable) 상태일 때 `WCSession.updateApplicationContext`를 fallback으로 사용한다. 문제는 applicationContext가 **단 하나의 딕셔너리 슬롯**만 가지며, 새 값이 이전 값을 덮어쓴다는 점이다.

```swift
// 기존 send() — 모든 메시지 타입이 동일한 슬롯 경쟁
private func send(_ dict: [String: Any]) {
    if WCSession.default.isReachable {
        WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
    } else {
        try? WCSession.default.updateApplicationContext(dict)  // 단 하나의 슬롯
    }
}
```

이로 인해 발생하는 두 가지 치명적 결함:

- `sessionStart`를 applicationContext에 저장해도, 이후 `scoreState` 업데이트가 같은 슬롯을 덮어씀 → Watch가 열릴 때 sessionStart를 받지 못함
- 이전 세션의 `workoutEnd`가 applicationContext에 남은 상태에서, 다음 세션의 메시지들이 Watch 활성 상태일 때 전송(sendMessage 경로)되면 applicationContext는 영원히 stale `workoutEnd`로 오염됨

---

## Bug 1: Watch에서 운동이 시작 안 됨

### 재현 경로

```
iOS: 운동 시작 (Watch 비활성) → sessionStart → updateApplicationContext({sessionStart})
iOS: 점수 기록 (Watch 비활성) → scoreState  → updateApplicationContext({scoreState}) ← sessionStart 덮어씀!
Watch: 앱 접속 → didReceiveApplicationContext({scoreState}) → receivedScoreState 설정됨
Watch: HomeView.onReceive(receivedSessionStart) 미발동 → 홈 화면에 머뭄
```

### 원인

`sendScoreState()`가 `send()` 경유로 applicationContext에 scoreState를 기록. `sessionStart` 슬롯을 덮어씀.

### 추가 원인: Watch 재연결 시 sessionStart 재전송 없음

Watch가 연결된 상태(reachable)에서 iOS가 sessionStart를 sendMessage로 보낸 뒤 Watch가 잠시 끊겼다가 재연결되면, iOS는 sessionStart를 다시 보내지 않아 Watch가 알 수 없는 상태가 됨.

### 수정

#### 1) `sendScoreState`, `sendMetrics`, `sendWorkoutEnd` → reachable 시에만 전송

**`Shared/Services/WatchConnectivityService.swift`**

```swift
// 수정 전 — 모든 메시지가 applicationContext fallback 사용
func sendScoreState(_ state: ScoreState) {
    send(state.toDictionary())
}
func sendMetrics(_ metrics: WorkoutMetrics) {
    send(metrics.toDictionary())
}
func sendWorkoutEnd() {
    send(["type": WCMessageType.workoutEnd.rawValue])
}

// 수정 후 — 실시간 메시지는 reachable 시에만 전송
func sendScoreState(_ state: ScoreState) {
    sendRealtimeOnly(state.toDictionary())
}
func sendMetrics(_ metrics: WorkoutMetrics) {
    sendRealtimeOnly(metrics.toDictionary())
}
func sendWorkoutEnd() {
    sendRealtimeOnly(["type": WCMessageType.workoutEnd.rawValue])
}

// 신규 헬퍼
private func sendRealtimeOnly(_ dict: [String: Any]) {
    guard WCSession.default.activationState == .activated,
          WCSession.default.isReachable else { return }
    #if os(iOS)
    guard WCSession.default.isWatchAppInstalled else { return }
    #endif
    WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
}
```

결과: `sessionStart`만 applicationContext를 사용 → scoreState 업데이트가 sessionStart를 덮어쓰지 않음.

#### 2) Watch 재연결 시 iOS가 sessionStart 재전송

**`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`**

```swift
init() {
    // 기존 구독들 ...

    // 추가: Watch가 연결될 때 경기 진행 중이면 sessionStart 재전송
    connectivity.$isWatchReachable
        .filter { $0 }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self, case .playing(let options) = self.phase else { return }
            self.connectivity.sendSessionStart(SessionStartMessage(
                sessionId: self.sessionId,
                options: options,
                workoutStartDate: self.startedAt ?? Date()
            ))
        }
        .store(in: &cancellables)
}
```

결과:
- Watch 앱 접속 시 iOS가 현재 진행 중인 경기 정보를 즉시 전송
- Watch `HomeView.onReceive(receivedSessionStart)` 발동 → 자동으로 WorkoutSession 이동

---

## Bug 2: Watch "운동 시작" 눌렀을 때 즉시 홈으로 돌아감

### 재현 경로 (영구 오염 시나리오)

```
[이전 세션]
iOS: 운동 종료 (Watch 비활성) → sendWorkoutEnd() → send() → updateApplicationContext({workoutEnd})
applicationContext = {workoutEnd}  ← 영구 저장

[현재 세션]
iOS: 운동 시작 (Watch 활성) → sendMessage({sessionStart})    → applicationContext 변경 없음!
iOS: 점수 기록 (Watch 활성) → sendMessage({scoreState})      → applicationContext 변경 없음!
applicationContext = 여전히 {workoutEnd}  ← 오염 지속

Watch: 앱 재시작 → didReceiveApplicationContext({workoutEnd}) 발동
handle() → DispatchQueue.main.async { receivedWorkoutEnd = Date() }  [블록 큐잉]

사용자: "운동 시작" 버튼 탭
Button: receivedWorkoutEnd = nil  (동기)
        navigateToWorkout = true  → WorkoutSessionView 생성
        WorkoutSessionViewModel.init() → receivedWorkoutEnd 구독 (현재값 nil, 필터됨)
        [버튼 액션 완료]

메인 런루프: 큐잉된 async 블록 실행
→ receivedWorkoutEnd = Date()  ← 구독 발동!
→ remoteWorkoutEnded = true
→ dismiss() 호출
→ 홈으로 돌아감!
```

### 원인: Race Condition + applicationContext 영구 오염

두 가지 문제가 결합:

1. **`workoutEnd`가 applicationContext에 남음**: Watch 비활성 시 `sendWorkoutEnd()`가 `updateApplicationContext`를 사용 → 이후 세션에서 Watch가 활성 상태이면 후속 메시지들은 sendMessage로 전송되어 applicationContext가 갱신되지 않음 → stale `workoutEnd` 영구 잔류

2. **Race condition**: `didReceiveApplicationContext`는 백그라운드 스레드에서 호출 → `handle()`이 `DispatchQueue.main.async`로 디스패치 → 이 블록이 **버튼 액션보다 늦게 실행**됨. 버튼이 `receivedWorkoutEnd = nil`로 초기화해도 이미 큐잉된 async 블록이 이후에 다시 `Date()`로 설정함.

```swift
// WatchConnectivityService.handle() — async 디스패치가 핵심
private func handle(_ message: [String: Any]) {
    DispatchQueue.main.async {   // ← 비동기! 버튼 액션 이후 실행될 수 있음
        switch message["type"] as? String {
        case WCMessageType.workoutEnd.rawValue:
            self.receivedWorkoutEnd = Date()  // ← 버튼의 nil 초기화를 덮어씀
        ...
        }
    }
}
```

### 수정

Bug 1의 수정(sendWorkoutEnd → sendRealtimeOnly)으로 함께 해결됨:

`workoutEnd`가 더 이상 applicationContext에 저장되지 않으므로, Watch 앱 재시작 시 stale `workoutEnd` 자체가 발생하지 않음. applicationContext 오염 원천 차단.

```
[수정 후]
iOS: 운동 종료 (Watch 비활성) → sendRealtimeOnly({workoutEnd}) → isReachable 아님 → 전송 안 함
applicationContext: 변경 없음 (기존 sessionStart 유지 또는 비어있음)

Watch: 앱 재시작 → didReceiveApplicationContext 발동 안 함 (workoutEnd 없음)
사용자: "운동 시작" → race condition 없이 정상 동작
```

**설계 근거**: Watch가 비활성 상태일 때 iOS가 운동을 종료했다면, Watch에는 진행 중인 워크아웃 세션 자체가 없다. `workoutEnd`를 전달할 이유가 없음.

---

## Bug 3: Watch 새 경기 시작 시 iOS의 이전 점수가 표시됨

### 재현 경로

```
iOS: 경기 진행 중 → scoreState 전송 → receivedScoreState = {3게임:2게임, 1세트:0세트, ...}
Watch: "운동 시작" → ModeView → 모드 선택 → startMatch(isRemote: false)
  └→ phase = .playing(options) → ScoreView 생성 → ScoreViewModel.init() 실행
        └→ connectivity.$receivedScoreState.compactMap { $0 }
              현재값 = {3:2, 1:0, ...} (nil 아님)  ← 즉시 emit!
              → applyRemoteState() 호출
              → 화면에 iOS의 점수가 그대로 표시됨
```

### 원인

`WatchConnectivityService.shared.receivedScoreState`는 싱글턴 상태로 유지됨. `ScoreViewModel`이 `@Published` 값을 구독하면 `compactMap { $0 }`이 현재 non-nil 값을 즉시 방출 → iOS 점수가 Watch의 새 경기에 덮어씌워짐.

### 수정

**`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`**

```swift
func startMatch(options: MatchOptions, sessionId: UUID? = nil, isRemote: Bool = false) {
    let id = sessionId ?? workoutSessionId
    let session = MatchSession(
        workoutSessionId: id,
        options: options,
        kcalAtStart: healthKit.currentCalories
    )
    _currentSession = session

    // 추가: 자체 경기 시작 시 ScoreView가 생성되기 전에 stale 상태 초기화
    if !isRemote {
        connectivity.receivedScoreState = nil
    }

    phase = .playing(options)   // ← 이 이후에 ScoreView/ScoreViewModel 생성됨

    if !isRemote {
        connectivity.sendSessionStart(...)
    }
}
```

`phase = .playing` 설정 전에 `receivedScoreState = nil` → `ScoreViewModel.init()` 구독 시 nil → 즉시 emit 없음 → 빈 점수판으로 시작.

`isRemote: true` (iPhone에서 시작한 경기에 Watch가 참여)인 경우에는 초기화하지 않음 → iOS의 현재 점수를 정상적으로 수신해야 하므로.

---

## 추가된 테스트

**`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`**

```swift
@Test @MainActor func startOwnMatchClearsStaleRemoteScoreState() {
    let service = WatchConnectivityService.shared
    // iOS 점수 상태 시뮬레이션
    service.receivedScoreState = ScoreState(
        myScore: 15, yourScore: 0,
        myGameScore: 3, yourGameScore: 2,
        mySetScore: 1, yourSetScore: 0,
        completedSets: [], isTieBreak: false
    )
    defer { service.receivedScoreState = nil }

    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: false)

    // 자체 경기 시작 시 stale 점수 초기화 확인
    #expect(service.receivedScoreState == nil)
}

@Test @MainActor func remoteMatchStartDoesNotClearScoreState() {
    let service = WatchConnectivityService.shared
    let existing = ScoreState(
        myScore: 15, yourScore: 0,
        myGameScore: 3, yourGameScore: 2,
        mySetScore: 1, yourSetScore: 0,
        completedSets: [], isTieBreak: false
    )
    service.receivedScoreState = existing
    defer { service.receivedScoreState = nil }

    let vm = WorkoutSessionViewModel()
    // isRemote: true → iOS 점수 유지해야 함
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true)

    #expect(service.receivedScoreState != nil)
}
```

---

## 메시지 타입별 전송 전략 정리 (수정 후)

| 메시지 | Watch 비활성 시 | 이유 |
|--------|----------------|------|
| `sessionStart` | applicationContext 저장 | Watch 재시작 시 받아야 함. 또한 iOS가 reachable 시 재전송(isWatchReachable subscription) |
| `scoreState`   | **전송 안 함** | 실시간 데이터. iOS ScoreViewModel이 reachable 변경 시 자동 재전송 |
| `workoutEnd`   | **전송 안 함** | Watch 비활성이면 Watch 워크아웃 세션 없음. 전달 불필요 |
| `metrics`      | **전송 안 함** | 실시간 데이터. 누락돼도 다음 업데이트로 대체 |
| `matchEnd`     | transferUserInfo | 경기 결과. 신뢰성 있는 전달 필요 (기존 유지) |

---

## 변경 파일 요약

| 파일 | 변경 내용 |
|------|----------|
| `Shared/Services/WatchConnectivityService.swift` | `sendRealtimeOnly()` 헬퍼 추가; `sendScoreState`, `sendMetrics`, `sendWorkoutEnd`를 reachable 전용으로 변경 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `$isWatchReachable.filter { $0 }` 구독 추가 → Watch 재연결 시 sessionStart 재전송 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `startMatch(isRemote: false)` 시 `receivedScoreState = nil` 초기화 |
| `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 테스트 2개 추가 (자체 경기 초기화, 원격 경기 비초기화) |

---

## 후속 (2026-06-11): iOS 동일 버그 수정

### 증상

Watch 실사용 중 "경기 중단(뒤로가기)이나 결과뷰 리매치 후에도 점수가 초기화되지 않음"을 재발견. 조사 결과 **Bug 3는 Watch에만 수정이 적용**되었고, **iOS `startMatch`에는 동일 클리어가 누락**되어 있었음.

### 진단 과정 (시뮬레이터 vs 실제 기기 분리)

1. `ScoreViewModel`에 `init`/`deinit`/`applyRemoteState` 계측 로그를 심고 watchOS 시뮬레이터에서 재현.
2. 시뮬레이터 결과: 새 경기마다 `🟢 init`은 찍히고(= StateObject는 정상 재생성), `🟡 applyRemoteState`는 **한 번도 안 찍힘** → 시뮬레이터에서는 점수가 **정상 초기화됨**.
3. 결론: 현재 코드(HEAD)는 Watch 측에서 정상. 실제 손목 워치의 버그는 **e2b15ef(Bug 3 수정) 이전 빌드(버전 14, `c013479`)가 설치돼 있던 탓** → 재설치로 해결되는 사안이었음.
4. 다만 같은 분석에서 **iOS `startMatch`에는 `receivedScoreState = nil` 클리어가 없음**을 확인 → iOS는 코드 레벨에서 아직 취약. (계측 로그는 진단 후 제거.)

### 원인

Bug 3와 동일. iOS `ScoreViewModel`도 `connectivity.$receivedScoreState`를 구독하므로, 새 경기에서 `ScoreViewModel.init()` 시 싱글턴에 남은 직전 점수가 즉시 emit되어 게임/세트 점수가 복원됨. iOS `startMatch`는 이 값을 비우지 않았다.

### 수정

**`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`**

```swift
func startMatch(options: MatchOptions, isRemote: Bool = false) {
    _currentSession = MatchSession(...)

    // 추가: 자체 경기 시작 시 ScoreView 생성 전에 stale 상태 초기화 (Watch와 동일)
    if !isRemote {
        connectivity.receivedScoreState = nil
    }

    phase = .playing(options)   // ← 이 이후에 ScoreView/ScoreViewModel 생성됨
    LiveActivityService.shared.start(mode: options.mode)
    ...
}
```

### 추가된 테스트

Watch 테스트를 iOS로 미러링. TDD로 먼저 RED 확인(`startOwnMatchClearsStaleRemoteScoreState`가 `== nil` 기대에서 실패) 후 수정 → 스위트 16/16 GREEN.

**`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`**

```swift
@Test @MainActor func startOwnMatchClearsStaleRemoteScoreState() { ... #expect(service.receivedScoreState == nil) }
@Test @MainActor func remoteMatchStartDoesNotClearScoreState()  { ... #expect(service.receivedScoreState != nil) }
```

### 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `startMatch(isRemote: false)` 시 `receivedScoreState = nil` 초기화 (Bug 3의 iOS 미러링) |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 테스트 2개 추가 (자체 경기 초기화, 원격 경기 비초기화) |

### 미해결 (별도 추적)

진단 중 `ScoreViewModel`의 `deinit`이 한 번도 호출되지 않음을 관찰 → 경기 반복 시 옛 인스턴스가 해제되지 않고 누적되는 **메모리 누수 의심**. 점수 초기화 버그와는 독립적인 사안으로 분리.
