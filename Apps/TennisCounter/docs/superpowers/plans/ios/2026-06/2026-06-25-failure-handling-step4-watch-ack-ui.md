# 저장 실패 처리 4단계: Watch ack 수신 + 타임아웃 + UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **선행 조건:** 1~3단계가 모두 머지된 상태여야 한다. 이 단계는 3단계가 추가한
> `MatchSaveResultMessage`/`connectivity.sendMatchSaveResult`에 의존한다.

**Goal:** Watch가 저장 버튼을 누르면 "저장 중" → iOS의 ack를 받아 "저장됨"/"실패"로 정확히
바뀐다. ack가 일정 시간(기본 8초) 안에 오지 않으면 "실패, 재시도"로 전환해 무한 로딩을 막는다.
지금은 Watch가 메시지를 보냈다는 사실만으로 무조건 "저장됨"을 보여준다 — 이 마지막 거짓
신호를 고쳐서, 1~4단계 전체로 "저장 버튼이 실제 저장 결과를 보여준다"는 목표를 완성한다.

**Architecture:** `WatchApp/.../WorkoutSessionViewModel`에 `SaveAckState`(`idle`/`pending`/
`succeeded`/`failed`) `@Published` 속성과 증가 카운터(`saveAttemptToken`)를 추가한다.
`saveCurrentMatch()`가 토큰을 증가시키고 `pending`으로 전환한 뒤, `ackTimeoutSeconds`(기본
8초, 테스트에서 짧은 값 주입 가능) 후 그 토큰이 여전히 최신이고 상태가 아직 `pending`이면
`failed`로 전환한다 — 재시도로 새 토큰이 발급된 뒤에 이전 시도의 지연된 타임아웃이 새 상태를
덮어쓰는 경합을 막는다. `connectivity.$receivedMatchSaveResult`를 구독해 `sessionId`가 일치하면
즉시 `succeeded`/`failed`로 반영한다. `SaveButton`(Watch)은 뷰 전용 4-state enum으로 매핑해
ViewModel 타입에 직접 의존하지 않는다 (CLAUDE.md: Component는 상위 ViewModel을 알지 않는다).

**Tech Stack:** Swift, SwiftUI, Combine, Swift Testing (async test로 타임아웃 검증).

**작업 브랜치:** `git switch -c failure-handling-step4-watch-ack-ui`

**빌드/테스트 명령:**
```bash
# Watch 빌드
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Watch 테스트 (시뮬레이터 id 필요 — 아래로 조회 후 사용)
xcrun simctl list devices available | grep -i "Apple Watch Series 11 (46mm)"
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=<위에서 조회한 id>' -only-testing:watchosTests/WorkoutSessionViewModelTests

# iOS 빌드 (회귀 없는지만 확인 — 이 단계는 iOS 파일을 건드리지 않음)
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Lint/Format
make fix && make lint
```

---

## File Structure

| 파일 | 변경 |
|------|------|
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `SaveAckState`, 토큰 기반 타임아웃, ack 수신 |
| `WatchApp/Features/Match/Result/Components/SaveButton.swift` | `idle`/`pending`/`saved`/`failed` 4-state |
| `WatchApp/Features/Match/Result/MatchResultView.swift` | ack 상태를 `SaveButton`에 매핑 |
| `WatchApp/en.lproj/Localizable.strings`, `ko.lproj/Localizable.strings` | `result_saving`, `result_save_failed` 키 추가 |
| `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | ack 수신/타임아웃/토큰 경합 테스트 |

---

### Task 0: 브랜치 생성
- [x] **Step 1:** `git switch -c failure-handling-step4-watch-ack-ui`

---

### Task 1: `SaveAckState` + ack 수신 + 토큰 기반 타임아웃

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

- [x] **Step 1: 실패 테스트 작성**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 다음 4개 테스트를 추가:

```swift
    @Test @MainActor func saveCurrentMatchStartsPending() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        #expect(vm.saveAckState == .pending)
    }

    @Test @MainActor func handleMatchSaveResultSucceeds() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))
        #expect(vm.saveAckState == .succeeded)
    }

    @Test @MainActor func handleMatchSaveResultIgnoredForMismatchedSession() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: UUID(), success: true))
        #expect(vm.saveAckState == .pending) // 다른 세션의 ack는 무시
    }

    @Test @MainActor func saveCurrentMatchTimesOutToFailedWhenNoAck() async throws {
        let vm = WorkoutSessionViewModel(ackTimeoutSeconds: 0.05)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()
        #expect(vm.saveAckState == .pending)

        try await Task.sleep(nanoseconds: 150_000_000) // 0.15s > 0.05s 타임아웃
        #expect(vm.saveAckState == .failed)
    }

    @Test @MainActor func retryAfterTimeoutIgnoresStaleTimeout() async throws {
        let vm = WorkoutSessionViewModel(ackTimeoutSeconds: 0.05)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        vm.saveCurrentMatch() // 시도 1
        try await Task.sleep(nanoseconds: 70_000_000) // 시도 1의 타임아웃 발동 (0.05s 경과)
        #expect(vm.saveAckState == .failed)

        vm.saveCurrentMatch() // 시도 2 (재시도) — pending으로 전환
        #expect(vm.saveAckState == .pending)
        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))
        #expect(vm.saveAckState == .succeeded)

        // 시도 1의 지연된 타임아웃 클로저가 혹시 아직 안 끝났더라도, 토큰이 달라 succeeded를 덮어쓰지 않아야 한다.
        try await Task.sleep(nanoseconds: 70_000_000)
        #expect(vm.saveAckState == .succeeded)
    }
