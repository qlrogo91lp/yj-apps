# Watch↔iPhone 운동 연동 버그 수정

## 작업일: 2026-05-29

## 증상

앱 출시 후 실사용 중 발견된 3가지 버그:
1. Watch와 iPhone을 번갈아 사용하면 운동이 시작되지 않음
2. 운동을 시작하면 바로 홈 화면으로 나와버리는 경우가 있음
3. Watch와 iPhone의 운동 경과 시간이 다르게 표시됨

---

## 버그 1: Watch `.finished` 상태에서 iPhone의 새 경기 시작 무시

### 원인

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 `receivedSessionStart` 구독에 `case .modeSelection = self.phase` guard가 있어, Watch가 경기 결과 화면(`.finished`)에 있을 때 iPhone이 새 경기를 시작해도 Watch가 무시함.

```swift
// 수정 전 — .modeSelection 상태에서만 처리
guard let self, case .modeSelection = self.phase else { return }

// 수정 후 — .playing 중일 때만 무시, .modeSelection/.finished 모두 처리
guard let self else { return }
if case .playing = self.phase { return }
```

**재현 경로:**
1. iPhone으로 경기 시작 → Watch도 자동으로 따라옴 (`.playing`)
2. 경기 종료 → Watch `.finished` 상태
3. iPhone에서 새 경기 시작 버튼 → 모드 선택 → `sendSessionStart` 전송
4. Watch: `phase == .finished` → guard 실패 → Watch에서 새 경기 안 시작됨

Watch `HomeView`에도 `guard !navigateToWorkout else { return }`이 있어 WorkoutSessionView가 열려있는 동안 화면 전환도 차단됨 → 양쪽에서 모두 차단된 상태.

---

## 버그 2: `sendWorkoutEnd` 핑퐁 루프로 인한 상태 꼬임

### 원인

종료 메시지를 받은 쪽이 다시 상대방에게 종료 메시지를 보내는 무한 루프 구조:

```
iOS endSession() → sendWorkoutEnd() → Watch endWorkout() → sendWorkoutEnd() → iOS endSession() → ...
```

### 수정

`endWorkout(notifyRemote:)` / `endSession(notifyRemote:)` 파라미터를 추가해, 원격에서 받은 종료 메시지는 다시 전송하지 않도록 처리.

**`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`**

```swift
// 수정 전
func endWorkout() {
    ...
    connectivity.sendWorkoutEnd()
    ...
}

// 수정 후
func endWorkout(notifyRemote: Bool = true) {
    ...
    if notifyRemote { connectivity.sendWorkoutEnd() }
    ...
}

// receivedWorkoutEnd 구독
self.endWorkout(notifyRemote: false)  // 루프 차단
```

**`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`**

```swift
// 수정 전
func endSession() {
    ...
    connectivity.sendWorkoutEnd()
}

// 수정 후
func endSession(notifyRemote: Bool = true) {
    ...
    if notifyRemote { connectivity.sendWorkoutEnd() }
}

// receivedWorkoutEnd 구독
self.endSession(notifyRemote: false)  // 루프 차단
```

---

## 버그 3: 운동 시작 직후 홈으로 나가는 현상 (stale `receivedWorkoutEnd`)

### 원인

`@Published var receivedWorkoutEnd: Date?`는 이전 세션에서 설정된 값이 nil로 초기화되지 않고 남아있음. 새 `WorkoutSessionViewModel`이 init될 때 `@Published`가 `CurrentValueSubject`처럼 동작하여 현재 값을 즉시 emit → `endWorkout()` / `endSession()`이 즉시 호출됨 → `remoteWorkoutEnded = true` → 화면 바로 닫힘.

`receivedMatchEnd`도 동일한 문제 가능성 존재 (새 ViewModel init 시 이전 경기 결과가 즉시 emit되어 `.finished` 화면으로 이동).

### 수정

새 `WorkoutSessionView`를 열기 직전에 stale 값들을 nil로 초기화.

**`WatchApp/Features/Home/HomeView.swift`**

```swift
// 직접 시작 버튼
Button {
    guard !navigateToWorkout else { return }
    connectivity.receivedSessionStart = nil
    connectivity.receivedWorkoutEnd = nil   // 추가
    connectivity.receivedMatchEnd = nil     // 추가
    navigateToWorkout = true
}

// 원격 세션 수신 시
.onReceive(connectivity.$receivedSessionStart.compactMap { $0 }) { msg in
    guard !navigateToWorkout else { return }
    remoteSession = msg
    connectivity.receivedSessionStart = nil
    connectivity.receivedWorkoutEnd = nil   // 추가
    connectivity.receivedMatchEnd = nil     // 추가
    navigateToWorkout = true
}
```

