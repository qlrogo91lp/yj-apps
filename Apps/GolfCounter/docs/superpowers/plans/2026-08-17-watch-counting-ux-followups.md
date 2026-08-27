# 카운팅 화면 UX 후속 정리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워치 카운팅 화면의 UX 결함 세 가지를 고친다 — 홀을 옮기면 사라지는 undo, 마지막 홀에서
죽어있는 `›` 버튼, 요약 화면의 안 눌리는 것처럼 보이는 "저장 안 함" 버튼과 산만한 표시 정보.

**Architecture:** `StrokeUndo`를 홀 인덱스별 저장소로 바꿔 `RoundViewModel`이 홀을 옮겨도 되돌리기
기록을 유지하게 한다. `CountingView` → `ScoringView` → `RoundSessionView`로 `onRequestEnd` 콜백을
내려 마지막 홀에서 기존 종료 다이얼로그를 재사용한다. `SummaryView`는 총타수 중심 레이아웃과
가로 2등분 실버튼으로 재작성한다.

**Tech Stack:** Swift, SwiftUI (watchOS 10+), Swift Testing (`watchosTests`).

## Global Constraints

- 커밋 메시지는 gitmoji prefix: ✨ feat / 🐛 fix / ♻️ refactor / 📝 docs / ✅ test / 🔧 chore.
- `main` 직접 push 금지 — 브랜치 + PR, 머지는 일반 merge commit(`gh pr merge <n> --merge --delete-branch`).
- 한 파일 = 한 타입, `Components/` 안 순수 컴포넌트는 suffix 없음, View는 테스트하지 않는다
  (ViewModel/모델 우선) — `CLAUDE.md` 컨벤션.
- ko/en `.lproj` 키 집합과 포맷 지정자가 항상 일치해야 한다 —
  `watchosTests/Localization/StringsParityTests.swift`가 검증한다.
- 워치 테스트: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test`
- Lint: `make lint` (swiftlint) / Format 검사: `make format` / 자동 수정: `make fix`
- 스펙 문서: `docs/superpowers/specs/2026-08-17-watch-counting-ux-followups-design.md`

---

## Task 0: 작업 브랜치 생성

**Files:** 없음(git 조작만).

- [ ] **Step 1: 브랜치 생성**

```bash
git checkout -b watch-counting-ux-followups
```

- [ ] **Step 2: 원격 최신 상태 확인**

```bash
git status
```

Expected: `On branch watch-counting-ux-followups`, working tree는 세션 시작 시 있던
`WatchApp/Features/Round/Counting/Components/ModeButton.swift`의 미커밋 변경만 그대로 있고
그 외 clean.

---

## Task 1: `StrokeUndo` — 홀 인덱스별 저장소

**Files:**
- Modify: `WatchApp/Features/Round/StrokeUndo.swift`
- Test: `watchosTests/Round/StrokeUndoTests.swift`

**Interfaces:**
- Produces: `struct StrokeUndo`의 새 API —
  `func history(forHole hole: Int) -> [StrokeInputMode]`,
  `func canUndo(hole: Int) -> Bool`,
  `mutating func record(_ mode: StrokeInputMode, hole: Int)`,
  `mutating func pop(hole: Int) -> StrokeInputMode?`.
  기존 `history`(no-arg), `canUndo`(no-arg), `record(_:)`, `pop()`, `clear()`는 전부 제거된다 —
  Task 2에서 `RoundViewModel`이 새 시그니처로 갱신된다.

- [ ] **Step 1: 실패하는 테스트로 전체 교체**

`watchosTests/Round/StrokeUndoTests.swift`를 다음으로 교체한다:

```swift
@testable import GolfCounter_Watch_App
import Testing

struct StrokeUndoTests {
    @Test func 초기에는_되돌릴게_없다() {
        let undo = StrokeUndo()

        #expect(undo.canUndo(hole: 0) == false)
        #expect(undo.history(forHole: 0).isEmpty)
    }

