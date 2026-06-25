# Set Score Transfer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Watch 앱 ScoreView에서 SetScores 알약을 롱프레스해 세트 귀속을 이전(수정)할 수 있는 기능 추가

**Architecture:** ScoreViewModel에 `transferSet(to:)` 추가 → SetScores 컴포넌트에 편집 모드 UI(롱프레스·chevron·scaleEffect·타임아웃) 추가 → ScoreView에서 편집 상태 관리 및 투명 레이어로 PlayerPointButton 탭 차단

**Tech Stack:** SwiftUI, WatchKit (haptic), Swift Testing, Swift async/await (타임아웃)

**Spec:** `docs/superpowers/specs/watch/2026-06-11-set-score-transfer-design.md`

---

## 파일 구조

| 파일 | 변경 유형 | 책임 |
|---|---|---|
| `WatchApp/Features/Match/Score/ScoreViewModel.swift` | Modify | `transferSet(to:)` 메서드 추가 |
| `WatchApp/Features/Match/Score/Components/SetScores.swift` | Rewrite | 편집 모드 UI (롱프레스, chevron, scaleEffect, 타임아웃) |
| `WatchApp/Features/Match/Score/ScoreView.swift` | Modify | `isSetEditing` 상태, SetScores 콜백 연결, 투명 탭 차단 레이어 |
| `watchosTests/Match/ScoreViewModelTests.swift` | Modify | `transferSet` 테스트 추가 |

---

## Task 1: ScoreViewModel — transferSet 추가 (TDD)

**Files:**
- Modify: `watchosTests/Match/ScoreViewModelTests.swift`
- Modify: `WatchApp/Features/Match/Score/ScoreViewModel.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Match/ScoreViewModelTests.swift`의 `ScoreViewModelTests` struct 닫는 `}` 바로 앞에 아래 테스트 4개를 추가한다.

```swift
@Test @MainActor func transferSet_toMe_movesSetFromOpponent() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false))
    vm.mySetScore = 0
    vm.yourSetScore = 1
    vm.transferSet(to: .me)
    #expect(vm.mySetScore == 1)
    #expect(vm.yourSetScore == 0)
}

@Test @MainActor func transferSet_toOpponent_movesSetFromMe() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false))
    vm.mySetScore = 1
    vm.yourSetScore = 0
    vm.transferSet(to: .opponent)
    #expect(vm.mySetScore == 0)
    #expect(vm.yourSetScore == 1)
}

@Test @MainActor func transferSet_toMe_whenOpponentHasNoSets_doesNothing() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false))
    vm.mySetScore = 1
    vm.yourSetScore = 0
    vm.transferSet(to: .me)
    #expect(vm.mySetScore == 1)
    #expect(vm.yourSetScore == 0)
}

@Test @MainActor func transferSet_toOpponent_whenMySetIsZero_doesNothing() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: false))
    vm.mySetScore = 0
    vm.yourSetScore = 1
    vm.transferSet(to: .opponent)
    #expect(vm.mySetScore == 0)
    #expect(vm.yourSetScore == 1)
}
```

- [ ] **Step 2: 테스트 실행 — 빌드 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1' \
  2>&1 | grep -E "error:|transferSet"
