# 경기 전체 멀티 undo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** undo 버튼이 직전 포인트 1회가 아니라 경기 시작까지 — 게임·세트 경계를 넘어 — 연속으로 되돌리게 한다.

**Architecture:** 스냅샷의 소유권을 `Score`에서 `ScoreViewModel`로 올린다. `Score`는 자기 내부 상태를 봉인한 불투명 `Score.Snapshot`을 만들고 되돌리는 방법만 제공하고(`makeSnapshot()`/`restore(_:)`), 게임·세트 스코어와 완료 세트를 아는 `ScoreViewModel`이 그것을 포함한 **전체 상태 스냅샷 스택**을 소유한다. `addPoint` 진입 시 push, `undo()`는 pop 후 전체 복원. 스택은 driver 로컬에만 존재하므로 와이어 포맷은 변하지 않는다.

**Tech Stack:** Swift 6 / SwiftUI / Combine, Swift Testing (`@Test`, `#expect`), Xcode 16 `PBXFileSystemSynchronizedRootGroup`.

**연관 문서:** `docs/superpowers/specs/2026-07-30-post-persistence-app-improvements-design.md` (② 절)

## Global Constraints

- **선행 조건**: `docs/superpowers/plans/2026-07-30-ralli-kit-persistence-core.md`(Plan 3)가 완료된 상태에서 착수한다.
- **이 머신의 destination** (2026-07-30 `xcrun simctl list devices available`로 확인. 배포 타겟이 26.4라 26.5 런타임을 쓴다):
  - `<IOS_DEST>` = `platform=iOS Simulator,id=CB44AC14-F009-482F-9F4B-712B87A1CB72` (iPhone 17 Pro, iOS 26.5)
  - `<WATCH_DEST>` = `platform=watchOS Simulator,id=D7B72A34-B290-40CE-ADF1-6076F5DB23D0` (Apple Watch Series 11 46mm, watchOS 26.5)
  - 이름이 여러 런타임에 중복 존재하므로 **반드시 `id=`로 지정**한다.
- **iOS와 Watch의 `ScoreViewModel`은 서로 다른 파일이고 상태 모양도 다르다.** iOS는 `completedSets: [(my: Int, your: Int)]` 튜플 + `matchResult` + `currentSetNumber`를 갖고, Watch는 `completedSets: [SetScore]` + `onMatchFinished` 콜백을 쓰며 `currentSetNumber`가 없다. 두 파일에 **같은 코드를 복붙하지 말고 각자의 상태에 맞게** 적는다 (이 계획은 각각의 전체 코드를 따로 싣는다).
- **`Shared/Models/Score.swift`는 iOS·Watch 양 타겟에 컴파일된다.** 이 파일을 바꾸면 두 타겟 모두 빌드·테스트해야 한다.
- 와이어 포맷(`ScoreState`) 변경 금지 — undo 스택은 driver 로컬 상태다.
- 테스트 프레임워크: Swift Testing. ViewModel 테스트는 `@Test @MainActor`.
- 각 태스크 종료 시 **관련 타겟 빌드 + 테스트 그린**. 마지막 태스크에서 Release 빌드까지 확인.
- 린트/포맷: 각 코드 태스크 마지막에 `make fix && make lint` 위반 0건. SwiftFormat 규칙 — 4-space indent, max width 150, 알파벳 순 import.
- 커밋: gitmoji + 한국어. **계획·스펙 문서 자체는 사용자 검토 전까지 커밋하지 않는다** (CLAUDE.md Docs Conventions).

## File Structure

| 파일 | 역할 | 태스크 |
|---|---|---|
| `Shared/Models/Score.swift` | 포인트 상태. `Score.Snapshot` 노출 + 죽은 단일 스냅샷 API 제거 | 1, 4 |
| `iosTests/Shared/ScoreTests.swift` | (신규) Score 스냅샷 왕복 검증 | 1 |
| `iOSApp/Features/Match/Score/ScoreViewModel.swift` | iOS 스냅샷 스택 소유 | 2 |
| `iOSApp/Features/Match/Score/ScoreView.swift` | undo 버튼 조건 + 수동 수정 경로 배선 | 2 |
| `iosTests/Match/ScoreViewModelTests.swift` | iOS undo 시나리오 | 2 |
| `WatchApp/Features/Match/Score/ScoreViewModel.swift` | Watch 스냅샷 스택 소유 | 3 |
| `WatchApp/Features/Match/Score/ScoreView.swift` | undo 버튼 조건 | 3 |
| `watchosTests/Match/ScoreViewModelTests.swift` | Watch undo 시나리오 | 3 |

**태스크 경계의 근거**: Task 1은 `Score`에 API를 **추가만** 하므로 기존 `score.undo()` 호출부가 그대로 살아 양 타겟이 계속 빌드된다. Task 2·3은 각 플랫폼을 독립적으로 전환한다. Task 4에서야 아무도 안 쓰게 된 옛 API를 지운다. 이 순서라야 매 태스크가 빌드·테스트 그린으로 끝난다.

---

### Task 1: Score에 스냅샷 API 추가 (순수 추가, 기존 동작 무변경)

