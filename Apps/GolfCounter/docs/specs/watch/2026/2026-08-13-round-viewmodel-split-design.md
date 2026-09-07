# RoundViewModel 분리 설계 (상태 소유권)

- 작성일: 2026-08-13
- 참조: `2026-07-31-golfcounter-rebuild-design.md` §3, `2026-08-13-watch-folder-structure-design.md` §9(후속 작업 ①), 미구현 플랜 ④ `2026-08-05-watch-round-transmission.md`
- 범위: `WatchApp/Features/Round/RoundViewModel.swift`의 내부 상태를 두 순수 타입으로 추출. **동작 변경 0.**
- 선행: 폴더 구조 개편(③-c) 완료. 이 설계의 파일 경로는 개편 후 구조를 전제한다.

## 1. 문제

`RoundViewModel`(237줄) 하나에 성격이 다른 세 축이 섞여 있다.

| 축 | 상태 | 성격 |
|----|------|------|
| 홀 진행 기록 | `holeScores`·`holePars`·`puttCounts`·`currentHoleIndex` | 라운드에 무엇이 기록됐나 |
| 되돌리기 세션 | `strokeHistory` | 현재 홀에서 취소할 수 있는 것. 홀이 바뀌면 리셋되는 별개 생명주기 |
| 화면 전환 판단 | `isEditingPar` → `phase` | 위 축들의 값을 조합해 파생 |

섞임의 실질적 비용은 **테스트 불가능성**이다. 용량 확장(`ensureCapacityForCurrentHole`)과 phantom hole 판정(`isPristinePhantomHole`)은 `private`이라 `RoundViewModel`의 공개 API를 우회해서만 간접 검증된다.

플랜 ④가 여기에 `id`·`holeCount`(홀 수 상한)·`isFinished`·`transmitter`·`finishRound()`·`save(endedAt:metrics:)`·`trimmedSnapshot` 등을 더해 350줄+가 된다. **지금이 가장 작을 때 나눈다.**

## 2. 원칙

- **파사드 유지.** `RoundViewModel`이 유일한 `ObservableObject`로 남는다. 추출된 타입은 내부 구현 세부사항이며 View는 그 존재를 모른다.
- **동작 변경 0.** 로직은 현재 코드를 그대로 옮긴다. 새로 쓰지 않는다.
- **기존 테스트 무변경.** 4개 테스트 파일(37건)은 `currentScore`·`canUndo` 같은 공개 API로만 검증하고 내부 배열을 직접 읽지 않는다(확인 완료) — 파사드 뒤로 숨겨도 전부 그대로 통과해야 한다.
- 추출 타입은 `struct` + `mutating` 메서드. UI 프레임워크를 import하지 않는다.

### 파사드를 유지하는 이유

"책임이 섞여있다"는 `RoundViewModel.swift` **내부 구현**의 문제이지 View가 보는 **인터페이스**의 문제가 아니다. View가 조각을 직접 참조하는 대안은 세 가지 문제를 낳는다.

1. `incrementStroke()`는 되돌리기 기록과 홀 배열을 **동시에** 건드린다. View가 조각을 따로 들면 이 조합을 View가 하게 되어 "ViewModel은 순수 로직, View는 UI" 규칙을 깬다.
2. SwiftUI 변경 감지를 받으려면 조각이 각자 `class`여야 하고, 소유권·초기화 순서가 복잡해진다.
3. 하위 컴포넌트(`HoleHeader`·`HoleNavigation` 등)는 이미 필요한 값만 프로퍼티로 받는다. `RoundViewModel`을 직접 쥐는 것은 화면급 컨테이너뿐이라 **View 계층 캡슐화는 이미 되어 있다.**

## 3. 새 타입

### HoleProgress (`WatchApp/Features/Round/HoleProgress.swift`)

"라운드에 무엇이 기록됐나". 병렬 배열 3개의 길이 불변식(항상 같은 길이)을 이 타입이 책임진다.

