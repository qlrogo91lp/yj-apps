# WatchApp 폴더 구조 개편 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `WatchApp/`을 "세션 페이지 = 폴더 하나 + `~View` 하나" 구조로 재배치·리네임한다. 동작 변경 0.

**Architecture:** 스펙 `docs/superpowers/specs/2026-08-13-watch-folder-structure-design.md`의 §3 최종 구조를 그대로 구현한다. 페이지 폴더 5개(SessionControls·ParSelection·Counting·Scorecard·SessionMetrics)와 컨테이너 2개(RoundSessionView 가로축, ScoringView 세로축)로 정리하고, 워치 전용 어댑터는 신설 `WatchApp/Services/`로 옮긴다. 모든 변경은 git mv + 타입명 치환 + 인라인 페이지 2건 추출이다.

**Tech Stack:** Swift / SwiftUI / Swift Testing. pbxproj는 `PBXFileSystemSynchronizedRootGroup`이라 **파일시스템 조작만으로 빌드에 반영된다 — pbxproj를 절대 수정하지 않는다.**

## Global Constraints

- **동작 변경 0.** 로직·레이아웃·수치를 바꾸지 않는다. diff는 이동/리네임/추출뿐이어야 한다.
- 이동은 반드시 `git mv` (히스토리 rename 감지 유지). 이동과 타입명 치환은 같은 커밋에 넣되 그 외 내용 수정은 금지.
- 커밋 메시지는 gitmoji `♻️ refactor:` prefix. 본문 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- 브랜치 `feature/watch-folder-restructure`에서 작업. `main` 직접 push 금지 (문서-only 커밋도 이번엔 코드와 같은 브랜치에 싣는다).
- 신규 테스트 없음 — View는 테스트하지 않는 프로젝트 규칙 + 동작 변경 0이므로 기존 테스트 통과가 검증이다.
- watch 빌드 검증 명령 (이하 "**watch build**"로 표기, `build`를 `test`로 바꾸면 "**watch test**"):
  ```bash
  xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
  ```
  기기명이 없으면 `xcrun simctl list devices available`로 확인해 대체한다.
- 치환은 `perl -pi -e` 사용. 치환 패턴은 각 태스크에 명시된 것만 — 추가 치환 금지.

---

### Task 1: 브랜치 생성 + WorkoutConfiguration을 Services로 이동

**Files:**
- Move: `WatchApp/Features/Round/WorkoutConfiguration+Golf.swift` → `WatchApp/Services/WorkoutConfiguration+Golf.swift`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: `WatchApp/Services/` 폴더. 타입 변경 없음 — `WorkoutConfiguration.golf`는 extension이라 참조부(`RoundSessionView`)는 수정 불필요.

- [ ] **Step 1: 브랜치 생성**

```bash
git checkout -b feature/watch-folder-restructure
```

- [ ] **Step 2: 폴더 생성 + git mv**

```bash
mkdir -p "WatchApp/Services"
git mv "WatchApp/Features/Round/WorkoutConfiguration+Golf.swift" "WatchApp/Services/WorkoutConfiguration+Golf.swift"
```

- [ ] **Step 3: watch build로 검증**

Run: watch build (Global Constraints의 명령)
Expected: BUILD SUCCEEDED — pbxproj 수정 없이 경로 변경이 자동 반영된다.

- [ ] **Step 4: 커밋**

```bash
git add -A
git commit -m "♻️ refactor: WorkoutConfiguration+Golf를 WatchApp/Services/로 이동

워치 전용 시스템 프레임워크 어댑터 자리 신설 (spec 2026-08-13 §3).
Shared/로 못 옮기는 이유: import WorkoutCore가 iOS 타깃 빌드를 깨기 때문.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Scorecard 페이지 폴더 분리 (Scorecard → ScorecardView)

**Files:**
- Move: `WatchApp/Features/Round/Counter/Components/Scorecard.swift` → `WatchApp/Features/Round/Scorecard/ScorecardView.swift`
- Move: `WatchApp/Features/Round/Counter/Components/ScorecardChunks.swift` → `WatchApp/Features/Round/Scorecard/ScorecardChunks.swift`
- Modify: `WatchApp/Features/Round/Counter/CounterView.swift` (참조 치환)
- Move: `watchosTests/Round/ScorecardChunksTests.swift` → `watchosTests/Round/Scorecard/ScorecardChunksTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: `ScorecardView(snapshot:holeRange:showsTotal:)` — 구 `Scorecard`와 시그니처 동일, 타입명만 변경. `ScorecardChunks.ranges(holeCount:)` 변경 없음.