**Files:**
- Modify: `Shared/Models/Score.swift` (`NormalState` 접근 수준 변경 + `Snapshot` 타입·`makeSnapshot()`·`restore(_:)` 추가)
- Create: `iosTests/Shared/ScoreTests.swift`

**Interfaces:**
- Consumes: 없음 (이 계획의 시작점)
- Produces: `Score.Snapshot` (불투명 struct — 멤버는 `fileprivate`라 다른 파일에서 내부를 볼 수 없다), `func makeSnapshot() -> Score.Snapshot`, `func restore(_ snapshot: Score.Snapshot)`. Task 2·3의 ViewModel이 이 셋을 쓴다.
- 이 태스크에서 **`undo()`·`lastAction`·`snapshot`은 건드리지 않는다** — Task 4에서 제거한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Shared/ScoreTests.swift` 신규 생성:

```swift
import Foundation
@testable import TennisCounter
import Testing

struct ScoreTests {
    @Test @MainActor func snapshotRestoresNormalPoints() {
        let score = Score()
        score.addPoint(.me) // 15-0
        score.addPoint(.me) // 30-0
        let snapshot = score.makeSnapshot()

        score.addPoint(.opponent) // 30-15
        score.addPoint(.opponent) // 30-30
        score.restore(snapshot)

        #expect(score.myDisplayScore == "30")
        #expect(score.yourDisplayScore == "0")
    }

    @Test @MainActor func snapshotRestoresTieBreakState() {
        let score = Score()
        score.setTieBreakMode()
        score.addPoint(.me)
        score.addPoint(.me)
        let snapshot = score.makeSnapshot()

        score.addPoint(.opponent)
        score.restore(snapshot)

        #expect(score.gameMode == .tieBreak)
        #expect(score.myTieBreak == 2)
        #expect(score.yourTieBreak == 0)
    }

    @Test @MainActor func snapshotTakenInNormalModeRestoresGameMode() {
        let score = Score()
        score.addPoint(.me) // normal 모드, 15-0
        let snapshot = score.makeSnapshot()

        score.setTieBreakMode() // 타이브레이크 진입
        score.addPoint(.me)
        score.restore(snapshot)

        #expect(score.gameMode == .normal)
        #expect(score.myDisplayScore == "15")
    }

    @Test @MainActor func snapshotRestoresAdvantage() {
        let score = Score()
        score.noAdRule = false
        for _ in 0 ..< 3 { score.addPoint(.me); score.addPoint(.opponent) } // 40-40 듀스
        score.addPoint(.me) // AD-40
        let snapshot = score.makeSnapshot()

        score.addPoint(.opponent) // 듀스로 복귀
        score.restore(snapshot)

        #expect(score.myDisplayScore == "AD")
        #expect(score.yourDisplayScore == "40")
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -30`
Expected: 컴파일 실패 — `value of type 'Score' has no member 'makeSnapshot'`

- [ ] **Step 3: Score.swift에 스냅샷 API 추가**

`Shared/Models/Score.swift`의 `private enum NormalState` 선언(19-21행)을 `fileprivate`로 바꾸고, 그 아래 기존 `private struct SnapShot { ... }`(23-29행) **바로 뒤에** 새 `Snapshot` 타입을 추가한다. 기존 `SnapShot`은 Task 4까지 그대로 둔다 (`undo()`가 아직 쓴다).

19-21행을 다음으로 교체:

```swift
    fileprivate enum NormalState: Equatable {
        case zero, fifteen, thirty, forty, advantage
    }

    /// Score의 복원 가능한 전체 상태. undo 스택은 ScoreViewModel이 소유하고,
    /// Score는 자기 상태를 봉인해 넘기고 되돌리는 방법만 제공한다.
    /// 멤버가 fileprivate라 다른 파일에서는 내부를 볼 수 없는 불투명 값이다.
    struct Snapshot {
        fileprivate let myNormal: NormalState
        fileprivate let yourNormal: NormalState
        fileprivate let myTieBreak: Int
        fileprivate let yourTieBreak: Int
        fileprivate let gameMode: GameMode
    }
```

그리고 `setTieBreakMode()` 메서드(94-99행) 바로 뒤에 다음 두 메서드를 추가:

```swift
    func makeSnapshot() -> Snapshot {
        Snapshot(myNormal: myNormal, yourNormal: yourNormal,
                 myTieBreak: myTieBreak, yourTieBreak: yourTieBreak,
                 gameMode: gameMode)
    }

    func restore(_ snapshot: Snapshot) {
        myNormal = snapshot.myNormal
        yourNormal = snapshot.yourNormal
        myTieBreak = snapshot.myTieBreak
        yourTieBreak = snapshot.yourTieBreak
        gameMode = snapshot.gameMode
        objectWillChange.send()
    }
```

(`NormalState`를 `private` → `fileprivate`로 올리는 이유: `Snapshot`의 `fileprivate` 저장 프로퍼티가 `private` 타입을 쓰면 "property cannot be declared fileprivate because its type uses a private type" 컴파일 에러가 난다.)

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -30`
Expected: TEST SUCCEEDED — `ScoreTests` 4개 PASS + 기존 iOS 스위트 전체 그린 (기존 동작을 건드리지 않았으므로)

- [ ] **Step 5: Watch 타겟 회귀 확인**

`Score.swift`는 Watch에도 컴파일되므로 확인한다.

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' 2>&1 | tail -30`
Expected: TEST SUCCEEDED

- [ ] **Step 6: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add Shared/Models/Score.swift iosTests/Shared/ScoreTests.swift
git commit -m "✨ Score에 불투명 Snapshot 왕복 API 추가

undo 스택을 ScoreViewModel이 소유하기 위한 선행 작업.
기존 단일 스냅샷 undo()는 아직 그대로 둔다 (호출부 전환 후 제거).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: iOS ScoreViewModel 멀티 undo 전환

**Files:**
- Modify: `iOSApp/Features/Match/Score/ScoreViewModel.swift`
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift:60`, `:84`
- Modify: `iosTests/Match/ScoreViewModelTests.swift` (기존 테스트 2개 수정 + 신규 8개 추가)

**Interfaces:**
- Consumes: Task 1의 `Score.Snapshot`, `score.makeSnapshot()`, `score.restore(_:)`
- Produces: iOS `ScoreViewModel`의 `var canUndo: Bool`, `func undo()`(동작 변경), `func applyManualEdit()`(신규). `ScoreView`가 이 셋을 쓴다. Task 3(Watch)은 이 태스크와 독립이다 — 파일이 다르므로 서로 영향 없음.

- [ ] **Step 1: 기존 테스트 2개를 새 동작으로 교체 (실패해야 함)**

`iosTests/Match/ScoreViewModelTests.swift`의 기존 `addPointUndoResetsScore`(29-35행)와 `undoAfterGameWinIsNoOp`(48-54행)는 **옛 동작을 고정한 테스트**다. 후자는 "게임 승리는 되돌릴 수 없다"를 단언하므로 새 동작과 정면으로 충돌한다. 두 테스트를 다음으로 교체한다.

`addPointUndoResetsScore`를 다음으로 교체:

```swift
    @Test @MainActor func addPointUndoResetsScore() {
        let vm = ScoreViewModel()
        vm.addPoint(.me) // 15-0
        vm.undo()
        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.canUndo == false)
    }
```

`undoAfterGameWinIsNoOp` 전체(주석 포함)를 다음으로 교체:

```swift
    @Test @MainActor func undoReversesGameWin() {
        let vm = ScoreViewModel()
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me) // 40-0
        vm.addPoint(.opponent) // 40-15
        vm.addPoint(.me) // 게임 획득 → 1-0
        #expect(vm.myGameScore == 1)