```swift
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

    /// 스냅샷 복구용. 길이가 어긋난 값이 들어와도 현재 홀까지 용량을 맞춘다.
    init(holeScores: [Int], holePars: [Int], puttCounts: [Int], currentHoleIndex: Int) {
        self.holeScores = holeScores
        self.holePars = holePars
        self.puttCounts = puttCounts
        self.currentHoleIndex = max(currentHoleIndex, 0)
        ensureCapacityForCurrentHole()
    }

    var currentHoleNumber: Int { currentHoleIndex + 1 }
    var currentScore: Int { holeScores[currentHoleIndex] }
    var currentPutts: Int { puttCounts[currentHoleIndex] }
    /// 0은 "아직 파가 설정되지 않음"을 뜻한다.
    var currentPar: Int { holePars[currentHoleIndex] }
    var canGoToPreviousHole: Bool { currentHoleIndex > 0 }

    /// 현재 홀이 "방금 만들어졌고 아직 아무것도 입력되지 않은" 상태인지.
    /// 세 배열의 마지막 원소가 현재 홀과 정확히 일치할 때만 안전하게 pop할 수 있다.
    /// isEditingPar 조건은 여기 없다 — 그것은 RoundViewModel 소유이므로 호출부가 판단한다.
    var isPristinePhantomHole: Bool {
        currentScore == 0 && currentPar == 0 && currentPutts == 0
            && currentHoleIndex == holeScores.count - 1
            && currentHoleIndex == holePars.count - 1
            && currentHoleIndex == puttCounts.count - 1
    }

    mutating func apply(_ mode: StrokeInputMode) {
        switch mode {
        case .swing:
            holeScores[currentHoleIndex] += 1
        case .putt:
            holeScores[currentHoleIndex] += 1
            puttCounts[currentHoleIndex] += 1
        }
    }

    /// apply의 정확한 역연산.
    mutating func revert(_ mode: StrokeInputMode) {
        holeScores[currentHoleIndex] -= 1
        if mode == .putt {
            puttCounts[currentHoleIndex] -= 1
        }
    }

    mutating func setPar(_ par: Int) {
        holePars[currentHoleIndex] = par
    }

    mutating func advanceToNextHole() {
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
    }

    mutating func retreatToPreviousHole() {
        currentHoleIndex -= 1
    }

    /// phantom hole을 배열에서 제거하고 이전 홀로 돌아간다. 호출 전 isPristinePhantomHole 확인 필수.
    mutating func removePhantomHoleAndRetreat() {
        holeScores.removeLast()
        holePars.removeLast()
        puttCounts.removeLast()
        currentHoleIndex -= 1
    }

    /// 홀 배열 세 개의 길이를 현재 홀까지 맞춘다. 세 배열은 항상 같은 길이를 유지한다.
    private mutating func ensureCapacityForCurrentHole() {
        let needed = currentHoleIndex + 1
        while holeScores.count < needed { holeScores.append(0) }
        while holePars.count < needed { holePars.append(0) }
        while puttCounts.count < needed { puttCounts.append(0) }
    }
}
```

### StrokeUndo (`WatchApp/Features/Round/StrokeUndo.swift`)

"현재 홀에서 되돌릴 수 있는 것". 되돌리기 스코프가 현재 홀이라는 규칙(spec §7)이 이 타입의 생명주기로 표현된다.

```swift
struct StrokeUndo: Equatable {
    /// 현재 홀에서 친 타의 종류 순서. 되돌리기의 유일한 상태다 (spec §7).
    ///
    /// incrementStroke()가 하는 일이 모드에 따라 (타수 +1) 또는 (타수 +1, 퍼트 +1)
    /// 두 가지뿐이므로, 어느 쪽이었는지만 알면 정확히 되돌릴 수 있다.
    private(set) var history: [StrokeInputMode] = []

    var canUndo: Bool { !history.isEmpty }

    mutating func record(_ mode: StrokeInputMode) { history.append(mode) }
    mutating func pop() -> StrokeInputMode? { history.popLast() }
    mutating func clear() { history.removeAll() }
}
```

## 4. RoundViewModel 축소본

237줄 → 약 150줄. 표시값은 전부 위임하고, 조정(두 조각의 조합)·`phase`·발행만 남는다.

```swift
@MainActor
final class RoundViewModel: ObservableObject {
    enum Phase: Equatable {
        case parSelection
        case counting
    }

    @Published private var progress = HoleProgress()
    @Published private var undoStack = StrokeUndo()
    @Published var inputMode: StrokeInputMode = .swing
    @Published private(set) var isEditingPar = false

    let startedAt: Date
    var courseName: String?
    private let publisher: RoundSnapshotPublishing

    // MARK: - 표시값

    var currentHoleNumber: Int { progress.currentHoleNumber }
    var currentScore: Int { progress.currentScore }
    var currentPutts: Int { progress.currentPutts }
    var currentPar: Int { progress.currentPar }
    var canGoToPreviousHole: Bool { progress.canGoToPreviousHole }
    var canUndo: Bool { undoStack.canUndo }
    var totalStrokes: Int { snapshot.totalStrokes }
    var relativeToPar: Int { snapshot.relativeToPar }

    var phase: Phase {
        if isEditingPar { return .parSelection }
        return currentPar == 0 ? .parSelection : .counting
    }

    var snapshot: RoundSnapshot {
        RoundSnapshot(startedAt: startedAt,
                      courseName: courseName,
                      currentHoleIndex: progress.currentHoleIndex,
                      holeScores: progress.holeScores,
                      holePars: progress.holePars,
                      puttCounts: progress.puttCounts)
    }

    // MARK: - 카운터

    func incrementStroke() {
        undoStack.record(inputMode)
        progress.apply(inputMode)
        publishSnapshot()
    }

    func undo() {
        guard let mode = undoStack.pop() else { return }
        progress.revert(mode)
        publishSnapshot()
    }

    // MARK: - 홀 이동

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

    private func resetHoleLocalState() {
        inputMode = .swing
        isEditingPar = false
        undoStack.clear()
    }
}
```

### 저장 프로퍼티 이름이 `undoStack`인 이유