    @Test func 기록하면_되돌릴게_생긴다() {
        var undo = StrokeUndo()

        undo.record(.swing, hole: 0)

        #expect(undo.canUndo(hole: 0))
        #expect(undo.history(forHole: 0) == [.swing])
    }

    @Test func pop은_마지막에_기록한_모드를_역순으로_돌려준다() {
        var undo = StrokeUndo()
        undo.record(.swing, hole: 0)
        undo.record(.putt, hole: 0)
        undo.record(.swing, hole: 0)

        #expect(undo.pop(hole: 0) == .swing)
        #expect(undo.pop(hole: 0) == .putt)
        #expect(undo.pop(hole: 0) == .swing)
        #expect(undo.canUndo(hole: 0) == false)
    }

    @Test func 비어있으면_pop은_nil이다() {
        var undo = StrokeUndo()

        #expect(undo.pop(hole: 0) == nil)
    }

    @Test func 존재하지_않는_홀도_되돌릴게_없다() {
        var undo = StrokeUndo()
        undo.record(.swing, hole: 0)

        #expect(undo.canUndo(hole: 3) == false)
        #expect(undo.history(forHole: 3).isEmpty)
        #expect(undo.pop(hole: 3) == nil)
    }

    @Test func 다른_홀의_기록은_서로_독립적이다() {
        var undo = StrokeUndo()
        undo.record(.swing, hole: 0)
        undo.record(.putt, hole: 1)

        #expect(undo.pop(hole: 1) == .putt)
        #expect(undo.canUndo(hole: 1) == false)
        #expect(undo.canUndo(hole: 0))
        #expect(undo.history(forHole: 0) == [.swing])
    }

    @Test func 한_홀을_모두_pop해도_다른_홀은_영향받지_않는다() {
        var undo = StrokeUndo()
        undo.record(.swing, hole: 0)
        undo.record(.putt, hole: 0)
        undo.record(.swing, hole: 5)

        _ = undo.pop(hole: 0)
        _ = undo.pop(hole: 0)

        #expect(undo.canUndo(hole: 0) == false)
        #expect(undo.canUndo(hole: 5))
    }
}
```

- [ ] **Step 2: 테스트가 컴파일 실패하는지 확인**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test -only-testing:watchosTests/StrokeUndoTests`

Expected: BUILD FAILED — `StrokeUndo`에 `canUndo(hole:)` 등 새 시그니처가 없다는 컴파일 에러.

- [ ] **Step 3: `StrokeUndo` 구현 교체**

`WatchApp/Features/Round/StrokeUndo.swift` 전체를 다음으로 교체한다:

```swift
import Foundation

/// 현재 홀에서 되돌릴 수 있는 입력 기록 (spec §7, 2026-08-17 개정 — 홀별 보관).
///
/// 되돌리기의 **의미**는 여전히 "지금 보는 홀의 마지막 입력만"으로 한정된다. 하지만 그
/// 기록의 **수명**은 라운드 전체다 — 홀을 옮겼다 돌아와도 그 홀에서 친 기록은 그대로
/// 남아 있어야 한다(실기 확인, 2026-08-17). `RoundViewModel`은 매 호출마다 현재 홀
/// 인덱스를 함께 넘긴다.
struct StrokeUndo: Equatable {
    private var historyByHole: [Int: [StrokeInputMode]] = [:]

    func history(forHole hole: Int) -> [StrokeInputMode] {
        historyByHole[hole] ?? []
    }

    func canUndo(hole: Int) -> Bool {
        !history(forHole: hole).isEmpty
    }

    mutating func record(_ mode: StrokeInputMode, hole: Int) {
        historyByHole[hole, default: []].append(mode)
    }

    mutating func pop(hole: Int) -> StrokeInputMode? {
        guard var history = historyByHole[hole], !history.isEmpty else { return nil }
        let mode = history.removeLast()
        historyByHole[hole] = history
        return mode
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test -only-testing:watchosTests/StrokeUndoTests`