        vm.undo() // 게임 경계를 넘어 되돌린다

        #expect(vm.myGameScore == 0)
        #expect(vm.score.myDisplayScore == "40")
        #expect(vm.score.yourDisplayScore == "15")
    }
```

- [ ] **Step 2: 신규 undo 시나리오 테스트 추가**

같은 파일의 `resetAllClearsStateAndAppliesNewOptions` 테스트 **앞에** 다음 블록을 삽입한다:

```swift
    // MARK: - 경기 전체 멀티 undo

    @Test @MainActor func undoRewindsGamePointsToZero() {
        let vm = ScoreViewModel()
        vm.addPoint(.me) // 15-0
        vm.addPoint(.opponent) // 15-15
        vm.addPoint(.me) // 30-15

        vm.undo(); vm.undo(); vm.undo()

        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.score.yourDisplayScore == "0")
        #expect(vm.canUndo == false)
    }

    @Test @MainActor func undoBeyondMatchStartIsNoOp() {
        let vm = ScoreViewModel()
        vm.undo() // 스택이 비어 있다
        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.canUndo == false)
    }

    @Test @MainActor func undoReversesSetCompletion() {
        // bestOfThree(setsToWin=2)라 세트 1개를 따도 경기는 안 끝난다
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        #expect(vm.mySetScore == 1)
        #expect(vm.completedSets.count == 1)
        #expect(vm.currentSetNumber == 2)

        vm.undo() // 세트 경계를 넘어 되돌린다

        #expect(vm.mySetScore == 0)
        #expect(vm.completedSets.isEmpty)
        #expect(vm.currentSetNumber == 1)
        #expect(vm.myGameScore == 4)
        #expect(vm.score.myDisplayScore == "40")
    }

    @Test @MainActor func undoAllTheWayBackToMatchStart() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        while vm.canUndo { vm.undo() }

        #expect(vm.myGameScore == 0)
        #expect(vm.mySetScore == 0)
        #expect(vm.completedSets.isEmpty)
        #expect(vm.currentSetNumber == 1)
        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.canUndo == false)
    }

    @Test @MainActor func undoReversesTieBreakEntry() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.isTieBreak == true)

        vm.undo() // 타이브레이크 진입 직전으로

        #expect(vm.isTieBreak == false)
        #expect(vm.myGameScore == 5)
        #expect(vm.yourGameScore == 4)
        #expect(vm.score.yourDisplayScore == "40")
    }

    @Test @MainActor func applyRemoteStateClearsUndoStack() {
        let vm = ScoreViewModel()
        vm.addPoint(.me)
        #expect(vm.canUndo == true)

        vm.applyRemoteState(ScoreState(
            myScore: 30, yourScore: 15,
            myGameScore: 2, yourGameScore: 1,
            mySetScore: 0, yourSetScore: 0,
            completedSets: [], isTieBreak: false
        ))

        #expect(vm.canUndo == false)
    }

    @Test @MainActor func applyManualEditClearsUndoStack() {
        let vm = ScoreViewModel()
        vm.addPoint(.me)
        #expect(vm.canUndo == true)

        vm.score.myIndex = 3 // ScoreEditSheet가 하는 조작
        vm.applyManualEdit()

        #expect(vm.canUndo == false)
        #expect(vm.score.myDisplayScore == "40")
    }

    @Test @MainActor func resetAllClearsUndoStack() {
        let vm = ScoreViewModel()
        vm.addPoint(.me)
        vm.resetAll(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        #expect(vm.canUndo == false)
    }
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -30`
Expected: 컴파일 실패 — `value of type 'ScoreViewModel' has no member 'canUndo'`, `has no member 'applyManualEdit'`

- [ ] **Step 4: iOS ScoreViewModel 구현**

`iOSApp/Features/Match/Score/ScoreViewModel.swift` 전체를 다음으로 교체:

```swift
import Combine
import Foundation

@MainActor
final class ScoreViewModel: ObservableObject {
    @Published private(set) var options: MatchOptions

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published private(set) var matchResult: MatchResult?

    /// 포인트 하나마다 쌓이는 경기 전체 상태. 게임·세트 경계를 넘어 되돌리기 위해
    /// Score뿐 아니라 게임·세트 스코어와 완료 세트까지 함께 봉인한다.
    private struct Snapshot {
        let score: Score.Snapshot
        let myGameScore: Int
        let yourGameScore: Int
        let mySetScore: Int
        let yourSetScore: Int
        let currentSetNumber: Int
        let completedSets: [(my: Int, your: Int)]
        let tieBreakInProgress: Bool
        let matchResult: MatchResult?
    }

    private var snapshots: [Snapshot] = []

    var isMatchOver: Bool {
        matchResult != nil
    }

    var didWin: Bool {
        matchResult == .win
    }

    var isTieBreak: Bool {
        score.gameMode == .tieBreak
    }

    var canUndo: Bool {
        !snapshots.isEmpty
    }

    var hasProgress: Bool {
        myGameScore > 0 || yourGameScore > 0 ||
            mySetScore > 0 || yourSetScore > 0 ||
            !completedSets.isEmpty ||
            canUndo
    }

    private var tieBreakInProgress = false
    private var cancellables = Set<AnyCancellable>()

    var onStateChanged: (() -> Void)?

    init(options: MatchOptions = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) {
        self.options = options
        score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        guard !isMatchOver else { return }
        snapshots.append(captureSnapshot())
        let gameWon = score.addPoint(side)
        if gameWon != nil {
            if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
            score.resetData()
            checkSetUpdate()
        }
        onStateChanged?()
    }

    /// 경기 시작까지 되돌린다 — 게임·세트 경계를 넘는다.
    func undo() {
        guard let snapshot = snapshots.popLast() else { return }
        apply(snapshot)
        onStateChanged?()
    }

    /// ScoreEditSheet 수동 수정 경로. 수정은 새 기준점이므로 이전 스택을 버린다
    /// (버리지 않으면 undo가 수정 이전 과거로 튄다).
    func applyManualEdit() {
        snapshots.removeAll()
        onStateChanged?()
    }

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
        snapshots.removeAll()
        score.noAdRule = options.noAdRule
        score.resetData()
    }

    func applyRemoteState(_ state: ScoreState) {
        myGameScore = state.myGameScore
        yourGameScore = state.yourGameScore
        mySetScore = state.mySetScore
        yourSetScore = state.yourSetScore
        completedSets = state.completedSets.map { (my: $0[0], your: $0[1]) }
        score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
        tieBreakInProgress = state.isTieBreak
        // mirror 측은 스스로 되돌릴 수 없다 — 권한은 driver에 있다.
        snapshots.removeAll()
    }

    func makeScoreState() -> ScoreState {
        let myS = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
        let yourS = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
        return ScoreState(
            myScore: myS, yourScore: yourS,
            myGameScore: myGameScore, yourGameScore: yourGameScore,
            mySetScore: mySetScore, yourSetScore: yourSetScore,
            completedSets: completedSets.map { [$0.my, $0.your] },
            isTieBreak: score.gameMode == .tieBreak
        )
    }

    // MARK: - Private

    private func captureSnapshot() -> Snapshot {
        Snapshot(
            score: score.makeSnapshot(),
            myGameScore: myGameScore,
            yourGameScore: yourGameScore,
            mySetScore: mySetScore,
            yourSetScore: yourSetScore,
            currentSetNumber: currentSetNumber,
            completedSets: completedSets,
            tieBreakInProgress: tieBreakInProgress,
            matchResult: matchResult
        )
    }

    private func apply(_ snapshot: Snapshot) {
        score.restore(snapshot.score)
        myGameScore = snapshot.myGameScore
        yourGameScore = snapshot.yourGameScore
        mySetScore = snapshot.mySetScore
        yourSetScore = snapshot.yourSetScore
        currentSetNumber = snapshot.currentSetNumber
        completedSets = snapshot.completedSets
        tieBreakInProgress = snapshot.tieBreakInProgress
        matchResult = snapshot.matchResult
    }

    private func checkSetUpdate() {
        let threshold = options.gameThreshold
        let my = myGameScore, your = yourGameScore

        if tieBreakInProgress {
            if (my == threshold + 1 && your == threshold) || (your == threshold + 1 && my == threshold) {
                tieBreakInProgress = false
                finalizeSet(winner: my > your ? .me : .opponent)
            }
            return
        }

        if my == threshold, your == threshold {
            if options.noTieRule {
                completedSets.append((my: my, your: your))
                matchResult = .draw
            } else {
                score.setTieBreakMode()
                tieBreakInProgress = true
            }
            return
        }

        let maxG = max(my, your), minG = min(my, your)
        guard maxG >= threshold, (maxG - minG) >= 2 else { return }
        finalizeSet(winner: my > your ? .me : .opponent)
    }

    private func finalizeSet(winner: PlayerSide) {
        completedSets.append((my: myGameScore, your: yourGameScore))
        if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0
        currentSetNumber += 1

        if mySetScore >= options.mode.setsToWin {
            matchResult = .win
        } else if yourSetScore >= options.mode.setsToWin {
            matchResult = .loss
        }
    }
}
```

원본 대비 변경점만 요약하면: `Snapshot` struct + `snapshots` 스택 + `canUndo` 추가, `hasProgress`가 `score.lastAction != .none` → `canUndo`, `addPoint`가 push, `undo()`가 pop+복원, `applyManualEdit()` 신설, `resetAll`·`applyRemoteState`에 `snapshots.removeAll()` 추가, `captureSnapshot()`/`apply(_:)` private 헬퍼 추가. `checkSetUpdate`·`finalizeSet`·`makeScoreState`는 무변경.

- [ ] **Step 5: iOS ScoreView 배선**

`iOSApp/Features/Match/Score/ScoreView.swift`의 60행을 교체:

```swift
                if viewModel.canUndo {
```

그리고 84행의 시트 생성을 교체 (수동 수정이 스택을 지우도록):

```swift
            ScoreEditSheet(score: viewModel.score, onChange: { viewModel.applyManualEdit() })
```

(`applyManualEdit()`가 내부에서 `onStateChanged?()`를 호출하므로 동기화 브로드캐스트는 그대로 유지된다.)

- [ ] **Step 6: iOS 테스트 통과 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -30`
Expected: TEST SUCCEEDED — 신규 undo 테스트 8개 + 교체한 2개 + 기존 iOS 스위트 전체 그린

- [ ] **Step 7: Watch 타겟 회귀 확인**

Watch 파일은 안 건드렸지만 `Score.swift`를 공유하므로 확인한다.

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' 2>&1 | tail -30`
Expected: TEST SUCCEEDED

- [ ] **Step 8: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add iOSApp/Features/Match/Score iosTests/Match/ScoreViewModelTests.swift
git commit -m "✨ iOS undo를 경기 전체 되돌리기로 확장

스냅샷 스택을 ScoreViewModel이 소유해 게임·세트 경계를 넘어
경기 시작까지 되돌린다. ScoreEditSheet 수동 수정은 새 기준점이므로
스택을 버린다. mirror 측은 기존대로 undo 불가.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Watch ScoreViewModel 멀티 undo 전환

**Files:**
- Modify: `WatchApp/Features/Match/Score/ScoreViewModel.swift`
- Modify: `WatchApp/Features/Match/Score/ScoreView.swift:53`, `:59`
- Modify: `watchosTests/Match/ScoreViewModelTests.swift` (신규 6개 추가)

**Interfaces:**
- Consumes: Task 1의 `Score.Snapshot`, `score.makeSnapshot()`, `score.restore(_:)`
- Produces: Watch `ScoreViewModel`의 `var canUndo: Bool`, `func undo()`(동작 변경). Watch `ScoreView`가 쓴다. **Watch에는 ScoreEditSheet가 없으므로 `applyManualEdit()`를 만들지 않는다** (YAGNI).

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Match/ScoreViewModelTests.swift`의 `resetAllClearsStateAndAppliesNewOptions` 테스트 **앞에** 다음 블록을 삽입:

```swift
    // MARK: - 경기 전체 멀티 undo

    @Test @MainActor func watchUndoRewindsGamePointsToZero() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.addPoint(.me) // 15-0
        vm.addPoint(.opponent) // 15-15
        vm.addPoint(.me) // 30-15

        vm.undo(); vm.undo(); vm.undo()

        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.score.yourDisplayScore == "0")
        #expect(vm.canUndo == false)
    }

    @Test @MainActor func watchUndoBeyondMatchStartIsNoOp() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.undo() // 스택이 비어 있다
        #expect(vm.score.myDisplayScore == "0")
        #expect(vm.canUndo == false)
    }

    @Test @MainActor func watchUndoReversesGameWin() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me) // 40-0
        vm.addPoint(.opponent) // 40-15
        vm.addPoint(.me) // 게임 획득 → 1-0
        #expect(vm.myGameScore == 1)

        vm.undo()

        #expect(vm.myGameScore == 0)
        #expect(vm.score.myDisplayScore == "40")
        #expect(vm.score.yourDisplayScore == "15")
    }

    @Test @MainActor func watchUndoReversesSetCompletion() {
        // bestOfThree(setsToWin=2)라 세트 1개를 따도 경기는 안 끝난다
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        }
        #expect(vm.mySetScore == 1)
        #expect(vm.completedSets.count == 1)

        vm.undo() // 세트 경계를 넘어 되돌린다

        #expect(vm.mySetScore == 0)
        #expect(vm.completedSets.isEmpty)
        #expect(vm.myGameScore == 4)
        #expect(vm.score.myDisplayScore == "40")
    }

    @Test @MainActor func watchUndoReversesTieBreakEntry() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
        for _ in 0 ..< 5 {
            vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
            vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
        }
        #expect(vm.score.gameMode == .tieBreak)

        vm.undo()

        #expect(vm.score.gameMode == .normal)
        #expect(vm.myGameScore == 5)
        #expect(vm.yourGameScore == 4)
        #expect(vm.score.yourDisplayScore == "40")
    }

    @Test @MainActor func watchApplyRemoteStateClearsUndoStack() {
        let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.addPoint(.me)
        #expect(vm.canUndo == true)

        vm.applyRemoteState(ScoreState(
            myScore: 30, yourScore: 15,
            myGameScore: 2, yourGameScore: 1,
            mySetScore: 0, yourSetScore: 0,
            completedSets: [], isTieBreak: false
        ))

        #expect(vm.canUndo == false)
    }
