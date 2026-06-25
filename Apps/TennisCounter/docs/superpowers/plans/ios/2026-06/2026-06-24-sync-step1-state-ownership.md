# 동기화 재설계 1단계: 상태 소유권 이동 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ScoreViewModel`을 `ScoreView`의 `@StateObject`에서 떼어내 `WorkoutSessionViewModel`이 소유하는 단일 인스턴스로 만들고, `resetAll(options:)`로 재사용한다. 이로써 리매치/탭전환/재진입 시 점수가 view 재생성에 의존하지 않고 명시적으로 초기화된다(증상 1 해소).

**Architecture:** `WorkoutSessionViewModel`이 `scoreVM: ScoreViewModel`을 프로퍼티로 소유한다. `startMatch`/`restartMatch`에서 `scoreVM.resetAll(options:)`를 호출한다. `ScoreView`는 `@ObservedObject`로 주입받아 표시만 한다. 동기화(connectivity) 책임은 이 단계에서 건드리지 않고 그대로 둔다(2단계에서 이동).

**Tech Stack:** Swift, SwiftUI, Combine, Swift Testing (`@Test`/`#expect`), Xcode 16 PBXFileSystemSynchronizedRootGroup.

**범위 메모:** 이 plan은 spec(`docs/superpowers/specs/ios/2026-06-24-sync-authority-redesign-design.md`)의 구현 순서 1단계만 다룬다. driver/mirror 단방향(2단계), workoutEnd 가드·미러 UI(3단계), 저장 upsert(4단계)는 별도 plan.

**작업 브랜치:** main에서 `git switch -c sync-step1-state-ownership`로 분기 후 작업한다.

**빌드/테스트 명령 (CLAUDE.md 참조):**
- iOS 빌드: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- iOS 테스트: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Watch 빌드: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`
- Watch 테스트: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'`

---

## File Structure

| 파일 | 책임 | 이 단계 변경 |
|------|------|------------|
| `iOSApp/Features/Match/Score/ScoreViewModel.swift` | 점수 비즈니스 로직 | `options` var화, `resetAll(options:)` |
| `WatchApp/Features/Match/Score/ScoreViewModel.swift` | 점수 비즈니스 로직 | `options` var화, `resetAll(options:)` 신설 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 세션/경기 흐름 | `scoreVM` 소유, start/restart 시 reset |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 세션/경기 흐름 | `scoreVM` 소유, onMatchFinished 연결, start 시 reset |
| `iOSApp/Features/Match/Score/ScoreView.swift` | 점수 화면 | `@StateObject`→`@ObservedObject` 주입 |
| `WatchApp/Features/Match/Score/ScoreView.swift` | 점수 화면 | `@StateObject`→`@ObservedObject` 주입 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` | 세션 컨테이너 | `scoreVM` 주입 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionView.swift` | 세션 컨테이너 | `scoreVM` 주입 |
| `iosTests/Match/ScoreViewModelTests.swift` | iOS 테스트 | resetAll 테스트 |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | iOS 테스트 | 리매치 reset 테스트 |
| `watchosTests/Match/ScoreViewModelTests.swift` | Watch 테스트 | resetAll 테스트 |
| `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | Watch 테스트 | 리매치 reset 테스트 |

---

### Task 0: 브랜치 생성

- [ ] **Step 1: main에서 작업 브랜치 분기**

Run:
```bash
git switch -c sync-step1-state-ownership
```
Expected: `Switched to a new branch 'sync-step1-state-ownership'`

---

### Task 1: iOS `ScoreViewModel.resetAll(options:)`

**Files:**
- Modify: `iOSApp/Features/Match/Score/ScoreViewModel.swift`
- Test: `iosTests/Match/ScoreViewModelTests.swift`

기존 `resetAll()`은 인자가 없고 호출부도 없다. options까지 교체 가능한 `resetAll(options:)`로 바꿔 단일 인스턴스 재사용을 가능하게 한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Match/ScoreViewModelTests.swift`에 추가:
```swift
@Test @MainActor func resetAllClearsStateAndAppliesNewOptions() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.myGameScore = 3
    vm.mySetScore = 1
    vm.completedSets = [(my: 6, your: 4)]

    let newOptions = MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false)
    vm.resetAll(options: newOptions)

    #expect(vm.myGameScore == 0)
    #expect(vm.yourGameScore == 0)
    #expect(vm.mySetScore == 0)
    #expect(vm.yourSetScore == 0)
    #expect(vm.completedSets.isEmpty)
    #expect(vm.matchResult == nil)
    #expect(vm.options.mode == .bestOfThree)
    #expect(vm.score.noAdRule == false)
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: iOS 테스트 명령 (위 헤더 참조)
Expected: 컴파일 에러 또는 FAIL — `resetAll(options:)` 시그니처 없음 / `options` set 불가

- [ ] **Step 3: 구현**

`iOSApp/Features/Match/Score/ScoreViewModel.swift`에서:

`let options: MatchOptions` → 다음으로 변경:
```swift
    private(set) var options: MatchOptions
