# iOS Home View & Match Session 구조 재설계 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS Match 탭에 HomeView를 추가하고, 경기 세션을 Watch 앱과 대칭되는 `[Workout | Score]` 2탭 구조로 재편한다. `MatchTabView`/`MatchContainerView` 중복을 제거하고 `MatchSessionView`로 통합한다.

**Architecture:** `HomeView`(NavigationStack) → NavigationLink → `MatchSessionView`(`[Workout | Score]` TabView). `MatchSessionViewModel`이 `MatchPhase` 상태 기계와 로컬 타이머를 소유. `.playing` phase에서 커스텀 BackButton으로 Workout 탭 이동. 종료 시 `confirmationDialog`.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing, Xcode 16

> **Xcode 프로젝트 파일:** 이 프로젝트는 `PBXFileSystemSynchronizedRootGroup` 방식(Xcode 16)을 사용한다. 파일 생성·삭제만으로 빌드 대상이 자동 갱신된다. `.pbxproj` 직접 수정 불필요.

---

## 변경 파일 전체 목록

### 생성
```
iOSApp/Components/BackButton.swift
iOSApp/Features/Match/Home/HomeView.swift
iOSApp/Features/Match/Session/MatchSessionView.swift
iOSApp/Features/Match/Session/MatchSessionViewModel.swift
```

### 수정
```
iOSApp/Features/Match/Mode/ModeView.swift               ← NavigationLink → callback
iOSApp/Features/Match/Score/ScoreView.swift             ← callbacks 추가, 결과 화면 제거
iOSApp/Features/Match/Result/MatchResultView.swift      ← onExit 추가
iOSApp/iOSApp.swift                                     ← Match 탭 → HomeView
iOSApp/en.lproj/Localizable.strings                    ← 문자열 추가
iOSApp/ko.lproj/Localizable.strings                    ← 문자열 추가
iosTests/iosTests.swift                                 ← MatchSessionViewModel 테스트 추가
```

### 삭제
```
iOSApp/Features/Match/Tab/MatchTabView.swift
iOSApp/Features/Match/Tab/MatchTabViewModel.swift
iOSApp/Features/Match/Session/MatchContainerView.swift
iOSApp/Features/Match/Session/MatchContainerViewModel.swift
iOSApp/Features/Match/Session/Score/ScoreTabView.swift
```

---

## Task 1: 로컬라이제이션 + BackButton 컴포넌트

**Files:**
- Modify: `iOSApp/en.lproj/Localizable.strings`
- Modify: `iOSApp/ko.lproj/Localizable.strings`
- Create: `iOSApp/Components/BackButton.swift`

- [ ] **Step 1: 영문 문자열 추가**

`iOSApp/en.lproj/Localizable.strings`의 `/* Workout */` 섹션 아래에 추가:

```
"ios_start_workout" = "Start Workout";
```

- [ ] **Step 2: 한국어 문자열 추가**

`iOSApp/ko.lproj/Localizable.strings`의 `/* Workout */` 섹션 아래에 추가:

```
"ios_start_workout" = "운동 시작";
```

- [ ] **Step 3: BackButton 컴포넌트 생성**

```swift
// iOSApp/Components/BackButton.swift
import SwiftUI

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(.thickMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/en.lproj/Localizable.strings iOSApp/ko.lproj/Localizable.strings iOSApp/Components/BackButton.swift
git commit -m "feat(ios): add BackButton component and ios_start_workout string"
```

---

## Task 2: MatchSessionViewModel + 테스트

**Files:**
- Create: `iOSApp/Features/Match/Session/MatchSessionViewModel.swift`
- Modify: `iosTests/iosTests.swift`

- [ ] **Step 1: 테스트 먼저 작성**

`iosTests/iosTests.swift`의 맨 아래 `}` 닫기 전에 추가:

```swift
    // MARK: - MatchSessionViewModel

    @Test @MainActor func matchSessionStartMatchSetsPlayingPhase() {
        let vm = MatchSessionViewModel()
        vm.startMatch(format: .oneSet)
        guard case .playing(let options) = vm.phase else {
            Issue.record("Expected .playing phase, got \(vm.phase)")
            return
        }
        #expect(options.mode == .oneSet)
        #expect(options.noAdRule == true)
    }

    @Test @MainActor func matchSessionFinishMatchSetsFinishedPhase() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .oneSet)
        vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
        guard case .finished(let session) = vm.phase else {
            Issue.record("Expected .finished phase, got \(vm.phase)")
            return
        }
        #expect(session.result == .win)
        #expect(session.completedSets.count == 1)
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 0)
    }

    @Test @MainActor func matchSessionStartNewMatchResetsToModeSelection() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .bestOfThree)
        vm.startNewMatch()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after startNewMatch")
            return
        }
    }

    @Test @MainActor func matchSessionEndSessionResetsState() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.startMatch(format: .oneSet)
        vm.endSession()
        guard case .modeSelection = vm.phase else {
            Issue.record("Expected .modeSelection after endSession")
            return
        }
        #expect(vm.elapsedSeconds == 0)
    }

    @Test @MainActor func matchSessionPauseStopsTimer() {
        let vm = MatchSessionViewModel()
        vm.startSession()
        vm.pauseSession()
        #expect(vm.isPaused == true)
        vm.resumeSession()
        #expect(vm.isPaused == false)
    }
```

- [ ] **Step 2: 테스트 실패 확인 (MatchSessionViewModel 없으므로 컴파일 오류 예상)**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD"
```

Expected: 컴파일 에러 (`MatchSessionViewModel` undefined)

- [ ] **Step 3: MatchSessionViewModel 구현**

```swift
// iOSApp/Features/Match/Session/MatchSessionViewModel.swift
import Combine
import Foundation

@MainActor
class MatchSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var elapsedSeconds: Int = 0
    @Published var metrics: WorkoutMetrics = .init()
    @Published var watchConnected: Bool = false
    @Published var isPaused: Bool = false

    private var startedAt: Date?
    private let sessionId: UUID = .init()
    private var currentOptions: MatchOptions?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let connectivity = WatchConnectivityService.shared

        connectivity.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$watchConnected)

        connectivity.$receivedMetrics
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .sink { [weak self] received in
                guard let self else { return }
                self.metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(self.elapsedSeconds),
                    calories: received.calories,
                    heartRate: received.heartRate
                )
            }
            .store(in: &cancellables)
    }

    deinit {
        timer?.invalidate()
    }

    func startSession() {
        startedAt = Date()
        startTimer()
    }

    func pauseSession() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resumeSession() {
        isPaused = false
        startTimer()
    }

    func startMatch(format: MatchFormat) {
        let mode = MatchMode(rawValue: format.rawValue) ?? .oneSet
        let options = MatchOptions(mode: mode, noAdRule: true, noTieRule: false)
        currentOptions = options
        phase = .playing(options)
    }

    func finishMatch(didWin: Bool, completedSets: [(my: Int, your: Int)]) {
        guard let options = currentOptions else { return }
        let session = MatchSession(
            workoutSessionId: sessionId,
            options: options,
            startedAt: startedAt ?? Date(),
            kcalAtStart: 0
        )
        session.endedAt = Date()
        session.result = didWin ? .win : .loss
        let setScores = completedSets.map { SetScore(my: $0.my, your: $0.your) }
        session.completedSets = setScores
        session.mySetScore = setScores.filter { $0.my > $0.your }.count
        session.yourSetScore = setScores.filter { $0.your > $0.my }.count
        session.kcalAtEnd = metrics.calories
        phase = .finished(session)
    }

    func startNewMatch() {
        currentOptions = nil
        phase = .modeSelection
    }

    func endSession() {
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
        metrics = .init()
        phase = .modeSelection
    }

    private func startTimer() {
        timer?.invalidate()
        guard let startedAt else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPaused else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
                self.metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(self.elapsedSeconds),
                    calories: self.metrics.calories,
                    heartRate: self.metrics.heartRate
                )
            }
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test.*passed|Test.*failed|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: 모든 테스트 passed, `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/Session/MatchSessionViewModel.swift iosTests/iosTests.swift
git commit -m "feat(ios): add MatchSessionViewModel with phase state machine and local timer"
```