```

그리고 기존 `resetAllClearsStateAndAppliesNewOptions` 테스트 본문의 마지막 `#expect` 뒤에 한 줄 추가:

```swift
        #expect(vm.canUndo == false)
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' 2>&1 | tail -30`
Expected: 컴파일 실패 — `value of type 'ScoreViewModel' has no member 'canUndo'`

- [ ] **Step 3: Watch ScoreViewModel 구현**

`WatchApp/Features/Match/Score/ScoreViewModel.swift` 전체를 다음으로 교체:

```swift
import Combine
import SwiftUI

class ScoreViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var completedSets: [SetScore] = []

    @Published private(set) var options: MatchOptions
    var onMatchFinished: ((MatchResult, [SetScore]) -> Void)?

    /// 포인트 하나마다 쌓이는 경기 전체 상태. 게임·세트 경계를 넘어 되돌리기 위해
    /// Score뿐 아니라 게임·세트 스코어와 완료 세트까지 함께 봉인한다.
    private struct Snapshot {
        let score: Score.Snapshot
        let myGameScore: Int
        let yourGameScore: Int
        let mySetScore: Int
        let yourSetScore: Int
        let completedSets: [SetScore]
        let tieBreakInProgress: Bool
    }

    private var snapshots: [Snapshot] = []
    private var tieBreakInProgress: Bool = false
    private var cancellables = Set<AnyCancellable>()

    var onStateChanged: (() -> Void)?

    var canUndo: Bool {
        !snapshots.isEmpty
    }

    init(options: MatchOptions) {
        self.options = options
        score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        snapshots.append(captureSnapshot())
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

    /// 경기 시작까지 되돌린다 — 게임·세트 경계를 넘는다.
    func undo() {
        guard let snapshot = snapshots.popLast() else { return }
        apply(snapshot)
        onStateChanged?()
    }

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

    func resetAll(options: MatchOptions) {
        self.options = options
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        completedSets = []
        tieBreakInProgress = false
        snapshots.removeAll()
        score.noAdRule = options.noAdRule
        score.reset()
    }

    func applyRemoteState(_ state: ScoreState) {
        myGameScore = state.myGameScore
        yourGameScore = state.yourGameScore
        mySetScore = state.mySetScore
        yourSetScore = state.yourSetScore
        completedSets = state.completedSets.map { SetScore(my: $0[0], your: $0[1]) }
        score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
        tieBreakInProgress = state.isTieBreak
        // mirror 측은 스스로 되돌릴 수 없다 — 권한은 driver에 있다.
        snapshots.removeAll()
    }

    private func captureSnapshot() -> Snapshot {
        Snapshot(
            score: score.makeSnapshot(),
            myGameScore: myGameScore,
            yourGameScore: yourGameScore,
            mySetScore: mySetScore,
            yourSetScore: yourSetScore,
            completedSets: completedSets,
            tieBreakInProgress: tieBreakInProgress
        )
    }

    private func apply(_ snapshot: Snapshot) {
        score.restore(snapshot.score)
        myGameScore = snapshot.myGameScore
        yourGameScore = snapshot.yourGameScore
        mySetScore = snapshot.mySetScore
        yourSetScore = snapshot.yourSetScore
        completedSets = snapshot.completedSets
        tieBreakInProgress = snapshot.tieBreakInProgress
    }

    private func checkSetUpdate() {
        let threshold = options.gameThreshold
        let my = myGameScore, your = yourGameScore

        if tieBreakInProgress {
            if (my == threshold + 1 && your == threshold) || (your == threshold + 1 && my == threshold) {
                tieBreakInProgress = false
                let winner: PlayerSide = my == threshold + 1 ? .me : .opponent
                finalizeSet(winner: winner)
            }
            return
        }

        if my == threshold, your == threshold {
            if options.noTieRule {
                completedSets.append(SetScore(my: my, your: your))
                onMatchFinished?(.draw, completedSets)
            } else {
                score.setTieBreakMode()
                tieBreakInProgress = true
            }
            return
        }

        let maxG = max(my, your), minG = min(my, your)
        guard maxG >= threshold, (maxG - minG) >= 2 else { return }
        finalizeSet(winner: my > your ? .me : .opponent)
    }

    private func finalizeSet(winner: PlayerSide) {
        completedSets.append(SetScore(my: myGameScore, your: yourGameScore))
        if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0

        let setsToWin = options.mode.setsToWin
        if mySetScore >= setsToWin {
            onMatchFinished?(.win, completedSets)
        } else if yourSetScore >= setsToWin {
            onMatchFinished?(.loss, completedSets)
        }
    }
}
```

