# RalliKit 원격 채택 + 카운터 크라운 페이징 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RalliKit 의존을 로컬 경로에서 원격 저장소로 바꾸고, 워치 워크아웃 화면을 공유 패키지 `WorkoutUI`의 것으로 교체하고, 카운터 스코어카드 노출을 크라운 스냅 페이징으로 고친다.

**Architecture:** 패키지는 한 줄도 고치지 않고 골프 앱이 패키지에 맞춘다. 워크아웃 화면은 값 타입 `WorkoutMetrics`만 받는 순수 뷰라, `RoundSessionView`가 `@StateObject`로 이미 관찰 중인 `WorkoutSessionService`를 computed property로 스냅샷 떠서 넘긴다. 카운터는 `ScrollView` + `.scrollTargetBehavior(.paging)`으로 세로 페이징하고, 작은 워치 대응은 `ViewThatFits`가 세 크기 세트 중 실제로 들어가는 것을 골라 처리한다 — 기기 모델 분기는 한 줄도 넣지 않는다.

**Tech Stack:** Swift 5 (language mode) / SwiftUI (watchOS 10+) / RalliKit 원격 SPM (`WorkoutCore`·`WorkoutUI`·`ConnectivityCore`·`PersistenceCore`) / Swift Testing

**참조 spec:** `docs/superpowers/specs/2026-08-09-rallikit-adoption-and-counter-paging-design.md`

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0**
- **RalliKit 패키지 코드 변경 0.** 이 plan은 `~/Workspace/Projects/ralli-kit`를 건드리지 않는다
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `🐛 fix:` / `♻️ refactor:` / `🎨 style:` / `📝 docs:` / `✅ test:` / `🔥 remove:`)
- **`main` 직접 push 금지** — 브랜치 + PR, 머지는 `gh pr merge <n> --merge --delete-branch`. 예외는 Task 5의 문서 커밋뿐
- 브랜치: `feature/rallikit-adoption-and-counter-paging`
- 파일 네이밍·폴더 규칙은 `CLAUDE.md` — View suffix는 독립 화면만, **한 파일 = 한 타입**, 계층화 Components, ViewModel은 UI 프레임워크 import 금지
- 테스트는 Swift Testing(`@Test`/`#expect`), 테스트명은 **한국어 `대상_행위_예상결과`**, `@testable import GolfCounter_Watch_App`, **View는 테스트하지 않는다**
- 사용자 노출 문자열은 한국어 하드코딩 유지 (로컬라이즈는 plan ⑦). 단 `WorkoutUI`가 제공하는 문자열은 패키지 것을 그대로 쓴다
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`
- `Shared/`는 세 타깃 모두에 동기화된다 — **이 plan의 신규 코드는 전부 `WatchApp/` 아래에만 둔다**

### 시작 상태

| 저장소 | 상태 |
|---|---|
| `/Users/yj/Workspace/Projects/golf-counter` | `main` @ `e2fd3bf` (스펙 커밋 직후) |
| `~/Workspace/Projects/ralli-kit` | `main` @ `bb084ee` == `origin/main`. **읽기 전용** |

현재 watchosTests는 **49건**이다. 이 plan은 Task 3에서 2건을 추가해 **51건**으로 만든다.

### 검증 명령

시뮬레이터 UDID는 **머신마다 다르다.** 매 세션 시작 시 다시 확인할 것:

```bash
xcrun simctl list devices available | grep -E "Apple Watch|iPhone 17 Pro"
```

작성 시점(2026-08-09) 값:

| 기기 | UDID |
|---|---|
| iPhone 17 Pro | `C29B5911-545A-4FD0-853B-9B219A300025` |
| Apple Watch Series 11 (46mm) | `74666695-204D-45AC-8787-2CFEA2CE0C51` |
| Apple Watch Series 11 (42mm) | `49B39752-0DA2-4462-BE08-E47987397F7F` |
| Apple Watch SE 3 (44mm) | `E51C0B4F-6E6F-4A62-BE26-0CFCA3F0BBD6` |
| Apple Watch SE 3 (40mm) | `2A87535E-7760-4B68-95B6-C6EB403111B7` |
| Apple Watch Ultra 3 (49mm) | `6A002CD0-99E5-40F3-BD99-8A47BBC4384F` |

> spec §6은 41mm를 언급하지만 이 머신에 41mm 시뮬레이터가 없다. **40mm(SE 3)와 42mm(Series 11)가 작은 화면 쪽을 대신 검증한다.**

```bash
# 워치 빌드
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' build

# 워치 테스트
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' test

# iOS 빌드
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 컴플리케이션 빌드
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' build
```

---

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `GolfCounter.xcodeproj/project.pbxproj` | 수정 (Xcode GUI) | 로컬 → 원격 패키지 참조, Watch App에 `WorkoutUI` 링크 |
| `GolfCounter.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | 신규 (Xcode 생성) | 원격 패키지 해석 결과 고정 |
| `WatchApp/Features/Round/Metrics/MetricsView.swift` | **삭제** | → `WorkoutUI.WorkoutMetricsView` |
| `WatchApp/Features/Round/Controls/ControlsView.swift` | **삭제** | → `WorkoutUI.WorkoutControlsView` |
| `WatchApp/Features/Round/Controls/Components/RoundPauseButton.swift` | **삭제** | 패키지 뷰에 흡수 |
| `WatchApp/Features/Round/Controls/Components/RoundEndButton.swift` | **삭제** | 패키지 뷰에 흡수 |
| `WatchApp/Features/Round/RoundSessionView.swift` | 수정 | 패키지 뷰 호출 + `currentMetrics` 매핑 + `togglePause` |
| `WatchApp/Features/Round/Counter/Components/CounterSizing.swift` | **신규** | 크기 세트 값 타입 (`.regular`/`.compact`/`.tight`) |
| `WatchApp/Features/Round/Counter/Components/CounterPage.swift` | **신규** | 카운터 세로 1페이지 내용 |
| `WatchApp/Features/Round/Counter/CounterView.swift` | 수정 | ScrollView 컨테이너 + `ViewThatFits` + 페이징 설정만 |
| `WatchApp/Features/Round/Counter/Components/StrokeButton.swift` | 수정 | `size`·`iconSize` 파라미터 (기본값 유지) |
| `WatchApp/Features/Round/Counter/Components/ModeToggle.swift` | 수정 | `height` 파라미터 (기본값 유지) |
| `WatchApp/Features/Round/Counter/Components/HoleNavigation.swift` | 수정 | `height` 파라미터 (기본값 유지) |
| `WatchApp/Features/Round/Counter/Components/Scorecard.swift` | 그대로 | 변경 없음 |
| `watchosTests/Round/CounterSizingTests.swift` | **신규** | 크기 세트 단조 감소 + 최소 탭 타깃 |
| `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` | 수정 | §2 의존성, §4 페이지 1/3·2/3·3/3 |
| `docs/superpowers/plans/2026-08-05-watch-round-transmission.md` | 수정 | Tech Stack, 타깃 링크 표, Task 3·6 서술 |

