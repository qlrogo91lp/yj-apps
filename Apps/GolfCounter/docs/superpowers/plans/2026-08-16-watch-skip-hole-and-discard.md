# watch: 홀 건너뛰기 확인 + 라운드 폐기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 한 타도 치지 않은 홀을 실수로 넘기는 것을 확인 다이얼로그로 막고, 넘긴 홀은 파까지 지워 "진짜 건너뛴 홀"로 만든다. 그리고 요약 화면에서 라운드를 저장하지 않고 버릴 수 있게 한다.

**Architecture:** 세 변경이 하나의 개념을 공유한다 — **"치지 않은 홀은 기록이 아니다."** 입력 단계에서 파를 0으로 되돌려 그런 홀이 애초에 안 생기게 하고(Task 2), 표시 단계에서 기록 홀 수를 spec 정의에 맞춰 정직하게 세고(Task 1), 종료 단계에서 라운드 자체를 버릴 선택지를 준다(Task 3). 불변식은 전부 `RoundViewModel`/`HoleProgress`에 두고 뷰는 확인만 받는다.

**Tech Stack:** Swift 5(language mode) / SwiftUI / Swift Testing. 새 의존성 없음.

**참조 spec:** `docs/superpowers/specs/2026-08-13-ios-history-stats-design.md` §3 (유효 홀 / 집계 대상 홀 / 기록 홀 수), `docs/superpowers/specs/2026-08-14-watch-round-transmission-design.md` (종료 → 요약 → 전송 플로우)

**병행 plan:** `2026-08-16-common-relative-to-par-aggregation.md` — 오버파 계산에서 미타구 홀을 빼는 수정. **이 plan과 상호 보완이며 서로를 대체하지 않는다.** 이쪽은 입력 단계 방어(새 라운드만 해당), 그쪽은 계산 교정(이미 저장된 라운드와 iOS 편집 경로까지 해당). 순서는 무관하나 둘 다 필요하다.

## 배경

현재 카운터 화면의 `>` 화살표는 아무 확인 없이 곧장 다음 홀로 넘어간다 (`CountingView.swift:66` → `viewModel.goToNextHole()`). 파를 고른 직후 실수로 누르면 그 홀은 `par > 0, score = 0`으로 남고, 다음 두 가지가 어긋난다.

1. **오버파** — `0 − par`가 언더파로 새어 든다. (이건 병행 plan이 계산 쪽에서 막는다.)
2. **기록 홀 수** — 치지도 않은 홀이 "기록된 홀"로 잡혀 `N홀` 표시가 부풀려진다.

또한 워치와 iOS가 기록 홀 수를 **서로 다르게 세고 있다**:

| 정의 | 계산 | 중간에 낀 `par == 0` 홀 |
|------|------|------------------------|
| `RoundSnapshot.recordedHoleCount` (워치) | `trimmed().holePars.count` | **센다** |
| `GolfRound.recordedHoleCount` (iOS) | `holePars.filter { $0 > 0 }.count` | 세지 않는다 |