Expected: `** TEST SUCCEEDED **`, `StrokeUndoTests`의 7개 테스트 전부 통과.

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/Round/StrokeUndo.swift watchosTests/Round/StrokeUndoTests.swift
git commit -m "♻️ refactor: StrokeUndo를 홀 인덱스별 저장소로 재구성"
```

---

## Task 2: `RoundViewModel` — undo 호출부를 홀 인덱스 기반으로 갱신

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift:110-112,227-238,310-316`
- Test: `watchosTests/Round/RoundViewModelUndoTests.swift`

**Interfaces:**
- Consumes: Task 1의 `StrokeUndo.canUndo(hole:)` / `record(_:hole:)` / `pop(hole:)`.
- Produces: `RoundViewModel.canUndo`(no-arg, 기존과 동일한 공개 시그니처 — 내부 구현만
  바뀐다), `undo()`(기존과 동일한 공개 시그니처).

- [ ] **Step 1: 실패하는 테스트 추가**

`watchosTests/Round/RoundViewModelUndoTests.swift`에서 기존 두 테스트
(`다음홀로_이동하면_되돌릴게_없다`, `이전홀로_이동하면_되돌릴게_없다`)는 **그대로 둔다** —
이동 직후의 홀은 기록이 없는 새 홀이라 이 두 assertion은 새 구현에서도 여전히 참이다.
버그 시나리오(기록이 있는 홀을 떠났다가 돌아왔을 때)를 검증하는 새 테스트를
`파를_고르는것은_되돌리기에_영향이_없다` 테스트 뒤, `되돌리면_스냅샷을_발행한다` 앞에
추가한다:

```swift
    /// 이 파일의 핵심 회귀 테스트 — 2026-08-17 실기 검토에서 발견된 버그.
    /// 홀 1에서 친 뒤 홀 2로 넘어갔다가 홀 1로 돌아오면, 홀 1의 되돌리기가 살아있어야 한다.
    @Test func 홀을_옮겼다_돌아오면_그_홀의_되돌리기_기록이_남아있다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.incrementStroke()
        viewModel.goToNextHole()
        viewModel.selectPar(3)

        viewModel.goToPreviousHole()

        #expect(viewModel.canUndo)

        viewModel.undo()

        #expect(viewModel.currentScore == 1)
    }

    /// 퍼팅으로 친 것까지 정확히 기억한다 — 종류 정보가 홀을 넘나들며 유실되지 않는다.
    @Test func 홀을_옮겼다_돌아와도_입력_종류를_정확히_기억한다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.inputMode = .putt
        viewModel.incrementStroke()
        viewModel.inputMode = .swing
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.incrementStroke()

        viewModel.goToPreviousHole()
        viewModel.undo()

        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
    }

    /// 두 홀을 오가며 각각 되돌리기를 확인해도 서로 섞이지 않는다.
    @Test func 여러_홀_사이를_오가도_각_홀의_되돌리기가_독립적으로_유지된다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.incrementStroke()
        viewModel.incrementStroke()

        viewModel.goToPreviousHole()
        #expect(viewModel.canUndo)
        viewModel.goToNextHole()
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.currentScore == 1)
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.canUndo == false)
    }
```

- [ ] **Step 2: 새 테스트가 실패하는지 확인**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test -only-testing:watchosTests/RoundViewModelUndoTests`

Expected: `홀을_옮겼다_돌아오면_그_홀의_되돌리기_기록이_남아있다`와 나머지 두 신규 테스트가
FAIL(`canUndo`가 `false`). 기존 테스트는 여전히 PASS.

- [ ] **Step 3: `RoundViewModel` 호출부 갱신**

`WatchApp/Features/Round/RoundViewModel.swift:110-112`의 `canUndo` 게터를 교체:

```swift
    var canUndo: Bool {
        undoStack.canUndo(hole: progress.currentHoleIndex)
    }
