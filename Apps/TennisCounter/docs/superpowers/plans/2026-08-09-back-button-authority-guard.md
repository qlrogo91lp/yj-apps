# 뒤로가기 버튼 권한 가드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워크아웃 탭으로 새어나온 매치용 뒤로가기 버튼을 막고, mirror가 진행 중인 매치를 로컬에서 임의로 리셋하지 못하게 해 두 기기의 매치 상태가 어긋나지 않게 한다.

**Architecture:** 두 결함이 겹쳐 하나의 증상을 만든다. (1) iOS는 `.toolbar`가 개별 탭이 아니라 `TabView`에 걸려 있어 매치용 뒤로가기가 워크아웃 탭에도 렌더링되고, 동작이 `selectedTab` 없이 `phase`만으로 결정된다. (2) `startNewMatch(notifyRemote:)`가 `isDriver`와 무관하게 로컬 `phase`를 리셋하는데 `sendMatchReset`은 `isDriver` 가드에 막혀 나가지 않아, mirror만 조용히 모드선택으로 빠진다. 권한 가드는 ViewModel(진짜 수정)과 View(죽은 버튼 노출 방지) 양쪽에 넣는다.

**Tech Stack:** Swift 6 toolchain (language mode v5), SwiftUI, Combine, Swift Testing (`@Test`/`#expect`)

## Global Constraints

- **권한 모델을 따른다.** driver만 공유 매치 상태를 바꾼다. mirror는 받은 상태를 적용만 한다 — 점수 입력·undo가 이미 `isDriver`로 막혀 있는 것과 같은 규칙을 뒤로가기에도 적용한다.
- **가드 범위는 `.playing`으로 한정한다.** `.finished`는 종료된 매치라 어긋날 진행 상태가 없고, 여기까지 막으면 mirror가 결과 화면에 갇힌다 (driver의 `.finished` 뒤로가기는 `sendMatchReset`을 보내지 않아 mirror에게 알려주지도 않는다).
- **수신 경로(`notifyRemote: false`)는 절대 막지 않는다.** `handleIncomingMatchReset`이 타는 경로이고, mirror가 driver의 리셋을 받아들이는 유일한 수단이다.
- **툴바 슬롯은 비우지 말고 투명 플레이스홀더로 채운다.** `Color.clear.frame(width: 36, height: 36)` — 워치가 이미 쓰는 방식이다. 슬롯이 사라지면 `.principal` 아이템(타이틀·`WorkoutIndicator`) 위치가 흔들린다.
- ViewModel 테스트는 `@MainActor` 필수. Swift Testing(`@Test`/`#expect`) 사용. **View는 테스트하지 않는다** — View 변경분은 실기기·시뮬레이터 수동 확인이 유일한 검증 수단이다.
- SwiftFormat 4-space indent, max width 150. 각 Task 끝에서 `make fix` 후 커밋.
- `.xcodeproj` 직접 편집 금지. 이 플랜은 파일 생성·삭제가 없어 Xcode GUI 작업이 없다.
- 커밋 브랜치: `feature/back-button-mirror-guard`.

### 시작 상태

| 항목 | 값 |
|---|---|
| 저장소 | `/Users/yj/Workspace/Projects/tennis-counter` |
| 브랜치 | `feature/back-button-mirror-guard` (`main` @ `e041683`에서 분기) |
| RalliKit 참조 | 원격 `https://github.com/qlrogo91lp/ralli-kit.git`, `branch: main` |

**주의 — 작업 트리에 미커밋 변경이 있다.** 조사 세션에서 Task 1·2의 테스트 코드를 이미 작성해 두었다:

```
 M iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
 M watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
```

Task 1·2의 Step 1은 **새로 쓰는 대신 아래 코드와 일치하는지 확인**하는 단계다. 일치하지 않으면 아래 코드로 맞춘다.

### 검증 명령

시뮬레이터 UDID는 **머신마다 다르다.** 매 세션 시작 시 다시 확인할 것:

```bash
xcrun simctl list devices available | grep -E "iPhone 17 Pro|Apple Watch Series 11"
```

작성 시점 값 — iPhone 17 Pro: `C29B5911-545A-4FD0-853B-9B219A300025`, Apple Watch Series 11 (46mm): `74666695-204D-45AC-8787-2CFEA2CE0C51`

```bash
# iOS
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Watch (이름 매칭 실패함 — 반드시 UDID)
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51'
```

---

## 근본 원인

### 결함 1 — iOS 툴바가 TabView에 걸려 두 탭이 공유한다

`iOSApp/Features/WorkoutSession/WorkoutSessionView.swift:36-55`. `.toolbar`가 `TabView` 자체에 붙어 있어 leading 아이템이 워크아웃 탭(tag 0)과 매치 탭(tag 1) 모두에 렌더링된다. 그런데 동작 분기는 `viewModel.phase`만 본다:

```swift
TabView(selection: $selectedTab) {
    WorkoutDashboardView(...).tag(0)
    scoreTabContent.tag(1)
}
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        switch viewModel.phase {          // ← selectedTab을 보지 않는다
        case .playing: BackButton { ...startNewMatch() }
        ...
```

그래서 **워크아웃 컨트롤 화면의 뒤로가기 = 매치 리셋 버튼**이다. `hasMatchProgress`가 false면 확인 알림도 없이 즉시 리셋된다. mirror뿐 아니라 **driver에서도 재현된다.**

바로 아래 `.principal` 아이템은 `selectedTab == 1`을 체크한다 — 탭 인지가 필요하다는 걸 알고 있었으나 leading 슬롯에만 누락됐다.

워치는 이 문제가 없다. 각 탭이 **자기 툴바를 선언**하고 워크아웃 탭들은 leading 슬롯을 투명 플레이스홀더로 덮는다 (`WatchApp/Features/WorkoutSession/WorkoutSessionView.swift:54-58`, `63-67`). iOS에 같은 처리가 안 들어갔다.

### 결함 2 — `startNewMatch`가 권한 없이 로컬 상태를 리셋한다

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:235-241` (워치는 `WatchApp/.../WorkoutSessionViewModel.swift:259-267`, 동일 구조):

```swift
func startNewMatch(notifyRemote: Bool = true) {
    if notifyRemote, isDriver, case .playing = phase {
        connectivity.sendMatchReset(sessionId: sessionId)   // ← isDriver일 때만 상대에게 알림
    }
    _currentSession = nil
    phase = .modeSelection                                   // ← 권한과 무관하게 무조건 로컬 리셋
}
```

mirror가 호출하면 상대에게 알리지도 않고 자기 화면만 리셋한다 → driver는 계속 경기 중, mirror만 모드선택. 게다가 mirror는 `applyRemoteState`가 `snapshots.removeAll()`을 하므로 `canUndo`가 항상 false고, `hasProgress`는 `canUndo`를 포함하므로 **첫 게임이 끝나기 전(예: 30-15)에는 확인 알림조차 없이** 즉시 리셋된다.

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | iOS 세션 상태·권한 | `startNewMatch` 권한 가드 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | Watch 세션 상태·권한 | `startNewMatch` 권한 가드 (대칭) |
| `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` | iOS 2탭 컨테이너·툴바 | 탭 게이팅 + mirror 시 뒤로가기 숨김 |
| `WatchApp/Features/Match/Score/ScoreView.swift` | Watch 점수 화면·툴바 | mirror 시 뒤로가기 숨김 |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | iOS ViewModel 테스트 | 권한 가드 테스트 3개 추가 |
| `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | Watch ViewModel 테스트 | 권한 가드 테스트 4개 추가 |
| `docs/superpowers/logs/2026-08-09-back-button-authority-guard.md` | 작업 기록 | 신규 |

**건드리지 않는 것** (의도적):