메서드 `undo()`와 저장 프로퍼티 `undo`가 같은 이름이면 `undo.pop()`이 모호해진다. 프로퍼티를 `undoStack`으로 두면 **메서드명 `undo()`가 유지되어 View 호출부(`CountingView`)와 `RoundViewModelUndoTests` 11건이 전부 무변경**이다. 반대로 메서드를 `undoLastStroke()`로 바꾸면 순수 리팩터링 diff에 이름 변경이 섞인다.

### isPristinePhantomHole에서 isEditingPar가 빠지는 것

현재 판정 안에 `!isEditingPar`가 포함되어 있으나, `isEditingPar`는 `RoundViewModel` 소유라 `HoleProgress`가 알 수 없다. 호출부 `cancelToPreviousHole()`의 guard로 옮긴다 — **동작은 완전히 동일**하고(`guard !isEditingPar, progress.isPristinePhantomHole`), "기록 상태 판정"과 "편집 중 여부"가 분리되어 각각 명확해진다.

## 5. 파일 배치

폴더 개편(③-c) 이후 구조 기준. 두 타입 모두 UI를 모르는 순수 로직이고 Round 기능 전용이므로 `RoundViewModel` 옆에 둔다.

```
WatchApp/Features/Round/
├── RoundSessionView.swift
├── RoundViewModel.swift        237줄 → 약 150줄
├── HoleProgress.swift          ← 신규 (약 75줄)
├── StrokeUndo.swift            ← 신규 (약 20줄)
├── ScoringView.swift
├── Counting/ · Scorecard/ · ParSelection/ · SessionControls/ · SessionMetrics/
```

`Shared/Models/`로 올리지 않는다 — iOS는 `GolfRound`(SwiftData)로 완성된 라운드만 다루고 진행 중 홀 이동·되돌리기 개념이 없다. 실제 사용처가 생기면 그때 승격한다.

## 6. 테스트

**기존 4개 파일(37건)은 무변경.** `RoundViewModelTests`·`RoundViewModelHoleFlowTests`·`RoundViewModelUndoTests`·`RoundViewModelSnapshotTests` 전부 공개 API로만 검증하므로 그대로 통과해야 한다. 통과하지 못하면 동작이 바뀐 것이다.

**신규 2개 파일.** 지금까지 `private`이라 간접 검증만 되던 로직을 직접 테스트한다 — 이것이 분리의 실질적 이득이다.

`watchosTests/Round/HoleProgressTests.swift`:
- 초기 상태는 1홀·전부 0
- `apply(.swing)`은 타수만, `apply(.putt)`은 타수와 퍼트를 함께 올린다
- `revert`는 `apply`의 역연산이다 (스윙/퍼팅 각각)
- `advanceToNextHole()`은 세 배열 길이를 함께 늘린다
- 길이가 어긋난 배열로 init하면 현재 홀까지 용량이 채워진다
- 새 홀은 `isPristinePhantomHole`이 참, 타수를 넣으면 거짓
- 파만 설정해도 `isPristinePhantomHole`이 거짓
- `removePhantomHoleAndRetreat()`은 세 배열에서 마지막을 제거하고 인덱스를 되돌린다
- 첫 홀에서 `canGoToPreviousHole`이 거짓

`watchosTests/Round/StrokeUndoTests.swift`:
- 초기에는 `canUndo`가 거짓
- `record` 후 `canUndo`가 참
- `pop`은 마지막에 기록한 모드를 역순으로 돌려준다
- 비어 있을 때 `pop`은 nil
- `clear` 후 `canUndo`가 거짓

## 7. 검증

동작 변경이 없으므로 아래가 완료 조건이다.

1. 기존 watchosTests 37건 **무변경 통과**
2. 신규 `HoleProgressTests`·`StrokeUndoTests` 통과
3. `make lint` / `make format` 위반 0
4. iOS·ComplicationAppExtension 빌드 통과 (WatchApp 그룹을 링크하지 않아 애초에 영향 없어야 정상)

## 8. 플랜 ④와의 관계

이 분리가 끝난 뒤 플랜 ④를 재작성한다. 추가되는 상태의 귀속은 다음과 같다.

| 플랜 ④ 추가분 | 귀속 |
|---------------|------|
| `holeCount`(홀 수 상한), `canGoToNextHole` 상한 검사 | `HoleProgress` — 배열 길이·인덱스 관리가 이미 이 타입 책임이다 |
| `id`, `isFinished`, `phase.summary` | `RoundViewModel` |
| `transmitter`, `finishRound()`, `save(endedAt:metrics:)` | `RoundViewModel` |
| `trimmedSnapshot`, `recordedHoleCount` 등 파생값 | `RoundViewModel` (트림 자체는 `RoundSnapshot`의 메서드) |

종료·전송을 별도 타입으로 더 쪼개는 것은 지금 범위 밖이다 — 플랜 ④ 기준으로도 `finishRound()`는 1줄, `save()`는 4줄이라 타입 하나를 만들 분량이 아니다. 플랜 ④ 구현 중 실제로 커지면 그때 뗀다.
