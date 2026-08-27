# 파 선택 화면 레이아웃 재설계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ParSelectionView`가 작은 워치에서 잘리지 않게 세 par 버튼을 `ScrollView`에 담고, 하단 전폭 "이전" 버튼을 헤더 라인의 원형 버튼으로 올린다.

**Architecture:** 세로 고정 요구량 210pt → `헤더 30 + 스크롤 콘텐츠 150`. 초과분은 `ScrollView`가 스크롤로 흡수하므로 기기별 크기 세트(`ViewThatFits`)가 필요 없다. 백버튼은 카운터 화면과 공유하는 `CircleIconButton`으로 통일하고, 재편집 경로에서는 홀을 옮기지 않고 편집만 닫는 새 ViewModel 메서드로 간다.

**Tech Stack:** SwiftUI (watchOS 10+), Swift Testing, SwiftLint / SwiftFormat

설계 근거: `docs/superpowers/specs/2026-08-16-watch-par-selection-layout-design.md`

## Global Constraints

- 타깃 최소 버전은 watchOS 10+. `.scrollBounceBehavior(.basedOnSize)`는 watchOS 9.4에서 도입되었으므로 사용 가능하다.
- **View는 테스트하지 않는다.** 테스트는 ViewModel까지만 (`watchosTests/`, Swift Testing, 테스트 이름은 한글 스네이크케이스).
- ViewModel은 UI 프레임워크를 import하지 않는다 — `RoundViewModel.swift`에 `import SwiftUI`를 추가하지 말 것.
- 컴포넌트 계층 규칙: 두 화면이 공유하는 컴포넌트는 `Features/Round/Components/`에 둔다. 한 화면 전용은 `ScreenName/Components/`.
- pbxproj는 `PBXFileSystemSynchronizedRootGroup`이라 파일 생성·이동·삭제가 파일시스템 조작만으로 빌드에 반영된다. **pbxproj를 직접 편집하지 말 것.**
- `main` 직접 push 금지 — 브랜치 + PR, 머지는 `gh pr merge <n> --merge --delete-branch`.
- 커밋 메시지는 gitmoji prefix (✨ feat / 🐛 fix / ♻️ refactor / 🎨 style / 📝 docs / ✅ test / 🔧 chore / 🔥 remove).
- 이 화면의 사용자 표시 문자열은 한글이다 (카운터 화면만 영어 표기로 통일).

---

## Task 0: 브랜치 생성

**Files:** 없음

- [ ] **Step 1: 최신 main에서 브랜치를 딴다**

```bash
git checkout main && git pull --ff-only && git checkout -b feature/watch-par-selection-layout
```

---

## Task 1: `cancelParEditing()` — 파 재편집 취소를 홀 이동에서 분리

카운터의 `[Par]` 버튼으로 들어온 재편집 상태에서 백버튼은 "편집만 닫고 카운터 복귀"여야 한다. 지금은 `cancelToPreviousHole()`이 이전 홀로 이동시켜 버린다.

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift` (`// MARK: - 파 선택` 섹션, `beginParEditing()` 아래)
- Test: `watchosTests/Round/RoundViewModelHoleFlowTests.swift`

**Interfaces:**
- Consumes: 없음 (기존 `RoundViewModel` API만 사용)
- Produces: `func cancelParEditing()` — 파라미터 없음, 반환값 없음. `@MainActor` 격리. Task 2의 `ParSelectionView`가 백버튼 액션으로 쓴다.

- [ ] **Step 1: 실패하는 테스트 2개를 작성한다**

`watchosTests/Round/RoundViewModelHoleFlowTests.swift`의 `// MARK: - cancelToPreviousHole (phantom hole 정리)` 주석 **바로 위**에 아래 두 테스트를 추가한다.