- `restartMatch()` — mirror의 rematch는 기존 테스트(`restartMatchPreservesMirrorRole`)가 보장하는 의도된 동작이다. 별개 사안.
- `MatchResultView`의 뒤로가기 (iOS 툴바 `.finished`, Watch `MatchResultView.swift:54`) — Global Constraints의 `.playing` 한정 원칙에 따라 mirror도 계속 사용 가능.
- `isDriver`를 `@Published`로 바꾸지 않는다 — `isDriver`는 `startMatch()` 안에서 `phase`와 항상 함께 바뀌고, `phase`가 `@Published`라 View가 같이 갱신된다. 기존 `ScoreView(isDriver:)` 전달도 이 동작에 이미 의존한다. 이 플랜에서 바꾸면 무관한 변경이 섞인다.

---

## Task 1: iOS ViewModel 권한 가드

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:235-241`
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` (파일 끝에 추가)

**Interfaces:**
- Consumes: 기존 `startMatch(options:sessionId:isRemote:)` — `isRemote: true`면 mirror가 된다. `handleIncomingMatchResetForTest(_:)`, `currentSessionIdForTest` (DEBUG 전용 헬퍼, 이미 존재).
- Produces: `startNewMatch(notifyRemote:)`의 계약 변경 — `.playing` + mirror + `notifyRemote: true`면 **no-op**. 나머지 조합은 기존과 동일. Task 3이 이 계약에 맞춰 View를 정리한다.

- [ ] **Step 1: 실패하는 테스트 확인 (이미 작성돼 있음 — 내용 일치 확인)**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` 맨 끝 `}` 직전에 아래 3개가 있어야 한다:

```swift
    /// mirror는 진행 중인 매치를 끝낼 권한이 없다. 로컬로 리셋해버리면 driver는 계속 경기 중인데
    /// mirror만 모드선택으로 빠져 두 기기가 어긋난다 (sendMatchReset은 isDriver 가드에 막혀 나가지도 않는다).
    @Test @MainActor func mirrorCannotResetPlayingMatchLocally() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.startNewMatch()
        guard case .playing = vm.phase else {
            Issue.record("mirror의 로컬 리셋은 무시되고 playing이 유지되어야 함")
            return
        }
    }

    /// 위 가드가 driver의 정상 리셋까지 막으면 안 된다.
    @Test @MainActor func driverCanResetPlayingMatchLocally() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // driver
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("driver는 진행 중인 매치를 끝낼 수 있어야 함")
            return
        }
    }

    /// 종료된 매치의 결과 화면은 mirror도 스스로 닫을 수 있다 — 진행 중인 매치가 아니라 어긋날 상태가 없다.
    /// (가드를 .playing으로 한정한 이유. 여기까지 막으면 mirror가 결과 화면에 갇힌다.)
    @Test @MainActor func mirrorCanLeaveFinishedResultScreen() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("mirror도 결과 화면에서는 빠져나올 수 있어야 함")
            return
        }
    }
```

기존 `mirrorMatchResetReturnsToModeSelection`(같은 파일)이 수신 경로 회귀를 이미 덮으므로 별도 추가는 불필요하다.

- [ ] **Step 2: 테스트를 돌려 RED 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:iosTests/WorkoutSessionViewModelTests
```

Expected: `mirrorCannotResetPlayingMatchLocally` **FAIL** (`mirror의 로컬 리셋은 무시되고 playing이 유지되어야 함`).
`driverCanResetPlayingMatchLocally`·`mirrorCanLeaveFinishedResultScreen`은 이미 PASS (현재 동작을 고정하는 회귀 테스트).

- [ ] **Step 3: 가드 구현**

`WorkoutSessionViewModel.swift`의 `startNewMatch`를 통째로 교체:

```swift
    func startNewMatch(notifyRemote: Bool = true) {
        if notifyRemote, case .playing = phase {
            // 진행 중인 매치를 끝낼 권한은 driver에게만 있다. mirror가 로컬로 리셋하면
            // sendMatchReset이 나가지 않아 driver는 계속 경기 중인데 mirror만 모드선택으로 빠진다.
            // 수신 경로(notifyRemote: false)는 이 가드를 타지 않는다 — mirror가 driver의 리셋을 받는 유일한 통로다.
            guard isDriver else { return }
            connectivity.sendMatchReset(sessionId: sessionId)
        }
        _currentSession = nil
        phase = .modeSelection
    }
```

- [ ] **Step 4: 테스트를 돌려 GREEN 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: `** TEST SUCCEEDED **`. 특히 기존 `mirrorMatchResetReturnsToModeSelection`·`remoteStartMatchSyncsSessionIdForMatchReset`(수신 경로)가 계속 통과해야 한다.

- [ ] **Step 5: 포맷 + 커밋**

```bash
make fix
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "🐛 iOS mirror가 진행 중인 매치를 로컬 리셋하지 못하게 가드"
```

---

## Task 2: Watch ViewModel 권한 가드

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:259-267`
- Test: `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` (파일 끝에 추가)

**Interfaces:**
- Consumes: `startMatch(options:sessionId:isRemote:)` — `isRemote: true`면 mirror. 워치에는 iOS의 `handleIncomingMatchResetForTest`에 해당하는 DEBUG 헬퍼가 **없다**. 수신 경로는 `startNewMatch(notifyRemote: false)`를 직접 호출해 검증한다 (`handleIncomingMatchReset`이 타는 바로 그 경로).
- Produces: iOS와 동일한 계약. 워치는 추가로 `saveAckState`/`saveAttemptToken`을 리셋하는데, no-op 경로에서는 이것도 건드리지 않아야 한다 (바뀐 게 없으니 되돌릴 ack 상태도 없다).

- [ ] **Step 1: 실패하는 테스트 확인 (이미 작성돼 있음 — 내용 일치 확인)**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` 맨 끝 `}` 직전에 아래 4개가 있어야 한다:

```swift
    /// mirror는 진행 중인 매치를 끝낼 권한이 없다. 로컬로 리셋해버리면 driver는 계속 경기 중인데
    /// mirror만 모드선택으로 빠져 두 기기가 어긋난다 (sendMatchReset은 isDriver 가드에 막혀 나가지도 않는다).
    @Test @MainActor func mirrorCannotResetPlayingMatchLocally() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.startNewMatch()
        guard case .playing = vm.phase else {
            Issue.record("mirror의 로컬 리셋은 무시되고 playing이 유지되어야 함")
            return
        }
    }

    /// 위 가드가 driver의 정상 리셋까지 막으면 안 된다.
    @Test @MainActor func driverCanResetPlayingMatchLocally() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) // driver
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("driver는 진행 중인 매치를 끝낼 수 있어야 함")
            return
        }
    }

    /// driver가 보낸 matchReset 수신 경로(notifyRemote: false)는 mirror에도 그대로 적용되어야 한다.
    @Test @MainActor func mirrorAppliesIncomingMatchReset() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.startNewMatch(notifyRemote: false) // handleIncomingMatchReset이 타는 경로
        guard case .modeSelection = vm.phase else {
            Issue.record("driver의 matchReset을 받으면 mirror도 모드선택으로 돌아가야 함")
            return
        }
    }

    /// 종료된 매치의 결과 화면은 mirror도 스스로 닫을 수 있다 — 진행 중인 매치가 아니라 어긋날 상태가 없다.
    /// (가드를 .playing으로 한정한 이유. 여기까지 막으면 mirror가 결과 화면에 갇힌다.)
    @Test @MainActor func mirrorCanLeaveFinishedResultScreen() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), isRemote: true) // mirror
        vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 4)])
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("mirror도 결과 화면에서는 빠져나올 수 있어야 함")
            return
        }
    }
```

주의: 워치의 `finishMatch`는 `[SetScore]`를 받는다 (iOS는 `[(my: Int, your: Int)]`). 위 코드가 이미 그렇게 돼 있다.