- [ ] **Step 1: 폴더 생성 + git mv**

```bash
mkdir -p "WatchApp/Features/Round/Scorecard" "watchosTests/Round/Scorecard"
git mv "WatchApp/Features/Round/Counter/Components/Scorecard.swift" "WatchApp/Features/Round/Scorecard/ScorecardView.swift"
git mv "WatchApp/Features/Round/Counter/Components/ScorecardChunks.swift" "WatchApp/Features/Round/Scorecard/ScorecardChunks.swift"
git mv "watchosTests/Round/ScorecardChunksTests.swift" "watchosTests/Round/Scorecard/ScorecardChunksTests.swift"
```

- [ ] **Step 2: 타입명 치환 (단어 경계 필수 — ScorecardChunks·ScorecardRow를 건드리면 안 된다)**

```bash
perl -pi -e 's/\bScorecard\b/ScorecardView/g' \
  "WatchApp/Features/Round/Scorecard/ScorecardView.swift" \
  "WatchApp/Features/Round/Counter/CounterView.swift"
```

치환 후 확인: `ScorecardView.swift`의 선언이 `struct ScorecardView: View`, Preview가 `ScorecardView(snapshot:`, `CounterView.swift`의 호출이 `ScorecardView(snapshot: viewModel.snapshot,`이어야 한다. `ScorecardChunks`와 `ScorecardRow`는 바뀌지 않았어야 한다.

```bash
grep -n "ScorecardViewChunks\|ScorecardViewRow" WatchApp -r
```
Expected: 출력 없음 (있으면 과치환 — 수동 복구).

- [ ] **Step 3: watch test로 검증**

Run: watch test
Expected: BUILD + TEST SUCCEEDED. `ScorecardChunksTests`는 타입 참조가 `ScorecardChunks`뿐이라 수정 없이 통과한다.

- [ ] **Step 4: 커밋**

```bash
git add -A
git commit -m "♻️ refactor: Scorecard를 페이지 폴더로 분리, ScorecardView로 리네임

세로 2~N페이지는 화면이므로 Components가 아니라 자기 페이지 폴더를 갖는다.
ScorecardChunks(순수 계산)는 폴더 루트 — Components에는 순수 View만 (spec 2026-08-13 §2).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Counting 페이지 폴더 (CounterPage → CountingView, CounterSizing → CountingSizing)

**Files:**
- Move: `WatchApp/Features/Round/Counter/Components/CounterPage.swift` → `WatchApp/Features/Round/Counting/CountingView.swift`
- Move: `WatchApp/Features/Round/Counter/Components/CounterSizing.swift` → `WatchApp/Features/Round/Counting/CountingSizing.swift`
- Move: `WatchApp/Features/Round/Counter/Components/RingSegments.swift` → `WatchApp/Features/Round/Counting/RingSegments.swift`
- Move: `Counter/Components/{CounterHeader,CounterControls,ModeButton,UndoButton,StrokeRing}.swift` → `Counting/Components/` (이동만 — Header/Controls 리네임은 Task 4)
- Modify: `WatchApp/Features/Round/Counter/CounterView.swift` (참조 치환)
- Move: `watchosTests/Round/CounterSizingTests.swift` → `watchosTests/Round/Counting/CountingSizingTests.swift`
- Move: `watchosTests/Round/RingSegmentsTests.swift` → `watchosTests/Round/Counting/RingSegmentsTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: `CountingView(viewModel:sizing:)` (구 `CounterPage`), `CountingSizing` — `.regular`/`.compact`/`.tight` 케이스명·전 프로퍼티명 유지. `sizing:` 파라미터명 유지.

- [ ] **Step 1: 폴더 생성 + git mv**