---

## Task 1: 패키지 참조를 원격으로 + WorkoutUI 링크

**Files:**
- Modify: `GolfCounter.xcodeproj/project.pbxproj` (**Xcode GUI로만**)
- Create: `GolfCounter.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (Xcode가 생성)

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: `GolfCounter Watch App` 타깃에서 `import WorkoutUI`가 컴파일된다. 이후 Task 2가 이에 의존한다

> **이 태스크에서 pbxproj를 손편집하지 않는다.** 패키지 참조를 전환하면 `XCSwiftPackageProductDependency`의 UUID가 전부 재발급되고, 네 개 product × 두 타깃의 `PBXBuildFile`·`PBXFrameworksBuildPhase` 항목이 함께 바뀐다. 하나라도 어긋나면 프로젝트가 열리지 않는다.

### ⚠️ Step 0은 사용자 수동 작업 — 에이전트는 여기서 멈추고 요청할 것

- [ ] **Step 0: Xcode GUI에서 패키지 참조 전환 (사용자)**

1. `GolfCounter.xcodeproj`를 Xcode에서 연다
2. Project navigator 최상단 **GolfCounter** 프로젝트 선택 → **Package Dependencies** 탭
3. 목록의 **`ralli-kit`** (로컬, 경로 `../ralli-kit`) 선택 → **`−`** 버튼으로 제거
   - 이 시점부터 프로젝트는 일시적으로 빌드되지 않는다. 정상이다
4. **`+`** → 우측 상단 검색창에 다음을 붙여넣고 Enter:
   ```
   https://github.com/qlrogo91lp/ralli-kit.git
   ```
5. **Dependency Rule** → **Branch** → `main` 입력
6. **Add Package** 클릭
7. product ↔ 타깃 배정 다이얼로그에서 다음과 같이 고른다:

   | Package Product | Add to Target |
   |---|---|
   | `ConnectivityCore` | `GolfCounter` |
   | `PersistenceCore` | `GolfCounter` |
   | `WorkoutCore` | `GolfCounter Watch App` |
   | `WorkoutUI` | `GolfCounter Watch App` |

   > 이 다이얼로그는 product당 타깃을 **하나만** 고르게 한다. `ConnectivityCore`는 iOS·워치 **두 타깃 모두** 필요하므로, 여기서는 `GolfCounter`만 고르고 워치 쪽은 8번에서 수동으로 추가한다.

8. 타깃별 **General → Frameworks, Libraries, and Embedded Content**에서 `+`로 빠진 것을 채워 최종 상태를 맞춘다:

   | 타깃 | 있어야 하는 것 |
   |---|---|
   | `GolfCounter` | `ConnectivityCore`, `PersistenceCore` |
   | `GolfCounter Watch App` | `ConnectivityCore`, `WorkoutCore`, `WorkoutUI` |
   | `ComplicationAppExtension` | **비어 있어야 함** |

9. **File → Packages → Resolve Package Versions** 실행

완료되면 에이전트에게 알린다.

- [ ] **Step 1: pbxproj가 실제로 원격으로 바뀌었는지 확인**

```bash
grep -c "XCLocalSwiftPackageReference" GolfCounter.xcodeproj/project.pbxproj
```

Expected: `0`

```bash
grep -n "XCRemoteSwiftPackageReference\|repositoryURL\|WorkoutUI" GolfCounter.xcodeproj/project.pbxproj
```

Expected: `XCRemoteSwiftPackageReference` 섹션 존재, `repositoryURL = "https://github.com/qlrogo91lp/ralli-kit.git"`, `WorkoutUI` product 참조 존재

`0`이 아니거나 `WorkoutUI`가 안 보이면 Step 0의 3·7·8번을 다시 확인한다.

- [ ] **Step 2: Package.resolved 생성 확인**

```bash
ls -la GolfCounter.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Expected: 파일 존재. 없으면 Xcode에서 **File → Packages → Resolve Package Versions**를 다시 실행한다.

- [ ] **Step 3: 세 타깃 전부 빌드**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: 셋 다 BUILD SUCCEEDED

> 컴플리케이션이 깨지면 8번 표의 "비어 있어야 함"이 지켜지지 않은 것이다.

- [ ] **Step 4: 기존 테스트 회귀 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' test 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED (**49건**)

- [ ] **Step 5: 커밋**

