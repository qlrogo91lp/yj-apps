# 워치 크라운 점수 입력 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워치 점수 화면에서 디지털 크라운을 위로 돌리면 내 포인트, 아래로 돌리면 상대 포인트가 들어간다. 탭 버튼은 그대로 두고 크라운을 **추가 입력 경로**로 얹는다.

**Architecture:** `ScoreView` 한 파일만 바뀐다. `.digitalCrownRotation` 으로 회전량을 누적하고 ±1 디텐트를 넘을 때마다 `viewModel.addPoint(_:)` 를 버튼과 똑같이 부른 뒤 누적을 0 으로 되돌린다. ViewModel 은 손대지 않으므로 햅틱·연쇄 판정·미러 가드가 그대로 탄다. 크라운은 포커스를 가진 뷰만 받으므로 `@FocusState` 로 화면이 보일 때와 다이얼로그가 닫힐 때 포커스를 되찾는다.

**Tech Stack:** watchOS 10+ / SwiftUI `digitalCrownRotation` · `FocusState`

**Spec:** 별도 스펙 없음 — 2026-09-07 대화에서 확정. 아래 §결정 사항.

**선행:** [햅틱 플랜](2026-09-07-match-haptics.md) — 포인트마다 `.click` 이 울려야 크라운 오입력을 사용자가 알아챈다. 크라운 자체 디텐트 햅틱은 끄므로, 햅틱 플랜 없이 이 플랜만 실행하면 크라운 입력에 촉각 피드백이 전혀 없다.

## 결정 사항 (2026-09-07)

| 논점 | 결정 | 이유 |
|---|---|---|
| 매핑 | **위 = 내 포인트, 아래 = 상대 포인트** | "위 = 나한테 좋은 일" 가치 방향. 화면 배치(좌우)와 무관하게 직관적 |
| 되돌리기 | 버튼 그대로. 크라운은 입력만 | 분업이 깔끔하고 기존 사용자에게 바뀌는 게 없다 |
| 오입력 방어 | **디텐트 1칸 = 1점**, 넘으면 누적 리셋. 크라운 자체 햅틱 끔 | 라켓 쥔 손목이 스치면 돌아간다. 스침은 1칸을 못 넘긴다. 햅틱은 `MatchHaptics` 가 울린다 (두 번 울림 방지) |
| 감도 | `.medium` 으로 시작 | 실기기에서 스침이 잡히면 `.low` |
| 포커스 | `@FocusState` 로 `onAppear` 와 다이얼로그 닫힘 때 되찾는다 | 탭을 오가거나 다이얼로그를 닫으면 포커스가 돌아온다는 보장이 없다. 잃으면 크라운이 **에러 없이 조용히** 죽는다 |
| 동작 범위 | 점수 화면만 | `digitalCrownRotation` 이 `ScoreView` 에 붙어 있어 다른 화면엔 영향 없음. 모드 선택의 `ScrollView` 와 안 만난다 |
| 미러 상태 | 무반응 | 버튼과 같은 `isDriver` 가드 |
| 발견 가능성 | 온보딩(작업 #6) 항목으로 | 워치 화면에 힌트를 넣기엔 좁다 |

## Global Constraints

- **`ScoreView.swift` 한 파일만 수정한다.** ViewModel·모델·다른 뷰는 건드리지 않는다.
- `isContinuous: false` 로 둔다 — `true` 면 범위 끝에서 반대편으로 감겨(`1 → -1`) 상대 포인트가 잘못 들어간다.
- `isHapticFeedbackEnabled: false` — 포인트 햅틱은 `MatchHaptics` 소관.
- 메인 체크아웃에서 작업한다. 커밋 1개 (`✨`).
- 유닛 테스트 없음 — 로직이 뷰에만 있고 시뮬레이터는 크라운을 못 돌린다. 검증은 빌드 + 실기기 체크리스트.

**빌드 명령** (루트에서)

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build
make lint && make format
```

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `Apps/TennisCounter/WatchApp/Features/Match/Score/ScoreView.swift` | 수정 | 크라운 회전 누적 → `addPoint`, 포커스 관리 |

---

### Task 1: 크라운 입력 + 포커스

**Files:**
- Modify: `Apps/TennisCounter/WatchApp/Features/Match/Score/ScoreView.swift`

- [ ] **Step 1: 상태 두 개 추가**

`@State private var showExitConfirm = false` 아래:

```swift
    /// 크라운 회전 누적. ±1 디텐트를 넘으면 포인트 하나로 바꾸고 0 으로 되돌린다 —
    /// 스침(1 미만)은 점수가 되지 않는다.
    @State private var crownAccumulator = 0.0
    /// 크라운은 포커스를 가진 뷰만 받는다. 탭을 오가거나 다이얼로그를 닫으면 돌아온다는 보장이 없어
    /// 화면이 보일 때마다 직접 잡는다. 잃으면 크라운이 에러 없이 조용히 죽는다.
    @FocusState private var isCrownFocused: Bool
```

- [ ] **Step 2: 루트 `ZStack` 에 모디파이어 추가**

`.toolbar { ... }` **앞**에 붙인다:

```swift
        .focusable()
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownAccumulator,
            from: -1000, through: 1000, by: 1,
            sensitivity: .medium,
            isContinuous: false,          // true 면 범위 끝에서 반대편으로 감겨 상대 포인트가 잘못 들어간다
            isHapticFeedbackEnabled: false // 포인트 햅틱은 MatchHaptics 가 울린다 — 두 번 울리지 않게
        )
        .onChange(of: crownAccumulator) { _, value in
            // 버튼과 같은 가드 — mirror 는 점수를 넣을 권한이 없다.
            guard flowViewModel.isDriver else { crownAccumulator = 0; return }
            if value >= 1 {
                viewModel.addPoint(.me)
                crownAccumulator = 0
            } else if value <= -1 {
                viewModel.addPoint(.opponent)
                crownAccumulator = 0
            }
        }
        .onAppear { isCrownFocused = true }