```bash
mkdir -p "WatchApp/Features/Round/Counting/Components" "watchosTests/Round/Counting"
git mv "WatchApp/Features/Round/Counter/Components/CounterPage.swift"   "WatchApp/Features/Round/Counting/CountingView.swift"
git mv "WatchApp/Features/Round/Counter/Components/CounterSizing.swift" "WatchApp/Features/Round/Counting/CountingSizing.swift"
git mv "WatchApp/Features/Round/Counter/Components/RingSegments.swift"  "WatchApp/Features/Round/Counting/RingSegments.swift"
git mv "WatchApp/Features/Round/Counter/Components/CounterHeader.swift"   "WatchApp/Features/Round/Counting/Components/CounterHeader.swift"
git mv "WatchApp/Features/Round/Counter/Components/CounterControls.swift" "WatchApp/Features/Round/Counting/Components/CounterControls.swift"
git mv "WatchApp/Features/Round/Counter/Components/ModeButton.swift"      "WatchApp/Features/Round/Counting/Components/ModeButton.swift"
git mv "WatchApp/Features/Round/Counter/Components/UndoButton.swift"      "WatchApp/Features/Round/Counting/Components/UndoButton.swift"
git mv "WatchApp/Features/Round/Counter/Components/StrokeRing.swift"      "WatchApp/Features/Round/Counting/Components/StrokeRing.swift"
git mv "watchosTests/Round/CounterSizingTests.swift" "watchosTests/Round/Counting/CountingSizingTests.swift"
git mv "watchosTests/Round/RingSegmentsTests.swift"  "watchosTests/Round/Counting/RingSegmentsTests.swift"
rmdir "WatchApp/Features/Round/Counter/Components" 2>/dev/null || true
```

- [ ] **Step 2: 타입명 치환**

`CounterPage`·`CounterSizing`은 다른 식별자의 부분 문자열이 아니므로 단어 경계 없이 치환해도 안전하다 (`CounterSizingTests` → `CountingSizingTests`까지 한 번에 잡힌다).

```bash
perl -pi -e 's/CounterPage/CountingView/g; s/CounterSizing/CountingSizing/g' \
  WatchApp/Features/Round/Counting/CountingView.swift \
  WatchApp/Features/Round/Counting/CountingSizing.swift \
  WatchApp/Features/Round/Counting/Components/CounterHeader.swift \
  WatchApp/Features/Round/Counting/Components/CounterControls.swift \
  WatchApp/Features/Round/Counting/Components/ModeButton.swift \
  WatchApp/Features/Round/Counting/Components/StrokeRing.swift \
  WatchApp/Features/Round/Counter/CounterView.swift \
  watchosTests/Round/Counting/CountingSizingTests.swift
```

(`UndoButton.swift`·`RingSegments.swift`는 두 타입을 참조하지 않아 대상에서 뺐다.)

- [ ] **Step 3: 잔존 참조 확인**

```bash
grep -rn "CounterPage\|CounterSizing" WatchApp watchosTests
```
Expected: 출력 없음.

- [ ] **Step 4: watch test로 검증**

Run: watch test
Expected: BUILD + TEST SUCCEEDED. `CountingSizingTests`의 프로퍼티 검증(`headerHeight` 등)은 프로퍼티명이 안 바뀌었으므로 그대로 통과.

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "♻️ refactor: 카운터 화면을 Counting/ 페이지 폴더로 — CountingView·CountingSizing

실제 화면(구 CounterPage)이 View 이름을 갖는다. 순수 계산인 CountingSizing·RingSegments는
폴더 루트, Components/에는 순수 View만 남긴다 (spec 2026-08-13 §2·§4).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: 컴포넌트 기능명 리네임 (CounterHeader → HoleHeader, CounterControls → HoleNavigation)

**Files:**
- Move: `Counting/Components/CounterHeader.swift` → `Counting/Components/HoleHeader.swift`
- Move: `Counting/Components/CounterControls.swift` → `Counting/Components/HoleNavigation.swift`
- Modify: `WatchApp/Features/Round/Counting/CountingView.swift` (참조 치환)

**Interfaces:**
- Consumes: Task 3의 `CountingView`·`CountingSizing`
- Produces: `HoleHeader(holeNumber:par:totalStrokes:canUndo:sizing:onEditPar:onUndo:)`, `HoleNavigation(mode:canGoToPrevious:sizing:onPrevious:onNext:)` — 구 타입과 시그니처 동일, 타입명만 변경.

- [ ] **Step 1: git mv + 치환**

```bash
git mv "WatchApp/Features/Round/Counting/Components/CounterHeader.swift"   "WatchApp/Features/Round/Counting/Components/HoleHeader.swift"
git mv "WatchApp/Features/Round/Counting/Components/CounterControls.swift" "WatchApp/Features/Round/Counting/Components/HoleNavigation.swift"
perl -pi -e 's/CounterHeader/HoleHeader/g; s/CounterControls/HoleNavigation/g' \
  "WatchApp/Features/Round/Counting/Components/HoleHeader.swift" \
  "WatchApp/Features/Round/Counting/Components/HoleNavigation.swift" \
  "WatchApp/Features/Round/Counting/CountingView.swift"
```