---

## Task 3: HomeView + stub MatchSessionView + iOSApp.swift 업데이트

**Files:**
- Create: `iOSApp/Features/Match/Home/HomeView.swift`
- Create: `iOSApp/Features/Match/Session/MatchSessionView.swift` (stub)
- Modify: `iOSApp/iOSApp.swift`

- [ ] **Step 1: stub MatchSessionView 생성**

Task 5에서 실제 구현으로 교체됨. 지금은 빌드를 통과시키기 위한 최소 stub.

```swift
// iOSApp/Features/Match/Session/MatchSessionView.swift
import SwiftUI

struct MatchSessionView: View {
    @StateObject private var viewModel = MatchSessionViewModel()
    @State private var selectedTab: Int = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            Text("Workout")
                .tabItem { Label(String(localized: "tab_workout"), systemImage: "figure.run") }
                .tag(0)
            Text("Score")
                .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startSession() }
    }
}

#Preview {
    NavigationStack {
        MatchSessionView()
    }
}
```

- [ ] **Step 2: HomeView 생성**

```swift
// iOSApp/Features/Match/Home/HomeView.swift
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                VStack(spacing: 4) {
                    Text("Ralli")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.green)
                        .italic()
                    Text("Tennis Counter")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                NavigationLink {
                    MatchSessionView()
                        .toolbar(.hidden, for: .tabBar)
                } label: {
                    Text(String(localized: "ios_start_workout"))
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HomeView()
}
```

- [ ] **Step 3: iOSApp.swift Match 탭 교체**

`iOSApp/iOSApp.swift`의 `MainTabView`에서 `ModeView()` → `HomeView()` 로 교체:

```swift
struct MainTabView: View {
    var body: some View {
        TabView {
            SummaryView()
                .tabItem {
                    Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill")
                }

            HomeView()
                .tabItem {
                    Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                }

            HistoryView()
                .tabItem {
                    Label(String(localized: "tab_history"), systemImage: "clock.fill")
                }
        }
    }
}
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/Home/HomeView.swift iOSApp/Features/Match/Session/MatchSessionView.swift iOSApp/iOSApp.swift
git commit -m "feat(ios): add HomeView and stub MatchSessionView, switch Match tab entry point"
```

---

## Task 4: ModeView + ScoreView + MatchResultView API 정리

**Files:**
- Modify: `iOSApp/Features/Match/Mode/ModeView.swift`
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift`
- Modify: `iOSApp/Features/Match/Result/MatchResultView.swift`

- [ ] **Step 1: ModeView 수정 — NavigationStack/NavigationLink 제거, callback 추가**

```swift
// iOSApp/Features/Match/Mode/ModeView.swift
import SwiftUI

struct ModeView: View {
    let onFormatSelected: (MatchFormat) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(String(localized: "new_match"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                    Button { onFormatSelected(format) } label: {
                        ModeListItem(format: format)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
    }
}

#Preview {
    ModeView(onFormatSelected: { _ in })
}
```

- [ ] **Step 2: ScoreView 수정 — callbacks 추가, MatchResultView 제거, 조기 종료 dialog 제거**

ScoreView가 match over를 감지하면 `onMatchFinished`를 호출하고, 조기 종료 버튼은 `onEnd`를 직접 호출한다. dialog는 MatchSessionView에서 관리.

```swift
// iOSApp/Features/Match/Score/ScoreView.swift
import SwiftData
import SwiftUI

struct ScoreView: View {
    let format: MatchFormat
    let onMatchFinished: (Bool, [(my: Int, your: Int)]) -> Void
    let onEnd: () -> Void

    @StateObject private var viewModel: MatchViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false