spec §3의 정의("기록 홀 수 = 유효 홀의 개수", 유효 홀 = `par > 0`)에 맞는 쪽은 iOS다. 지금은 중간에 낀 건너뛴 홀이 드물어 눈에 안 띄지만, **Task 2가 건너뛴 홀의 파를 0으로 만들면 이 상황이 일상적이 된다** — 같은 라운드를 워치는 "18홀 완료", iOS는 "17홀"로 표시하게 된다. 그래서 Task 1을 먼저 둔다.

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0** (ralli-kit 최소 요구)
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `🐛 fix:` / `♻️ refactor:` / `✅ test:` / `📝 docs:`), **main 직접 커밋 금지** — 브랜치 + PR, 머지는 `gh pr merge <n> --merge --delete-branch`
- 빌드 검증 시뮬레이터: watch/complication은 `Apple Watch Series 11 (46mm)`, iOS는 `iPhone 17 Pro` (`xcrun simctl list devices available`로 존재 확인)
- 파일 네이밍·폴더 규칙: `CLAUDE.md` 컨벤션 — **한 파일 = 한 타입**(private helper는 예외), `ScreenName/Components/`는 그 화면 전용, **ViewModel은 UI 프레임워크 import 금지**
- 테스트: Swift Testing(`@Test`/`#expect`), 테스트명은 한국어 `대상_행위_예상결과`, ViewModel 테스트는 `@MainActor`, **View는 테스트하지 않는다**
- 사용자 노출 문자열은 **한국어 하드코딩**으로 둔다 (로컬라이즈는 plan ⑦에서 세 타깃 일괄). 단 `Par`·`H`는 관용 표기로 영문 유지
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`
- 기존 테스트 더블은 `watchosTests/Support/`의 `RoundSnapshotPublisherSpy`(`published`·`clearCallCount`·`stored` 노출)와 `RoundTransmitterSpy`(`sent` 노출)를 **그대로 재사용한다** — 새로 만들지 않는다

## 파일 구조

| 파일 | 책임 |
|------|------|
| `Shared/Models/RoundSnapshot.swift` (수정) | `recordedHoleCount`를 유효 홀 기준으로 — iOS와 같은 규칙 |
| `WatchApp/Features/Round/RoundViewModel.swift` (수정) | `skipCurrentHole()`·`discardRound()` 추가 |
| `WatchApp/Features/Round/Counting/CountingView.swift` (수정) | `>` 화살표에 미타구 확인 다이얼로그 |
| `WatchApp/Features/Round/Summary/SummaryView.swift` (수정) | "저장 안 함" 버튼 + 확인 다이얼로그 |
| `watchosTests/Shared/RoundSnapshotTrimTests.swift` (수정) | 중간 건너뛴 홀 회귀 테스트 |
| `watchosTests/Round/RoundViewModelHoleFlowTests.swift` (수정) | `skipCurrentHole()` 테스트 |
| `watchosTests/Round/RoundViewModelTransmissionTests.swift` (수정) | `discardRound()` 테스트 |

새 파일은 없다. `HoleProgress`도 건드리지 않는다 — `setPar(_:)`와 `advanceToNextHole()`이 이미 있어 조합만 하면 된다.

---

### Task 1: `RoundSnapshot.recordedHoleCount`를 유효 홀 기준으로 통일

**Files:**
- Modify: `Shared/Models/RoundSnapshot.swift` (`recordedHoleCount` 계산 프로퍼티)
- Test: `watchosTests/Shared/RoundSnapshotTrimTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (기존 `RoundSnapshot.recordedHoleCount` 시그니처 그대로, 동작만 교정)