```

- [x] **Step 2: 실패 확인**

Run: `xcrun simctl list devices available | grep -i "Apple Watch Series 11 (46mm)"` 로 시뮬레이터
id를 확인한 뒤,
`xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=<id>' -only-testing:watchosTests/WorkoutSessionViewModelTests`
Expected: BUILD FAILED — `saveAckState`/`handleMatchSaveResultForTest`/`activeSessionId`(이미
`private(set)`로 읽기 가능하나 `ackTimeoutSeconds` init 파라미터)가 없어 컴파일 에러

- [x] **Step 3: 구현**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 프로퍼티 선언부:
```swift
    private(set) var isDriver = false
    private(set) var activeSessionId: UUID = .init()
    private var hasSyncedSession = false
```
바로 다음에 추가:
```swift
    enum SaveAckState: Equatable {
        case idle, pending, succeeded, failed
    }

    @Published var saveAckState: SaveAckState = .idle
    private var saveAttemptToken = 0
    private let ackTimeoutSeconds: TimeInterval
```

`init(metricsThrottle: TimeInterval = 5) {`를 다음으로 교체:
```swift
    init(metricsThrottle: TimeInterval = 5, ackTimeoutSeconds: TimeInterval = 8) {
        self.metricsThrottle = metricsThrottle
        self.ackTimeoutSeconds = ackTimeoutSeconds
```
(이 줄 다음의 기존 본문 `healthKit.$isPaused...`는 그대로 둔다.)

`private func setupConnectivityBindings()`:
```swift
    private func setupConnectivityBindings() {
        connectivity.$receivedSessionStart
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handleIncomingSessionStart(msg) }
            .store(in: &cancellables)

        connectivity.$receivedWorkoutEnd
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in self?.handleIncomingWorkoutEnd(id) }
            .store(in: &cancellables)
    }
```
를 다음으로 교체 (ack 구독 추가):
```swift
    private func setupConnectivityBindings() {
        connectivity.$receivedSessionStart
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handleIncomingSessionStart(msg) }
            .store(in: &cancellables)

        connectivity.$receivedWorkoutEnd
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in self?.handleIncomingWorkoutEnd(id) }
            .store(in: &cancellables)

        connectivity.$receivedMatchSaveResult
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in self?.handleMatchSaveResult(result) }
            .store(in: &cancellables)
    }

    private func handleMatchSaveResult(_ result: MatchSaveResultMessage) {
        guard result.sessionId == activeSessionId else { return }
        connectivity.receivedMatchSaveResult = nil
        saveAckState = result.success ? .succeeded : .failed
    }
```