```

기존 `resetAll()` (현재 70~81행)을 다음으로 교체:
```swift
    func resetAll(options: MatchOptions) {
        self.options = options
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        currentSetNumber = 1
        completedSets = []
        matchResult = nil
        tieBreakInProgress = false
        score.noAdRule = options.noAdRule
        score.resetData()
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: iOS 테스트 명령
Expected: `resetAllClearsStateAndAppliesNewOptions` PASS, 기존 테스트 모두 GREEN

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/Score/ScoreViewModel.swift iosTests/Match/ScoreViewModelTests.swift
git commit -m "♻️ iOS ScoreViewModel: resetAll(options:)로 재사용 가능하게"
```

---

### Task 2: Watch `ScoreViewModel.resetAll(options:)`

**Files:**
- Modify: `WatchApp/Features/Match/Score/ScoreViewModel.swift`
- Test: `watchosTests/Match/ScoreViewModelTests.swift`

Watch `ScoreViewModel`에는 `resetAll`이 없다. 신설한다. (Watch는 `matchResult` 대신 `onMatchFinished` 콜백을 쓰므로 matchResult 리셋은 없다.)

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Match/ScoreViewModelTests.swift`에 추가:
```swift
@Test @MainActor func resetAllClearsStateAndAppliesNewOptions() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.myGameScore = 3
    vm.mySetScore = 1
    vm.completedSets = [SetScore(my: 6, your: 4)]

    let newOptions = MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false)
    vm.resetAll(options: newOptions)

    #expect(vm.myGameScore == 0)
    #expect(vm.yourGameScore == 0)
    #expect(vm.mySetScore == 0)
    #expect(vm.yourSetScore == 0)
    #expect(vm.completedSets.isEmpty)
    #expect(vm.options.mode == .bestOfThree)
    #expect(vm.score.noAdRule == false)
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: Watch 테스트 명령
Expected: 컴파일 에러 — `resetAll(options:)` 없음 / `options` set 불가

- [ ] **Step 3: 구현**

`WatchApp/Features/Match/Score/ScoreViewModel.swift`에서:

`let options: MatchOptions` → 변경:
```swift
    private(set) var options: MatchOptions
```

`undo()` 메서드 아래(45~47행 부근)에 추가:
```swift
    func resetAll(options: MatchOptions) {
        self.options = options
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        completedSets = []
        tieBreakInProgress = false
        score.noAdRule = options.noAdRule
        score.reset()
    }
```

(주의: `tieBreakInProgress`는 현재 `private var`이지만 같은 타입 내부이므로 접근 가능. `score.reset()`은 `Score`의 public 메서드.)

- [ ] **Step 4: 테스트 통과 확인**

Run: Watch 테스트 명령
Expected: `resetAllClearsStateAndAppliesNewOptions` PASS, 기존 테스트 GREEN

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/Match/Score/ScoreViewModel.swift watchosTests/Match/ScoreViewModelTests.swift
git commit -m "♻️ Watch ScoreViewModel: resetAll(options:) 신설"
```

---

### Task 3: iOS `WorkoutSessionViewModel`이 `scoreVM` 소유

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

`WorkoutSessionViewModel`이 단일 `scoreVM`을 소유하고, `startMatch`/`restartMatch`에서 `resetAll(options:)`로 초기화한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가:
```swift
@Test @MainActor func restartMatchResetsScoreVM() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.scoreVM.myGameScore = 3
    vm.scoreVM.mySetScore = 1
    vm.scoreVM.completedSets = [(my: 6, your: 4)]

    vm.restartMatch()

    #expect(vm.scoreVM.myGameScore == 0)
    #expect(vm.scoreVM.mySetScore == 0)
    #expect(vm.scoreVM.completedSets.isEmpty)
}

@Test @MainActor func startMatchAppliesOptionsToScoreVM() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false))
    #expect(vm.scoreVM.options.mode == .bestOfThree)
    #expect(vm.scoreVM.score.noAdRule == false)
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: iOS 테스트 명령
Expected: 컴파일 에러 — `vm.scoreVM` 없음

- [ ] **Step 3: 구현**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

프로퍼티 영역(예: `private var _currentSession: MatchSession?` 부근)에 추가:
```swift
    let scoreVM = ScoreViewModel()
```

`startMatch(options:isRemote:)` 안에서 `phase = .playing(options)` **직전**에 추가:
```swift
        scoreVM.resetAll(options: options)
```

(`restartMatch()`는 이미 `startMatch`를 호출하므로 별도 수정 불필요. 확인만.)

- [ ] **Step 4: 테스트 통과 확인**

Run: iOS 테스트 명령
Expected: 두 테스트 PASS, 기존 GREEN

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "♻️ iOS WorkoutSessionViewModel이 scoreVM 소유 + start 시 reset"
```

---

### Task 4: Watch `WorkoutSessionViewModel`이 `scoreVM` 소유 + onMatchFinished 연결

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

Watch는 `scoreVM`을 소유하고, 경기 종료 콜백(`onMatchFinished`)을 `WorkoutSessionViewModel.finishMatch`에 연결한다(기존엔 `ScoreView.onAppear`에서 설정). `startMatch` 시 `resetAll`.

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가:
```swift
@Test @MainActor func restartMatchResetsScoreVM() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.scoreVM.myGameScore = 3
    vm.scoreVM.mySetScore = 1
    vm.scoreVM.completedSets = [SetScore(my: 6, your: 4)]

    vm.restartMatch()

    #expect(vm.scoreVM.myGameScore == 0)
    #expect(vm.scoreVM.mySetScore == 0)
    #expect(vm.scoreVM.completedSets.isEmpty)
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: Watch 테스트 명령
Expected: 컴파일 에러 — `vm.scoreVM` 없음

- [ ] **Step 3: 구현**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

프로퍼티 영역(`private var _currentSession: MatchSession?` 부근)에 추가:
```swift
    let scoreVM = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
```

(Watch `ScoreViewModel.init`은 `options` 인자가 필수이므로 임시 기본값으로 생성하고, 실제 경기 시작 때 `resetAll(options:)`로 교체한다.)

`init()`의 마지막(구독 설정들 뒤)에 추가 — 경기 종료 콜백 연결:
```swift
        scoreVM.onMatchFinished = { [weak self] result, sets in
            self?.finishMatch(result: result, completedSets: sets)
        }
```

`startMatch(options:sessionId:isRemote:)` 안에서 `phase = .playing(options)` **직전**에 추가:
```swift
        scoreVM.resetAll(options: options)
```

- [ ] **Step 4: 테스트 통과 확인**

Run: Watch 테스트 명령
Expected: PASS, 기존 GREEN

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "♻️ Watch WorkoutSessionViewModel이 scoreVM 소유 + onMatchFinished 연결"
```

---

### Task 5: iOS `ScoreView`를 주입식(@ObservedObject)으로 전환

**Files:**
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`

UI 변경이라 단위 테스트 없이 빌드로 검증한다.

- [ ] **Step 1: ScoreView 시그니처 변경**

`iOSApp/Features/Match/Score/ScoreView.swift`에서:

현재:
```swift
    let options: MatchOptions
    let onMatchFinished: (MatchResult, [(my: Int, your: Int)]) -> Void
    let onProgressChanged: (Bool) -> Void

    @StateObject private var viewModel: ScoreViewModel
    @State private var showEditSheet = false

    init(options: MatchOptions,
         onMatchFinished: @escaping (MatchResult, [(my: Int, your: Int)]) -> Void,
         onProgressChanged: @escaping (Bool) -> Void = { _ in }) {
        self.options = options
        self.onMatchFinished = onMatchFinished
        self.onProgressChanged = onProgressChanged
        _viewModel = StateObject(wrappedValue: ScoreViewModel(options: options))
    }
```

변경:
```swift
    let onMatchFinished: (MatchResult, [(my: Int, your: Int)]) -> Void
    let onProgressChanged: (Bool) -> Void

    @ObservedObject var viewModel: ScoreViewModel
    @State private var showEditSheet = false

    init(viewModel: ScoreViewModel,
         onMatchFinished: @escaping (MatchResult, [(my: Int, your: Int)]) -> Void,
         onProgressChanged: @escaping (Bool) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.onMatchFinished = onMatchFinished
        self.onProgressChanged = onProgressChanged
    }
```

body 안에서 `options.mode == .bestOfThree`를 `viewModel.options.mode == .bestOfThree`로 변경 (현재 43행).

`#Preview`의 `ScoreView(options:...)`를 다음으로 변경:
```swift
        ScoreView(
            viewModel: ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false)),
            onMatchFinished: { _, _ in }
        )
```

- [ ] **Step 2: WorkoutSessionView 주입 변경**

`iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`의 `scoreTabContent` 안 `.playing` 케이스(현재 115~122행)를 변경:
```swift
        case .playing:
            ScoreView(
                viewModel: viewModel.scoreVM,
                onMatchFinished: { result, sets in
                    viewModel.finishMatch(result: result, completedSets: sets)
                },
                onProgressChanged: { hasMatchProgress = $0 }
            )
```

- [ ] **Step 3: iOS 빌드 검증**

Run: iOS 빌드 명령
Expected: BUILD SUCCEEDED

- [ ] **Step 4: iOS 테스트 회귀 확인**

Run: iOS 테스트 명령
Expected: 전체 GREEN

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/Score/ScoreView.swift iOSApp/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "♻️ iOS ScoreView를 scoreVM 주입식으로 전환"
```

---

### Task 6: Watch `ScoreView`를 주입식(@ObservedObject)으로 전환

**Files:**
- Modify: `WatchApp/Features/Match/Score/ScoreView.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionView.swift`

- [ ] **Step 1: ScoreView 시그니처 변경**

`WatchApp/Features/Match/Score/ScoreView.swift`에서:

현재:
```swift
    let options: MatchOptions
    @ObservedObject var flowViewModel: WorkoutSessionViewModel
    @StateObject private var viewModel: ScoreViewModel
    @State private var showExitConfirm = false

    init(options: MatchOptions, flowViewModel: WorkoutSessionViewModel) {
        self.options = options
        self.flowViewModel = flowViewModel
        _viewModel = StateObject(wrappedValue: ScoreViewModel(options: options))
    }
```

변경:
```swift
    @ObservedObject var flowViewModel: WorkoutSessionViewModel
    @ObservedObject var viewModel: ScoreViewModel
    @State private var showExitConfirm = false

    init(viewModel: ScoreViewModel, flowViewModel: WorkoutSessionViewModel) {
        self.viewModel = viewModel
        self.flowViewModel = flowViewModel
    }
```

`onAppear`의 `onMatchFinished` 설정 블록(현재 83~87행)을 **삭제**한다 (Task 4에서 `WorkoutSessionViewModel.init`이 연결하므로 중복):
```swift
        .onAppear {
            viewModel.onMatchFinished = { result, sets in
                flowViewModel.finishMatch(result: result, completedSets: sets)
            }
        }
```
→ 이 `.onAppear { ... }` 전체 제거.

`#Preview`의 `ScoreView(options:...)`를 변경:
```swift
    ScoreView(
        viewModel: ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false)),
        flowViewModel: WorkoutSessionViewModel()
    )
```

(주의: body의 점수 영역은 이미 `viewModel.mySetScore` 등을 쓰므로 `options` 직접 참조가 없다. 컴파일 에러가 나면 해당 참조를 `viewModel.options`로 바꾼다.)

- [ ] **Step 2: WorkoutSessionView 주입 변경**

`WatchApp/Features/WorkoutSession/WorkoutSessionView.swift`의 `centerView` 안 `.playing` 케이스(현재 42~43행)를 변경:
```swift
        case .playing:
            ScoreView(viewModel: viewModel.scoreVM, flowViewModel: viewModel)
```

- [ ] **Step 3: Watch 빌드 검증**

Run: Watch 빌드 명령
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Watch 테스트 회귀 확인**

Run: Watch 테스트 명령
Expected: 전체 GREEN

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/Match/Score/ScoreView.swift WatchApp/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "♻️ Watch ScoreView를 scoreVM 주입식으로 전환"
```

---

### Task 7: 전체 검증 + code-review

- [ ] **Step 1: 양 타겟 빌드**

Run: iOS 빌드 명령 → BUILD SUCCEEDED, Watch 빌드 명령 → BUILD SUCCEEDED

- [ ] **Step 2: 양 타겟 테스트**

Run: iOS 테스트 명령, Watch 테스트 명령
Expected: 전체 GREEN

- [ ] **Step 3: lint/format**

Run: `make fix && make lint`
Expected: 위반 없음

- [ ] **Step 4: code-review (spec 게이트)**

Run: `/code-review`
리뷰 지적은 `superpowers:receiving-code-review`로 검증 후 반영한다. 반영했으면 재빌드·재테스트.

- [ ] **Step 5: (가능하면) 실기기 2대 수동 확인**

워치로 경기 시작 → 점수 입력 → 결과화면 → 리매치 → 점수가 0-0으로 초기화되는지 확인. 탭 전환(Controls↔Match↔Metrics) 후 점수 유지 확인.

---

## 이 단계가 검증하는 것 (증상 1)

- 리매치 시 `scoreVM.resetAll(options:)`가 명시적으로 점수를 0으로 만든다 → view 재생성에 의존하지 않음.
- `scoreVM`이 `WorkoutSessionViewModel` 소유라 탭 전환/재진입으로 view가 갱신돼도 동일 인스턴스를 유지한다.
- 동기화(connectivity) 동작은 이 단계에서 변경하지 않았으므로 기존 동기화 회귀가 없어야 한다(2단계에서 단방향 전환).