**`iOSApp/iOSApp.swift` (MainTabView)**

```swift
// 직접 시작 버튼
HomeView(onMatchStart: {
    connectivity.receivedWorkoutEnd = nil   // 추가
    connectivity.receivedMatchEnd = nil     // 추가
    withAnimation { isMatchActive = true }
})

// 원격 세션 수신 시
.onReceive(connectivity.$receivedSessionStart.compactMap { $0 }) { msg in
    guard !isMatchActive else { return }
    remoteSession = msg
    connectivity.receivedSessionStart = nil // 추가
    connectivity.receivedWorkoutEnd = nil   // 추가
    connectivity.receivedMatchEnd = nil     // 추가
    withAnimation { isMatchActive = true }
}
```

---

## 버그 4: Watch와 iPhone의 운동 경과 시간 불일치

### 원인

`SessionStartMessage`에 운동 시작 시각이 포함되지 않아, 수신 측이 메시지를 받는 순간을 T=0으로 타이머를 시작.

Watch에서 먼저 시작하는 경우:
- T=0: Watch "운동 시작" 버튼 → HealthKit 타이머 시작
- T=20~30: 모드 선택 완료 → `sendSessionStart` 전송
- T=20~30+δ: iOS 수신 → iOS 타이머 T=0 시작 → **20~30초 차이 발생**

### 수정

`SessionStartMessage`에 `workoutStartDate: Date` 필드 추가, 수신 측이 동일한 기준 시각으로 타이머를 시작하도록 변경.

**`Shared/Services/WatchConnectivityService.swift`**

```swift
struct SessionStartMessage {
    let sessionId: UUID
    let options: MatchOptions
    let workoutStartDate: Date   // 추가

    func toDictionary() -> [String: Any] {
        [
            ...
            "workoutStartDate": workoutStartDate.timeIntervalSince1970  // 추가
        ]
    }

    init?(from dict: [String: Any]) {
        ...
        let ts = dict["workoutStartDate"] as? Double ?? Date().timeIntervalSince1970
        workoutStartDate = Date(timeIntervalSince1970: ts)  // 추가
    }

    init(sessionId: UUID, options: MatchOptions, workoutStartDate: Date = Date()) { ... }
}
```

**`Shared/Services/HealthKitService.swift`**

```swift
// private var startDate → private(set) var startDate (외부 읽기 허용)
private(set) var startDate: Date?
```

**`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`**
Watch가 `sendSessionStart` 시 HealthKit 세션 시작 시각 포함:

```swift
connectivity.sendSessionStart(SessionStartMessage(
    sessionId: id,
    options: options,
    workoutStartDate: healthKit.startDate ?? Date()  // HK 실제 시작 시각
))
```

**`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`**

```swift
// startSession에 시작 시각 파라미터 추가
func startSession(startDate: Date = Date()) {
    startedAt = startDate   // Date() 대신 파라미터 사용
    ...
}

// 원격 세션 수신 시 Watch의 시작 시각으로 타이머 기준 설정
self.startSession(startDate: msg.workoutStartDate)

// iOS가 먼저 시작할 때 자신의 startedAt을 메시지에 포함
connectivity.sendSessionStart(SessionStartMessage(
    sessionId: sessionId,
    options: options,
    workoutStartDate: startedAt ?? Date()
))
```

**`iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`**

```swift
// remoteSession이 있으면 Watch 시작 시각으로 타이머 시작
.onAppear {
    if let remote = remoteSession {
        viewModel.startSession(startDate: remote.workoutStartDate)
        viewModel.startMatch(options: remote.options, isRemote: true)
    } else {
        viewModel.startSession()
    }
}
```

---

## 변경 파일 요약

| 파일 | 변경 내용 |
|------|----------|
| `Shared/Services/WatchConnectivityService.swift` | `SessionStartMessage`에 `workoutStartDate` 필드 추가 |
| `Shared/Services/HealthKitService.swift` | `startDate`를 `private(set)` 으로 변경 |
| `WatchApp/Features/Home/HomeView.swift` | 워크아웃 진입 전 stale WC 상태 초기화 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `.finished` 상태 처리, `endWorkout(notifyRemote:)`, `sendSessionStart`에 startDate 포함 |
| `iOSApp/iOSApp.swift` | 워크아웃 진입 전 stale WC 상태 초기화 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `startSession(startDate:)`, `endSession(notifyRemote:)`, `sendSessionStart`에 startDate 포함, 원격 수신 시 workoutStartDate 사용 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` | `onAppear`에서 remoteSession 있을 때 Watch startDate 기준 타이머 시작 |