`saveCurrentMatch()`:
```swift
    /// Watch엔 로컬 저장소가 없다. 저장 버튼 → iOS에 저장 요청을 보내고 iOS가 히스토리에 persist 한다.
    func saveCurrentMatch() {
        guard let session = _currentSession else { return }
        connectivity.sendMatchSave(makeMatchEndMessage(session: session))
    }
```
를 다음으로 교체:
```swift
    /// Watch엔 로컬 저장소가 없다. 저장 버튼 → iOS에 저장 요청을 보내고 iOS가 히스토리에 persist 한다.
    /// iOS의 ack(`matchSaveResult`)를 받아 실제 결과를 반영하며, ackTimeoutSeconds 안에 ack가
    /// 없으면 failed로 전환한다. saveAttemptToken은 재시도로 새 시도가 시작된 뒤 이전 시도의
    /// 지연된 타임아웃이 새 상태를 덮어쓰지 않게 막는 표식이다.
    func saveCurrentMatch() {
        guard let session = _currentSession else { return }
        saveAttemptToken += 1
        let token = saveAttemptToken
        saveAckState = .pending
        connectivity.sendMatchSave(makeMatchEndMessage(session: session))
        DispatchQueue.main.asyncAfter(deadline: .now() + ackTimeoutSeconds) { [weak self] in
            guard let self, saveAttemptToken == token, saveAckState == .pending else { return }
            saveAckState = .failed
        }
    }
```

마지막으로 `#if DEBUG` 블록:
```swift
    #if DEBUG
        func applyIncomingScoreStateForTest(_ state: ScoreState) {
            handleIncomingScoreState(state)
        }

        func applyIncomingSessionStartForTest(_ msg: SessionStartMessage) {
            handleIncomingSessionStart(msg)
        }
    #endif
```
를 다음으로 교체:
```swift
    #if DEBUG
        func applyIncomingScoreStateForTest(_ state: ScoreState) {
            handleIncomingScoreState(state)
        }

        func applyIncomingSessionStartForTest(_ msg: SessionStartMessage) {
            handleIncomingSessionStart(msg)
        }

        func handleMatchSaveResultForTest(_ result: MatchSaveResultMessage) {
            handleMatchSaveResult(result)
        }
    #endif
```

- [x] **Step 4: 통과 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=<id>' -only-testing:watchosTests/WorkoutSessionViewModelTests`
Expected: PASS (전체 5개 신규 테스트 포함)

- [x] **Step 5: 커밋**

```bash
git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "✨ Watch 저장 ack 수신 + 타임아웃 처리"
```

---

### Task 2: SaveButton 4-state + MatchResultView 연결 + 로컬라이즈

**Files:**
- Modify: `WatchApp/Features/Match/Result/Components/SaveButton.swift`
- Modify: `WatchApp/Features/Match/Result/MatchResultView.swift`
- Modify: `WatchApp/en.lproj/Localizable.strings`, `WatchApp/ko.lproj/Localizable.strings`

(View는 자동 테스트 대상이 아니다 — 시뮬레이터/실기기로 수동 확인한다.)

- [x] **Step 1: 로컬라이즈 키 추가**

`WatchApp/ko.lproj/Localizable.strings`에서 다음 줄(현재 29-30번째 줄 부근)을 찾는다:
```
"result_save" = "저장";
"result_saved" = "저장됨";
```
바로 아래에 추가:
```
"result_saving" = "저장 중…";
"result_save_failed" = "실패, 재시도";
```

`WatchApp/en.lproj/Localizable.strings`에서 동일하게:
```
"result_save" = "Save";
"result_saved" = "Saved";
```
바로 아래에 추가:
```
"result_saving" = "Saving…";
"result_save_failed" = "Failed, Retry";
```

- [x] **Step 2: SaveButton.swift 교체**

`WatchApp/Features/Match/Result/Components/SaveButton.swift` 전체를 다음으로 교체:
```swift
import SwiftUI

enum SaveButtonState: Equatable {
    case idle, pending, saved, failed
}

struct SaveButton: View {
    let state: SaveButtonState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(state == .saved || state == .pending)
    }

    private var icon: String {
        switch state {
        case .idle: "square.and.arrow.down"
        case .pending: "ellipsis.circle"
        case .saved: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        switch state {
        case .idle: String(localized: "result_save")
        case .pending: String(localized: "result_saving")
        case .saved: String(localized: "result_saved")
        case .failed: String(localized: "result_save_failed")
        }
    }

    private var tint: Color {
        switch state {
        case .idle: .green
        case .pending: .gray
        case .saved: .gray
        case .failed: .orange
        }
    }
}
```

- [x] **Step 3: MatchResultView.swift 수정**

