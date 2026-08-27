# 동기화 재설계 2단계: 단방향 authority Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **선행 조건:** 1단계(`2026-06-24-sync-step1-state-ownership.md`)가 머지되어 있어야 한다. 이 plan의 코드 스니펫은 1단계 완료 상태를 가정한다. 구현 시작 시 실제 코드와 대조해 시그니처/행 위치를 확정할 것.

**Goal:** 동기화 책임을 `ScoreViewModel`에서 `WorkoutSessionViewModel`로 옮기고, driver/mirror 단방향으로 전환한다. driver만 전송, mirror만 수신 적용 → echo 충돌 제거(증상 3). 전송을 매 포인트·올바른 타이밍으로 바꿔 인게임 점수(15/30/40)가 정확히 전파된다.

**Architecture:** `ScoreViewModel`은 connectivity 의존을 버리고 순수 점수 로직 + `onStateChanged` 콜백 + `makeScoreState()`만 노출한다. `WorkoutSessionViewModel`이 `isDriver`를 들고, driver면 `scoreVM.onStateChanged`에서 스냅샷 전송, mirror면 `receivedScoreState`를 받아 `scoreVM.applyRemoteState`로 적용한다. LiveActivity 갱신(iOS 전용)도 `WorkoutSessionViewModel`로 이동한다.

**Tech Stack:** Swift, SwiftUI, Combine, Swift Testing, WatchConnectivity.

**작업 브랜치:** `git switch -c sync-step2-unidirectional-authority` (1단계 머지된 main에서).

**빌드/테스트 명령:** 1단계 plan 헤더 참조.

---

## File Structure

| 파일 | 이 단계 변경 |
|------|------------|
| `iOSApp/Features/Match/Score/ScoreViewModel.swift` | connectivity 구독/전송 제거, `onStateChanged` 추가, `makeScoreState` public, addPoint/undo가 `onStateChanged` 호출, LiveActivity 호출 제거 |
| `WatchApp/Features/Match/Score/ScoreViewModel.swift` | 동일(+ `makeScoreState()` 신설, 전송 타이밍 버그 제거) |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `isDriver`, broadcast(onStateChanged 핸들러), mirror 수신, 재연결 스냅샷, LiveActivity 이동 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 동일(LiveActivity 제외) |
| `iosTests/`, `watchosTests/` | makeScoreState 인게임 점수 포함 / driver 미수신 / mirror 수신 테스트 |

---

### Task 0: 브랜치 생성

- [ ] **Step 1:** `git switch -c sync-step2-unidirectional-authority`

---

### Task 1: iOS `ScoreViewModel` 순수화

**Files:** Modify `iOSApp/Features/Match/Score/ScoreViewModel.swift`, Test `iosTests/Match/ScoreViewModelTests.swift`

- [ ] **Step 1: 실패 테스트 — makeScoreState가 인게임 점수를 포함**

`iosTests/Match/ScoreViewModelTests.swift`에 추가:
```swift
@Test @MainActor func makeScoreStateIncludesInGamePoints() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.addPoint(.me) // 0 → 15 (게임 미승리)
    let state = vm.makeScoreState()
    #expect(state.myScore == 15)   // 현재 인게임 점수가 0이 아니라 15
    #expect(state.myGameScore == 0)
}
```
> 이 테스트는 증상 3의 회귀 가드다. 현재(2단계 전)는 `makeScoreState`가 private이고 전송이 `score.resetData()` 뒤라 항상 0이 나갔다.

- [ ] **Step 2: 실패 확인** — `makeScoreState`가 private이라 컴파일 에러.

- [ ] **Step 3: 구현**

`iOSApp/Features/Match/Score/ScoreViewModel.swift`에서:

1) connectivity 관련 제거: `private let connectivity = WatchConnectivityService.shared`, `private var isApplyingRemote`, init 내 `$receivedScoreState` 구독, `$isWatchReachable` 구독, `sendScoreState()` 메서드 전부 삭제.