    init(format: MatchFormat,
         onMatchFinished: @escaping (Bool, [(my: Int, your: Int)]) -> Void,
         onEnd: @escaping () -> Void) {
        self.format = format
        self.onMatchFinished = onMatchFinished
        self.onEnd = onEnd
        _viewModel = StateObject(wrappedValue: MatchViewModel(format: format))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 0) {
                PlayerScoreZone(
                    displayScore: viewModel.score.myDisplayScore,
                    playerLabel: String(localized: "watch_score_me"),
                    color: .green,
                    onTap: { withAnimation { viewModel.addPoint(.me) } },
                    onLongPress: { showEditSheet = true }
                )
                PlayerScoreZone(
                    displayScore: viewModel.score.yourDisplayScore,
                    playerLabel: String(localized: "watch_score_opp"),
                    color: .orange,
                    onTap: { withAnimation { viewModel.addPoint(.opponent) } },
                    onLongPress: { showEditSheet = true }
                )
            }
            .ignoresSafeArea()

            ScoreOverlay(
                myGameScore: viewModel.myGameScore,
                yourGameScore: viewModel.yourGameScore,
                mySetScore: viewModel.mySetScore,
                yourSetScore: viewModel.yourSetScore,
                format: format,
                showUndo: viewModel.score.lastAction != .none,
                onUndo: { viewModel.undo() }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "early_end_button"), action: onEnd)
                    .font(.system(size: 14))
            }
        }
        .onAppear {
            viewModel.injectContext(modelContext)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: viewModel.isMatchOver) { _, isOver in
            if isOver {
                onMatchFinished(viewModel.didWin, viewModel.completedSets)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score)
        }
    }
}

#Preview {
    NavigationStack {
        ScoreView(
            format: .oneSet,
            onMatchFinished: { _, _ in },
            onEnd: {}
        )
    }
}
```

- [ ] **Step 3: MatchResultView 수정 — onExit 추가**

```swift
// iOSApp/Features/Match/Result/MatchResultView.swift
import SwiftUI