```

`WatchApp/Features/Round/RoundViewModel.swift:227-238`의 `incrementStroke()`/`undo()`를 교체:

```swift
    func incrementStroke() {
        undoStack.record(inputMode, hole: progress.currentHoleIndex)
        progress.apply(inputMode)
        publishSnapshot()
    }

    /// 현재 홀의 마지막 입력을 되돌린다. 입력의 정확한 역연산이다.
    func undo() {
        guard let mode = undoStack.pop(hole: progress.currentHoleIndex) else { return }
        progress.revert(mode)
        publishSnapshot()
    }
```

`WatchApp/Features/Round/RoundViewModel.swift:310-316`의 `resetHoleLocalState()`에서
undo clear를 제거하고 주석을 갱신:

```swift
    /// 홀을 옮기면 입력 모드는 스윙으로 리셋되고(spec §3), 진행 중이던 파 편집은 취소된다.
    /// 되돌리기 기록은 비우지 않는다 — 히스토리가 홀 인덱스별로 보관되므로 이 홀로 다시
    /// 돌아오면 그대로 살아난다(spec 2026-08-17 개정).
    private func resetHoleLocalState() {
        inputMode = .swing
        isEditingPar = false
    }
```

- [ ] **Step 4: 전체 undo 테스트 통과 확인**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test -only-testing:watchosTests/RoundViewModelUndoTests -only-testing:watchosTests/RoundViewModelHoleFlowTests -only-testing:watchosTests/RoundViewModelTests -only-testing:watchosTests/RoundViewModelSnapshotTests -only-testing:watchosTests/RoundViewModelTransmissionTests`

Expected: `** TEST SUCCEEDED **` — 새 테스트 3개 포함 전부 통과, 기존 홀 흐름·스냅샷·전송
테스트도 회귀 없음.

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/Round/RoundViewModel.swift watchosTests/Round/RoundViewModelUndoTests.swift
git commit -m "🐛 fix: 홀을 옮겨도 undo 기록이 유지되도록 수정"
```

---

## Task 3: 마지막 홀 `›` 자리를 종료 버튼으로 교체

**Files:**
- Modify: `WatchApp/Features/Round/Counting/CountingView.swift`
- Modify: `WatchApp/Features/Round/ScoringView.swift`
- Modify: `WatchApp/Features/Round/RoundSessionView.swift:82-89`(`centerPage`)

**Interfaces:**
- Consumes: `RoundViewModel.canGoToNextHole`(기존), `RoundSessionView`의 기존
  `@State private var isConfirmingEnd`와 그 위에 걸린 `confirmationDialog`(제목·문구·
  `endRound()` 그대로 재사용, 수정 없음).
- Produces: `CountingView`에 `onRequestEnd: () -> Void` 신규 파라미터. `ScoringView`에
  `onRequestEnd: () -> Void` 신규 파라미터(그대로 통과).

View는 테스트하지 않는 컨벤션(`CLAUDE.md`)이라 이 태스크는 자동 테스트가 없다 — 빌드 성공과
시뮬레이터 실기 확인으로 검증한다.

- [ ] **Step 1: `CountingView`에 `onRequestEnd` 추가하고 마지막 홀 분기**

`WatchApp/Features/Round/Counting/CountingView.swift`의 프로퍼티 선언부(`let sizing: CountingSizing`
바로 아래)에 추가:

```swift
    let onRequestEnd: () -> Void
```

`goToNextHoleOrConfirm()`을 다음으로 교체(더 이상 `canGoToNextHole` 가드가 필요 없다 — 이
함수는 이제 그 값이 참일 때만 연결된다):

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

`ringArea`의 `HoleArrowButton(systemName: "chevron.right", ...)` 블록을 다음으로 교체:

```swift
                if viewModel.canGoToNextHole {
                    HoleArrowButton(systemName: "chevron.right",
                                    size: sizing.arrowSize,
                                    action: goToNextHoleOrConfirm)
                } else {
                    HoleArrowButton(systemName: "flag.checkered",
                                    size: sizing.arrowSize,
                                    action: onRequestEnd)
                }
```

파일 하단 `#Preview`를 갱신:

```swift
#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CountingView(viewModel: viewModel, sizing: .regular, onRequestEnd: {})
}
```