```bash
git checkout -b feature/rallikit-adoption-and-counter-paging
git add GolfCounter.xcodeproj
git commit -m "🔧 chore: RalliKit 의존을 로컬 경로에서 원격(branch main)으로 전환

- XCLocalSwiftPackageReference ../ralli-kit → XCRemoteSwiftPackageReference
- GolfCounter Watch App에 WorkoutUI 링크 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

> **이 태스크 이후 ralli-kit을 고쳐야 할 일이 생기면**: push → Xcode에서 **File → Packages → Update to Latest Package Versions**를 거쳐야 반영된다. 반복이 잦다면 Finder에서 `../ralli-kit` 폴더를 Xcode 프로젝트 navigator로 끌어다 놓으면 같은 이름의 원격 패키지보다 **로컬이 우선 적용**된다. 작업이 끝나면 그 참조를 제거한다 — **커밋되는 pbxproj는 항상 원격 참조여야 한다.** (이 plan은 패키지를 고치지 않으므로 여기 해당 사항이 없다.)

---

## Task 2: 워크아웃 화면을 WorkoutUI로 교체

**Files:**
- Delete: `WatchApp/Features/Round/Metrics/` (폴더 전체)
- Delete: `WatchApp/Features/Round/Controls/` (폴더 전체)
- Modify: `WatchApp/Features/Round/RoundSessionView.swift`

**Interfaces:**
- Consumes: Task 1의 `WorkoutUI` 링크. 패키지 API — `WorkoutMetricsView(metrics:isPaused:)`, `WorkoutControlsView(isPaused:isPauseAvailable:onPauseResume:onEnd:)`, `WorkoutCore.WorkoutMetrics(elapsedSeconds:activeCalories:totalCalories:heartRate:)`
- Produces: `RoundSessionView`의 private `currentMetrics: WorkoutMetrics`, private `togglePause()`. 외부 표면(`init(resuming:)`)은 불변이므로 `HomeView`는 손대지 않는다

> **View는 테스트하지 않는다**(CLAUDE.md). 이 태스크의 검증은 빌드 + 기존 테스트 회귀 + 시뮬레이터 육안이다.

- [ ] **Step 1: 화면 폴더 두 개 삭제**

```bash
rm -rf WatchApp/Features/Round/Metrics WatchApp/Features/Round/Controls
```

`PBXFileSystemSynchronizedRootGroup` 방식이라 파일시스템 삭제만으로 빌드에 반영된다.

- [ ] **Step 2: 빌드 실패 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' build 2>&1 | grep -E "error:"
```

Expected: FAIL — `cannot find 'ControlsView' in scope`, `cannot find 'MetricsView' in scope` (`RoundSessionView.swift`)

- [ ] **Step 3: `RoundSessionView` 교체**

`WatchApp/Features/Round/RoundSessionView.swift` 전체를 다음으로 교체:

```swift
import SwiftUI
import WorkoutCore
import WorkoutUI

struct RoundSessionView: View {
    @StateObject private var viewModel: RoundViewModel
    @StateObject private var healthKit = WorkoutSessionService(configuration: .golf)
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1
    @State private var startTask: Task<Void, Never>?
    /// endRound()가 정상적으로 워크아웃을 끝냈는지 표시한다.
    /// false인 채로 뷰가 사라지면(edge-swipe 등 endRound() 밖의 경로) onDisappear에서 방어적으로 정리한다.
    @State private var didFinish = false

    /// 진행 중 스냅샷이 있으면 그 라운드를 이어서, 없으면 새 라운드를 시작한다.
    init(resuming snapshot: RoundSnapshot? = nil) {
        if let snapshot {
            _viewModel = StateObject(wrappedValue: RoundViewModel(resuming: snapshot))
        } else {
            _viewModel = StateObject(wrappedValue: RoundViewModel())
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutControlsView(isPaused: healthKit.isPaused,
                                onPauseResume: togglePause,
                                onEnd: endRound)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Color.clear.frame(width: 36, height: 36)
                    }
                }
                .tag(0)
            centerPage
                .tag(1)
            WorkoutMetricsView(metrics: currentMetrics, isPaused: healthKit.isPaused)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear(perform: startRound)
        .onDisappear(perform: stopWorkoutIfNotFinished)
    }

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

    private func togglePause() {
        if healthKit.isPaused {
            healthKit.resumeWorkout()
        } else {
            healthKit.pauseWorkout()
        }
    }

    private func startRound() {
        viewModel.start()
        startTask = Task {
            await healthKit.requestAuthorization()
            guard !Task.isCancelled else { return }
            healthKit.startWorkout()
        }
    }

    /// 워크아웃을 끝내고 스냅샷을 지운 뒤 홈으로 돌아간다.
    /// 종료 요약 화면과 iOS 전송은 plan ④에서 이 자리에 들어온다.
    /// 인증 대기 중이던 시작 Task를 먼저 취소해, 라운드 종료 후 뒤늦게 startWorkout()이
    /// 불려 고아 HKWorkoutSession이 남는 경쟁 상태를 막는다.
    private func endRound() {
        startTask?.cancel()
        didFinish = true
        viewModel.finish()
        let service = healthKit
        Task { _ = await service.stopWorkout() }
        dismiss()
    }

    /// endRound()를 거치지 않고 뷰가 사라지면(예: edge-swipe 뒤로가기) 워크아웃 세션이 고아로 남는다.
    /// 스냅샷/App Group 상태는 건드리지 않는다 — 크래시 복구는 HomeView의 resumeIfNeeded()가 계속 담당한다.
    /// TabView 내부 페이지 전환이 아니라 RoundSessionView 자체가 내비게이션 스택에서 빠질 때만 호출된다.
    private func stopWorkoutIfNotFinished() {
        guard !didFinish else { return }
        let service = healthKit
        Task { _ = await service.stopWorkout() }
    }
}
```

- [ ] **Step 4: 빌드 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: 기존 테스트 회귀 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' test 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED (**49건** — `RoundViewModel` 로직을 안 건드렸으므로 그대로여야 한다)

- [ ] **Step 6: 시뮬레이터 육안 확인**

46mm에서 앱을 실행해 라운드를 시작하고 확인한다:

| 확인 | 기대 |
|---|---|
| 왼쪽 탭(컨트롤) | "일시정지" / "운동 종료" 버튼. 일시정지 누르면 "계속하기"로 바뀐다 |
| 왼쪽 탭 상단 | 시계 옆 여백이 예전과 같다 (toolbar 자리채움이 살아 있음) |
| 오른쪽 탭(메트릭) | 경과시간(노랑) · 활동 kcal · 총 kcal · BPM 네 줄. **거리(km) 줄은 없다** |
| 일시정지 상태 | 경과시간이 흐린 노랑으로 바뀐다 |

- [ ] **Step 7: lint/format**

```bash
make fix && make lint && make format
```

Expected: 위반 0

- [ ] **Step 8: 커밋**