- [ ] **Step 2: 잔존 확인 + watch build로 검증**

```bash
grep -rn "CounterHeader\|CounterControls" WatchApp watchosTests
```
Expected: 출력 없음. 이후 watch build → BUILD SUCCEEDED.

- [ ] **Step 3: 커밋**

```bash
git add -A
git commit -m "♻️ refactor: 헤더·조작행 컴포넌트를 기능명으로 — HoleHeader·HoleNavigation

접두 통일이 아니라 기능으로 짓는다 — 헤더는 현재 홀 정보 표시, 하단 행은 홀 이동
(spec 2026-08-13 §3). ModeButton·UndoButton·StrokeRing과 같은 원칙.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: 세로 컨테이너 리네임 (CounterView → ScoringView) + Counter/ 폴더 소멸

**Files:**
- Move: `WatchApp/Features/Round/Counter/CounterView.swift` → `WatchApp/Features/Round/ScoringView.swift`
- Modify: `WatchApp/Features/Round/RoundSessionView.swift` (`centerPage`의 `CounterView(viewModel:)` 호출)
- Modify: `Counting/CountingView.swift`·`Counting/CountingSizing.swift` (주석 속 "CounterView" 언급)

**Interfaces:**
- Consumes: Task 2 `ScorecardView`, Task 3 `CountingView`
- Produces: `ScoringView(viewModel:)` — 구 `CounterView`와 시그니처 동일. `RoundViewModel.Phase`는 `.counting` 유지 (리네임하지 않는다 — CountingView와 1:1이라 스펙 §3에서 유지 결정).

- [ ] **Step 1: git mv + 치환 + 빈 폴더 제거**

```bash
git mv "WatchApp/Features/Round/Counter/CounterView.swift" "WatchApp/Features/Round/ScoringView.swift"
perl -pi -e 's/CounterView/ScoringView/g' \
  "WatchApp/Features/Round/ScoringView.swift" \
  "WatchApp/Features/Round/RoundSessionView.swift" \
  "WatchApp/Features/Round/Counting/CountingView.swift" \
  "WatchApp/Features/Round/Counting/CountingSizing.swift"
rmdir "WatchApp/Features/Round/Counter" 2>/dev/null || true
```

(`CountingView.swift`·`CountingSizing.swift`는 코드가 아니라 주석에서 "`CounterView`의 ViewThatFits가…"라고 언급한다 — 치환하면 "ScoringView의 ViewThatFits"로 사실이 유지된다.)

- [ ] **Step 2: 잔존 확인**

```bash
grep -rn "Counter" WatchApp watchosTests | grep -v "GolfCounter\|Golf Counter"
```
Expected: 출력 없음 — 남은 "Counter"는 앱 이름(`GolfCounter_Watch_App`, "Golf Counter" 타이틀)뿐이어야 한다.

```bash
ls "WatchApp/Features/Round/"
```
Expected: `Counting  ParSelection  RoundSessionView.swift  RoundViewModel.swift  Scorecard  ScoringView.swift` (Counter/ 없음)

- [ ] **Step 3: watch build로 검증 후 커밋**

Run: watch build
Expected: BUILD SUCCEEDED.

```bash
git add -A
git commit -m "♻️ refactor: 세로 페이징 컨테이너를 ScoringView로 리네임, Counter/ 폴더 정리

껍데기(구 CounterView)는 카운터 화면과 스코어카드를 담는 세로축 컨테이너다.
Counting·Counter와 아예 다른 단어를 써서 층위 혼동을 없앤다 (spec 2026-08-13 §3).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: SessionControlsView 추출

**Files:**
- Create: `WatchApp/Features/Round/SessionControls/SessionControlsView.swift`
- Modify: `WatchApp/Features/Round/RoundSessionView.swift`

**Interfaces:**
- Consumes: WorkoutUI의 `WorkoutControlsView(isPaused:onPauseResume:onEnd:)`
- Produces: `SessionControlsView(isPaused: Bool, onPauseResume: @escaping () -> Void, onEnd: @escaping () -> Void)`

- [ ] **Step 1: 신규 파일 생성**

`WatchApp/Features/Round/SessionControls/SessionControlsView.swift`:

```swift
import SwiftUI
import WorkoutUI

/// 세션 가로 1/3 페이지 — 일시정지/재개 · 라운드 종료 (spec §4).
/// WorkoutUI의 공유 컨트롤 화면을 그대로 쓰되, 상단 왼쪽에 투명 자리채움을 둬
/// 내비게이션 바 영역 레이아웃을 다른 페이지와 맞춘다.
struct SessionControlsView: View {
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        WorkoutControlsView(isPaused: isPaused,
                            onPauseResume: onPauseResume,
                            onEnd: onEnd)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
    }
}

#Preview {
    SessionControlsView(isPaused: false, onPauseResume: {}, onEnd: {})
}
```

- [ ] **Step 2: RoundSessionView의 tag(0) 블록 교체**

`RoundSessionView.swift`에서 아래 블록을:

```swift
            WorkoutControlsView(isPaused: healthKit.isPaused,
                                onPauseResume: togglePause,
                                onEnd: endRound)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Color.clear.frame(width: 36, height: 36)
                    }
                }
                .tag(0)
```

다음으로 교체:

```swift
            SessionControlsView(isPaused: healthKit.isPaused,
                                onPauseResume: togglePause,
                                onEnd: endRound)
                .tag(0)
```

- [ ] **Step 3: watch build로 검증 후 커밋**

Run: watch build
Expected: BUILD SUCCEEDED.

```bash
git add -A
git commit -m "♻️ refactor: 세션 컨트롤 페이지를 SessionControlsView로 추출

가로 1/3 페이지도 다른 세션 페이지와 같은 폴더+View 구조를 갖는다 (spec 2026-08-13 §5).
코드 이동만 — toolbar 자리채움 포함 동작 변경 없음.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: SessionMetricsView 추출

**Files:**
- Create: `WatchApp/Features/Round/SessionMetrics/SessionMetricsView.swift`
- Modify: `WatchApp/Features/Round/RoundSessionView.swift` (tag(2) 교체 + `currentMetrics` 삭제)

**Interfaces:**
- Consumes: WorkoutCore의 `WorkoutSessionService`(ObservableObject)·`WorkoutMetrics`, WorkoutUI의 `WorkoutMetricsView(metrics:isPaused:)`
- Produces: `SessionMetricsView(healthKit: WorkoutSessionService)` — `@ObservedObject`로 관찰만, 소유는 계속 `RoundSessionView`의 `@StateObject`.

- [ ] **Step 1: 신규 파일 생성**

`WatchApp/Features/Round/SessionMetrics/SessionMetricsView.swift`:

```swift
import SwiftUI
import WorkoutCore
import WorkoutUI

/// 세션 가로 3/3 페이지 — 경과시간 · 활동/총 kcal · 심박수 (spec §4).
///
/// WorkoutUI의 공유 화면은 값 타입만 받는다 — 서비스의 현재 값을 스냅샷으로 옮긴다.
/// healthKit은 RoundSessionView의 @StateObject가 소유하고 여기서는 관찰만 하므로
/// computed property로 충분하다. (테니스는 같은 매핑을 ViewModel의 @Published로 뺐는데,
/// 그쪽은 View가 서비스를 소유하지 않아 init에서 매번 새 인스턴스가 만들어지는
/// 함정이 있었기 때문이다. 여기엔 그 함정이 없다.)
struct SessionMetricsView: View {
    @ObservedObject var healthKit: WorkoutSessionService

    var body: some View {
        WorkoutMetricsView(metrics: metrics, isPaused: healthKit.isPaused)
    }

    private var metrics: WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
                       activeCalories: healthKit.currentCalories,
                       totalCalories: healthKit.currentCalories + healthKit.currentBasalCalories,
                       heartRate: healthKit.currentHeartRate)
    }
}
```

(#Preview 없음 — `WorkoutSessionService` 실 인스턴스가 필요해 프리뷰가 HealthKit에 닿는다.)

- [ ] **Step 2: RoundSessionView 수정**

tag(2) 블록을:

```swift
            WorkoutMetricsView(metrics: currentMetrics, isPaused: healthKit.isPaused)
                .tag(2)
```

다음으로 교체:

```swift
            SessionMetricsView(healthKit: healthKit)
                .tag(2)