이 값은 워치 종료 확인 다이얼로그 문구("N홀이 기록됩니다")와 요약 헤더("N홀 완료")가 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Shared/RoundSnapshotTrimTests.swift`의 마지막 `}` 앞에 추가한다. 같은 파일의 기존 `snapshot(...)` 헬퍼를 그대로 쓴다:

```swift
    @Test func 기록홀수_중간에_건너뛴홀은_세지않는다() {
        // 3번 홀을 건너뛴 상태(파 0)가 배열 중간에 남아 있다.
        let value = snapshot(currentHoleIndex: 3,
                             holeScores: [4, 5, 0, 3],
                             holePars: [4, 5, 0, 3],
                             puttCounts: [2, 2, 0, 1])

        // 옛 공식(trimmed().holePars.count)이라면 말단만 자르므로 4가 나온다.
        #expect(value.recordedHoleCount == 3)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 새 테스트만 FAIL — `Expectation failed: (value.recordedHoleCount → 4) == 3`

다른 테스트가 함께 실패하면 **멈추고 보고할 것.** 기존 두 테스트(`기록홀수는_트림후_홀_개수다`, `아무것도_치지_않았으면_기록홀수가_0이다`)는 말단 0만 다루므로 새 정의에서도 같은 값이 나와야 한다.

- [ ] **Step 3: `recordedHoleCount` 교체**

`Shared/Models/RoundSnapshot.swift`에서 기존 프로퍼티와 doc comment를 통째로 교체한다.

교체 대상(기존):

```swift
    /// 트림 후 실제로 기록된 홀 수. 종료 확인 문구와 요약 헤더가 쓴다.
    var recordedHoleCount: Int {
        trimmed().holePars.count
    }
```

교체 결과(신규):

```swift
    /// 파가 기록된 홀 수 = 유효 홀의 개수 (spec §3). 종료 확인 문구와 요약 헤더가 쓴다.
    ///
    /// 건너뛴 홀(`par == 0`)은 배열 **중간**에 남아 있어도 세지 않는다 —
    /// `GolfRound.recordedHoleCount`와 같은 규칙이라 워치 요약과 iOS 기록 뱃지가 같은 수를 보인다.
    /// 말단 0은 `filter`가 알아서 걸러내므로 `trimmed()`를 거칠 필요가 없다.
    var recordedHoleCount: Int {
        holePars.filter { $0 > 0 }.count
    }
```

- [ ] **Step 4: 기존 테스트명 정정**

같은 파일의 기존 테스트 이름이 새 정의와 맞지 않는다. 이름만 바꾼다(본문·기대값은 그대로):

```swift
    @Test func 기록홀수는_파가있는_홀_개수다() {
```

교체 대상은 `@Test func 기록홀수는_트림후_홀_개수다() {` 한 줄이다.

- [ ] **Step 5: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 워치 타깃 전부 PASS

- [ ] **Step 6: 컴플리케이션 타깃 빌드 확인**

`ComplicationState`가 `RoundSnapshot`을 쓰므로 별도 타깃 빌드가 필요하다:

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 커밋**

```bash
make lint && make format
git add Shared/Models/RoundSnapshot.swift watchosTests/Shared/RoundSnapshotTrimTests.swift
git commit -m "🐛 fix: 기록 홀 수에서 중간에 건너뛴 홀 제외"
```

---

### Task 2: 홀 건너뛰기 — 확인 다이얼로그 + 파 리셋

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift` (`skipCurrentHole()` 추가)
- Modify: `WatchApp/Features/Round/Counting/CountingView.swift` (`>` 화살표 동작)
- Test: `watchosTests/Round/RoundViewModelHoleFlowTests.swift`

**Interfaces:**
- Consumes: `RoundSnapshot.recordedHoleCount`(Task 1), 기존 `HoleProgress.setPar(_:)`·`advanceToNextHole()`·`canGoToNextHole`
- Produces: `RoundViewModel.skipCurrentHole()` — 현재 홀의 파를 0으로 되돌리고 다음 홀로 이동

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Round/RoundViewModelHoleFlowTests.swift`의 마지막 `}` 앞에 추가한다. 같은 파일의 기존 `makeViewModel()` 헬퍼를 쓴다:

```swift
    // MARK: - skipCurrentHole (미타구 홀 건너뛰기)

    @Test func 건너뛰기_파를0으로_되돌리고_다음홀로_간다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)

        viewModel.skipCurrentHole()

        #expect(viewModel.currentHoleNumber == 2)
        // 파가 0으로 돌아갔으므로 건너뛴 홀은 기록 홀 수에 잡히지 않는다.
        #expect(viewModel.recordedHoleCount == 0)
        // 새 홀은 파가 없으므로 다시 파 선택 화면이다.
        #expect(viewModel.phase == .parSelection)
    }

    @Test func 건너뛰기_타수가있으면_아무일도_없다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.skipCurrentHole()

        // 이미 친 홀은 건너뛸 수 없다 — 파가 지워지면 그 타수가 미아가 된다.
        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
        #expect(viewModel.currentScore == 1)
    }

    @Test func 건너뛰기_마지막홀에서는_아무일도_없다() {
        // 이 파일의 makeViewModel()은 holeCount를 받지 않으므로 직접 만든다.
        let viewModel = RoundViewModel(holeCount: 1,
                                       startedAt: Date(timeIntervalSince1970: 1000),
                                       publisher: RoundSnapshotPublisherSpy())
        viewModel.selectPar(4)

        viewModel.skipCurrentHole()

        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
    }

    @Test func 건너뛴홀은_오버파에도_잡히지_않는다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.skipCurrentHole()
        viewModel.selectPar(3)
        for _ in 0 ..< 4 {
            viewModel.incrementStroke()
        }

        // 1번 홀은 건너뛰었으므로 2번 홀의 +1만 남는다.
        #expect(viewModel.relativeToPar == 1)
        #expect(viewModel.recordedHoleCount == 1)
    }
```

이 파일의 `makeViewModel()`은 인자를 받지 않고 18홀 기본값을 쓴다 (확인 완료). 홀 수를 바꿔야 하는 세 번째 테스트만 `RoundViewModel`을 직접 생성한다.

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 컴파일 실패 — `value of type 'RoundViewModel' has no member 'skipCurrentHole'`

- [ ] **Step 3: `skipCurrentHole()` 추가**

`WatchApp/Features/Round/RoundViewModel.swift`의 `// MARK: - 홀 이동` 섹션에서 `goToNextHole()` **바로 아래**에 추가한다:

```swift
    /// 한 타도 치지 않은 홀을 건너뛴다 — 파를 0으로 되돌려 "진짜 건너뛴 홀"로 만든 뒤 다음 홀로 간다.
    ///
    /// 파를 남긴 채 넘어가면 그 홀이 기록 홀 수에 잡히고(spec §3 유효 홀), 오버파에서는
    /// 집계 대상 홀이 아니라 빠져서 "18홀인데 17홀치 스코어"라는 어긋남이 생긴다.
    /// 파를 지우면 두 지표가 같은 홀 집합을 보게 된다.
    ///
    /// 타수가 이미 있는 홀에는 아무 일도 하지 않는다 — 파를 지우면 그 타수가 미아가 되고,
    /// `par == 0 && score > 0`은 어느 화면도 해석할 수 없는 상태다.
    func skipCurrentHole() {
        guard progress.canGoToNextHole, progress.currentScore == 0 else { return }
        progress.setPar(0)
        progress.advanceToNextHole()
        resetHoleLocalState()
        publishSnapshot()
    }
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 새 테스트 4개 PASS, 기존 워치 테스트 전부 PASS

- [ ] **Step 5: `CountingView`의 `>` 화살표에 확인 다이얼로그 연결**

`WatchApp/Features/Round/Counting/CountingView.swift`를 세 군데 고친다.

**(a)** `private let horizontalPadding: CGFloat = 4` 바로 아래에 상태를 추가한다:

```swift
    /// 한 타도 치지 않은 홀에서 `>`를 눌렀을 때의 확인. 실수로 홀을 날리는 것을 막는다.
    @State private var isConfirmingSkip = false
```

**(b)** `body`의 modifier 체인 맨 끝(`.animation(fillAnimation, value: viewModel.canUndo)` 바로 아래)에 다이얼로그를 단다:

```swift
        .confirmationDialog("이 홀은 기록되지 않습니다",
                            isPresented: $isConfirmingSkip,
                            titleVisibility: .visible)
        {
            Button("건너뛰기", role: .destructive, action: viewModel.skipCurrentHole)
            Button("취소", role: .cancel) {}
        }
```

**(c)** `ringArea`의 `chevron.right` 버튼 action을 교체한다.

교체 대상(기존):

```swift
                CircleIconButton(systemName: "chevron.right",
                                 size: sizing.arrowSize,
                                 action: viewModel.goToNextHole)
```

교체 결과(신규):

```swift
                CircleIconButton(systemName: "chevron.right",
                                 size: sizing.arrowSize,
                                 action: goToNextHoleOrConfirm)
```

그리고 `fillAnimation` 계산 프로퍼티 **아래**에 헬퍼를 추가한다:

```swift
    /// 타수가 있으면 그냥 넘어가고, 한 타도 없으면 확인부터 받는다.
    private func goToNextHoleOrConfirm() {
        if viewModel.currentScore == 0 {
            isConfirmingSkip = true
        } else {
            viewModel.goToNextHole()
        }
    }
```

- [ ] **Step 6: 빌드 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 커밋**

```bash
make lint && make format
git add WatchApp/Features/Round/RoundViewModel.swift \
        WatchApp/Features/Round/Counting/CountingView.swift \
        watchosTests/Round/RoundViewModelHoleFlowTests.swift
git commit -m "✨ feat: 미타구 홀 건너뛰기 확인과 파 리셋"
```

---

### Task 3: 요약 화면 "저장 안 함" 버튼

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift` (`discardRound()` 추가)
- Modify: `WatchApp/Features/Round/Summary/SummaryView.swift` (버튼 + 확인 다이얼로그)
- Test: `watchosTests/Round/RoundViewModelTransmissionTests.swift`

**Interfaces:**
- Consumes: 기존 `publisher.clear()`, `didComplete`
- Produces: `RoundViewModel.discardRound()` — 전송 없이 스냅샷을 지우고 라운드를 끝낸다

18홀로 시작해 중간에 끝낸 라운드를 매번 저장할지 버릴지 사용자가 고르게 한다. 저장 자체를 막지 않으므로 16홀 치고 중단한 라운드는 그대로 남길 수 있다.

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Round/RoundViewModelTransmissionTests.swift`의 마지막 `}` 앞에 추가한다. 같은 파일의 기존 `makeViewModel(publisher:transmitter:)`·`playHole(_:par:strokes:)` 헬퍼를 쓴다:

```swift
    // MARK: - discardRound (저장 안 함)

    @Test func 저장안함_전송하지않고_스냅샷을_지운다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()

        viewModel.discardRound()

        #expect(transmitter.sent.isEmpty)
        #expect(publisher.clearCallCount == 1)
        #expect(viewModel.didComplete == true)
    }

    @Test func 저장안함_메트릭을_기다리지_않는다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()

        // 워크아웃 집계가 아직 안 온 상태에서도 즉시 끝난다 — 버릴 라운드에 메트릭은 필요 없다.
        viewModel.discardRound()

        #expect(viewModel.didComplete == true)
        #expect(viewModel.isTransmitting == false)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 컴파일 실패 — `value of type 'RoundViewModel' has no member 'discardRound'`