- [ ] **Step 2: 테스트를 돌려 RED 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' \
  -only-testing:watchosTests/WorkoutSessionViewModelTests
```

Expected: `mirrorCannotResetPlayingMatchLocally` **FAIL**. 나머지 3개는 PASS.

- [ ] **Step 3: 가드 구현**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 `startNewMatch`를 통째로 교체:

```swift
    func startNewMatch(notifyRemote: Bool = true) {
        if notifyRemote, case .playing = phase {
            // 진행 중인 매치를 끝낼 권한은 driver에게만 있다. mirror가 로컬로 리셋하면
            // sendMatchReset이 나가지 않아 driver는 계속 경기 중인데 mirror만 모드선택으로 빠진다.
            // 수신 경로(notifyRemote: false)는 이 가드를 타지 않는다 — mirror가 driver의 리셋을 받는 유일한 통로다.
            guard isDriver else { return }
            connectivity.sendMatchReset(sessionId: activeSessionId)
        }
        _currentSession = nil
        phase = .modeSelection
        saveAckState = .idle
        saveAttemptToken += 1
    }
```

- [ ] **Step 4: 테스트를 돌려 GREEN 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51'
```

Expected: `** TEST SUCCEEDED **`. 특히 기존 `startNewMatchResetsSaveAckState`가 계속 통과해야 한다 (driver 경로라 영향 없음).

- [ ] **Step 5: 포맷 + 커밋**

```bash
make fix
git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "🐛 Watch mirror가 진행 중인 매치를 로컬 리셋하지 못하게 가드"
```

---

## Task 3: iOS 툴바 — 탭 게이팅 + mirror 뒤로가기 숨김

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift:39-55` (툴바 leading 아이템), `:110` 부근 (computed property 추가)

**Interfaces:**
- Consumes: Task 1의 `startNewMatch` 계약 (mirror `.playing`에서는 no-op), 기존 `viewModel.isDriver`·`viewModel.phase`·`selectedTab`·`hasMatchProgress`.
- Produces: 없음 (최종 UI).

**테스트 없음.** CLAUDE.md: "View — 테스트하지 않는다. UI는 직접 확인." Step 3의 수동 확인이 유일한 검증이다.

- [ ] **Step 1: 툴바 leading 아이템을 탭으로 게이팅**

`WorkoutSessionView.swift`에서 아래 블록을 찾는다:

```swift
            ToolbarItem(placement: .topBarLeading) {
                switch viewModel.phase {
                case .modeSelection:
                    BackButton { selectedTab = 0 }
                case .playing:
                    BackButton {
                        if hasMatchProgress {
                            showEndMatchConfirm = true
                        } else {
                            viewModel.startNewMatch()
                        }
                    }
                case .finished:
                    BackButton { viewModel.startNewMatch() }
                }
            }
```

이것으로 교체:

```swift
            ToolbarItem(placement: .topBarLeading) {
                if selectedTab == 1 {
                    matchBackButton
                } else {
                    // 툴바가 개별 탭이 아니라 TabView에 걸려 두 탭이 공유한다. 워크아웃 탭에
                    // 매치용 뒤로가기가 새어나가지 않도록 자리만 비운다 (워치와 같은 방식 —
                    // 슬롯을 없애면 .principal 아이템 위치가 흔들린다).
                    Color.clear.frame(width: 36, height: 36)
                }
            }