2) 콜백 프로퍼티 추가 (프로퍼티 영역):
```swift
    var onStateChanged: (() -> Void)?
```

3) `addPoint`를 connectivity/LiveActivity 없이, 매 포인트 콜백 호출로 변경:
```swift
    func addPoint(_ side: PlayerSide) {
        guard !isMatchOver else { return }
        let gameWon = score.addPoint(side)
        if gameWon != nil {
            if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
            score.resetData()
            checkSetUpdate()
        }
        onStateChanged?()
    }
```

4) `undo()`도 콜백 호출:
```swift
    func undo() {
        score.undo()
        onStateChanged?()
    }
```

5) `makeScoreState()`를 `private` → 접근제어 제거(internal):
```swift
    func makeScoreState() -> ScoreState {
```

6) `applyRemoteState`에서 `LiveActivityService.shared.update(...)` 줄 제거(LiveActivity는 WorkoutSessionViewModel로 이동). `isApplyingRemote` 플래그도 제거.

- [ ] **Step 4: 통과 확인** — 위 테스트 PASS, 기존 GREEN.

- [ ] **Step 5: 커밋**
```bash
git add iOSApp/Features/Match/Score/ScoreViewModel.swift iosTests/Match/ScoreViewModelTests.swift
git commit -m "♻️ iOS ScoreViewModel 순수화: connectivity 제거 + onStateChanged"
```

---

### Task 2: Watch `ScoreViewModel` 순수화 (+ 전송 타이밍 버그 제거)

**Files:** Modify `WatchApp/Features/Match/Score/ScoreViewModel.swift`, Test `watchosTests/Match/ScoreViewModelTests.swift`

- [ ] **Step 1: 실패 테스트 — makeScoreState 인게임 점수 포함**
```swift
@Test @MainActor func makeScoreStateIncludesInGamePoints() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.addPoint(.me) // 0 → 15
    let state = vm.makeScoreState()
    #expect(state.myScore == 15)
    #expect(state.myGameScore == 0)
}
```

- [ ] **Step 2: 실패 확인** — `makeScoreState` 없음.

- [ ] **Step 3: 구현**

`WatchApp/Features/Match/Score/ScoreViewModel.swift`에서:

1) 제거: `private let connectivity`, `private var isApplyingRemote`, init의 `$receivedScoreState` 구독, `sendScoreState()`.

2) 추가:
```swift
    var onStateChanged: (() -> Void)?

    func makeScoreState() -> ScoreState {
        let myScore = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
        let yourScore = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
        return ScoreState(
            myScore: myScore, yourScore: yourScore,
            myGameScore: myGameScore, yourGameScore: yourGameScore,
            mySetScore: mySetScore, yourSetScore: yourSetScore,
            completedSets: completedSets.map { [$0.my, $0.your] },
            isTieBreak: score.gameMode == .tieBreak
        )
    }
```

3) `addPoint`를 전송 제거 + 콜백 + 올바른 순서로 변경 (기존 버그: `sendScoreState()`가 `checkSetUpdate()` 앞 + `score.reset()` 뒤):
```swift
    func addPoint(_ side: PlayerSide) {
        let gameWon = score.addPoint(side)
        if gameWon != nil {
            withAnimation(.bouncy) {
                if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
            }
            score.reset()
            checkSetUpdate()
        }
        onStateChanged?()
    }
```

4) `undo()`에 콜백:
```swift
    func undo() {
        score.undo()
        onStateChanged?()
    }
```

5) `applyRemoteState`는 유지(순수 상태 적용). `isApplyingRemote` 참조 제거.

- [ ] **Step 4: 통과 확인** — PASS, 기존 GREEN.

- [ ] **Step 5: 커밋**
```bash
git add WatchApp/Features/Match/Score/ScoreViewModel.swift watchosTests/Match/ScoreViewModelTests.swift
git commit -m "♻️ Watch ScoreViewModel 순수화 + 전송 타이밍 버그 제거"
```

---

### Task 3: iOS `WorkoutSessionViewModel` — driver/mirror 동기화

