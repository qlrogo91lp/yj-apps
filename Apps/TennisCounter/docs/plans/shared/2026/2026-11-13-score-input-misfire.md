# 점수 오입력 방지 (undo 연타 · 워치/iOS) 플랜

작성일: 2026-11-13
상태: **검토 대기**
Linear: YJ-39
브랜치: `fix/ralli-score-input-misfire`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** undo 를 연타해도 득점이 들어가지 않게 한다.

**Architecture:** 두 겹으로 막는다. (1) undo 버튼을 스택이 비어도 화면에 남겨 그 자리의 탭을 흡수한다. (2) `ScoreViewModel` 이 undo 요청 직후 0.4초 동안 득점 입력을 무시한다 — 버튼 가장자리를 빗나간 탭과 크라운 입력까지 같은 규칙으로 막는다.

**Tech Stack:** SwiftUI · Swift Testing

**Spec:** 없음. 이 문서의 "배경"과 "원인"이 근거다.

---

## 배경 — 실제로 겪은 일

2026-11 실사용 중, 경기 초반 0-0 근처에서 undo 를 여러 번 누른 뒤로 점수가 의도와 다르게 올라갔다.
어느 기기에서 조작했는지, 폰이 입력 기기였는지는 확인되지 않았다.

## 원인

코드 읽기로 확인한 것 (실기기 재현은 아직 하지 않았다).

- **undo 로직과 동기화는 정상이다.** 빈 스택의 `undo()` 는 `popLast` 가드로 아무 일도 하지 않고 메시지도 내지 않는다.
  입력 기기(driver)는 수신한 `ScoreState` 를 무시한다.
- **undo 버튼이 0-0 에서 화면에서 제거된다.** 워치 `ScoreView.swift:61-71` 과 iOS `ScoreView.swift:59-66` 모두
  `if viewModel.canUndo` 로 그린다. 그 밑은 화면 전체를 덮는 득점 버튼이라 다음 탭이 `addPoint` 가 된다.
  득점하면 버튼이 다시 나타나 "취소 → 득점 → 취소 → 득점"이 반복된다.
- 득점·undo 어디에도 연타 방어가 없다.

## 미결 결정 — 이 플랜에 넣지 않는다

**워치 Digital Crown 득점** (`ScoreView.swift:78-92`). 스윙 중 손등·밴드가 크라운을 돌려 1점이 들어갈 수 있다.
1.1.8 부터 있는 기능이고 이번 증상의 원인이라는 증거가 없다. Task 3 의 실기기 확인에서 크라운 오입력이
관찰되면 별도 이슈로 "설정에서 끄기"를 다룬다. Task 1 의 0.4초 가드는 크라운 입력에도 걸린다.

**폰이 입력 기기일 때 주머니 터치** (iOS 는 화면이 꺼지지 않고 전체가 탭 영역). 같은 이유로 넣지 않는다.

## Global Constraints

- ViewModel 은 SwiftUI 를 새로 import 하지 않는다 (워치 `ScoreViewModel` 의 기존 import 는 그대로 둔다).
- 컴포넌트는 값과 콜백만 받는다. ViewModel 을 넘기지 않는다.
- View 는 테스트하지 않는다. 버튼 동작은 Task 3 의 실기기 확인으로 본다.
- 테스트는 Swift Testing, ViewModel 테스트는 `@MainActor`.
- 가드 시간은 **0.4초** 하나다. 워치와 iOS 가 같은 값을 쓴다.

## Review Focus

1. undo 직후 0.4초 안에 올바른 쪽으로 다시 득점하려는 정상 조작 — 무시된다. 0.4초가 지나면 들어가야 한다 (Task 1 테스트).
2. 빈 스택에서의 undo 연타 — 점수가 0-0 에 머물러야 한다 (Task 1 테스트).
3. mirror 기기 — undo 버튼이 아니라 `MirrorBadge` 가 그대로 보여야 한다 (Task 2, 실기기).
4. undo 직후 상대가 보낸 `ScoreState` 적용(mirror) — 가드와 무관하게 적용돼야 한다. `applyRemoteState` 는 건드리지 않는다.
5. 경기 종료를 undo 로 되돌린 직후 — 가드가 풀린 뒤 득점이 정상 동작해야 한다 (기존 테스트가 `undoGuardInterval: 0` 으로 계속 통과).