```bash
git add -A
git commit -m "♻️ refactor: 워치 워크아웃 화면을 RalliKit WorkoutUI로 교체

- Metrics/·Controls/ 폴더 삭제 (4개 파일)
- WorkoutMetricsView·WorkoutControlsView 채택, toolbar 자리채움은 호출부에 유지
- 실시간 거리(km) 표시 제외 — 수집·기록 경로는 그대로 (spec 2026-08-09 §5)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: CounterSizing 신설 + 컴포넌트 크기 파라미터화 (TDD)

**Files:**
- Create: `WatchApp/Features/Round/Counter/Components/CounterSizing.swift`
- Create: `watchosTests/Round/CounterSizingTests.swift`
- Modify: `WatchApp/Features/Round/Counter/Components/StrokeButton.swift`
- Modify: `WatchApp/Features/Round/Counter/Components/ModeToggle.swift`
- Modify: `WatchApp/Features/Round/Counter/Components/HoleNavigation.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `struct CounterSizing` — 프로퍼티 `headerFont`, `scoreFont`, `strokeButton`, `strokeIcon`, `controlHeight`, `navHeight`, `spacing` (전부 `CGFloat`), 정적 세트 `.regular` / `.compact` / `.tight`
  - `StrokeButton(systemName:tint:size:iconSize:action:)` — `size` 기본값 62, `iconSize` 기본값 26
  - `ModeToggle(mode:height:)` — `height` 기본값 28
  - `HoleNavigation(canGoToPrevious:height:onPrevious:onNext:)` — `height` 기본값 30

> 크기 파라미터에 **기본값을 주는 이유**: 이 태스크만으로 `CounterView`가 그대로 컴파일되고 화면이 시각적으로 하나도 안 바뀐다. 즉 이 태스크는 독립적으로 머지 가능하고, 리뷰어는 "크기 값이 타당한가"만 보면 된다. 실제 배선은 Task 4가 한다.
>
> `CounterSizing`은 도메인 모델이 아니라 **뷰 레이아웃 값**이고 워치 전용이므로 `Shared/Models/`가 아니라 `Counter/Components/`에 둔다. `Shared/`에 두면 세 타깃 모두에 동기화되어 불필요하게 퍼진다.

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Round/CounterSizingTests.swift` 신규 생성:

```swift
import CoreGraphics
@testable import GolfCounter_Watch_App
import Testing

struct CounterSizingTests {
    /// ViewThatFits는 regular → compact → tight 순으로 시도해 첫 번째로 들어가는 것을 고른다.
    /// 뒤 세트가 앞 세트보다 큰 값이 하나라도 있으면 그 순서가 의미를 잃는다.
    @Test func 크기세트는_regular에서_tight로_갈수록_모든_값이_작아진다() {
        let sets: [CounterSizing] = [.regular, .compact, .tight]
        for (larger, smaller) in zip(sets, sets.dropFirst()) {
            #expect(smaller.headerFont < larger.headerFont)
            #expect(smaller.scoreFont < larger.scoreFont)
            #expect(smaller.strokeButton < larger.strokeButton)
            #expect(smaller.strokeIcon < larger.strokeIcon)
            #expect(smaller.controlHeight < larger.controlHeight)
            #expect(smaller.navHeight < larger.navHeight)
            #expect(smaller.spacing < larger.spacing)
        }
    }

    /// 타수 버튼은 라운드 중 가장 많이 눌리는 컨트롤이다.
    /// 가장 작은 세트에서도 Apple 권장 최소 탭 타깃 44pt 아래로 내려가면 안 된다.
    @Test func 가장_작은_크기세트도_타수버튼이_44pt_이상이다() {
        #expect(CounterSizing.tight.strokeButton >= 44)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' test 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `cannot find 'CounterSizing' in scope`

- [ ] **Step 3: `CounterSizing` 구현**

`WatchApp/Features/Round/Counter/Components/CounterSizing.swift` 신규 생성:

```swift
import CoreGraphics

/// 카운터 세로 1페이지를 워치 화면 높이에 맞추기 위한 크기 세트.
///
/// `CounterView`의 `ViewThatFits`가 regular → compact → tight 순으로 시도해
/// 실제로 들어가는 첫 세트를 고른다. **기기 모델을 분기하지 않는다** — 측정은 SwiftUI가 하므로
/// 여기에 화면 높이나 기기 이름이 등장할 이유가 없다.
struct CounterSizing {
    let headerFont: CGFloat
    let scoreFont: CGFloat
    let strokeButton: CGFloat
    let strokeIcon: CGFloat
    /// 모드 토글과 Par 버튼의 높이.
    let controlHeight: CGFloat
    /// 홀 이동 버튼의 높이.
    let navHeight: CGFloat
    let spacing: CGFloat

    /// 46mm 이상. 기존 레이아웃 값 그대로다.
    static let regular = CounterSizing(headerFont: 15,
                                       scoreFont: 22,
                                       strokeButton: 62,
                                       strokeIcon: 26,
                                       controlHeight: 28,
                                       navHeight: 30,
                                       spacing: 8)

    /// 42~44mm.
    static let compact = CounterSizing(headerFont: 14,
                                       scoreFont: 20,
                                       strokeButton: 54,
                                       strokeIcon: 23,
                                       controlHeight: 26,
                                       navHeight: 28,
                                       spacing: 6)

    /// 40mm. 타수 버튼이 최소 탭 타깃(44pt)에 가장 가까워지는 세트다.
    static let tight = CounterSizing(headerFont: 13,
                                     scoreFont: 18,
                                     strokeButton: 46,
                                     strokeIcon: 20,
                                     controlHeight: 24,
                                     navHeight: 26,
                                     spacing: 4)
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' test 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED (**51건** — 49 + 2)

- [ ] **Step 5: `StrokeButton`에 크기 파라미터 추가**

`WatchApp/Features/Round/Counter/Components/StrokeButton.swift` 전체를 다음으로 교체:

```swift
import SwiftUI

struct StrokeButton: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 62
    var iconSize: CGFloat = 26
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .background(tint.opacity(0.85), in: Circle())
        .foregroundStyle(.white)
    }
}
```

> `size`·`iconSize`가 `action` **앞**에 와야 기존 후행 클로저 호출부(`StrokeButton(systemName:tint:) { ... }`)가 그대로 컴파일된다.

- [ ] **Step 6: `ModeToggle`에 높이 파라미터 추가**

`WatchApp/Features/Round/Counter/Components/ModeToggle.swift` 전체를 다음으로 교체:

```swift
import SwiftUI