```

그리고 `currentMetrics` computed property를 **주석 블록째** 삭제한다 (주석은 신규 파일로 이동했다):

```swift
    /// WorkoutUI의 공유 화면은 값 타입만 받는다 — 서비스의 현재 값을 스냅샷으로 옮긴다.
    /// healthKit이 이 View의 @StateObject라 관찰이 이미 걸려 있어 computed property로 충분하다.
    /// (테니스는 같은 매핑을 ViewModel의 @Published로 뺐는데, 그쪽은 View가 서비스를 소유하지 않아
    /// init에서 매번 새 인스턴스가 만들어지는 함정이 있었기 때문이다. 여기엔 그 함정이 없다.)
    private var currentMetrics: WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
                       activeCalories: healthKit.currentCalories,
                       totalCalories: healthKit.currentCalories + healthKit.currentBasalCalories,
                       heartRate: healthKit.currentHeartRate)
    }
```

- [ ] **Step 3: watch test로 검증 (전체 테스트)**

Run: watch test
Expected: BUILD + TEST SUCCEEDED — 이 시점에 소스 재배치가 전부 끝났다.

- [ ] **Step 4: 커밋**

```bash
git add -A
git commit -m "♻️ refactor: 세션 메트릭 페이지를 SessionMetricsView로 추출

currentMetrics 매핑과 그 근거 주석을 함께 이동. healthKit 소유권은
RoundSessionView의 @StateObject 그대로, 여기서는 @ObservedObject 관찰만 (spec 2026-08-13 §5).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: 스펙 2건 경로·타입명 개정

**Files:**
- Modify: `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` (§2 폴더 구조 그림)
- Modify: `docs/superpowers/specs/2026-08-11-watch-counter-redesign-design.md` (파일 경로 표)

**Interfaces:**
- Consumes: Task 1~7이 만든 실제 구조
- Produces: 문서가 코드 현실과 일치. 플랜 ④(`2026-08-05-watch-round-transmission.md`)는 **개정하지 않는다** — 후속 작업에서 재작성 확정.

- [ ] **Step 1: 리빌드 스펙 §2의 WatchApp 블록 교체**

`2026-07-31-golfcounter-rebuild-design.md`의 폴더 구조 코드블록에서:

```
WatchApp/
├── Components/
└── Features/
    ├── Home/          # 시작 화면
    └── Round/         # 라운드 세션 (파 선택·카운터·컨트롤·메트릭·요약)
```

다음으로 교체:

```
WatchApp/
├── Services/          # 워치 전용 시스템 프레임워크 어댑터 (Shared에 두면 iOS 빌드가 깨지는 것)
└── Features/
    ├── Home/          # 시작 화면
    └── Round/         # 라운드 세션 — 세션 페이지마다 폴더 하나 + ~View 하나
        ├── SessionControls/   # 일시정지·종료 (가로 1/3)
        ├── ParSelection/      # 파 선택 (가로 2/3 · phase)
        ├── Counting/          # 메인 카운터 (세로 1페이지)
        ├── Scorecard/         # 스코어카드 (세로 2~N페이지)
        └── SessionMetrics/    # 메트릭 (가로 3/3)
```

블록 바로 아래에 한 줄 추가: `WatchApp/Components/`(앱 루트)는 두 Feature 이상이 공유하는 UI가 생기는 시점에 만든다. 상세 구조는 `2026-08-13-watch-folder-structure-design.md` 참조.

- [ ] **Step 2: 재설계 스펙의 파일 경로 표 치환**

`2026-08-11-watch-counter-redesign-design.md`에서 `grep -n "Counter" <파일>`로 경로·타입 언급을 찾아 아래 매핑대로 치환한다. **경로·타입명만 바꾸고 설명 열·산문은 유지한다.**

| 구 표기 | 신 표기 |
|---------|---------|
| `WatchApp/Features/Round/Counter/Components/StrokeRing.swift` | `WatchApp/Features/Round/Counting/Components/StrokeRing.swift` |
| `WatchApp/Features/Round/Counter/Components/RingSegments.swift` | `WatchApp/Features/Round/Counting/RingSegments.swift` |
| `WatchApp/Features/Round/Counter/Components/CounterHeader.swift` | `WatchApp/Features/Round/Counting/Components/HoleHeader.swift` |
| `WatchApp/Features/Round/Counter/Components/CounterControls.swift` | `WatchApp/Features/Round/Counting/Components/HoleNavigation.swift` |
| `WatchApp/Features/Round/Counter/Components/ModeButton.swift` | `WatchApp/Features/Round/Counting/Components/ModeButton.swift` |
| `WatchApp/Features/Round/Counter/Components/UndoButton.swift` | `WatchApp/Features/Round/Counting/Components/UndoButton.swift` |
| `Counter/Components/CounterPage.swift` | `Counting/CountingView.swift` |
| `Counter/Components/CounterSizing.swift` | `Counting/CountingSizing.swift` |
| `Counter/Components/Scorecard.swift` | `Scorecard/ScorecardView.swift` |
| 타입명 `CounterPage` / `CounterSizing` / `CounterHeader` / `CounterControls` | `CountingView` / `CountingSizing` / `HoleHeader` / `HoleNavigation` |