```

Expected: `error: value of type 'ScoreViewModel' has no member 'transferSet'`

- [ ] **Step 3: transferSet 구현**

`WatchApp/Features/Match/Score/ScoreViewModel.swift`에서 `func undo()` 아래에 추가:

```swift
func transferSet(to side: PlayerSide) {
    switch side {
    case .me:
        guard yourSetScore > 0 else { return }
        yourSetScore -= 1
        mySetScore += 1
    case .opponent:
        guard mySetScore > 0 else { return }
        mySetScore -= 1
        yourSetScore += 1
    }
    sendScoreState()
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1' \
  2>&1 | grep -E "Test run|passed|failed|transferSet"
```

Expected: 신규 테스트 4개 포함 전체 통과

- [ ] **Step 5: 커밋**

```bash
git add watchosTests/Match/ScoreViewModelTests.swift \
        WatchApp/Features/Match/Score/ScoreViewModel.swift
git commit -m "feat(watch): add transferSet(to:) to ScoreViewModel"
```

---

## Task 2: SetScores — 편집 모드 UI

**Files:**
- Rewrite: `WatchApp/Features/Match/Score/Components/SetScores.swift`

- [ ] **Step 1: SetScores 전체 교체**

파일 전체를 아래 내용으로 교체한다.

```swift
import SwiftUI
import WatchKit

struct SetScores: View {
    let mySetScore: Int
    let yourSetScore: Int
    @Binding var isEditing: Bool
    let onTransfer: (PlayerSide) -> Void

    @State private var timeoutTask: Task<Void, Never>?

    var body: some View {
        if mySetScore > 0 || yourSetScore > 0 {
            HStack(spacing: 6) {
                if isEditing {
                    Button {
                        onTransfer(.me)
                        resetTimeout()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .opacity(yourSetScore == 0 ? 0.2 : 1.0)
                    .disabled(yourSetScore == 0)
                }

                HStack(spacing: 4) {
                    Text("\(mySetScore)")
                        .foregroundColor(.green.opacity(0.8))
                    Text(String(localized: "watch_set_label"))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(yourSetScore)")
                        .foregroundColor(.orange.opacity(0.8))
                }
                .font(.system(size: 16, weight: .bold))

                if isEditing {
                    Button {
                        onTransfer(.opponent)
                        resetTimeout()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .opacity(mySetScore == 0 ? 0.2 : 1.0)
                    .disabled(mySetScore == 0)
                }
            }
            .scaleEffect(isEditing ? 1.12 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isEditing)
            .onLongPressGesture(minimumDuration: 0.5) {
                WKInterfaceDevice.current().play(.click)
                isEditing = true
                resetTimeout()
            }
        }
    }

    private func resetTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isEditing = false }
        }
    }
}

#Preview {
    @Previewable @State var isEditing = false
    SetScores(mySetScore: 1, yourSetScore: 0, isEditing: $isEditing, onTransfer: { _ in })
}
```

> **Note:** SetScores의 인터페이스가 바뀌었으므로 ScoreView가 일시적으로 빌드 실패한다. Task 3에서 즉시 수정한다.

---

## Task 3: ScoreView — 편집 상태 연결 + 탭 차단 레이어

**Files:**
- Modify: `WatchApp/Features/Match/Score/ScoreView.swift`

- [ ] **Step 1: isSetEditing 상태 추가**

`@State private var showExitConfirm = false` 아래 줄에 추가:

```swift
@State private var isSetEditing = false
```

- [ ] **Step 2: ZStack에 탭 차단 레이어 추가**

`ScoreView.swift`의 ZStack 내부, `HStack(spacing: 0)` 블록과 `GeometryReader` 블록 사이에 아래 코드를 추가한다.

```swift
if isSetEditing {
    Color.clear
        .contentShape(Rectangle())
        .onTapGesture { isSetEditing = false }
        .ignoresSafeArea()
}
```

- [ ] **Step 3: SetScores 호출부 수정**

`ScoreView.swift`에서 기존:

```swift
SetScores(
    mySetScore: viewModel.mySetScore,
    yourSetScore: viewModel.yourSetScore
)
```

를 아래로 교체한다:

```swift
SetScores(
    mySetScore: viewModel.mySetScore,
    yourSetScore: viewModel.yourSetScore,
    isEditing: $isSetEditing,
    onTransfer: { viewModel.transferSet(to: $0) }
)
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: 테스트 전체 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1' \
  2>&1 | grep -E "Test run|passed|failed"
```

Expected: 전체 통과

- [ ] **Step 6: 커밋**

```bash
git add WatchApp/Features/Match/Score/Components/SetScores.swift \
        WatchApp/Features/Match/Score/ScoreView.swift
git commit -m "feat(watch): set score transfer UI with long press on SetScores pill"
```