- [ ] **Step 2: `ScoringView`에 `onRequestEnd` 통과**

`WatchApp/Features/Round/ScoringView.swift`의 `@ObservedObject var viewModel: RoundViewModel`
바로 아래에 추가:

```swift
    let onRequestEnd: () -> Void
```

`ViewThatFits` 안 세 개의 `CountingView` 생성부 각각에 `onRequestEnd: onRequestEnd`를 추가:

```swift
            ViewThatFits(in: [.horizontal, .vertical]) {
                CountingView(viewModel: viewModel, sizing: .regular, onRequestEnd: onRequestEnd)
                CountingView(viewModel: viewModel, sizing: .compact, onRequestEnd: onRequestEnd)
                CountingView(viewModel: viewModel, sizing: .tight, onRequestEnd: onRequestEnd)
            }
            .tag(0)
```

파일 하단 `#Preview`를 갱신:

```swift
#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return ScoringView(viewModel: viewModel, onRequestEnd: {})
}
```

- [ ] **Step 3: `RoundSessionView.centerPage`에서 종료 콜백 연결**

`WatchApp/Features/Round/RoundSessionView.swift:82-89`의 `centerPage`를 교체:

```swift
    @ViewBuilder
    private var centerPage: some View {
        switch viewModel.phase {
        case .parSelection:
            ParSelectionView(viewModel: viewModel)
        case .counting, .summary:
            ScoringView(viewModel: viewModel, onRequestEnd: { isConfirmingEnd = true })
        }
    }
```

- [ ] **Step 4: 빌드 확인**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: 기존 테스트 회귀 확인**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test -only-testing:watchosTests/RoundViewModelHoleFlowTests`

Expected: `** TEST SUCCEEDED **` — `건너뛰기_마지막홀에서는_아무일도_없다` 등 마지막 홀 관련
ViewModel 테스트는 뷰를 거치지 않으므로 영향 없이 통과해야 한다.

- [ ] **Step 6: 시뮬레이터 실기 확인**

`mcp__Claude_Code_iOS_Simulator__control`(attach → build 결과 앱을 launch)로 워치 시뮬레이터에서
1홀짜리 라운드(`holeCount: 1`은 코드 경로 확인용이므로 실제로는 9홀로 시작해 9번 홀까지
넘겨서)를 진행해 마지막 홀에서 `›` 자리에 깃발(`flag.checkered`) 아이콘이 뜨고, 누르면 기존
종료 확인 다이얼로그가 뜨는지 확인한다. 46mm와 40mm(SE 3) 두 기기에서 모두 확인한다 —
`CountingSizing.regular`/`.tight` 두 세트에서 아이콘이 잘리지 않는지가 핵심이다.

- [ ] **Step 7: 커밋**

```bash
git add WatchApp/Features/Round/Counting/CountingView.swift WatchApp/Features/Round/ScoringView.swift WatchApp/Features/Round/RoundSessionView.swift
git commit -m "🐛 fix: 마지막 홀에서 죽어있던 › 버튼을 종료 진입점으로 교체"
```

---

## Task 4: 요약 화면 재구성 — 총타수 중심 레이아웃, 가로 2등분 버튼

**Files:**
- Modify: `WatchApp/Features/Round/Summary/SummaryView.swift`
- Modify: `WatchApp/ko.lproj/Localizable.strings`
- Modify: `WatchApp/en.lproj/Localizable.strings`
- Test: `watchosTests/Localization/StringsParityTests.swift`(수정 없음 — 기존 테스트가 새
  키를 그대로 검증한다)

**Interfaces:**
- Consumes: `RoundViewModel.trimmedTotalStrokes` / `.trimmedTotalPutts` /
  `.trimmedRelativeToPar` / `.recordedHoleCount` / `.isTransmitting` / `.saveAndTransmit()` /
  `.discardRound()`(전부 기존, 시그니처 변경 없음), `ScoreFormat.relativeToPar(_:) -> String`(기존).

View는 테스트하지 않으므로 이 태스크의 검증은 문자열 파리티 테스트 + 빌드 + 시뮬레이터
실기 확인이다.

- [ ] **Step 1: Localizable.strings 갱신 (ko)**

`WatchApp/ko.lproj/Localizable.strings`의 `/* Summary */` 블록(28~36행)을 교체:

```
/* Summary */
"summary_holes_empty" = "기록된 홀 없음";
"summary_holes_putts" = "%lld홀 · %lld퍼트";
"summary_discard_button" = "버리기";
"summary_discard_title" = "이 라운드를 저장하지 않고 버릴까요?";
"summary_discard_confirm" = "버리기";
"summary_transmitting" = "전송 중…";
"summary_save" = "저장";
```

- [ ] **Step 2: Localizable.strings 갱신 (en)**

`WatchApp/en.lproj/Localizable.strings`의 `/* Summary */` 블록(29~37행)을 교체:

```
/* Summary */
"summary_holes_empty" = "No holes recorded";
"summary_holes_putts" = "%lld holes · %lld putts";
"summary_discard_button" = "Discard";
"summary_discard_title" = "Discard this round without saving?";
"summary_discard_confirm" = "Discard";
"summary_transmitting" = "Sending…";
"summary_save" = "Save";
```

- [ ] **Step 3: 파리티 테스트로 두 파일이 아직 어긋나지 않았는지 확인**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test -only-testing:watchosTests/StringsParityTests`