`@State private var saved = false` 줄을 삭제한다 (더 이상 로컬 상태가 필요 없음 — ViewModel의
`@Published var saveAckState`를 직접 매핑한다).

```swift
            HStack(spacing: 6) {
                SaveButton(saved: saved) { saveMatch() }
                RematchButton { flowViewModel.restartMatch() }
            }
```
를 다음으로 교체:
```swift
            HStack(spacing: 6) {
                SaveButton(state: buttonState) { flowViewModel.saveCurrentMatch() }
                RematchButton { flowViewModel.restartMatch() }
            }
```

`private func saveMatch() { ... }` 함수 전체를 삭제하고, 대신 다음 계산 속성을 추가:
```swift
    private var buttonState: SaveButtonState {
        switch flowViewModel.saveAckState {
        case .idle: .idle
        case .pending: .pending
        case .succeeded: .saved
        case .failed: .failed
        }
    }
```

- [x] **Step 4: 빌드 확인**

Run: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: 시뮬레이터 수동 확인 (페어링된 iOS 시뮬레이터와 함께)**

watch-sync-simulator-trap 메모리대로 연동 동작은 시뮬레이터에서 완전히 재현되지 않을 수 있다
— 가능한 범위까지만 확인: 경기 종료 → 저장 버튼 탭 → "저장 중…" 표시 확인. ack 수신 후
"저장됨"으로 바뀌는지는 페어링 상태에 따라 제한적으로만 확인 가능.

- [x] **Step 6: 커밋**

```bash
git add WatchApp/Features/Match/Result/Components/SaveButton.swift WatchApp/Features/Match/Result/MatchResultView.swift WatchApp/en.lproj/Localizable.strings WatchApp/ko.lproj/Localizable.strings
git commit -m "✨ Watch 저장 버튼에 ack 기반 진짜 상태 표시"
```

---

### Task 3: 전체 검증 + code-review

- [x] **Step 1:** Watch 빌드/테스트 전체 GREEN

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=<id>'`

- [x] **Step 2:** iOS 빌드 회귀 확인 (이 단계는 iOS 파일을 건드리지 않지만, Shared 의존성 확인 차원)

Run: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

- [x] **Step 3:** `make fix && make lint` — 모두 클린

- [x] **Step 4:** `/code-review` 실행 → 지적 사항은 `superpowers:receiving-code-review`로 검증 후 반영

- [ ] **Step 5:** **실기기 2대로 수동 검증** (이 단계의 핵심 — `watch-sync-simulator-trap` 메모리에
  따라 연동 버그는 시뮬레이터에서 재현되지 않는다):
  - Watch에서 저장 → iOS가 정상 동작 중이면 Watch가 "저장 중…" → "저장됨"으로 전환되는지 확인
  - iOS 앱을 백그라운드로 보내거나 종료한 뒤 Watch에서 저장 → 8초 후 "실패, 재시도"로 전환되는지 확인
  - "실패, 재시도" 상태에서 버튼을 다시 탭하면 재시도되고, iOS가 살아있으면 "저장됨"으로 바뀌는지 확인

- [ ] **Step 6:** 위 검증·반영이 끝나면 `superpowers:finishing-a-development-branch`로 브랜치 정리

---

## 이 단계가 검증하는 것 (1~4단계 전체 마무리)

- Watch 저장 버튼이 iOS의 실제 persist 결과를 정확히 반영한다 — 더 이상 "보냈다 = 저장됐다"로
  거짓 신호를 주지 않는다.
- ack가 오지 않으면(iOS 꺼짐, 연결 끊김 등) 8초 후 "실패, 재시도"로 전환되어 무한 로딩이 없다.
- 재시도 시 이전 시도의 지연된 타임아웃이 새 시도의 상태를 덮어쓰지 않는다(토큰 검증).
- (1단계와 함께) `upsert` 실패가 컨텍스트를 stuck 상태로 만들지 않는다.
- (2단계와 함께) iOS 로컬 저장도 동일하게 성공/실패를 정확히 보여주고 재시도 가능하다.

이로써 `docs/superpowers/specs/ios/2026-06-25-upsert-failure-handling-design.md`의 목표
4가지(컨텍스트 stuck 방지, iOS 로컬 정확한 UI, Watch ack 프로토콜, ack 타임아웃)가 모두
구현된다.