**Files:** Modify `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`, Test `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

- [ ] **Step 1: 실패 테스트 — driver는 수신 상태를 무시, mirror는 적용**
```swift
@Test @MainActor func driverIgnoresRemoteScoreState() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // isDriver = true
    vm.scoreVM.myGameScore = 2
    vm.applyIncomingScoreStateForTest(ScoreState(
        myScore: 0, yourScore: 0, myGameScore: 5, yourGameScore: 5,
        mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false))
    #expect(vm.scoreVM.myGameScore == 2) // driver는 덮어쓰지 않음
}

@Test @MainActor func mirrorAppliesRemoteScoreState() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
    vm.applyIncomingScoreStateForTest(ScoreState(
        myScore: 30, yourScore: 15, myGameScore: 3, yourGameScore: 2,
        mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false))
    #expect(vm.scoreVM.myGameScore == 3)
    #expect(vm.scoreVM.score.myScore == 30)
}
```
> 비동기 Combine sink를 직접 테스트하면 타이밍이 불안정하므로, 수신 처리 본체를 동기 메서드로 빼고(`handleIncomingScoreState`) 테스트는 그 메서드를 직접 호출하는 얇은 래퍼(`applyIncomingScoreStateForTest`)로 검증한다. 실제 구독 sink는 이 메서드를 호출만 한다.

- [ ] **Step 2: 실패 확인** — `isDriver`/`applyIncomingScoreStateForTest` 없음.

- [ ] **Step 3: 구현**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

1) 프로퍼티 추가:
```swift
    private(set) var isDriver = false
```

2) `startMatch(options:isRemote:)`에서 `isDriver` 설정 (맨 앞):
```swift
        isDriver = !isRemote
```

3) `init()`에 scoreVM 콜백·수신 처리 연결 (1단계에서 `scoreVM` 소유 추가됨):
```swift
        scoreVM.onStateChanged = { [weak self] in
            guard let self else { return }
            LiveActivityService.shared.update(from: self.scoreVM.makeScoreState(), score: self.scoreVM.score)
            guard self.isDriver else { return }
            self.connectivity.sendScoreState(self.scoreVM.makeScoreState())
        }

        connectivity.$receivedScoreState
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleIncomingScoreState(state) }
            .store(in: &cancellables)
```

4) 수신 처리 본체 + 테스트 래퍼:
```swift
    private func handleIncomingScoreState(_ state: ScoreState) {
        guard !isDriver else { return }
        scoreVM.applyRemoteState(state)
        LiveActivityService.shared.update(from: state, score: scoreVM.score)
    }

    #if DEBUG
    func applyIncomingScoreStateForTest(_ state: ScoreState) { handleIncomingScoreState(state) }
    #endif
```

5) 재연결 시 driver가 스냅샷 재전송 — 기존 `$isWatchReachable.filter { $0 }` 구독(현재 sendSessionStart만)에 추가:
```swift
            .sink { [weak self] _ in
                guard let self, self.isDriver, case .playing(let options) = self.phase else { return }
                self.connectivity.sendSessionStart(SessionStartMessage(
                    sessionId: self.sessionId, options: options, workoutStartDate: self.startedAt ?? Date()))
                self.connectivity.sendScoreState(self.scoreVM.makeScoreState())
            }
```

- [ ] **Step 4: 통과 확인** — 두 테스트 PASS, 기존 GREEN.

- [ ] **Step 5: 커밋**
```bash
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "✨ iOS WorkoutSessionViewModel: driver/mirror 단방향 동기화"
```

---

### Task 4: Watch `WorkoutSessionViewModel` — driver/mirror 동기화

**Files:** Modify `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`, Test `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

Watch는 LiveActivity가 없다. 그 외 구조는 iOS와 동일.