주의 2건:
- 삭제 이력 표의 `Counter/Components/HoleNavigation.swift | CounterControls로 흡수` 행은 **역사 기록이므로 경로를 바꾸지 않는다.** 대신 행 끝에 `(2026-08-13 구조 개편에서 이 이름이 Counting/Components/HoleNavigation.swift로 부활)`을 덧붙인다.
- 산문 속 "카운터 화면"·"메인 카운터" 같은 서술 어휘는 그대로 둔다 — CountingView와 어긋나지 않는다.

- [ ] **Step 3: 잔존 확인 + 커밋**

```bash
grep -n "Counter/Components\|CounterPage\|CounterSizing\|CounterHeader" \
  docs/superpowers/specs/2026-08-11-watch-counter-redesign-design.md
```
Expected: 역사 기록으로 남긴 행(삭제 이력 표)만 출력.

```bash
git add docs/superpowers/specs/
git commit -m "📝 docs: 스펙 2건을 새 WatchApp 폴더 구조·타입명으로 동기화

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: 최종 검증 + PR

**Files:**
- 없음 (검증·PR만)

**Interfaces:**
- Consumes: Task 1~8 전체
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
Expected: 전부 SUCCEEDED. iOS·Complication은 WatchApp 그룹을 링크하지 않아 애초에 영향이 없어야 정상이다 — 실패하면 잘못된 파일이 Shared로 샌 것이다.

- [ ] **Step 2: lint/format + 히스토리 확인**

```bash
make lint && make format
git log --oneline --follow -- "WatchApp/Features/Round/Counting/CountingView.swift" | head -5
```
Expected: lint/format 통과. `--follow`가 CounterPage 시절 커밋까지 이어 보여줘야 한다 (rename 감지 확인).

- [ ] **Step 3: push + PR 생성**

```bash
git push -u origin feature/watch-folder-restructure
gh pr create --title "♻️ WatchApp 폴더 구조 개편 — 페이지 단위 재배치·리네임" --body "$(cat <<'EOF'
## Summary
- 스펙: docs/superpowers/specs/2026-08-13-watch-folder-structure-design.md
- 세션 페이지 5개를 "폴더 하나 + ~View 하나"로 통일 (SessionControls · ParSelection · Counting · Scorecard · SessionMetrics)
- 이름 역전 해소: 실제 화면 CounterPage → CountingView, 껍데기 CounterView → ScoringView
- 컴포넌트는 기능명으로: CounterHeader → HoleHeader, CounterControls → HoleNavigation
- 순수 계산(CountingSizing·RingSegments·ScorecardChunks)을 Components/ 밖 페이지 폴더 루트로
- 워치 전용 어댑터 자리 WatchApp/Services/ 신설 (WorkoutConfiguration+Golf 이동)
- watchosTests를 소스 구조 미러링으로 재배치, 스펙 2건 경로 동기화

**동작 변경 0** — diff는 전부 이동/리네임/추출.

## Test plan
- [ ] GolfCounter Watch App: test 통과
- [ ] GolfCounter (iOS)·ComplicationAppExtension: build 통과 (영향 없음 확인)
- [ ] make lint / make format 통과
- [ ] git log --follow로 rename 히스토리 연속성 확인

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

머지는 사용자 확인 후 `gh pr merge <n> --merge --delete-branch` (일반 merge commit 규칙).

---

## 후속 작업 (이 플랜 범위 밖 — 스펙 §9)

1. **RoundViewModel 분리** — 별도 브레인스토밍으로 상태 소유권 설계부터.
2. **플랜 ④ 재작성 → 실행** — 새 구조 기준. HomeViewModel·홀 수 선택 화면 포함. 요약 화면은 `Round/Summary/SummaryView.swift`.