struct ModeToggle: View {
    @Binding var mode: StrokeInputMode
    var height: CGFloat = 28

    var body: some View {
        HStack(spacing: 4) {
            segment(title: "스윙", value: .swing)
            segment(title: "퍼팅", value: .putt)
        }
    }

    private func segment(title: String, value: StrokeInputMode) -> some View {
        Button {
            mode = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .buttonStyle(.plain)
        .background(mode == value ? Color.green.opacity(0.8) : Color.gray.opacity(0.25), in: Capsule())
        .foregroundStyle(.white)
    }
}
```

- [ ] **Step 7: `HoleNavigation`에 높이 파라미터 추가**

`WatchApp/Features/Round/Counter/Components/HoleNavigation.swift` 전체를 다음으로 교체:

```swift
import SwiftUI

struct HoleNavigation: View {
    let canGoToPrevious: Bool
    var height: CGFloat = 30
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            navButton(title: "이전", systemName: "chevron.left", action: onPrevious)
                .disabled(!canGoToPrevious)
                .opacity(canGoToPrevious ? 1 : 0.35)
            navButton(title: "다음", systemName: "chevron.right", action: onNext)
        }
    }

    private func navButton(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.25), in: Capsule())
    }
}
```

- [ ] **Step 8: 빌드·테스트 통과 확인 (화면은 안 바뀌어야 한다)**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' test 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED (51건). `CounterView`는 기본값을 쓰므로 카운터 화면이 시각적으로 동일해야 한다.

- [ ] **Step 9: lint/format 후 커밋**

```bash
make fix && make lint && make format
git add -A
git commit -m "✨ feat: CounterSizing 크기 세트 + 카운터 컴포넌트 크기 파라미터화

- regular/compact/tight 세 세트, 기기 분기 없음
- StrokeButton·ModeToggle·HoleNavigation에 기본값 있는 크기 파라미터 추가
- 단조 감소·최소 탭 타깃 44pt 테스트 2건 (49 → 51)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: CounterPage 추출 + 크라운 스냅 페이징

**Files:**
- Create: `WatchApp/Features/Round/Counter/Components/CounterPage.swift`
- Modify: `WatchApp/Features/Round/Counter/CounterView.swift`

**Interfaces:**
- Consumes: Task 3의 `CounterSizing`, `StrokeButton(systemName:tint:size:iconSize:action:)`, `ModeToggle(mode:height:)`, `HoleNavigation(canGoToPrevious:height:onPrevious:onNext:)`
- Produces: `CounterPage(viewModel:sizing:)`. `CounterView(viewModel:)`의 외부 표면은 불변이므로 `RoundSessionView`는 손대지 않는다

> **View는 테스트하지 않는다.** 이 태스크의 검증은 빌드 + 세 사이즈 시뮬레이터 육안이다. 특히 40mm에서 카운터 페이지가 잘리지 않는지가 이 태스크의 성패다.

- [ ] **Step 1: `CounterPage` 신규 생성**

`WatchApp/Features/Round/Counter/Components/CounterPage.swift`:

```swift
import SwiftUI
import WatchKit

/// 카운터의 세로 1페이지 — 헤더·현재 홀 점수·타수 버튼·모드/Par·홀 이동.
///
/// 어떤 크기 세트를 쓸지는 이 뷰가 정하지 않는다. `CounterView`의 `ViewThatFits`가
/// 화면에 실제로 들어가는 세트를 골라 `sizing`으로 넘겨준다.
struct CounterPage: View {
    @ObservedObject var viewModel: RoundViewModel
    let sizing: CounterSizing

    var body: some View {
        VStack(spacing: sizing.spacing) {
            header
            currentHoleScore
            strokeButtons
            modeAndPar
            HoleNavigation(canGoToPrevious: viewModel.canGoToPreviousHole,
                           height: sizing.navHeight,
                           onPrevious: viewModel.goToPreviousHole,
                           onNext: viewModel.goToNextHole)
        }
        .padding(.horizontal, 4)
    }

    private var header: some View {
        HStack {
            Text("H\(viewModel.currentHoleNumber) · Par \(viewModel.currentPar)")
                .font(.system(size: sizing.headerFont, weight: .semibold))
            Spacer()
            Text(ScoreFormat.relativeToPar(viewModel.relativeToPar))
                .font(.system(size: sizing.headerFont, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
        }
    }

    private var currentHoleScore: some View {
        Text("\(viewModel.currentScore)타 · \(viewModel.currentPutts)퍼트")
            .font(.system(size: sizing.scoreFont, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
    }

    private var strokeButtons: some View {
        HStack(spacing: 12) {
            StrokeButton(systemName: "plus",
                         tint: .green,
                         size: sizing.strokeButton,
                         iconSize: sizing.strokeIcon) {
                viewModel.incrementStroke()
                WKInterfaceDevice.current().play(.click)
            }
            StrokeButton(systemName: "minus",
                         tint: .orange,
                         size: sizing.strokeButton,
                         iconSize: sizing.strokeIcon) {
                viewModel.decrementStroke()
                WKInterfaceDevice.current().play(.directionDown)
            }
        }
    }

    private var modeAndPar: some View {
        HStack(spacing: 4) {
            ModeToggle(mode: $viewModel.inputMode, height: sizing.controlHeight)
            Button {
                viewModel.beginParEditing()
            } label: {
                Text("Par")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 44, minHeight: sizing.controlHeight)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.25), in: Capsule())
        }
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CounterPage(viewModel: viewModel, sizing: .regular)
}
```

- [ ] **Step 2: `CounterView`를 컨테이너로 축소**

`WatchApp/Features/Round/Counter/CounterView.swift` 전체를 다음으로 교체:

```swift
import SwiftUI

/// 카운터 화면 — 크라운으로 넘기는 세로 페이지 스크롤.
///
/// 1페이지는 화면 높이에 정확히 고정된 카운터, 그 아래가 전체 스코어카드다 (spec §4).
/// 스코어카드가 한 화면을 넘으면 `.paging`이 컨테이너 높이 단위로 알아서 더 나눈다.
///
/// 이 화면은 `RoundSessionView`의 **가로** TabView 안에 들어 있다. 크라운(세로)과
/// 스와이프(가로)는 입력 채널이 달라 충돌하지 않는다 — 세로 TabView를 중첩하지 않은 이유다.
struct CounterView: View {
    @ObservedObject var viewModel: RoundViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ViewThatFits(in: .vertical) {
                    CounterPage(viewModel: viewModel, sizing: .regular)
                    CounterPage(viewModel: viewModel, sizing: .compact)
                    CounterPage(viewModel: viewModel, sizing: .tight)
                }
                .containerRelativeFrame(.vertical)

                Scorecard(snapshot: viewModel.snapshot)
                    .padding(.horizontal, 4)
            }
        }
        .scrollTargetBehavior(.paging)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CounterView(viewModel: viewModel)
}
```

- [ ] **Step 3: 빌드·테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' test 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED (51건)

- [ ] **Step 4: 46mm 육안 확인 — 스냅이 되는가**

46mm에서 라운드를 시작해 카운터 화면에서 확인한다:

| 확인 | 기대 |
|---|---|
| 크라운을 아래로 돌린다 | 카운터가 통째로 밀려 올라가고 스코어카드 페이지에 **딱 멈춘다** (중간에 어중간하게 서지 않음) |
| 크라운을 위로 돌린다 | 카운터 페이지로 딱 돌아온다 |
| 카운터 페이지 | 헤더부터 홀 이동 버튼까지 **전부 보이고 잘리지 않는다** |
| 좌우 스와이프 | 컨트롤·메트릭 탭으로 정상 이동 (크라운 스크롤과 안 섞임) |
| 홀 여러 개 기록 후 | 스코어카드가 길어지면 세로 3페이지로 자연스럽게 이어진다 |
| 카운터 페이지만 볼 때 | 아래에 더 있다는 것이 스크롤 인디케이터로 인지된다 |

> **스냅이 안 되고 자유 스크롤이면** `.scrollTargetBehavior(.paging)`이 안 먹은 것이다. `.containerRelativeFrame(.vertical)`이 `ViewThatFits` **뒤에** 붙어 있는지 먼저 확인한다.
>
> **스냅은 되는데 크라운 감촉이 튀면**(한 칸씩 덜컥거림) `.scrollTargetBehavior(.paging)`을 `.scrollTargetBehavior(.viewAligned)`로 바꾸고, `VStack`에 `.scrollTargetLayout()`을 붙여 본다. 뷰 경계에 정렬하는 방식이라 스코어카드가 길 때 더 부드럽다. 어느 쪽이 나은지는 실측으로 정하고, 바꿨다면 `CounterView`의 주석도 함께 고친다.
>
> **마지막 칸이 인지되지 않으면**(아래에 스코어카드가 있는 줄 모르겠으면) 카운터 페이지 하단에 `Image(systemName: "chevron.compact.down")`을 흐리게 두는 것을 검토한다. 기본 스크롤 인디케이터로 충분하면 넣지 않는다 — 좁은 화면에 요소를 늘리지 않는 편이 낫다.

- [ ] **Step 5: 40mm 육안 확인 — 가장 중요한 단계**

```bash
xcrun simctl boot 2A87535E-7760-4B68-95B6-C6EB403111B7
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=2A87535E-7760-4B68-95B6-C6EB403111B7' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

40mm에서 카운터 페이지를 확인한다:

| 확인 | 기대 |
|---|---|
| 카운터 페이지 | 헤더·점수·+/− 버튼·모드/Par·홀 이동이 **전부 보인다**. 아래가 잘리면 실패 |
| 타수 버튼 | 46pt로 작아졌지만 누를 만하다 |
| 크라운 스냅 | 46mm와 동일하게 동작 |

> **잘리면**: `CounterSizing.tight`가 여전히 크다는 뜻이다. Task 3의 `tight` 값을 더 줄이되 `strokeButton`은 44pt 아래로 내리지 않는다(테스트가 막는다). 그래도 안 맞으면 네 번째 세트를 추가하고 `CounterSizingTests`의 `sets` 배열에도 넣는다.

- [ ] **Step 6: 42mm 육안 확인**

```bash
xcrun simctl boot 49B39752-0DA2-4462-BE08-E47987397F7F
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=49B39752-0DA2-4462-BE08-E47987397F7F' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: 카운터 페이지가 잘리지 않고, 40mm보다는 여유 있게 보인다.

- [ ] **Step 7: lint/format 후 커밋**