```

`crownAccumulator = 0` 대입이 `onChange` 를 한 번 더 부르지만 `0` 은 두 조건 어디에도 안 걸려 무한 루프가 아니다.

- [ ] **Step 3: 다이얼로그 닫힐 때 포커스 복구**

`.confirmationDialog(...) { ... } message: { ... }` **뒤**에:

```swift
        .onChange(of: showExitConfirm) { _, shown in
            if !shown { isCrownFocused = true }
        }
```

- [ ] **Step 4: 빌드 + 린트**

Run:
```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build 2>&1 | tail -2
make lint && make format
```
Expected: `BUILD SUCCEEDED`, 린트 0. 시뮬레이터에서 점수 화면이 뜨고 탭 버튼이 여전히 동작하는지 한 번 본다 (크라운은 시뮬레이터에서 못 돌린다 — 트랙패드 스크롤이 크라운을 흉내 내긴 하지만 디텐트가 없어 참고만).

- [ ] **Step 5: Commit**

```bash
git add Apps/TennisCounter/WatchApp/Features/Match/Score/ScoreView.swift
git commit -m "✨ 워치 크라운으로 점수 입력 — 위 내 포인트, 아래 상대 포인트"
```

---

### Task 2: 실기기 확인 (사람이 한다)

디텐트·스침·포커스·손목 내림은 전부 실기기에서만 확인된다.

**기본 동작**
- [ ] 크라운 1칸 위 → 내 점수 15. `.click` 한 번
- [ ] 1칸 아래 → 상대 점수 15
- [ ] 빠르게 3칸 위 → 내 점수 3개 올라감 (연속 입력)
- [ ] 되돌리기 버튼 → 크라운으로 넣은 포인트도 되돌아감

**오입력 방어**
- [ ] 크라운을 반 칸만 살짝 밀었다 놓기 → 점수 안 바뀜
- [ ] 라켓 쥔 손목 자세로 크라운을 팔에 스치기 → 점수 안 바뀜. 바뀌면 `sensitivity: .low` 로 내리고 다시
- [ ] **손목을 내려 화면이 꺼진 상태에서 크라운 1칸** → 화면만 깨는지, 점수까지 들어가는지 확인. 들어가면 결정 필요 (허용 / 첫 회전 무시)

**포커스 회복 — 여기가 조용히 죽는 지점**
- [ ] 점수 화면 → 컨트롤 탭으로 밀기 → 다시 점수 화면 → 크라운 동작
- [ ] 점수 화면 → 지표 탭 → 점수 화면 → 크라운 동작
- [ ] 뒤로가기 → 조기 종료 다이얼로그 → 취소 → 크라운 동작
- [ ] 세트 종료 후 (화면 갱신 뒤) → 크라운 동작

**경계**
- [ ] 폰이 driver 인 미러 상태 → 크라운 무반응, 미러 배지 그대로
- [ ] 모드 선택 화면 → 크라운은 여전히 스크롤

**결과 기록** — 감도를 바꿨거나 손목 내림 케이스에서 결정이 필요했으면 이 문서 §결정 사항에 한 줄 추가한다.

---

## 후속 (이번 커밋에 넣지 않는다)

- **온보딩 (작업 #6)** — "워치에서 크라운을 돌려도 점수가 올라갑니다" 한 페이지. 화면에 힌트가 없어 이게 유일한 안내다.
- **첫 회전 무시** — 손목 내림 케이스에서 점수가 들어가는 걸로 확인되면, 화면이 깨어난 뒤 짧은 유예(예: 0.5초) 동안 누적을 버리는 가드를 `onChange` 앞에 둔다. 실측 전엔 넣지 않는다.

## Self-Review

- 결정 사항 8개 → 매핑·되돌리기(Step 2), 오입력 방어(디텐트 임계 + `isHapticFeedbackEnabled: false`), 감도(`.medium` + Task 2 조정), 포커스(Step 1·2·3 + Task 2 체크 4개), 범위·미러(가드 + Task 2 경계), 발견 가능성(후속) ✅
- 제약 — 한 파일만(File Structure), `isContinuous: false`, 크라운 햅틱 끔 ✅
- 선행 관계 — 햅틱 플랜 명시 ✅
- 플레이스홀더 없음.