- [ ] **Step 3: `discardRound()` 추가**

`WatchApp/Features/Round/RoundViewModel.swift`의 `saveAndTransmit()` **바로 아래**에 추가한다:

```swift
    /// 요약의 "저장 안 함". 전송하지 않고 스냅샷만 지운 뒤 홈으로 돌아간다.
    ///
    /// `saveAndTransmit()`의 0홀 경로와 같은 처리지만, 이쪽은 기록이 있는데도 사용자가
    /// 명시적으로 버리기를 고른 경우다 — 뷰가 확인 다이얼로그를 한 번 거치게 한다.
    /// 스냅샷을 지우므로 다음 실행 때 복구되지 않는다.
    func discardRound() {
        publisher.clear()
        isTransmitting = false
        didComplete = true
    }
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 새 테스트 2개 PASS, 기존 워치 테스트 전부 PASS

- [ ] **Step 5: `SummaryView`에 버튼 추가**

`WatchApp/Features/Round/Summary/SummaryView.swift`를 세 군데 고친다.

**(a)** `@ObservedObject var viewModel: RoundViewModel` 바로 아래에 상태를 추가한다:

```swift
    /// 폐기는 되돌릴 수 없다(스냅샷까지 지운다) — 확인을 한 번 받는다.
    @State private var isConfirmingDiscard = false