원본 대비 변경점: `Snapshot` struct + `snapshots` 스택 + `canUndo` 추가, `addPoint`가 push, `undo()`가 `score.undo()` → pop+복원, `resetAll`·`applyRemoteState`에 `snapshots.removeAll()` 추가, `captureSnapshot()`/`apply(_:)` 추가. `checkSetUpdate`·`finalizeSet`·`makeScoreState`는 무변경.

- [ ] **Step 4: Watch ScoreView 배선**

`WatchApp/Features/Match/Score/ScoreView.swift`의 53행을 교체:

```swift
                    } else if viewModel.canUndo {
```

그리고 59행의 애니메이션 트리거를 교체:

```swift
                .animation(.easeInOut(duration: 0.2), value: viewModel.canUndo)
```

- [ ] **Step 5: Watch 테스트 통과 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' 2>&1 | tail -30`
Expected: TEST SUCCEEDED — 신규 undo 테스트 6개 + 기존 Watch 스위트 전체 그린

- [ ] **Step 6: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add WatchApp/Features/Match/Score watchosTests/Match/ScoreViewModelTests.swift
git commit -m "✨ Watch undo를 경기 전체 되돌리기로 확장

iOS와 동일하게 스냅샷 스택을 ScoreViewModel이 소유한다.
Watch에는 수정 시트가 없어 applyManualEdit는 두지 않는다.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Score의 죽은 단일 스냅샷 API 제거 + 문서