```swift
    // MARK: - cancelParEditing (재편집 취소)

    @Test func 파_재편집을_취소하면_홀을_옮기지_않고_카운팅으로_돌아간다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.incrementStroke()
        viewModel.beginParEditing()
        #expect(viewModel.phase == .parSelection)

        viewModel.cancelParEditing()

        #expect(viewModel.phase == .counting)
        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
        #expect(viewModel.currentScore == 2)
    }

    @Test func 파가_없는_홀에서_재편집_취소는_파선택_단계를_벗어나지_않는다() {
        let viewModel = makeViewModel()
        #expect(viewModel.phase == .parSelection)

        viewModel.cancelParEditing()

        #expect(viewModel.phase == .parSelection)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.currentHoleNumber == 1)
    }
```

두 번째 테스트가 필요한 이유: 새 홀 진입 경로에서는 백버튼이 `cancelToPreviousHole()`로 가므로 실제로 도달하지 않지만, `phase`가 `isEditingPar`와 `currentPar` 둘에서 파생되므로 파가 없을 때 이 메서드가 상태를 깨뜨리지 않음을 고정해 둔다.

- [ ] **Step 2: 테스트가 실패(컴파일 에러)하는지 확인한다**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
```

Expected: FAIL — `value of type 'RoundViewModel' has no member 'cancelParEditing'`

- [ ] **Step 3: 최소 구현을 추가한다**

`WatchApp/Features/Round/RoundViewModel.swift`의 `beginParEditing()` 바로 아래에 넣는다.

```swift
    /// 카운터의 [Par] 버튼으로 시작한 파 재편집을 취소하고 카운터로 돌아간다.
    /// 홀은 옮기지 않고 파 값도 그대로 둔다 — 편집 진입 자체를 무르는 것뿐이다.
    ///
    /// 스냅샷을 발행하지 않는다: `isEditingPar`는 화면 분기용 UI 상태일 뿐
    /// `RoundSnapshot`에 들어가지 않으므로 발행할 변경이 없다 (`beginParEditing()`도 같다).
    func cancelParEditing() {
        isEditingPar = false
    }
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
```

Expected: PASS (신규 2개 포함 전체 통과)

- [ ] **Step 5: 기존 테스트 이름을 실제 검증 대상에 맞게 바꾼다**

`cancelToPreviousHole()`의 재편집 분기는 **방어적으로 남겨둔다** — Task 2 이후 백버튼은 이 경로로 오지 않지만, 분기를 지우면 `isEditingPar`가 참인 채로 불렸을 때 동작이 정의되지 않는다. 검증 내용은 그대로 두고 이름만 바꾼다. "취소"가 더는 백버튼을 가리키지 않기 때문이다.

`watchosTests/Round/RoundViewModelHoleFlowTests.swift`에서:

```swift
    @Test func 이미_점수가_있던_홀의_파_재편집_중_취소는_아무것도_제거하지_않는다() {
```

를 아래로 바꾸고, 본문 안 주석 `// hole 2를 [Par] 버튼으로 재편집하는 중 (phantom hole이 아님).` 아래 줄들은 그대로 둔다.

```swift
    @Test func 재편집_중_cancelToPreviousHole은_phantom_hole을_제거하지_않고_이전홀로만_이동한다() {
```

같은 테스트 본문의 아래 주석도 함께 고쳐, 백버튼 경로가 아님을 분명히 한다.

```swift
        // 일반 goToPreviousHole()과 동일하게 동작해, hole 1로 이동하되 hole 2 데이터는 보존되어야 한다.
```

→

```swift
        // 백버튼은 이제 cancelParEditing()으로 가므로 이 경로는 방어적 분기다.
        // 불릴 경우 일반 goToPreviousHole()과 동일하게, hole 1로 이동하되 hole 2 데이터는 보존한다.
```

- [ ] **Step 6: 린트·포맷과 테스트를 다시 돌린다**

```bash
make lint && make format
```

Expected: 위반 없음

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
```

Expected: PASS

- [ ] **Step 7: 커밋**

```bash
git add WatchApp/Features/Round/RoundViewModel.swift watchosTests/Round/RoundViewModelHoleFlowTests.swift
git commit -m "✨ feat: 파 재편집 취소를 홀 이동에서 분리한 cancelParEditing 추가"
```

---

## Task 2: `CircleIconButton` 승격과 `ParSelectionView` 재작성

**Files:**
- Move: `WatchApp/Features/Round/Counting/Components/CircleIconButton.swift` → `WatchApp/Features/Round/Components/CircleIconButton.swift`
- Delete: `WatchApp/Features/Round/ParSelection/Components/ParBackButton.swift`
- Modify: `WatchApp/Features/Round/ParSelection/ParSelectionView.swift` (전체 재작성)

**Interfaces:**
- Consumes: `CircleIconButton(systemName: String, size: CGFloat, hitInset: CGFloat = 0, action: () -> Void)` — 이동만 하고 시그니처는 그대로다. `RoundViewModel.cancelParEditing()` (Task 1), `RoundViewModel.isEditingPar: Bool` (읽기 전용, 기존), `RoundViewModel.canGoToPreviousHole: Bool` (기존), `RoundViewModel.cancelToPreviousHole()` (기존), `ParOptionButton(par:isSelected:action:)` (기존, 변경 없음)
- Produces: 없음 (화면 최종단)

- [ ] **Step 1: `CircleIconButton`을 두 화면 공유 위치로 옮긴다**

```bash
mkdir -p WatchApp/Features/Round/Components
git mv WatchApp/Features/Round/Counting/Components/CircleIconButton.swift WatchApp/Features/Round/Components/CircleIconButton.swift
```

CLAUDE.md 계층 규칙: 두 화면(`CountingView`, `ParSelectionView`)이 쓰므로 `Counting/` 아래에 있으면 안 된다. pbxproj는 건드리지 않는다 — 파일시스템 동기화로 반영된다.

- [ ] **Step 2: 옮긴 파일의 doc 주석에서 카운터 전용 표현을 없앤다**

`WatchApp/Features/Round/Components/CircleIconButton.swift`의 맨 위 doc 주석을 아래로 교체한다 (`struct CircleIconButton` 선언 위 3줄).

```swift
/// 회색 원반 위 아이콘 하나 — 라운드 화면들이 공유하는 보조 조작 버튼이다 (spec §5).
///
/// 카운터의 취소·홀 이동 화살표와 파 선택 화면의 백버튼이 같은 시각 계열(회색 배경 원)을
/// 쓴다. 화면의 보조 조작이 전부 한 가족으로 읽히게 하려는 것이고, 색을 가지는 것은
/// 링과 모드 알약뿐이라 색이 곧 "카운트에 관여한다"는 신호가 된다.
```

나머지(`hitInset` 주석, `body`, `#Preview`)는 그대로 둔다.

- [ ] **Step 3: 빌드해서 이동이 깨지지 않았는지 확인한다**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

Expected: BUILD SUCCEEDED (`CountingView`가 같은 타깃 안에서 계속 찾는다 — Swift는 타깃 내 파일 위치를 가리지 않는다)

- [ ] **Step 4: `ParSelectionView`를 재작성한다**

`WatchApp/Features/Round/ParSelection/ParSelectionView.swift` 전체를 아래로 교체한다.

```swift
import SwiftUI

/// 파 선택 화면 — 홀에 파가 없거나(신규 진입) 카운터의 [Par]로 재편집할 때 뜬다.
///
/// 세 par 버튼을 `ScrollView`에 담아 세로 예산 초과를 스크롤로 흡수한다. 고정 높이
/// `VStack`이던 이전 구조는 세로 요구량이 210pt여서 40mm(예산 150pt 안팎)에서 잘렸다.
/// 기기별 크기 세트(`ViewThatFits`)를 쓰지 않는 이유는 스크롤이 그 역할을 대신하기
/// 때문이다 — `CountingView`가 크기 세트를 쓰는 건 링이 스크롤될 수 없는 단일 도형이라서다.
///
/// 이 화면은 `RoundSessionView`의 **가로** `TabView(.page)` 안에만 있어 세로 크라운이
/// 비어 있다. 중첩 `.verticalPage` 안이라 `ScrollView`를 금지한 `ScoringView`와 달리,
/// 여기서는 크라운을 두고 다툴 상대가 없다.
struct ParSelectionView: View {
    @ObservedObject var viewModel: RoundViewModel

    /// 백버튼 원형 지름. 헤더 행 높이도 이 값이다.
    private let backButtonSize: CGFloat = 30

    /// 하단 가로 페이지 점 인디케이터가 마지막 par 행을 덮지 않도록 두는 여백.
    /// 인디케이터는 콘텐츠 위에 그려지므로 레이아웃이 알아서 피해주지 않는다.
    private let indicatorClearance: CGFloat = 8

    var body: some View {
        VStack(spacing: 6) {
            header

            ScrollView {
                VStack(spacing: 6) {
                    ForEach([3, 4, 5], id: \.self) { par in
                        ParOptionButton(par: par, isSelected: viewModel.currentPar == par) {
                            viewModel.selectPar(par)
                        }
                    }
                }
                .padding(.bottom, indicatorClearance)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, 4)
    }

    /// 헤더는 `ScrollView` 밖에 둔다 — 안에 넣으면 스크롤했을 때 백버튼이 화면 밖으로
    /// 밀려, phantom hole의 유일한 탈출 경로가 사라진다.
    private var header: some View {
        HStack(spacing: 6) {
            backButton

            Text("\(viewModel.currentHoleNumber)번 홀")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(height: backButtonSize)
    }

    /// 재편집 중이면 편집만 닫고 카운터로 돌아간다(`xmark`) — [Par]로 들어온 사용자가
    /// 기대하는 취소는 홀 이동이 아니라 원래 화면으로 복귀다. 새 홀 진입이면 phantom hole을
    /// 제거하며 이전 홀로 돌아가고(`chevron.left`), 첫 홀에서는 갈 곳이 없어 비활성이다.
    ///
    /// `CircleIconButton`은 비활성 표현을 내장하지 않으므로 호출부에서 붙인다 —
    /// `CountingView.ringArea`의 홀 화살표와 같은 방식이다.
    @ViewBuilder
    private var backButton: some View {
        if viewModel.isEditingPar {
            CircleIconButton(systemName: "xmark",
                             size: backButtonSize,
                             action: viewModel.cancelParEditing)
        } else {
            CircleIconButton(systemName: "chevron.left",
                             size: backButtonSize,
                             action: viewModel.cancelToPreviousHole)
                .disabled(!viewModel.canGoToPreviousHole)
                .opacity(viewModel.canGoToPreviousHole ? 1 : 0.35)
        }
    }
}

#Preview("새 홀 진입") {
    ParSelectionView(viewModel: RoundViewModel())
}

#Preview("파 재편집") {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.beginParEditing()
    return ParSelectionView(viewModel: viewModel)
}
```

- [ ] **Step 5: `ParBackButton`을 삭제한다**

```bash
git rm WatchApp/Features/Round/ParSelection/Components/ParBackButton.swift
```

`ParSelection/Components/`는 `ParOptionButton.swift`가 남아 있으므로 폴더는 유지된다.

- [ ] **Step 6: 남은 참조가 없는지 확인한다**

```bash
grep -rn "ParBackButton" WatchApp iosTests watchosTests
```

Expected: 출력 없음 (grep 종료코드 1)

- [ ] **Step 7: 린트·포맷과 빌드·테스트**

```bash
make lint && make format
```

Expected: 위반 없음

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
```

Expected: BUILD SUCCEEDED + 전체 테스트 PASS

- [ ] **Step 8: 커밋**

```bash
git add -A WatchApp/Features/Round
git commit -m "🎨 style: 파 선택 화면을 스크롤 + 헤더 백버튼 구조로 재배치"
```

---

## Task 3: 시뮬레이터 실측 — 40mm·46mm에서 잘림과 인디케이터 확인

세로 예산(40mm 150pt 안팎)은 스펙에서 추정값이다. `ScrollView`가 잘림 자체는 구조적으로 막지만, **하단 인디케이터가 `Par 5`를 덮는지**는 실측해야 확정된다.

**Files:**
- Modify (실측 결과에 따라서만): `WatchApp/Features/Round/ParSelection/ParSelectionView.swift` (`indicatorClearance` 값)

**Interfaces:**
- Consumes: Task 2의 완성된 `ParSelectionView`
- Produces: 없음

- [ ] **Step 1: 40mm 시뮬레이터에 빌드·설치·실행한다**

```bash
xcrun simctl boot "Apple Watch SE 3 (40mm)" || true
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm)' -derivedDataPath /tmp/gc-dd build
xcrun simctl install "Apple Watch SE 3 (40mm)" "/tmp/gc-dd/Build/Products/Debug-watchsimulator/GolfCounter Watch App.app"
xcrun simctl launch "Apple Watch SE 3 (40mm)" com.yj.GolfCounter.watchkitapp
```

- [ ] **Step 2: 파 선택 화면까지 이동해 스크린샷을 찍는다**

시뮬레이터 창에서 "라운드 시작"을 눌러 1홀 파 선택 화면에 진입한 뒤:

```bash
xcrun simctl io "Apple Watch SE 3 (40mm)" screenshot /tmp/par-40mm.png
```

확인할 것:
1. `Par 3`가 헤더 바로 아래에서 온전히 보이는가 (상단 잘림 없음)
2. 크라운/스크롤로 `Par 5`까지 도달 가능한가
3. `Par 5`까지 스크롤했을 때 하단 페이지 점 인디케이터가 버튼 텍스트를 덮지 않는가
4. `(‹)` 백버튼이 1홀이라 흐리게(opacity 0.35) 보이는가

- [ ] **Step 3: 46mm에서 같은 확인을 한다**

```bash
xcrun simctl boot "Apple Watch Series 11 (46mm)" || true
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -derivedDataPath /tmp/gc-dd build
xcrun simctl install "Apple Watch Series 11 (46mm)" "/tmp/gc-dd/Build/Products/Debug-watchsimulator/GolfCounter Watch App.app"
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.yj.GolfCounter.watchkitapp
xcrun simctl io "Apple Watch Series 11 (46mm)" screenshot /tmp/par-46mm.png
```

확인할 것: 세 par 버튼이 **스크롤 없이** 전부 보이는가. 안 보이면 예산 추정이 틀린 것이므로 `ParOptionButton`의 `minHeight`(현재 46)를 44로 낮추는 것을 먼저 검토한다 — Apple 최소 탭 타깃이 44pt라 그 아래로는 내리지 않는다.

- [ ] **Step 4: 재편집 경로를 확인한다**

46mm 시뮬레이터에서 `Par 4`를 눌러 카운터로 넘어간 뒤, 헤더 왼쪽 `Par 4` 원형 버튼을 탭한다.

확인할 것:
1. 파 선택 화면이 뜨고 `Par 4`가 초록으로 하이라이트되는가
2. 백버튼이 `chevron.left`가 아니라 `xmark`인가
3. `xmark`를 누르면 **1홀 카운터로 돌아가는가** (이전 홀로 튕기지 않고, 타수도 보존)

- [ ] **Step 5: 실측 결과를 반영한다**

인디케이터가 `Par 5`를 덮었으면 `ParSelectionView`의 `indicatorClearance`를 실제로 겹친 양만큼 올린다. 덮지 않았으면 코드 변경 없이 다음 단계로 간다.

변경했다면 다시 빌드·확인:

```bash
make lint && make format && xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
```

Expected: 위반 없음 + PASS

- [ ] **Step 6: 커밋 (Step 5에서 변경이 있었을 때만)**

```bash
git add WatchApp/Features/Round/ParSelection/ParSelectionView.swift
git commit -m "🎨 style: 하단 페이지 인디케이터 여백을 실측값으로 조정"
```

- [ ] **Step 7: PR 생성**

```bash
git push -u origin feature/watch-par-selection-layout
gh pr create --title "🎨 style: 파 선택 화면 레이아웃 재설계" --body "$(cat <<'EOF'
## 요약
- 세 par 버튼을 `ScrollView`에 담아 작은 워치에서의 잘림을 제거 (세로 요구량 210pt → 헤더 30 + 스크롤 콘텐츠 150)
- 하단 전폭 "이전" 버튼을 헤더 라인의 원형 버튼(`CircleIconButton`)으로 이동, 전용 `ParBackButton` 삭제
- 재편집 중 백버튼을 `cancelParEditing()`으로 분리 — 이전 홀로 튕기지 않고 카운터로 복귀