struct MatchResultView: View {
    let didWin: Bool
    let completedSets: [(my: Int, your: Int)]
    let onNewMatch: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(didWin
                ? String(localized: "match_over_win")
                : String(localized: "match_over_lose"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(didWin ? .green : .orange)

            HStack(spacing: 24) {
                ForEach(completedSets.indices, id: \.self) { idx in
                    let set = completedSets[idx]
                    VStack(spacing: 2) {
                        Text("Set \(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 4) {
                            Text("\(set.my)").foregroundColor(.green)
                            Text("–").foregroundColor(.white.opacity(0.5))
                            Text("\(set.your)").foregroundColor(.orange)
                        }
                        .font(.system(size: 18, weight: .bold))
                    }
                }
            }

            Button(action: onNewMatch) {
                Text(String(localized: "btn_new_match"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Button(action: onExit) {
                Text(String(localized: "btn_end_match"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    MatchResultView(
        didWin: true,
        completedSets: [(my: 6, your: 4), (my: 6, your: 3)],
        onNewMatch: {},
        onExit: {}
    )
}
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/Mode/ModeView.swift iOSApp/Features/Match/Score/ScoreView.swift iOSApp/Features/Match/Result/MatchResultView.swift
git commit -m "refactor(ios): adapt ModeView/ScoreView/MatchResultView to callback-based API"
```

---

## Task 5: MatchSessionView 완성

**Files:**
- Modify: `iOSApp/Features/Match/Session/MatchSessionView.swift` (stub → final)

- [ ] **Step 1: MatchSessionView 최종 구현으로 교체**

```swift
// iOSApp/Features/Match/Session/MatchSessionView.swift
import SwiftUI

struct MatchSessionView: View {
    @StateObject private var viewModel = MatchSessionViewModel()
    @State private var selectedTab: Int = 1
    @State private var showEndConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutTabView(
                metrics: viewModel.metrics,
                onPauseResume: {
                    viewModel.isPaused ? viewModel.resumeSession() : viewModel.pauseSession()
                },
                onEnd: { showEndConfirm = true }
            )
            .tabItem { Label(String(localized: "tab_workout"), systemImage: "figure.run") }
            .tag(0)

            scoreTabContent
                .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(!isBackAllowed)
        .toolbar {
            if case .playing = viewModel.phase {
                ToolbarItem(placement: .topBarLeading) {
                    BackButton { selectedTab = 0 }
                }
            }
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEndConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                viewModel.endSession()
                dismiss()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .onAppear { viewModel.startSession() }
    }

    private var isBackAllowed: Bool {
        if case .modeSelection = viewModel.phase { return true }
        return false
    }

    @ViewBuilder
    private var scoreTabContent: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView { format in
                viewModel.startMatch(format: format)
            }

        case .playing(let options):
            let format = MatchFormat(rawValue: options.mode.rawValue) ?? .oneSet
            ScoreView(
                format: format,
                onMatchFinished: { didWin, sets in
                    viewModel.finishMatch(didWin: didWin, completedSets: sets)
                },
                onEnd: { showEndConfirm = true }
            )

        case .finished(let session):
            MatchResultView(
                didWin: session.result == .win,
                completedSets: session.completedSets.map { ($0.my, $0.your) },
                onNewMatch: { viewModel.startNewMatch() },
                onExit: { dismiss() }
            )
            .navigationBarBackButtonHidden()
        }
    }
}

#Preview {
    NavigationStack {
        MatchSessionView()
            .toolbar(.hidden, for: .tabBar)
    }
}
```

- [ ] **Step 2: 빌드 + 테스트 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test.*passed|Test.*failed|BUILD"
```

Expected: 모든 테스트 passed, `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/Match/Session/MatchSessionView.swift
git commit -m "feat(ios): implement MatchSessionView with Workout/Score tabs and phase-based navigation"
```

---

## Task 6: 구식 파일 삭제 + 최종 빌드 검증

**Files:**
- Delete: `iOSApp/Features/Match/Tab/MatchTabView.swift`
- Delete: `iOSApp/Features/Match/Tab/MatchTabViewModel.swift`
- Delete: `iOSApp/Features/Match/Session/MatchContainerView.swift`
- Delete: `iOSApp/Features/Match/Session/MatchContainerViewModel.swift`
- Delete: `iOSApp/Features/Match/Session/Score/ScoreTabView.swift`

- [ ] **Step 1: 구식 파일 삭제**

```bash
git rm iOSApp/Features/Match/Tab/MatchTabView.swift
git rm iOSApp/Features/Match/Tab/MatchTabViewModel.swift
git rm iOSApp/Features/Match/Session/MatchContainerView.swift
git rm iOSApp/Features/Match/Session/MatchContainerViewModel.swift
git rm iOSApp/Features/Match/Session/Score/ScoreTabView.swift
```

- [ ] **Step 2: 빈 폴더 확인 및 삭제**

```bash
ls iOSApp/Features/Match/Tab/
ls iOSApp/Features/Match/Session/Score/
```

폴더가 비어 있으면:

```bash
rmdir iOSApp/Features/Match/Tab/
rmdir iOSApp/Features/Match/Session/Score/
```

- [ ] **Step 3: 최종 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 최종 테스트 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test.*passed|Test.*failed|BUILD"
```

Expected: 모든 테스트 passed

- [ ] **Step 5: lint 확인**

```bash
make lint
```

Expected: 경고 없이 통과

- [ ] **Step 6: 커밋**

```bash
git add -u
git commit -m "refactor(ios): remove MatchTabView, MatchContainerView and legacy Session/Score files"
```

---

## 스펙 대조 체크리스트

| 요구사항 | 구현 Task |
|---------|----------|
| iOS Match 탭 HomeView 추가 | Task 3 |
| "운동 시작" 버튼으로 세션 진입 | Task 3 |
| `[Workout \| Score]` 2탭 구조 | Task 5 |
| 로컬 타이머 (항상 작동) | Task 2 |
| Watch 연결 시 칼로리/심박수 수신 | Task 2 |
| `.modeSelection` → 기본 back 버튼 | Task 5 |
| `.playing` → 커스텀 BackButton → Workout 탭 이동 | Task 5 |
| 종료 버튼 → confirmationDialog | Task 5 |
| `.finished` → MatchResultView (새 경기 / 종료) | Task 5 |
| MatchTabView/MatchContainerView 중복 제거 | Task 6 |
| BackButton 컴포넌트 (iOSApp/Components/) | Task 1 |