**Files:**
- Modify: `Shared/Models/Score.swift` (`LastAction` enum, `lastAction`, `snapshot`, `SnapShot`, `undo()` 제거)
- Modify: `CLAUDE.md` (Score 설명 한 줄)

**Interfaces:**
- Consumes: Task 2·3 완료 상태 (양 플랫폼 모두 `score.undo()`·`score.lastAction`을 더 이상 참조하지 않는다)
- Produces: 없음 (이 계획의 마지막 코드 변경)

- [ ] **Step 1: 잔여 참조가 없는지 확인**

```bash
cd /Users/yj/Workspace/tennis_counter
grep -rn "lastAction\|score\.undo()\|LastAction" --include="*.swift" . | grep -v "Shared/Models/Score.swift"
```

Expected: **출력 없음.** 하나라도 나오면 Task 2·3이 덜 끝난 것이므로 그 파일을 먼저 고친다.

- [ ] **Step 2: Score.swift에서 죽은 코드 제거**

`Shared/Models/Score.swift`에서 다음 5곳을 삭제한다.

① 파일 상단의 `LastAction` enum 전체 (`PlayerSide` 아래):

```swift
enum LastAction {
    case myPoint
    case opponentPoint
    case none
}
```

② 기존 `private struct SnapShot { ... }` 전체 (Task 1에서 추가한 `struct Snapshot`은 **남긴다** — 이름이 다르다):