```bash
make fix && make lint && make format
git add -A
git commit -m "✨ feat: 카운터를 크라운 스냅 페이징으로 전환

- CounterPage 추출, CounterView는 ScrollView 컨테이너로 축소
- .scrollTargetBehavior(.paging) + .containerRelativeFrame(.vertical)
- ViewThatFits로 40/42/46mm 대응, 기기 분기 없음
- Divider 제거 — 페이지 경계가 대신한다 (spec §4 의도 복원)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: 스펙·플랜 ④ 문서 갱신

**Files:**
- Modify: `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md`
- Modify: `docs/superpowers/plans/2026-08-05-watch-round-transmission.md`

**Interfaces:**
- Consumes: Task 1~4에서 확정된 실제 구조
- Produces: 없음 (문서만)

> 문서 커밋은 CLAUDE.md 예외 조항에 따라 `main`에 직접 해도 되지만, **이 plan에서는 같은 feature 브랜치에 담아 PR로 함께 올린다.** 코드와 문서가 한 PR에서 같이 리뷰되는 편이 낫다.

- [ ] **Step 1: 스펙 §2 의존성 갱신**

`docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md`에서 다음 줄을 찾아:

```markdown
- **ralli-kit 로컬 SPM 패키지** (`../ralli-kit`): `WorkoutCore` / `ConnectivityCore` / `PersistenceCore`.
```

다음으로 교체:

```markdown
- **ralli-kit 원격 SPM 패키지** (`https://github.com/qlrogo91lp/ralli-kit.git`, branch `main`): `WorkoutCore` / `WorkoutUI` / `ConnectivityCore` / `PersistenceCore`. 타깃별 링크와 원격 전환 근거는 `2026-08-09-rallikit-adoption-and-counter-paging-design.md` §4 참조. (앱스토어 릴리즈 시점에 semver 태그로 전환 예정)
```

- [ ] **Step 2: 스펙 §4 페이지 1/3 — 잠금 삭제**

다음 줄을 찾아:

```markdown
**페이지 1/3 컨트롤**: 일시정지 / 라운드 종료 / 잠금(오터치 방지, water lock 방식)
```

다음으로 교체:

```markdown
**페이지 1/3 컨트롤**: 일시정지 / 라운드 종료. RalliKit `WorkoutUI.WorkoutControlsView`를 그대로 쓴다. (초안의 "잠금(water lock)"은 plan ①~④ 어디에도 들어가지 않은 채 미구현으로 남았고, 손목을 내리면 화면이 꺼지는 watchOS 기본 동작이 오터치를 상당히 막아준다 — 2026-08-09 설계에서 삭제)
```

- [ ] **Step 3: 스펙 §4 페이지 2/3 — 스냅 페이징 명시**

다음 줄을 찾아:

```markdown
- 아래로 스크롤(crown) 시 전체 스코어카드 표시 — 모달 아님:
```

다음으로 교체:

```markdown
- 크라운을 돌리면 **화면 단위로 스냅되며** 전체 스코어카드가 나온다 — 모달 아님. `ScrollView` + `.scrollTargetBehavior(.paging)`이고, 카운터 블록은 `ViewThatFits`가 세 크기 세트 중 화면에 들어가는 것을 골라 맞춘다 (기기 모델 분기 없음 — 2026-08-09 설계 §6):
```

- [ ] **Step 4: 스펙 §4 페이지 3/3 — 메트릭 항목 교체**

다음 줄을 찾아:

```markdown
**페이지 3/3 메트릭**: 심박수 · 칼로리 · 거리 · 경과 시간 실시간 표시 (WorkoutCore 경유).
```

다음으로 교체:

```markdown
**페이지 3/3 메트릭**: 경과시간 · 활동 kcal · 총 kcal · 심박수. RalliKit `WorkoutUI.WorkoutMetricsView`를 그대로 쓴다. **실시간 거리는 표시하지 않는다** — 공유 값 타입 `WorkoutMetrics`에 거리 필드가 없기 때문이며, 거리·걸음수의 수집과 기록(`WorkoutResult` → `RoundMetrics` → `GolfRound`)은 전부 그대로 유지된다 (2026-08-09 설계 §5).
```

- [ ] **Step 5: 플랜 ④ Tech Stack 갱신**

`docs/superpowers/plans/2026-08-05-watch-round-transmission.md`에서 다음 줄을 찾아:

```markdown
**Tech Stack:** Swift 5(language mode) / SwiftUI / WidgetKit / ralli-kit(`ConnectivityCore`·`WorkoutCore`, 로컬 SPM `../ralli-kit`) / Swift Testing
```

다음으로 교체:

```markdown
**Tech Stack:** Swift 5(language mode) / SwiftUI / WidgetKit / ralli-kit(`ConnectivityCore`·`WorkoutCore`·`WorkoutUI`, 원격 SPM `https://github.com/qlrogo91lp/ralli-kit.git` branch `main`) / Swift Testing
```

- [ ] **Step 6: 플랜 ④ 타깃 링크 표 갱신**

다음 표의 워치 행을 찾아:

```markdown
| `GolfCounter Watch App` | `ConnectivityCore`, `WorkoutCore` |
```

다음으로 교체:

```markdown
| `GolfCounter Watch App` | `ConnectivityCore`, `WorkoutCore`, `WorkoutUI` |
```

- [ ] **Step 7: 플랜 ④ Task 3 — HoleNavigation 시그니처·호출부 갱신**

(a) `- Produces:` 줄에서 다음을 찾아:

```markdown
- Produces: `RoundViewModel.canGoToNextHole: Bool`, `HoleNavigation(canGoToPrevious:canGoToNext:onPrevious:onNext:)`
```

다음으로 교체:

```markdown
- Produces: `RoundViewModel.canGoToNextHole: Bool`, `HoleNavigation(canGoToPrevious:canGoToNext:height:onPrevious:onNext:)` — `height`는 2026-08-09 plan에서 추가된 기본값 30의 파라미터다
```

(b) "**Step 5: `CounterView` 호출부 수정**" 스텝 전체를 다음으로 교체:

````markdown
- [ ] **Step 5: `CounterPage` 호출부 수정**

> 2026-08-09 plan이 카운터 1페이지를 `CounterPage.swift`로 분리했다. `HoleNavigation` 호출부는 이제 `CounterView.swift`가 아니라 여기에 있다.

`WatchApp/Features/Round/Counter/Components/CounterPage.swift`의 `HoleNavigation(...)` 호출을 교체:

```swift
            HoleNavigation(canGoToPrevious: viewModel.canGoToPreviousHole,
                           canGoToNext: viewModel.canGoToNextHole,
                           height: sizing.navHeight,
                           onPrevious: viewModel.goToPreviousHole,
                           onNext: viewModel.goToNextHole)