```

- [ ] **Step 2: `matchBackButton` computed property 추가**

같은 파일에서 `scoreTabContent`를 선언하는 `@ViewBuilder` 줄 **바로 위**에 추가 (`body` 클로저 밖, 타입 스코프):

```swift
    /// 매치 탭 전용 뒤로가기 — phase별로 동작이 다르다.
    /// `.playing`에서 진행 중인 매치를 끝낼 권한은 driver에게만 있다 (점수 입력·undo와 같은 규칙).
    /// mirror에게는 눌러도 아무 일 없는 버튼을 보여주는 대신 자리를 비운다.
    @ViewBuilder
    private var matchBackButton: some View {
        switch viewModel.phase {
        case .modeSelection:
            BackButton { selectedTab = 0 }
        case .playing:
            if viewModel.isDriver {
                BackButton {
                    if hasMatchProgress {
                        showEndMatchConfirm = true
                    } else {
                        viewModel.startNewMatch()
                    }
                }
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        case .finished:
            BackButton { viewModel.startNewMatch() }
        }
    }
```

- [ ] **Step 3: 빌드 + 시뮬레이터 수동 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

시뮬레이터에서 폰 단독(driver)으로 확인:

| 확인 | 기대 |
|---|---|
| 모드선택 화면 → 매치 탭의 뒤로가기 | 있음. 누르면 워크아웃 탭으로 이동 |
| 모드선택 화면 → 워크아웃 탭 | 뒤로가기 **없음** (이전엔 있었음) |
| 매치 시작(0-0) → 워크아웃 탭 | 뒤로가기 **없음**. ← 이 결함의 핵심 재현 경로 |
| 매치 시작(0-0) → 매치 탭 | 뒤로가기 있음. 누르면 즉시 모드선택 (driver, 진행 없음) |
| 점수 1점 후 → 매치 탭 뒤로가기 | 확인 알림 표시 |
| 매치 진행 중 워크아웃 탭 ↔ 매치 탭 전환 | 상단 경과시간(`WorkoutIndicator`) 위치가 흔들리지 않음 |

- [ ] **Step 4: 포맷 + 커밋**

```bash
make fix
git add iOSApp/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "🐛 iOS 워크아웃 탭에 새어나온 매치 뒤로가기 차단 + mirror 시 숨김"
```

---

## Task 4: Watch 점수 화면 — mirror 뒤로가기 숨김

**Files:**
- Modify: `WatchApp/Features/Match/Score/ScoreView.swift:62-74` (툴바)

**Interfaces:**
- Consumes: Task 2의 `startNewMatch` 계약, 기존 `flowViewModel.isDriver`.
- Produces: 없음 (최종 UI).

**테스트 없음** (View). 워치는 각 탭이 자기 툴바를 선언하므로 결함 1(탭 누수)은 해당 없다 — mirror 숨김만 하면 된다.

- [ ] **Step 1: 툴바를 `isDriver`로 게이팅**

`ScoreView.swift`에서 아래 블록을 찾는다:

```swift
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton {
                    if viewModel.mySetScore == 0, viewModel.yourSetScore == 0,
                       viewModel.myGameScore == 0, viewModel.yourGameScore == 0
                    {
                        flowViewModel.startNewMatch()
                    } else {
                        showExitConfirm = true
                    }
                }
            }
        }
```

이것으로 교체:

```swift
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // 진행 중인 매치를 끝낼 권한은 driver에게만 있다 (점수 입력·undo와 같은 규칙).
                // mirror에게는 눌러도 아무 일 없는 버튼 대신 자리를 비운다 — 워크아웃 탭들과 같은 방식.
                if flowViewModel.isDriver {
                    BackButton {
                        if viewModel.mySetScore == 0, viewModel.yourSetScore == 0,
                           viewModel.myGameScore == 0, viewModel.yourGameScore == 0
                        {
                            flowViewModel.startNewMatch()
                        } else {
                            showExitConfirm = true
                        }
                    }
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
        }
```

- [ ] **Step 2: 빌드 + 시뮬레이터 수동 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' build
```

Expected: `** BUILD SUCCEEDED **`

워치 시뮬레이터에서 단독(driver)으로 확인:

| 확인 | 기대 |
|---|---|
| 워치에서 매치 시작(driver) → 점수 화면 | 뒤로가기 있음, 기존과 동일하게 동작 |
| 점수 1점 후 뒤로가기 | 확인 다이얼로그 표시 |
| 좌우 스와이프(컨트롤·메트릭 탭) | 뒤로가기 없음 (기존과 동일) |