```swift
    private struct SnapShot {
        let myNormal: NormalState
        let yourNormal: NormalState
        let myTieBreak: Int
        let yourTieBreak: Int
        let gameMode: GameMode
    }
```

③ `@Published private(set) var lastAction: LastAction = .none` 한 줄과 `private var snapshot: SnapShot?` 한 줄.

④ `addPoint(_:)`의 앞 4줄 — 메서드가 다음으로 시작하게 만든다:

```swift
    @discardableResult
    func addPoint(_ side: PlayerSide) -> PlayerSide? {
        switch gameMode {
        case .normal: return addNormalPoint(side)
        case .tieBreak: return addTieBreakPoint(side)
        }
    }
```

⑤ `undo()` 메서드 전체:

```swift
    func undo() {
        guard let s = snapshot else { return }
        myNormal = s.myNormal
        ...
    }
```

그리고 `reset()`에서 `lastAction = .none`·`snapshot = nil` 두 줄, `applyRemote(...)`에서 `snapshot = nil`·`lastAction = .none` 두 줄을 삭제한다. 삭제 후 두 메서드는 각각 이렇게 된다:

```swift
    func reset() {
        myNormal = .zero
        yourNormal = .zero
        myTieBreak = 0
        yourTieBreak = 0
        gameMode = .normal
        objectWillChange.send()
    }
```

```swift
    func applyRemote(myScore: Int, yourScore: Int, isTieBreak: Bool) {
        if isTieBreak {
            gameMode = .tieBreak
            myTieBreak = myScore
            yourTieBreak = yourScore
        } else {
            gameMode = .normal
            let myIdx = Self.scoreValues.firstIndex(of: myScore) ?? 0
            let yourIdx = Self.scoreValues.firstIndex(of: yourScore) ?? 0
            myNormal = Self.normalStates[myIdx]
            yourNormal = Self.normalStates[yourIdx]
        }
        objectWillChange.send()
    }
```