원탭 즉시 선택은 유지했다. Select + Confirm 2단계는 검토했으나 이번 재설계의 동기가 오터치가 아니라 공간 부족이라 기각.

설계: `docs/superpowers/specs/2026-08-16-watch-par-selection-layout-design.md`

## 검증
- `make lint` / `make format` 통과
- watch 테스트 전체 통과 (`cancelParEditing` 2건 추가)
- 시뮬레이터 실측: 40mm / 46mm에서 세 par 버튼 도달 가능, 하단 인디케이터 간섭 없음, 재편집 `xmark` 복귀 동작 확인

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review

**스펙 커버리지**

| 스펙 절 | 담당 태스크 |
|---|---|
| §3 결정 1 (원탭 유지) | 변경 없음 — `ParOptionButton` 그대로 |
| §3 결정 2 (세로 3행 + `ScrollView`) | Task 2 Step 4 |
| §3 결정 3 (헤더를 스크롤 밖에) | Task 2 Step 4 (`header`가 `VStack` 첫 요소) |
| §3 결정 4 (백버튼 → `CircleIconButton`) | Task 2 Step 1·4·5 |
| §3 결정 5 (재편집은 편집만 닫기) | Task 1 + Task 2 Step 4 (`backButton`) |
| §5 크라운 충돌 / `.scrollBounceBehavior` | Task 2 Step 4 |
| §5 하단 인디케이터 (기본 8pt, 실측 조정) | Task 2 Step 4 + Task 3 Step 5 |
| §5 헤더 라벨 `H7` → `7번 홀` | Task 2 Step 4 |
| §5 `CircleIconButton` 승격 | Task 2 Step 1 |
| §5 첫 홀 비활성 (`.disabled` + `.opacity(0.35)`) | Task 2 Step 4 |
| §6 동작 표 (아이콘 분기 포함) | Task 2 Step 4 |
| §6 `cancelToPreviousHole()` 방어적 분기 유지 | Task 1 Step 5 (구현 변경 없음, 테스트 이름만) |
| §8 파일 변경 4건 | Task 1 (VM), Task 2 (나머지 3건) |
| §9 테스트 추가 2건 + 이름 변경 1건 | Task 1 Step 1·5 |
| §10 검증 (lint/format/test/실측) | Task 1 Step 6, Task 2 Step 7, Task 3 |

누락 없음.

**플레이스홀더 스캔:** TBD·TODO 없음. 모든 코드 단계에 실제 코드 블록이 있고, 모든 실행 단계에 정확한 명령과 기대 결과가 있다. Task 3 Step 5만 실측 결과에 따라 값이 갈리는데, 기본값(8pt)과 조정 기준("실제로 겹친 양만큼"), 조정하지 않을 조건이 모두 명시되어 있어 판단이 열려 있지 않다.

**타입 일관성:** Task 1이 만드는 `cancelParEditing()`을 Task 2가 같은 이름으로 쓴다. `CircleIconButton(systemName:size:action:)`는 이동 전 파일의 실제 시그니처와 일치하며 `hitInset`은 기본값이 있어 생략 가능하다. `isEditingPar`·`canGoToPreviousHole`·`currentHoleNumber`·`currentPar`·`cancelToPreviousHole()`·`selectPar(_:)`·`beginParEditing()`은 모두 `RoundViewModel`의 기존 멤버이며 접근 수준(`@Published private(set)`은 외부 읽기 가능)도 맞다.