Expected: `** TEST SUCCEEDED **` — 키 집합·포맷 지정자 모두 일치(둘 다 같은 블록을 같은
모양으로 고쳤으므로).

- [ ] **Step 4: `SummaryView` 재작성**

`WatchApp/Features/Round/Summary/SummaryView.swift` 전체를 다음으로 교체:

```swift
import SwiftUI

/// 종료 요약 — 총타수(주인공) · 오버파 배지 · 홀/퍼트 · 저장/버리기 (spec 2026-08-17 개정).
///
/// 총타수·오버파·퍼트는 **트림 후** 기준이다. 워크아웃 메트릭은 여기 띄우지 않고 전송
/// 페이로드에만 싣는다 — iOS 상세 화면이 같은 정보를 보여준다.
struct SummaryView: View {
    @ObservedObject var viewModel: RoundViewModel

    /// 폐기는 되돌릴 수 없다(스냅샷까지 지운다) — 확인을 한 번 받는다.
    @State private var isConfirmingDiscard = false

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            if viewModel.recordedHoleCount > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(viewModel.trimmedTotalStrokes)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text(ScoreFormat.relativeToPar(viewModel.trimmedRelativeToPar))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(String(format: String(localized: "summary_holes_putts"),
                            viewModel.recordedHoleCount,
                            viewModel.trimmedTotalPutts))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "summary_holes_empty"))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            buttons
        }
        .padding(.horizontal, 8)
        .confirmationDialog(String(localized: "summary_discard_title"),
                            isPresented: $isConfirmingDiscard,
                            titleVisibility: .visible)
        {
            Button(String(localized: "summary_discard_confirm"), role: .destructive, action: viewModel.discardRound)
            Button(String(localized: "common_cancel"), role: .cancel) {}
        }
    }

    /// 0홀·전송 중에는 저장 버튼 하나가 전폭을 차지한다. 그 외에는 버리기/저장 가로 2등분.
    @ViewBuilder
    private var buttons: some View {
        if viewModel.recordedHoleCount == 0 {
            primaryButton(label: String(localized: "round_end_confirm_empty"))
        } else if viewModel.isTransmitting {
            primaryButton(label: String(localized: "summary_transmitting"))
        } else {
            HStack(spacing: 8) {
                Button(action: { isConfirmingDiscard = true }) {
                    Text(String(localized: "summary_discard_button"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.bordered)

                Button(action: viewModel.saveAndTransmit) {
                    Text(String(localized: "summary_save"))
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }

    private func primaryButton(label: String) -> some View {
        Button(action: viewModel.saveAndTransmit) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    viewModel.finishRound()
    return SummaryView(viewModel: viewModel)
}
```