- [ ] **Step 3: 양 타겟 테스트 통과 확인**

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -20
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' 2>&1 | tail -20
```

Expected: 둘 다 TEST SUCCEEDED

- [ ] **Step 4: 양 타겟 Release 빌드 확인**

Debug 전용 검증이 아카이브 실패를 숨긴 이력이 있다 (RalliKit Plan 1 교훈).

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' -configuration Release build 2>&1 | tail -5
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' -configuration Release build 2>&1 | tail -5
```

Expected: 둘 다 BUILD SUCCEEDED

- [ ] **Step 5: CLAUDE.md 한 줄 갱신**

`CLAUDE.md`의 Architecture 트리에서 Score 설명 줄을 교체한다.

기존:

```
│   ├── Score.swift          # 점수 상태 ObservableObject. scoreArr = [0,15,30,40,50], undo via LastAction enum
```

교체:

```
│   ├── Score.swift          # 점수 상태 ObservableObject. scoreArr = [0,15,30,40,50], Snapshot 왕복 API 제공
```

그리고 같은 파일 아래쪽 불릿 목록의 Score 줄도 교체한다.

기존:

```markdown
- **Score** (`ObservableObject`): point state (`scoreArr = [0, 15, 30, 40, 50]`), undo via `LastAction` enum. iOS/Watch 타겟 공유.
```

교체:

```markdown
- **Score** (`ObservableObject`): point state (`scoreArr = [0, 15, 30, 40, 50]`), 복원용 `Score.Snapshot` 왕복 API 제공. undo 스택은 `ScoreViewModel`이 소유한다 (경기 전체 되돌리기). iOS/Watch 타겟 공유.
```

- [ ] **Step 6: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add Shared/Models/Score.swift CLAUDE.md
git commit -m "🔥 Score의 단일 스냅샷 undo 잔재 제거

lastAction·LastAction·SnapShot·undo()는 스택이 ScoreViewModel로
옮겨간 뒤 아무도 참조하지 않는다.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: [사용자 수동] 실기기 2대 동기화 회귀

**⚠️ 시뮬레이터로는 WCSession 큐잉·실제 워치 조작을 재현할 수 없다** (메모리: 연동 버그는 시뮬레이터/싱글톤 테스트로 재현되지 않음 — 실기기 2대로 검증). undo가 driver 로컬 상태를 되감고 전체 `ScoreState`를 브로드캐스트하는 구조라, 동기화 회귀 여부는 실기기에서만 확정된다.

- [ ] **Step 1: [사용자] iPhone + Apple Watch에 설치 후 아래 확인**

- [ ] **워치 driver → 폰 mirror**: 워치에서 게임을 하나 딴 뒤 undo → 폰 화면의 게임 스코어도 같이 되돌아온다
- [ ] **세트 경계**: 워치에서 세트를 하나 딴 뒤 undo → 폰의 세트 스코어·완료 세트 표시가 되돌아온다
- [ ] **연속 undo**: 워치에서 5회 이상 연속 탭 → 폰이 마지막 상태로 수렴한다 (중간 상태에서 멈추지 않음)
- [ ] **폰 driver → 워치 mirror**: 폰에서 같은 시나리오 → 워치가 따라온다
- [ ] **mirror 측 버튼 부재**: mirror 기기에는 undo 버튼이 안 보이고 Mirror 배지가 보인다
- [ ] **폰 수동 수정**: 폰에서 길게 눌러 ScoreEditSheet로 점수 수정 → undo 버튼이 사라지고, 워치에 수정된 점수가 반영된다
- [ ] **Live Activity / Complication**: undo 후 잠금화면 Live Activity와 워치 컴플리케이션 점수가 되돌아온 값으로 갱신된다

- [ ] **Step 2: 결과 기록**

전부 통과하면 `docs/superpowers/logs/2026-07-30-match-wide-undo.md`에 결과를 남긴다. 실패가 있으면 증상을 기록하고 `superpowers:systematic-debugging`으로 진입한다. 롤백 단위는 Task 2(iOS 커밋)·Task 3(Watch 커밋)으로 분리돼 있어 한쪽만 되돌릴 수 있다.

---

## 완료 기준 (Definition of Done)

1. `grep -rn "lastAction\|LastAction\|score\.undo()" --include="*.swift" .` → 0건
2. `grep -n "canUndo" iOSApp/Features/Match/Score/ScoreView.swift WatchApp/Features/Match/Score/ScoreView.swift` → 각 파일에서 최소 1건 (iOS 1건, Watch 2건)
3. iOS 테스트 스위트 그린 — 신규 `ScoreTests` 4개 + `ScoreViewModelTests`의 undo 테스트 9개 포함
4. Watch 테스트 스위트 그린 — undo 테스트 6개 포함
5. 양 타겟 **Release 빌드** 그린
6. `make lint` 위반 0건
7. `ScoreState` 필드·직렬화 키 무변경 (`git diff` 범위에 `Shared/Services/ConnectivityMessages.swift` 없음)
8. Task 5 실기기 회귀 완료