```

**(b)** 기존 "저장 & 전송" `Button` 블록 **아래**, `VStack`의 닫는 `}` 앞에 폐기 버튼을 추가한다:

```swift
            if viewModel.recordedHoleCount > 0 {
                Button("저장 안 함") { isConfirmingDiscard = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .disabled(viewModel.isTransmitting)
            }
```

기록 홀이 0이면 주 버튼이 이미 "저장 없이 종료"라 같은 일을 하므로 띄우지 않는다. 전송 중에는 비활성화한다 — 전송이 이미 시작된 뒤에 버리면 iOS에 절반만 도착한 라운드가 남는다.

**(c)** `VStack`의 modifier 체인(`.padding(.horizontal, 8)` 바로 아래)에 다이얼로그를 단다:

```swift
        .confirmationDialog("이 라운드를 저장하지 않고 버릴까요?",
                            isPresented: $isConfirmingDiscard,
                            titleVisibility: .visible)
        {
            Button("버리기", role: .destructive, action: viewModel.discardRound)
            Button("취소", role: .cancel) {}
        }
```

- [ ] **Step 6: 빌드 확인 + 작은 화면 레이아웃 점검**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

버튼이 하나 늘어 세로 공간이 빠듯해질 수 있다. **40mm 시뮬레이터에서 요약 화면을 띄워** 오버파 숫자·타수/퍼트 줄·두 버튼이 잘리지 않는지 확인한다. 잘리면 그대로 두지 말고 보고할 것 — 간격 조정이 필요하다.

- [ ] **Step 7: 커밋**

```bash
make lint && make format
git add WatchApp/Features/Round/RoundViewModel.swift \
        WatchApp/Features/Round/Summary/SummaryView.swift \
        watchosTests/Round/RoundViewModelTransmissionTests.swift
git commit -m "✨ feat: 요약에서 라운드를 저장하지 않고 버리기"
```

---

## 완료 조건

- 한 타도 치지 않은 홀에서 `>`를 누르면 확인 다이얼로그가 뜨고, 확인하면 그 홀의 파가 지워진 채 다음 홀로 넘어간다
- 타수가 있는 홀에서는 확인 없이 기존대로 넘어간다
- 건너뛴 홀은 워치·iOS 양쪽에서 기록 홀 수에 잡히지 않는다 (두 `recordedHoleCount`가 같은 규칙)
- 요약 화면에서 기록이 있는 라운드를 확인을 거쳐 저장 없이 버릴 수 있고, 버리면 다음 실행 때 복구되지 않는다
- 워치 타깃 테스트 전부 통과, 세 타깃 전부 빌드 성공
- `make lint`·`make format` 위반 0

## 이 plan이 다루지 않는 것

- **오버파 계산 교정** — 병행 plan `2026-08-16-common-relative-to-par-aggregation.md`가 맡는다. 이 plan은 새로 생기는 홀만 막을 뿐, 이미 저장된 라운드와 iOS 편집 시트 경로는 계산 쪽에서 잡아야 한다.
- **`isFullRound` 판정** — 18홀 중 일부를 건너뛴 라운드는 `recordedHoleCount < 18`이 되어 자동으로 18홀 라운드에서 빠진다. 별도 작업이 필요 없다.
- **부분 라운드 자동 폐기** — 저장 여부는 매번 사용자가 고른다. 자동으로 버리지 않는다.