- [ ] **Step 5: 빌드 확인**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`

Expected: `** BUILD SUCCEEDED **`. (`viewModel.courseName` 표시 블록 제거로 더 이상 참조하지
않지만, 프로퍼티 자체는 `RoundViewModel`에 남아 있으므로 다른 참조는 영향 없다.)

- [ ] **Step 6: 시뮬레이터 실기 확인**

`mcp__Claude_Code_iOS_Simulator__control`으로 46mm·40mm 두 기기에서 각각:
1. 정상 라운드를 몇 홀 진행하고 종료 → 요약에 총타수가 크게, 오버파가 옆에, "N홀 · N퍼트"가
   아래에 뜨는지. 버튼이 "버리기"/"저장" 가로 2등분으로 보이고 둘 다 눌리는 느낌(테두리·배경)이
   있는지.
2. 0홀(시작하자마자 종료) → 안내 문구 한 줄 + "저장 없이 종료" 전폭 버튼 하나만 뜨는지.
3. "저장" 탭 직후 워크아웃 메트릭 도착 전 짧게 "전송 중…" 전폭 버튼으로 바뀌는지(타이밍이
   빠르면 눈으로 못 잡을 수 있다 — 코드 리뷰로 대체 가능).

- [ ] **Step 7: 커밋**

```bash
git add WatchApp/Features/Round/Summary/SummaryView.swift WatchApp/ko.lproj/Localizable.strings WatchApp/en.lproj/Localizable.strings
git commit -m "✨ feat: 요약 화면을 총타수 중심 + 가로 2등분 버튼으로 재구성"
```

---

## Task 5: 전체 검증 및 PR

**Files:** 없음(검증 + git 조작만).

- [ ] **Step 1: lint**

Run: `make lint`

Expected: 에러 없음. 있으면 `make fix`로 자동 수정 가능한 것만 고치고 재실행.

- [ ] **Step 2: format 검사**

Run: `make format`

Expected: 에러 없음.

- [ ] **Step 3: 워치 테스트 스위트 전체**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test`

Expected: `** TEST SUCCEEDED **` — 전체 스위트 회귀 없음.

- [ ] **Step 4: 워치 빌드**

Run: `xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: 세션 시작 시 있던 미커밋 변경(`ModeButton.swift`) 처리**

이 플랜과 무관한 변경이다(`figure.golf` 아이콘 대체 아이콘 교체, 세션 시작 전부터 존재).
`git status`로 여전히 unstaged인지 확인하고, 사용자에게 이 브랜치에 포함할지 별도로 물어본다
— 임의로 커밋하거나 버리지 않는다.

- [ ] **Step 6: 푸시 및 PR 생성**

```bash
git push -u origin watch-counting-ux-followups
gh pr create --title "카운팅 화면 UX 후속 정리" --body "$(cat <<'EOF'
## Summary
- undo 히스토리를 홀 인덱스별로 보관해, 홀을 옮겼다 돌아와도 되돌리기가 유지되도록 수정
- 마지막 홀의 죽어있던 `›` 버튼을 종료 진입점(깃발 아이콘)으로 교체
- 요약 화면을 총타수 중심 레이아웃 + 가로 2등분 실버튼("버리기"/"저장")으로 재구성

## Test plan
- [x] `StrokeUndoTests`, `RoundViewModelUndoTests`, `RoundViewModelHoleFlowTests` 등 워치 테스트 스위트 통과
- [x] `StringsParityTests` 통과 (ko/en 키·포맷 지정자 일치)
- [ ] 46mm·40mm 시뮬레이터 실기: 홀 이동 후 undo 유지, 마지막 홀 종료 버튼, 요약 화면 3가지 상태(정상/0홀/전송 중) 확인

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL 출력. `docs/superpowers/specs/2026-08-17-watch-counting-ux-followups-design.md`는
이미 `main`에 직접 커밋되어 있으므로 이 PR diff에는 포함되지 않는다.