---

### Task 1: `ScoreViewModel` 에 undo 직후 득점 가드를 넣는다 (워치 · iOS)

**Files:**
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift`
- Test: `Apps/TennisCounter/watchosTests/WorkoutSession/Match/ScoreViewModelTests.swift`
- Test: `Apps/TennisCounter/iosTests/WorkoutSession/Match/ScoreViewModelTests.swift`

**Interfaces:**
- Produces (워치): `init(options: MatchOptions, haptics: MatchHapticsPlaying = MatchHaptics(), undoGuardInterval: TimeInterval = 0.4, now: @escaping () -> Date = Date.init)`
- Produces (iOS): `init(options: MatchOptions = ..., undoGuardInterval: TimeInterval = 0.4, now: @escaping () -> Date = Date.init)`
- 동작: `undo()` 는 스택이 비어 있어도 호출 시각을 기록한다. `addPoint(_:)` 는 `now()` 가 그 시각에서 `undoGuardInterval` 미만이면 아무 일도 하지 않는다 (스냅샷·햅틱·`onStateChanged` 없음).

- [ ] **Step 1: 실패하는 테스트를 쓴다 (워치·iOS 테스트 파일에 같은 4개)**

시계는 테스트가 쥔다.

```swift
@Test @MainActor func addPointRightAfterUndoIsIgnored() {
    var clock = Date(timeIntervalSince1970: 1000)
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), now: { clock })
    vm.addPoint(.me) // 15-0
    clock += 1
    vm.undo() // 0-0
    clock += 0.1
    vm.addPoint(.me)
    #expect(vm.score.myDisplayScore == "0")
    #expect(vm.canUndo == false)
}

@Test @MainActor func addPointRightAfterEmptyUndoIsIgnored() {
    var clock = Date(timeIntervalSince1970: 1000)
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), now: { clock })
    vm.undo() // 스택이 비어 있다
    clock += 0.1
    vm.addPoint(.opponent)
    #expect(vm.score.yourDisplayScore == "0")
}

@Test @MainActor func addPointAfterUndoGuardIntervalIsAccepted() {
    var clock = Date(timeIntervalSince1970: 1000)
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), now: { clock })
    vm.undo()
    clock += 0.4
    vm.addPoint(.me)
    #expect(vm.score.myDisplayScore == "15")
}

@Test @MainActor func alternatingUndoAndPointTapsKeepScoreAtZero() {
    var clock = Date(timeIntervalSince1970: 1000)
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false), now: { clock })
    for _ in 0 ..< 6 { // 0.15초 간격 연타가 undo·득점 버튼에 번갈아 떨어진다
        vm.undo()
        clock += 0.15
        vm.addPoint(.me)
        clock += 0.15
    }
    #expect(vm.score.myDisplayScore == "0")
    #expect(vm.myGameScore == 0)
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:RalliWatchTests/ScoreViewModelTests test
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/ScoreViewModelTests test
```

Expected: 컴파일 실패 (`now:` 인자 없음).

- [ ] **Step 3: 두 `ScoreViewModel` 에 가드를 구현한다**

위 Interfaces 의 시그니처대로 `undoGuardInterval` 과 `now` 를 저장하고, `undo()` 첫 줄에서 시각을 기록하고,
`addPoint` 의 기존 종료 가드 다음에 시간 가드를 둔다. `resetAll` 은 기록한 시각을 지운다 — 새 경기 첫 득점이 막히면 안 된다.

- [ ] **Step 4: undo 직후 바로 득점하는 기존 테스트를 고친다**

두 테스트 파일과 `ScoreViewModelHapticsTests.swift`, 양쪽 `WorkoutSessionViewModelTests.swift` 에서
`undo()` 다음 줄에 `addPoint` 가 오는 테스트는 `undoGuardInterval: 0` 으로 만든다.
`WorkoutSessionViewModel` 이 `scoreVM` 을 직접 만들어 인자를 넘길 수 없는 테스트가 있으면, 그 테스트는
득점과 undo 순서를 바꾸지 말고 `WorkoutSessionViewModel.init` 에 `undoGuardInterval: TimeInterval = 0.4` 를
추가해 `scoreVM` 에 전달한다.

- [ ] **Step 5: 전체 테스트가 통과하는지 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" test
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test
```