```
````

(c) 같은 Task의 커밋 스텝에서 파일 경로를 확인하고, `WatchApp/Features/Round/Counter/CounterView.swift`가 있으면 `WatchApp/Features/Round/Counter/Components/CounterPage.swift`로 바꾼다.

- [ ] **Step 8: 플랜 ④ 테스트 건수 기준선 갱신**

플랜 ④는 자기 출발점을 watchosTests 49건으로 잡고 누적 건수를 단계마다 적어 뒀다. 이 plan이 `CounterSizingTests` 2건을 추가했으므로 **전부 +2** 해야 한다. 다음 위치를 정확히 고친다:

| 줄 | 현재 | 교체 |
|---|---|---|
| 82 | `watchosTests **49건** PASS. 이 숫자가 이 plan의 출발점이다.` | `watchosTests **51건** PASS. 이 숫자가 이 plan의 출발점이다.` |
| 299 | `watchosTests **51건** PASS (49 + 2)` | `watchosTests **53건** PASS (51 + 2)` |
| 470 | `watchosTests **57건** PASS (51 + 6)` | `watchosTests **59건** PASS (53 + 6)` |
| 662 | `watchosTests **62건** PASS (57 + 5)` | `watchosTests **64건** PASS (59 + 5)` |
| 1000 | `watchosTests **66건** PASS (62 + 4)` | `watchosTests **68건** PASS (64 + 4)` |
| 1342 | `watchosTests **74건** PASS (66 + 8)` | `watchosTests **76건** PASS (68 + 8)` |
| 1543 · 1772 · 1826 · 1870 · 1886 | `74건` | `76건` |

줄 번호는 Step 1~7의 편집으로 밀릴 수 있으니 문자열로 찾는다:

```bash
grep -n "건 PASS\|watchosTests 74건" docs/superpowers/plans/2026-08-05-watch-round-transmission.md
```

교체 후 다시 grep해서 `49건`·`57건`·`62건`·`66건`·`74건`이 하나도 안 남았는지 확인한다.

- [ ] **Step 9: 플랜 ④의 RoundSessionView 서술 갱신**

플랜 ④에서 `RoundSessionView`의 3페이지 TabView를 언급하는 서술에, 컨트롤·메트릭 페이지가 이제 `WorkoutUI` 뷰라는 점을 한 줄로 덧붙인다. 다음으로 위치를 찾는다:

```bash
grep -n "3페이지 TabView" docs/superpowers/plans/2026-08-05-watch-round-transmission.md
```

각 위치에 다음 문구를 덧붙인다:

```markdown
(컨트롤·메트릭 페이지는 2026-08-09 plan 이후 `WorkoutUI.WorkoutControlsView`·`WorkoutMetricsView`다)
```

- [ ] **Step 10: 문서에 남은 옛 사실이 없는지 확인**

```bash
grep -rn "로컬 SPM\|../ralli-kit\|water lock\|잠금" docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md docs/superpowers/plans/2026-08-05-watch-round-transmission.md
```

Expected: 남은 결과가 없거나, 있다면 전부 이 plan에서 의도적으로 남긴 맥락(예: 삭제 사유 설명)이어야 한다.

- [ ] **Step 11: 커밋**

```bash
git add docs/
git commit -m "📝 docs: RalliKit 원격 채택·WorkoutUI·크라운 페이징을 스펙과 플랜 ④에 반영

- 스펙 §2 의존성: 로컬 → 원격, WorkoutUI 추가
- 스펙 §4: 잠금(water lock) 삭제, 스냅 페이징 명시, 메트릭 항목 교체
- 플랜 ④: Tech Stack·타깃 링크 표·HoleNavigation 호출부·테스트 기준선 갱신

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: PR 생성

**Files:** 없음

**Interfaces:**
- Consumes: Task 1~5의 커밋 5개
- Produces: 없음

- [ ] **Step 1: 최종 전체 검증**

```bash
make lint && make format
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' test 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: lint/format 위반 0, 워치 TEST SUCCEEDED (51건), iOS·컴플리케이션 BUILD SUCCEEDED

- [ ] **Step 2: PR 생성**

```bash
git push -u origin feature/rallikit-adoption-and-counter-paging
gh pr create --title "♻️ RalliKit 원격 채택 + 카운터 크라운 스냅 페이징" --body "$(cat <<'EOF'
## 요약

`docs/superpowers/specs/2026-08-09-rallikit-adoption-and-counter-paging-design.md` 구현.

- **RalliKit 의존을 로컬 경로에서 원격(branch `main`)으로 전환**하고 워치 타깃에 `WorkoutUI` 링크 추가
- **워치 워크아웃 화면을 공유 패키지 것으로 교체** — `Metrics/`·`Controls/` 폴더 4개 파일 삭제
- **카운터를 크라운 스냅 페이징으로 전환** — 기존 스펙 §4의 의도를 구현이 못 살리고 있던 것을 바로잡음
- 작은 워치 대응은 `ViewThatFits` 3단계, **기기 모델 분기 0줄**

RalliKit 패키지는 한 줄도 고치지 않았다.

## 의도적으로 포기한 것

메트릭 페이지의 **실시간 거리(km)** 표시. 공유 값 타입 `WorkoutMetrics`에 거리 필드가 없어서인데, 거리·걸음수의 **수집과 기록은 그대로**다 (`WorkoutResult` → `RoundMetrics` → `GolfRound`, 애플 건강 앱 포함). 되돌릴 수 있는 결정으로 남겨뒀다 — 필요해지면 `WorkoutMetrics`에 additive로 필드를 추가하면 된다.

스펙 §4의 **잠금(water lock)**도 삭제했다. plan ①~④ 어디에도 들어가지 않은 채 미구현으로 남아 있었다.

## 검증

- watchosTests **51건** PASS (49 → 51, `CounterSizingTests` 2건 추가)
- iOS · 워치 · 컴플리케이션 세 타깃 빌드 성공
- 시뮬레이터 육안: **40mm · 42mm · 46mm** — 카운터 페이지 잘림 없음, 크라운 스냅 정상
- `make lint` / `make format` 위반 0

## 리뷰 포인트

View가 대부분이라 자동화 테스트로 잡히는 게 적다. 특히 봐주실 곳:

- `CounterSizing`의 세 세트 값 — 특히 `tight`의 타수 버튼 46pt가 골프 장갑 낀 손에 충분한지
- `RoundSessionView.currentMetrics`를 computed property로 둔 판단 (테니스는 ViewModel `@Published`로 뺐음 — 근거는 코드 주석에)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## 시뮬레이터 회귀 체크리스트

머지 전에 46mm에서 한 번 통과시킨다.

- [ ] 라운드 시작 → 파 선택 → 카운터 진입까지 정상
- [ ] `+`/`−` 버튼 햅틱이 서로 다르다 (`.click` / `.directionDown`)
- [ ] 스윙/퍼팅 토글 전환, `Par` 버튼으로 파 정정 진입
- [ ] 홀 이동 후 토글이 스윙으로 리셋된다
- [ ] 크라운으로 스코어카드까지 내려갔다 올라와도 타수 입력이 정상
- [ ] 컨트롤 탭에서 일시정지 → 메트릭 탭의 경과시간이 멈추고 흐려진다
- [ ] 일시정지 → 계속하기 후 경과시간이 이어진다
- [ ] 라운드 종료 → 홈 복귀, 재실행 시 스냅샷 복구 동작 유지
- [ ] edge-swipe로 빠져나가도 워크아웃 세션이 고아로 안 남는다 (`stopWorkoutIfNotFinished`)