- [ ] **Step 1: 실패 테스트**
```swift
@Test @MainActor func driverIgnoresRemoteScoreState() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.scoreVM.myGameScore = 2
    vm.applyIncomingScoreStateForTest(ScoreState(
        myScore: 0, yourScore: 0, myGameScore: 5, yourGameScore: 5,
        mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false))
    #expect(vm.scoreVM.myGameScore == 2)
}

@Test @MainActor func mirrorAppliesRemoteScoreState() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true)
    vm.applyIncomingScoreStateForTest(ScoreState(
        myScore: 30, yourScore: 15, myGameScore: 3, yourGameScore: 2,
        mySetScore: 0, yourSetScore: 0, completedSets: [], isTieBreak: false))
    #expect(vm.scoreVM.myGameScore == 3)
    #expect(vm.scoreVM.score.myScore == 30)
}
```

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: 구현**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

1) `private(set) var isDriver = false`

2) `startMatch(...)` 맨 앞에 `isDriver = !isRemote`

3) `init()`에 (1단계에서 추가한 `scoreVM.onMatchFinished` 연결 근처):
```swift
        scoreVM.onStateChanged = { [weak self] in
            guard let self, self.isDriver else { return }
            self.connectivity.sendScoreState(self.scoreVM.makeScoreState())
        }

        connectivity.$receivedScoreState
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleIncomingScoreState(state) }
            .store(in: &cancellables)
```

4) 수신 본체 + 테스트 래퍼 + 재연결:
```swift
    private func handleIncomingScoreState(_ state: ScoreState) {
        guard !isDriver else { return }
        scoreVM.applyRemoteState(state)
    }

    #if DEBUG
    func applyIncomingScoreStateForTest(_ state: ScoreState) { handleIncomingScoreState(state) }
    #endif
```

재연결 — `init()`에 driver 스냅샷 재전송 구독 추가(Watch엔 기존에 없음):
```swift
        connectivity.$isWatchReachable
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isDriver, case .playing = self.phase else { return }
                self.connectivity.sendScoreState(self.scoreVM.makeScoreState())
            }
            .store(in: &cancellables)
```

- [ ] **Step 4: 통과 확인.**

- [ ] **Step 5: 커밋**
```bash
git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "✨ Watch WorkoutSessionViewModel: driver/mirror 단방향 동기화"
```

---

### Task 5: 전송 호출부 잔재 확인

- [ ] **Step 1:** Run `grep -rn "sendScoreState\|receivedScoreState\|WatchConnectivityService" iOSApp/Features/Match WatchApp/Features/Match`
Expected: Match 폴더(ScoreView/ScoreViewModel)에 connectivity 참조 없음. 동기화는 WorkoutSession 레이어에만.

- [ ] **Step 2:** 잔재가 있으면 제거 후 커밋.

---

### Task 6: 전체 검증 + code-review

- [ ] **Step 1:** iOS·Watch 빌드 → BUILD SUCCEEDED
- [ ] **Step 2:** iOS·Watch 테스트 → 전체 GREEN
- [ ] **Step 3:** `make fix && make lint` → 위반 없음
- [ ] **Step 4:** `/code-review` → 지적은 `superpowers:receiving-code-review`로 검증 후 반영
- [ ] **Step 5: 실기기 2대 수동 확인 (필수 권장 — 시뮬레이터 함정)**
  - 워치로 경기 시작(워치=driver) → 30-15 입력 → 폰(mirror) 화면에 30-15 실시간 표시 확인
  - 손목 내렸다 올리기 반복(도달성 깜빡) → 워치 점수가 0으로 안 날아가는지 확인 (증상 3)
  - 폰에서 시작(폰=driver) → 워치(mirror)에 전파 확인

---

## 이 단계가 검증하는 것 (증상 3)

- `makeScoreState`가 인게임 점수를 포함하고, driver가 매 포인트 전송 → 미러·Live Activity 실시간 정확.
- driver는 수신 상태를 무시(`handleIncomingScoreState` guard), mirror는 전송하지 않음(`onStateChanged` guard) → echo 양방향 차단.
- `ScoreViewModel`이 순수화되어 동기화 회귀 테스트가 ViewModel 레벨에서 가능.