mirror 상태는 실기기 2대 회귀에서 확인한다 (시뮬레이터 페어링으로도 가능하나 불안정).

- [ ] **Step 3: 포맷 + 커밋**

```bash
make fix
git add WatchApp/Features/Match/Score/ScoreView.swift
git commit -m "🐛 Watch mirror 상태에서 매치 뒤로가기 숨김"
```

---

## Task 5: 작업 기록 로그

**Files:**
- Create: `docs/superpowers/logs/2026-08-09-back-button-authority-guard.md`

**Interfaces:** 없음 (문서).

- [ ] **Step 1: 로그 작성**

아래 목차를 채운다. 커밋 메시지에 담기 어려운 맥락을 보존하는 게 목적이다 (CLAUDE.md의 logs 규약).

- **증상**: 실기기 테스트 중 폰 워크아웃 컨트롤 화면에서 뒤로가기를 눌렀더니 폰만 매치가 초기화되고 워치는 계속 경기 중이었다.
- **근본 원인 2가지**: 위 "근본 원인" 절 내용 (툴바 공유 + 권한 없는 로컬 리셋). 두 결함이 겹쳐 하나의 증상이 됐다는 점을 명시.
- **왜 워치는 안 그랬나**: 워치는 탭마다 툴바를 선언하고 투명 플레이스홀더로 슬롯을 덮어놨다. iOS에 같은 처리가 누락됐다.
- **수정 범위 결정**: 가드를 `.playing`으로 한정한 이유 (`.finished`까지 막으면 mirror가 결과 화면에 갇힘, 진행 중 매치가 아니라 어긋날 상태 없음). `restartMatch`·`isDriver` `@Published` 전환을 건드리지 않은 이유.
- **before/after 코드**: `startNewMatch` 2개, iOS 툴바, Watch 툴바.
- **테스트**: 추가한 테스트 7개와 각각이 막는 회귀. `mirrorCannotResetPlayingMatchLocally`가 RED→GREEN으로 버그를 재현·검증했다는 사실.
- **남은 것**: View 변경분은 단위 테스트가 없어 실기기 2대 회귀가 유일한 최종 검증 (아래 체크리스트).

- [ ] **Step 2: 커밋**

```bash
git add docs/superpowers/logs/2026-08-09-back-button-authority-guard.md
git commit -m "📝 뒤로가기 권한 가드 작업 기록"
```

---

## 완료 후 확인

- [x] iOS 테스트 `** TEST SUCCEEDED **`
- [x] Watch 테스트 `** TEST SUCCEEDED **`
- [x] iOS·Watch Release 빌드 통과 (Plan 1 교훈 — `#Preview`가 Release에서 깨진 전례가 있다)

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Release build
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' -configuration Release build
```

- [ ] **실기기 2대 회귀** (이 플랜의 핵심 — mirror 경로는 시뮬레이터로 재현이 불안정하다):
  - [ ] 워치에서 매치 시작(워치 driver) → 폰이 자동 합류(mirror) → **폰 점수 화면에 뒤로가기 없음**
  - [ ] 같은 상태에서 폰 워크아웃 탭 → **뒤로가기 없음** (원 증상 재현 경로)
  - [ ] 워치에서 점수 진행 → 폰에 계속 반영됨 (가드가 미러링을 막지 않았는지)
  - [ ] 워치(driver)에서 뒤로가기 → 확인 후 종료 → **폰도 함께 모드선택으로 복귀** (matchReset 수신 경로 정상)
  - [ ] 폰에서 매치 시작(폰 driver) → 워치가 mirror → **워치 점수 화면에 뒤로가기 없음**
  - [ ] 폰(driver)에서 뒤로가기 → **워치도 함께 모드선택으로 복귀**
  - [ ] 매치 종료 후 결과 화면 → **mirror 쪽에서도 뒤로가기 동작함** (`.finished`는 의도적으로 허용)
  - [ ] 매치 진행 중 폰 탭 전환 시 상단 경과시간 위치가 흔들리지 않음
