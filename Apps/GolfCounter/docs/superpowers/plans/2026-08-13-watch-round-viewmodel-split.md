# RoundViewModel 분리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `RoundViewModel`(237줄)의 내부 상태를 `HoleProgress`·`StrokeUndo` 두 순수 struct로 추출해, 지금까지 private이라 간접 검증만 되던 로직을 직접 테스트할 수 있게 한다.

**Architecture:** 파사드 유지 — `RoundViewModel`이 유일한 `ObservableObject`로 남고, 추출된 두 struct는 내부 구현 세부사항이다. View는 지금처럼 `@ObservedObject var viewModel: RoundViewModel` 하나만 받으며 **View 코드는 한 줄도 바뀌지 않는다.** 기존 테스트 37건도 공개 API로만 검증하므로 무변경 통과해야 한다(확인 완료: `viewModel.holeScores` 류 직접 참조가 소스·테스트 어디에도 없다).

**Tech Stack:** Swift / SwiftUI / Swift Testing. pbxproj는 `PBXFileSystemSynchronizedRootGroup`이라 **파일 추가만으로 빌드에 반영된다 — pbxproj를 수정하지 않는다.**

**참조 spec:** `docs/superpowers/specs/2026-08-13-round-viewmodel-split-design.md`

**선행:** 폴더 구조 개편(③-c, PR #10 머지 완료). 이 plan의 경로는 개편 후 구조를 전제한다.

## Global Constraints

- **동작 변경 0.** 로직은 현재 코드를 그대로 옮긴다. 새로 쓰지 않는다.
- **기존 테스트 37건 무변경 통과.** 한 건이라도 고쳐야 한다면 동작이 바뀐 것이므로 멈추고 재검토한다. (`RoundViewModelTests` 4건 / `RoundViewModelHoleFlowTests` 13건 / `RoundViewModelUndoTests` 11건 / `RoundViewModelSnapshotTests` 9건)
- **View 코드 무변경.** `WatchApp/Features/Round/` 아래 `.swift` View 파일을 하나도 건드리지 않는다.
- 추출 타입은 `struct` + `mutating` 메서드. UI 프레임워크를 import하지 않는다 (`Foundation`만).
- 브랜치 `feature/round-viewmodel-split`에서 작업. `main` 직접 push 금지 — PR + `gh pr merge <n> --merge --delete-branch`.
- 커밋 메시지는 gitmoji prefix (`♻️ refactor:` / `✅ test:`). 본문 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- 테스트: Swift Testing(`@Test`/`#expect`), 테스트명은 한국어 `대상_행위_예상결과`. **View는 테스트하지 않는다.**
- watch 테스트 명령 (이하 "**watch test**"로 표기):
  ```bash
  xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
  ```
  기기명이 없으면 `xcrun simctl list devices available`로 확인해 대체한다.
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`.

---

### Task 1: `StrokeUndo` 추출 (TDD)

가장 작고 의존성이 없는 조각부터 시작한다. `RoundViewModel`의 `strokeHistory`를 대체한다.

**Files:**
- Create: `WatchApp/Features/Round/StrokeUndo.swift`
- Create: `watchosTests/Round/StrokeUndoTests.swift`
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`

**Interfaces:**
- Consumes: `StrokeInputMode`(기존 `Shared/Models/StrokeInputMode.swift`, `.swing`/`.putt`)
- Produces: `StrokeUndo` — `history: [StrokeInputMode]`(get), `canUndo: Bool`, `mutating record(_:)`, `mutating pop() -> StrokeInputMode?`, `mutating clear()`

- [ ] **Step 1: 브랜치 생성**

```bash
git checkout -b feature/round-viewmodel-split
```

- [ ] **Step 2: 실패하는 테스트 작성**

`watchosTests/Round/StrokeUndoTests.swift` 신규 생성:

```swift
@testable import GolfCounter_Watch_App
import Testing

struct StrokeUndoTests {
    @Test func 초기에는_되돌릴게_없다() {
        let undo = StrokeUndo()

        #expect(undo.canUndo == false)
        #expect(undo.history.isEmpty)
    }

    @Test func 기록하면_되돌릴게_생긴다() {
        var undo = StrokeUndo()

        undo.record(.swing)

        #expect(undo.canUndo)
        #expect(undo.history == [.swing])
    }

    @Test func pop은_마지막에_기록한_모드를_역순으로_돌려준다() {
        var undo = StrokeUndo()
        undo.record(.swing)
        undo.record(.putt)
        undo.record(.swing)

        #expect(undo.pop() == .swing)
        #expect(undo.pop() == .putt)
        #expect(undo.pop() == .swing)
        #expect(undo.canUndo == false)
    }

    @Test func 비어있으면_pop은_nil이다() {
        var undo = StrokeUndo()

        #expect(undo.pop() == nil)
    }

    @Test func clear하면_되돌릴게_없다() {
        var undo = StrokeUndo()
        undo.record(.swing)
        undo.record(.putt)

        undo.clear()

        #expect(undo.canUndo == false)
        #expect(undo.history.isEmpty)
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `cannot find 'StrokeUndo' in scope`

- [ ] **Step 4: `StrokeUndo` 구현**

`WatchApp/Features/Round/StrokeUndo.swift` 신규 생성:

```swift
import Foundation

/// 현재 홀에서 되돌릴 수 있는 입력 기록 (spec §7).
///
/// 되돌리기 스코프가 현재 홀이라는 규칙이 이 타입의 생명주기로 표현된다 —
/// 홀을 옮기면 `RoundViewModel`이 `clear()`를 부른다.
struct StrokeUndo: Equatable {
    /// 현재 홀에서 친 타의 종류 순서. 되돌리기의 유일한 상태다.
    ///
    /// `incrementStroke()`가 하는 일이 모드에 따라 (타수 +1) 또는 (타수 +1, 퍼트 +1)
    /// 두 가지뿐이므로, 어느 쪽이었는지만 알면 정확히 되돌릴 수 있다. 배열 전체를
    /// 복사할 필요가 없다.
    private(set) var history: [StrokeInputMode] = []

    var canUndo: Bool {
        !history.isEmpty
    }

    mutating func record(_ mode: StrokeInputMode) {
        history.append(mode)
    }

    mutating func pop() -> StrokeInputMode? {
        history.popLast()
    }

    mutating func clear() {
        history.removeAll()
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: watch test
Expected: 신규 5건 PASS + 기존 37건 PASS (`StrokeUndo`는 아직 아무도 안 쓰므로 기존 동작 영향 없음)

- [ ] **Step 6: `RoundViewModel`이 `StrokeUndo`를 쓰도록 교체**

`strokeHistory` 선언(주석 블록 포함)을 삭제하고 그 자리에 넣는다:

```swift
    /// 되돌리기 기록. `canUndo`가 이 값에서 파생되므로 `@Published`여야
    /// 뷰가 취소 버튼의 등장·퇴장을 관찰할 수 있다.
    /// 프로퍼티명이 `undo`가 아닌 이유: 같은 이름의 메서드 `undo()`와 충돌한다.
    @Published private var undoStack = StrokeUndo()
```

`canUndo`를 교체:

```swift
    var canUndo: Bool {
        undoStack.canUndo
    }
```

`incrementStroke()`의 첫 줄을 교체:

```swift
    func incrementStroke() {
        undoStack.record(inputMode)
        switch inputMode {
```

`undo()`의 첫 줄을 교체:

```swift
    func undo() {
        guard let mode = undoStack.pop() else { return }
```

`resetHoleLocalState()`의 마지막 줄을 교체:

```swift
        undoStack.clear()
```

- [ ] **Step 7: 기존 테스트가 그대로 통과하는지 확인**

Run: watch test
Expected: 전체 42건 PASS (기존 37 + 신규 5). **기존 테스트 파일을 고치지 않았어야 한다** — 고쳐야 통과한다면 동작이 바뀐 것이므로 되돌리고 재검토한다.

- [ ] **Step 8: 커밋**

```bash
git add WatchApp/Features/Round/StrokeUndo.swift watchosTests/Round/StrokeUndoTests.swift \
  WatchApp/Features/Round/RoundViewModel.swift
git commit -m "♻️ refactor: 되돌리기 기록을 StrokeUndo로 추출

strokeHistory와 그 조작을 순수 struct로 옮긴다. 되돌리기 스코프가 현재 홀이라는
규칙(spec §7)이 타입 생명주기로 드러나고, 그동안 private이라 간접 검증만 되던
pop 역순 동작을 직접 테스트한다. 공개 API는 그대로라 View·기존 테스트 무변경.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: `HoleProgress` 타입 신설 (TDD, 아직 연결하지 않음)

홀 배열 3개와 인덱스를 담을 타입을 **먼저 완성**한다. `RoundViewModel` 연결은 Task 3에서 한다 — 타입 자체의 정확성을 독립적으로 확정해 두면 연결 단계에서 실패 원인이 명확해진다.

**Files:**
- Create: `WatchApp/Features/Round/HoleProgress.swift`
- Create: `watchosTests/Round/HoleProgressTests.swift`

**Interfaces:**
- Consumes: `StrokeInputMode`
- Produces: `HoleProgress` — `init()`, `init(holeScores:holePars:puttCounts:currentHoleIndex:)`, 읽기 프로퍼티 `holeScores`/`holePars`/`puttCounts`/`currentHoleIndex`/`currentHoleNumber`/`currentScore`/`currentPutts`/`currentPar`/`canGoToPreviousHole`/`isPristinePhantomHole`, `mutating` 메서드 `apply(_:)`/`revert(_:)`/`setPar(_:)`/`advanceToNextHole()`/`retreatToPreviousHole()`/`removePhantomHoleAndRetreat()`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Round/HoleProgressTests.swift` 신규 생성:

```swift
@testable import GolfCounter_Watch_App
import Testing

struct HoleProgressTests {
    @Test func 초기상태는_1홀이고_값이_모두_0이다() {
        let progress = HoleProgress()

        #expect(progress.currentHoleIndex == 0)
        #expect(progress.currentHoleNumber == 1)
        #expect(progress.currentScore == 0)
        #expect(progress.currentPutts == 0)
        #expect(progress.currentPar == 0)
        #expect(progress.holeScores == [0])
        #expect(progress.holePars == [0])
        #expect(progress.puttCounts == [0])
    }

    @Test func 스윙_적용은_타수만_올린다() {
        var progress = HoleProgress()

        progress.apply(.swing)
        progress.apply(.swing)

        #expect(progress.currentScore == 2)
        #expect(progress.currentPutts == 0)
    }

    @Test func 퍼팅_적용은_타수와_퍼팅을_함께_올린다() {
        var progress = HoleProgress()

        progress.apply(.putt)

        #expect(progress.currentScore == 1)
        #expect(progress.currentPutts == 1)
    }

    @Test func 스윙_되돌리기는_타수만_내린다() {
        var progress = HoleProgress()
        progress.apply(.swing)
        progress.apply(.putt)

        progress.revert(.putt)
        progress.revert(.swing)

        #expect(progress.currentScore == 0)
        #expect(progress.currentPutts == 0)
    }

    @Test func 퍼팅_되돌리기는_타수와_퍼팅을_함께_내린다() {
        var progress = HoleProgress()
        progress.apply(.putt)
        progress.apply(.putt)

        progress.revert(.putt)

        #expect(progress.currentScore == 1)
        #expect(progress.currentPutts == 1)
    }

    @Test func 파를_설정하면_현재홀의_파가_바뀐다() {
        var progress = HoleProgress()

        progress.setPar(4)

        #expect(progress.currentPar == 4)
        #expect(progress.holePars == [4])
    }

    @Test func 다음홀로_가면_세_배열이_함께_늘어난다() {
        var progress = HoleProgress()
        progress.setPar(4)
        progress.apply(.swing)

        progress.advanceToNextHole()

        #expect(progress.currentHoleIndex == 1)
        #expect(progress.holeScores == [1, 0])
        #expect(progress.holePars == [4, 0])
        #expect(progress.puttCounts == [0, 0])
    }

    @Test func 이전홀로_가면_인덱스만_내려가고_배열은_그대로다() {
        var progress = HoleProgress()
        progress.setPar(4)
        progress.advanceToNextHole()

        progress.retreatToPreviousHole()

        #expect(progress.currentHoleIndex == 0)
        #expect(progress.currentPar == 4)
        #expect(progress.holeScores.count == 2)
    }

    @Test func 첫홀에서는_이전홀로_갈_수_없다() {
        let progress = HoleProgress()

        #expect(progress.canGoToPreviousHole == false)
    }

    @Test func 홀을_옮기면_이전홀로_갈_수_있다() {
        var progress = HoleProgress()

        progress.advanceToNextHole()

        #expect(progress.canGoToPreviousHole)
    }

    @Test func 길이가_어긋난_배열로_시작해도_현재홀까지_용량이_채워진다() {
        let progress = HoleProgress(holeScores: [4],
                                    holePars: [4],
                                    puttCounts: [2],
                                    currentHoleIndex: 3)

        #expect(progress.holeScores == [4, 0, 0, 0])
        #expect(progress.holePars == [4, 0, 0, 0])
        #expect(progress.puttCounts == [2, 0, 0, 0])
        #expect(progress.currentScore == 0)
    }

    @Test func 음수_인덱스로_시작하면_0으로_보정된다() {
        let progress = HoleProgress(holeScores: [3],
                                    holePars: [4],
                                    puttCounts: [1],
                                    currentHoleIndex: -5)

        #expect(progress.currentHoleIndex == 0)
        #expect(progress.currentScore == 3)
    }

    @Test func 새로_만든_홀은_phantom_hole이다() {
        var progress = HoleProgress()
        progress.setPar(4)
        progress.apply(.swing)

        progress.advanceToNextHole()

        #expect(progress.isPristinePhantomHole)
    }

    @Test func 타수를_입력하면_phantom_hole이_아니다() {
        var progress = HoleProgress()
        progress.advanceToNextHole()

        progress.apply(.swing)

        #expect(progress.isPristinePhantomHole == false)
    }

    @Test func 파만_설정해도_phantom_hole이_아니다() {
        var progress = HoleProgress()
        progress.advanceToNextHole()

        progress.setPar(3)

        #expect(progress.isPristinePhantomHole == false)
    }

    @Test func 값이_비어도_말단이_아니면_phantom_hole이_아니다() {
        var progress = HoleProgress()
        progress.advanceToNextHole()
        progress.advanceToNextHole()

        // index 1은 score·par·putts가 전부 0이지만 말단(index 2)이 아니라 pop 대상이 아니다
        progress.retreatToPreviousHole()

        #expect(progress.currentHoleIndex == 1)
        #expect(progress.currentScore == 0)
        #expect(progress.currentPar == 0)
        #expect(progress.isPristinePhantomHole == false)
    }

    @Test func phantom_hole을_제거하면_이전홀_데이터가_그대로_남는다() {
        var progress = HoleProgress()
        progress.setPar(4)
        progress.apply(.putt)
        progress.advanceToNextHole()

        progress.removePhantomHoleAndRetreat()

        #expect(progress.currentHoleIndex == 0)
        #expect(progress.holeScores == [1])
        #expect(progress.holePars == [4])
        #expect(progress.puttCounts == [1])
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `cannot find 'HoleProgress' in scope`

- [ ] **Step 3: `HoleProgress` 구현**

`WatchApp/Features/Round/HoleProgress.swift` 신규 생성:

```swift
import Foundation

/// 라운드에 무엇이 기록됐는지 — 홀별 타수·파·퍼트와 현재 홀 위치 (spec §3).
///
/// 홀 데이터는 관계가 아니라 **병렬 배열**이다(인덱스 = 홀 번호 - 1). 세 배열의
/// 길이가 항상 같아야 한다는 불변식을 이 타입이 책임진다 — 홀을 늘리는 경로가
/// `advanceToNextHole()`과 복구 `init` 둘뿐이고, 양쪽 다 용량을 함께 맞춘다.
struct HoleProgress: Equatable {
    private(set) var holeScores: [Int]
    private(set) var holePars: [Int]
    private(set) var puttCounts: [Int]
    private(set) var currentHoleIndex: Int

    init() {
        holeScores = [0]
        holePars = [0]
        puttCounts = [0]
        currentHoleIndex = 0
    }

    /// 스냅샷 복구용 (spec §12). 길이가 어긋난 값이 들어와도 현재 홀까지 용량을 맞춘다.
    init(holeScores: [Int], holePars: [Int], puttCounts: [Int], currentHoleIndex: Int) {
        self.holeScores = holeScores
        self.holePars = holePars
        self.puttCounts = puttCounts
        self.currentHoleIndex = max(currentHoleIndex, 0)
        ensureCapacityForCurrentHole()
    }

    // MARK: - 현재 홀

    var currentHoleNumber: Int {
        currentHoleIndex + 1
    }

    var currentScore: Int {
        holeScores[currentHoleIndex]
    }

    var currentPutts: Int {
        puttCounts[currentHoleIndex]
    }

    /// 0은 "아직 파가 설정되지 않음"을 뜻한다.
    var currentPar: Int {
        holePars[currentHoleIndex]
    }

    var canGoToPreviousHole: Bool {
        currentHoleIndex > 0
    }

    /// 현재 홀이 "방금 만들어졌고 아직 아무것도 입력되지 않은" phantom hole 상태인지 판단한다.
    /// 세 배열의 마지막 원소가 현재 홀과 정확히 일치할 때만 안전하게 pop할 수 있다.
    ///
    /// 파 편집 중(`isEditingPar`) 여부는 여기 조건에 없다 — 그것은 `RoundViewModel`의
    /// 상태이므로 호출부가 판단한다. 이 타입은 "기록 상태" 사실만 본다.
    var isPristinePhantomHole: Bool {
        currentScore == 0
            && currentPar == 0
            && currentPutts == 0
            && currentHoleIndex == holeScores.count - 1
            && currentHoleIndex == holePars.count - 1
            && currentHoleIndex == puttCounts.count - 1
    }

    // MARK: - 카운터

    mutating func apply(_ mode: StrokeInputMode) {
        switch mode {
        case .swing:
            holeScores[currentHoleIndex] += 1
        case .putt:
            holeScores[currentHoleIndex] += 1
            puttCounts[currentHoleIndex] += 1
        }
    }

    /// `apply`의 정확한 역연산.
    mutating func revert(_ mode: StrokeInputMode) {
        holeScores[currentHoleIndex] -= 1
        if mode == .putt {
            puttCounts[currentHoleIndex] -= 1
        }
    }

    mutating func setPar(_ par: Int) {
        holePars[currentHoleIndex] = par
    }

    // MARK: - 홀 이동

    mutating func advanceToNextHole() {
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
    }

    mutating func retreatToPreviousHole() {
        currentHoleIndex -= 1
    }

    /// 말단 phantom hole을 배열에서 제거하고 이전 홀로 돌아간다.
    /// 호출 전 `isPristinePhantomHole` 확인이 필수다 — 아니면 기록된 홀이 날아간다.
    mutating func removePhantomHoleAndRetreat() {
        holeScores.removeLast()
        holePars.removeLast()
        puttCounts.removeLast()
        currentHoleIndex -= 1
    }

    /// 홀 배열 세 개의 길이를 현재 홀까지 맞춘다. 세 배열은 항상 같은 길이를 유지한다.
    private mutating func ensureCapacityForCurrentHole() {
        let needed = currentHoleIndex + 1
        while holeScores.count < needed {
            holeScores.append(0)
        }
        while holePars.count < needed {
            holePars.append(0)
        }
        while puttCounts.count < needed {
            puttCounts.append(0)
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: watch test
Expected: 전체 59건 PASS (기존 37 + Task 1의 5 + 신규 17). `HoleProgress`는 아직 아무도 안 쓰므로 기존 동작 영향 없음.

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/Round/HoleProgress.swift watchosTests/Round/HoleProgressTests.swift
git commit -m "✅ test: 홀 진행 기록을 담을 HoleProgress 신설

병렬 배열 3개의 길이 불변식과 phantom hole 판정을 담는 순수 struct.
그동안 RoundViewModel의 private이라 간접 검증만 되던 용량 확장·말단 판정을
직접 테스트한다. RoundViewModel 연결은 다음 커밋.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: `RoundViewModel`을 `HoleProgress`로 교체

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`

**Interfaces:**
- Consumes: Task 2의 `HoleProgress` 전체 API, Task 1의 `undoStack`
- Produces: `RoundViewModel`의 공개 API는 **변경 없음** — `currentHoleNumber`·`currentScore`·`currentPutts`·`currentPar`·`canGoToPreviousHole`·`canUndo`·`totalStrokes`·`relativeToPar`·`snapshot`·`phase`·`start()`·`finish()`·`incrementStroke()`·`undo()`·`selectPar(_:)`·`beginParEditing()`·`goToNextHole()`·`goToPreviousHole()`·`cancelToPreviousHole()` 모두 시그니처 동일
- **제거**: `@Published private(set) var holeScores`/`holePars`/`puttCounts`/`currentHoleIndex` (외부 참조가 소스·테스트 어디에도 없음을 확인했다), `private var isPristinePhantomHole`, `private func ensureCapacityForCurrentHole()`

- [ ] **Step 1: 저장 프로퍼티 교체**

네 개의 `@Published private(set) var` 선언을 삭제하고 그 자리에 넣는다:

```swift
    @Published private var progress = HoleProgress()
```

결과적으로 저장 프로퍼티 블록은 이렇게 된다:

```swift
    @Published private var progress = HoleProgress()
    @Published var inputMode: StrokeInputMode = .swing
    /// 파가 이미 설정된 홀에서 [Par] 버튼으로 파 선택 화면을 다시 띄운 상태.
    @Published private(set) var isEditingPar = false
    /// 되돌리기 기록. `canUndo`가 이 값에서 파생되므로 `@Published`여야
    /// 뷰가 취소 버튼의 등장·퇴장을 관찰할 수 있다.
    /// 프로퍼티명이 `undo`가 아닌 이유: 같은 이름의 메서드 `undo()`와 충돌한다.
    @Published private var undoStack = StrokeUndo()
```

- [ ] **Step 2: 두 init 수정**

지정 init의 배열 초기화 4줄(`holeScores = [0]` … `currentHoleIndex = 0`)을 삭제한다. `progress`는 선언부에서 이미 `HoleProgress()`로 초기화되므로 init 본문에 아무것도 추가하지 않는다:

```swift
    init(startedAt: Date = Date(),
         courseName: String? = nil,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        self.startedAt = startedAt
        self.courseName = courseName
        self.publisher = publisher
    }
```

복구 init의 배열 대입 4줄과 `ensureCapacityForCurrentHole()` 호출을 `progress` 생성으로 교체한다 (용량 보정과 음수 인덱스 보정은 `HoleProgress`의 init이 한다):

```swift
    /// App Group 스냅샷으로 라운드를 되살린다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 새로 시작하므로, 여기서는 스코어 상태만 복원한다.
    init(resuming snapshot: RoundSnapshot,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        startedAt = snapshot.startedAt
        courseName = snapshot.courseName
        self.publisher = publisher
        progress = HoleProgress(holeScores: snapshot.holeScores,
                                holePars: snapshot.holePars,
                                puttCounts: snapshot.puttCounts,
                                currentHoleIndex: snapshot.currentHoleIndex)
    }
```

- [ ] **Step 3: 표시값 위임**

`// MARK: - 표시값` 절의 네 프로퍼티와 `canGoToPreviousHole`을 교체한다:

```swift
    var currentHoleNumber: Int {
        progress.currentHoleNumber
    }

    var currentScore: Int {
        progress.currentScore
    }

    var currentPutts: Int {
        progress.currentPutts
    }

    /// 0은 "아직 파가 설정되지 않음"을 뜻한다.
    var currentPar: Int {
        progress.currentPar
    }
```

```swift
    var canGoToPreviousHole: Bool {
        progress.canGoToPreviousHole
    }
```

`phase`·`canUndo`·`totalStrokes`·`relativeToPar`는 그대로 둔다 (`currentPar`·`undoStack`·`snapshot` 경유라 이미 올바르다).

`snapshot`을 교체:

```swift
    var snapshot: RoundSnapshot {
        RoundSnapshot(startedAt: startedAt,
                      courseName: courseName,
                      currentHoleIndex: progress.currentHoleIndex,
                      holeScores: progress.holeScores,
                      holePars: progress.holePars,
                      puttCounts: progress.puttCounts)
    }
```

- [ ] **Step 4: 카운터·파 선택·홀 이동 교체**

```swift
    func incrementStroke() {
        undoStack.record(inputMode)
        progress.apply(inputMode)
        publishSnapshot()
    }

    /// 현재 홀의 마지막 입력을 되돌린다. 입력의 정확한 역연산이다.
    /// 상태를 바꾸는 모든 경로가 스냅샷을 발행한다는 규칙을 따라 마지막에 발행한다.
    func undo() {
        guard let mode = undoStack.pop() else { return }
        progress.revert(mode)
        publishSnapshot()
    }

    // MARK: - 파 선택

    func selectPar(_ par: Int) {
        progress.setPar(par)
        isEditingPar = false
        publishSnapshot()
    }

    func beginParEditing() {
        isEditingPar = true
    }

    // MARK: - 홀 이동

    func goToNextHole() {
        progress.advanceToNextHole()
        resetHoleLocalState()
        publishSnapshot()
    }

    func goToPreviousHole() {
        guard progress.canGoToPreviousHole else { return }
        progress.retreatToPreviousHole()
        resetHoleLocalState()
        publishSnapshot()
    }
```

- [ ] **Step 5: `cancelToPreviousHole` 교체 + 죽은 private 멤버 삭제**

```swift
    /// 파 선택 화면의 "이전" 버튼에서 호출한다.
    /// 방금 실수로 다음 홀에 진입해 아직 아무 값도 입력하지 않은 홀(phantom hole)이면
    /// 그 홀을 배열에서 완전히 제거하고 이전 홀로 돌아가, mis-tap 이전 상태를 그대로 복원한다.
    /// 반대로 이미 점수가 있던 홀을 [Par] 버튼으로 재편집(`beginParEditing()`)하는 중이라면
    /// 지울 phantom hole이 없으므로 일반 `goToPreviousHole()`과 동일하게 동작한다.
    func cancelToPreviousHole() {
        guard progress.canGoToPreviousHole else { return }

        guard !isEditingPar, progress.isPristinePhantomHole else {
            goToPreviousHole()
            return
        }

        progress.removePhantomHoleAndRetreat()
        resetHoleLocalState()
        publishSnapshot()
    }
```

그리고 `private var isPristinePhantomHole`과 `private func ensureCapacityForCurrentHole()`을 **주석 블록째 삭제**한다 — 둘 다 `HoleProgress`로 옮겨갔다. (`!isEditingPar` 조건이 위 guard로 이동한 것이 유일한 형태 변화이며 동작은 동일하다.)

- [ ] **Step 6: 기존 테스트가 그대로 통과하는지 확인**

Run: watch test
Expected: 전체 59건 PASS. **기존 테스트 파일을 하나도 고치지 않았어야 한다.** 특히 다음 3건이 이 Task의 핵심 회귀 방어선이다:
- `실수로_다음홀에_진입한_뒤_취소하면_phantom_hole이_제거되고_이전홀_데이터가_그대로_남는다`
- `이미_점수가_있던_홀의_파_재편집_중_취소는_아무것도_제거하지_않는다` (← `!isEditingPar`가 guard로 옮겨간 것을 검증)
- `길이가_어긋난_스냅샷도_안전하게_복구한다` (← 복구 init의 용량 보정)

- [ ] **Step 7: 줄 수 확인**

```bash
wc -l WatchApp/Features/Round/RoundViewModel.swift WatchApp/Features/Round/HoleProgress.swift WatchApp/Features/Round/StrokeUndo.swift
```
Expected: `RoundViewModel.swift`가 237줄에서 150줄 안팎으로 줄어야 한다. 200줄을 넘으면 옮기다 만 코드가 남은 것이니 다시 확인한다.

- [ ] **Step 8: 커밋**

```bash
git add WatchApp/Features/Round/RoundViewModel.swift
git commit -m "♻️ refactor: RoundViewModel의 홀 상태를 HoleProgress로 위임

배열 3개·인덱스와 용량 확장·phantom hole 판정이 HoleProgress로 옮겨가고,
RoundViewModel은 phase·inputMode·스냅샷 발행을 조정하는 코디네이터로 남는다.
237줄 → 150줄. 공개 API·View·기존 테스트 전부 무변경.

isPristinePhantomHole의 !isEditingPar 조건은 호출부 guard로 이동했다 —
isEditingPar는 RoundViewModel 소유라 HoleProgress가 알 수 없기 때문이며
동작은 동일하다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: 최종 검증 + PR

**Files:**
- 없음 (검증·PR만)

**Interfaces:**
- Consumes: Task 1~3 전체
- Produces: 3개 타깃 그린 + lint/format 통과 + PR

- [ ] **Step 1: 3개 타깃 빌드/테스트**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```
Expected: 전부 SUCCEEDED, watchosTests 59건 PASS. iOS·Complication은 `WatchApp` 그룹을 링크하지 않아 애초에 영향이 없어야 정상이다.

- [ ] **Step 2: View 무변경 확인**

```bash
git diff main --stat -- WatchApp/
```
Expected: `RoundViewModel.swift`·`HoleProgress.swift`·`StrokeUndo.swift` 세 파일만 나온다. View 파일(`*View.swift`, `Components/*`)이 하나라도 있으면 Global Constraints 위반이므로 되돌린다.

- [ ] **Step 3: 기존 테스트 무변경 확인**

```bash
git diff main --stat -- watchosTests/
```
Expected: `HoleProgressTests.swift`·`StrokeUndoTests.swift` 두 신규 파일만 나온다. `RoundViewModel*Tests.swift`가 하나라도 나오면 동작이 바뀐 것이므로 원인을 찾는다.

- [ ] **Step 4: lint/format**

```bash
make lint && make format
```
Expected: 위반 0. 실패 시 `make fix` 후 재실행하고 결과를 커밋한다.

- [ ] **Step 5: push + PR 생성**

```bash
git push -u origin feature/round-viewmodel-split
gh pr create --title "♻️ RoundViewModel 분리 — HoleProgress·StrokeUndo 추출" --body "$(cat <<'EOF'
## Summary
- 스펙: docs/superpowers/specs/2026-08-13-round-viewmodel-split-design.md
- `HoleProgress` 추출 — 홀 배열 3개·인덱스, 용량 확장, phantom hole 판정
- `StrokeUndo` 추출 — 되돌리기 기록
- `RoundViewModel` 237줄 → 150줄, 조정자 역할만 남음
- 그동안 private이라 간접 검증만 되던 로직에 직접 테스트 22건 추가

**동작 변경 0** — View 코드와 기존 테스트 37건 전부 무변경.

## Test plan
- [ ] GolfCounter Watch App: 59건 PASS (기존 37 + 신규 22)
- [ ] GolfCounter (iOS)·ComplicationAppExtension: build 통과
- [ ] make lint / make format 통과
- [ ] git diff --stat으로 View·기존 테스트 무변경 확인

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

머지는 사용자 확인 후 `gh pr merge <n> --merge --delete-branch`.

---

## 후속 작업 (이 플랜 범위 밖)

**플랜 ④ 재작성 → 실행** — 새 구조 기준. 추가 상태의 귀속은 스펙 §8 참조:

| 플랜 ④ 추가분 | 귀속 |
|---------------|------|
| `holeCount`(홀 수 상한), `canGoToNextHole` 상한 검사 | `HoleProgress` |
| `id`, `isFinished`, `phase.summary` | `RoundViewModel` |
| `transmitter`, `finishRound()`, `save(endedAt:metrics:)` | `RoundViewModel` |
| `trimmedSnapshot`, `recordedHoleCount` 등 | `RoundViewModel` (트림 자체는 `RoundSnapshot` 메서드) |