Expected: 두 스킴 모두 `** TEST SUCCEEDED **`.

- [ ] **Step 6: 커밋**

```bash
git commit -m "🐛 fix: undo 직후 0.4초 동안 득점 입력을 무시한다"
```

---

### Task 2: undo 버튼을 스택이 비어도 화면에 남긴다 (워치 · iOS)

**Files:**
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/Match/Score/Components/UndoButton.swift`
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/Match/Score/ScoreView.swift:61-71`
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/Components/UndoButton.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/ScoreView.swift:59-66`

**Interfaces:**
- Produces (양쪽): `UndoButton(isEnabled: Bool, action: @escaping () -> Void)`

- [ ] **Step 1: `UndoButton` 에 `isEnabled` 를 추가한다 (워치 · iOS)**

- `.disabled()` 를 쓰지 않는다. 버튼은 항상 탭을 받고, `isEnabled` 가 false 면 `action` 을 부르지 않는다 —
  꺼진 버튼이 탭을 밑으로 흘리지 않게 하려는 것이다.
- `isEnabled` 가 false 면 `opacity(0.35)`.
- 탭 영역을 보이는 캡슐보다 사방 10pt 넓힌다 (`.padding(10)` + `.contentShape(Rectangle())`).
- 워치 버튼의 `.transition(.scale.combined(with: .opacity))` 를 지운다.

- [ ] **Step 2: 양쪽 `ScoreView` 가 driver 에게 버튼을 항상 그린다**

- `isDriver` 면 `UndoButton(isEnabled: viewModel.canUndo) { viewModel.undo() }`, 아니면 기존대로 `MirrorBadge()`.
- 워치 `ScoreView.swift:71` 의 `.animation(.easeInOut(duration: 0.2), value: viewModel.canUndo)` 를 지운다.
- 위치·패딩은 그대로 둔다.

- [ ] **Step 3: 빌드와 lint**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build
make lint && make format
```

Expected: 두 빌드 `** BUILD SUCCEEDED **`, lint·format 위반 0.

- [ ] **Step 4: 커밋**

```bash
git commit -m "🐛 fix: undo 버튼을 0-0 에서도 남겨 연타가 득점으로 떨어지지 않게 한다"
```

---

### Task 3: 실기기 확인 · PR

이번에는 생략하지 않는다. 결과를 PR 본문 체크박스에 적는다.

- [ ] 워치: 15-0 에서 undo 를 빠르게 6회 누른다 → 0-0 에 머문다.
- [ ] 워치: 0-0 에서 흐려진 undo 버튼과 그 주변 10pt 를 누른다 → 점수가 오르지 않는다.
- [ ] 워치: undo 후 0.5초 뒤 득점 → 정상 득점.
- [ ] 워치: 40mm 에서 흐려진 버튼이 점수 숫자를 가리지 않는다.
- [ ] iOS: 위 세 항목을 폰에서 반복.
- [ ] mirror 기기에 `MirrorBadge` 가 보이고 undo 버튼은 없다.
- [ ] 크라운을 일부러 건드리며 스윙 동작 → 오입력이 나오는지 기록한다 (나오면 별도 이슈).
- [ ] PR 생성. 본문에 `YJ-39` 와 위 체크 결과를 적는다.
