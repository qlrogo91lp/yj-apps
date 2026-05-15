# WorkoutSession Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS `MatchSession` → `WorkoutSession` 이름 통일, iOS `ModeView` 인라인 병합, `noAdRule`/`noTieRule` 미적용 버그 수정.

**Architecture:** `WorkoutSessionView`가 경기 전체 흐름(modeSelection → playing → finished)을 조율하는 컨테이너 역할을 한다. 모드 선택 UI는 독립 파일 없이 컨테이너 내부에 인라인으로 존재한다. Watch 앱의 `WorkoutSessionView` 구조와 대칭을 이룬다. `ScoreView`/`ScoreViewModel`은 `MatchFormat` 대신 `MatchOptions` 전체를 받아 룰을 적용한다.

**Tech Stack:** SwiftUI, Combine, `MatchOptions`(Shared), `Score`(Shared)

---

## 파일 변경 맵

| 변경 종류 | 파일 |
|---|---|
| Rename+Move | `Session/MatchSessionView.swift` → `WorkoutSession/WorkoutSessionView.swift` |
| Rename+Move | `Session/MatchSessionViewModel.swift` → `WorkoutSession/WorkoutSessionViewModel.swift` |
| Delete | `Mode/ModeView.swift` |
| Delete | `Mode/ModeViewModel.swift` |
| Keep | `Mode/Components/ModeListItem.swift` (WorkoutSessionView에서 계속 사용) |
| Modify | `WorkoutSession/WorkoutSessionView.swift` (ModeView 인라인, ScoreView에 options 전달) |
| Modify | `WorkoutSession/WorkoutSessionViewModel.swift` (타입명만 변경) |
| Modify | `Score/ScoreView.swift` (MatchOptions 수신) |
| Modify | `Score/ScoreViewModel.swift` (MatchOptions 수신, noAdRule/noTieRule 적용) |
| Modify | `Result/MatchResultView.swift` (타입 참조 업데이트) |
| Modify | `iOSApp.swift` (WorkoutSessionView로 참조 변경) |

---

### Task 1: WorkoutSession 폴더 생성 및 파일 이동

**Files:**
- Create: `iOSApp/Features/Match/WorkoutSession/WorkoutSessionView.swift`
- Create: `iOSApp/Features/Match/WorkoutSession/WorkoutSessionViewModel.swift`
- Delete: `iOSApp/Features/Match/Session/MatchSessionView.swift`
- Delete: `iOSApp/Features/Match/Session/MatchSessionViewModel.swift`

- [ ] **Step 1: 새 폴더 생성 및 ViewModel 파일 복사 후 타입명 변경**

`iOSApp/Features/Match/WorkoutSession/WorkoutSessionViewModel.swift` 를 아래 내용으로 생성 (기존 `MatchSessionViewModel.swift`와 동일하되 타입명만 변경):

```swift
import Combine
import Foundation

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var elapsedSeconds: Int = 0
    @Published var metrics: WorkoutMetrics = .init()
    @Published var watchConnected: Bool = false
    @Published var isPaused: Bool = false

    private var startedAt: Date?
    private let sessionId: UUID = .init()
    private var currentOptions: MatchOptions?
    private var _currentSession: MatchSession?
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

    deinit { timer?.invalidate() }

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

    func startMatch(options: MatchOptions) {
        currentOptions = options
        _currentSession = MatchSession(
            workoutSessionId: sessionId,
            options: options,
            startedAt: startedAt ?? Date(),
            kcalAtStart: 0
        )
        phase = .playing(options)
    }

    func finishMatch(didWin: Bool, completedSets: [(my: Int, your: Int)]) {
        guard let session = _currentSession else { return }
        session.endedAt = Date()
        session.result = didWin ? .win : .loss
        let setScores = completedSets.map { SetScore(my: $0.my, your: $0.your) }
        session.completedSets = setScores
        session.mySetScore = setScores.filter { $0.my > $0.your }.count
        session.yourSetScore = setScores.filter { $0.your > $0.my }.count
        session.kcalAtEnd = metrics.calories
        phase = .finished(session)
    }

    func saveCurrentMatch() throws {
        guard let session = _currentSession else { return }
        let record = MatchRecord(from: session)
        try MatchPersistenceService.shared.save(record)
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options)
    }

    func startNewMatch() {
        _currentSession = nil
        currentOptions = nil
        phase = .modeSelection
    }

    func endSession() {
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
        metrics = .init()
        _currentSession = nil
        currentOptions = nil
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

- [ ] **Step 2: WorkoutSessionView 파일 생성 (ModeView 인라인 포함)**

`iOSApp/Features/Match/WorkoutSession/WorkoutSessionView.swift` 를 아래 내용으로 생성.
기존 `MatchSessionView`에서 `ModeView` 인라인 병합 + `ScoreView`에 `options` 전달:

```swift
import SwiftUI

struct WorkoutSessionView: View {
    let onExit: () -> Void

    @StateObject private var viewModel = WorkoutSessionViewModel()
    @State private var selectedTab: Int = 1
    @State private var showEndMatchConfirm = false
    @State private var showEndWorkoutConfirm = false
    @State private var hasMatchProgress = false

    // Mode selection state (previously in ModeViewModel)
    @State private var noAdRule: Bool = true
    @State private var noTieRule: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutTabView(
                metrics: viewModel.metrics,
                isPaused: viewModel.isPaused,
                onPauseResume: {
                    viewModel.isPaused ? viewModel.resumeSession() : viewModel.pauseSession()
                },
                onEnd: { showEndWorkoutConfirm = true }
            )
            .tabItem { Label(String(localized: "tab_workout"), systemImage: "figure.run") }
            .tag(0)

            scoreTabContent
                .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                switch viewModel.phase {
                case .modeSelection:
                    BackButton { selectedTab = 0 }
                case .playing:
                    BackButton {
                        if hasMatchProgress {
                            showEndMatchConfirm = true
                        } else {
                            viewModel.startNewMatch()
                        }
                    }
                case .finished:
                    BackButton { viewModel.startNewMatch() }
                }
            }
            ToolbarItem(placement: .principal) {
                if case .modeSelection = viewModel.phase {
                    Text(String(localized: "new_match"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .alert(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEndMatchConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                hasMatchProgress = false
                viewModel.startNewMatch()
            }
            Button(String(localized: "btn_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .alert(
            String(localized: "end_workout_confirm_title"),
            isPresented: $showEndWorkoutConfirm
        ) {
            Button(String(localized: "workout_end"), role: .destructive) {
                viewModel.endSession()
                onExit()
            }
            Button(String(localized: "btn_cancel"), role: .cancel) {}
        } message: {
            if case .playing = viewModel.phase {
                Text(String(localized: "end_workout_with_match_message"))
            } else {
                Text(String(localized: "end_workout_confirm_message"))
            }
        }
        .onAppear { viewModel.startSession() }
    }

    @ViewBuilder
    private var scoreTabContent: some View {
        switch viewModel.phase {
        case .modeSelection:
            modeSelectionContent

        case .playing(let options):
            ScoreView(
                options: options,
                onMatchFinished: { didWin, sets in
                    viewModel.finishMatch(didWin: didWin, completedSets: sets)
                },
                onProgressChanged: { hasMatchProgress = $0 }
            )

        case .finished(let session):
            MatchResultView(session: session, viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var modeSelectionContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                    Button {
                        let mode = MatchMode(rawValue: format.rawValue) ?? .oneSet
                        viewModel.startMatch(options: MatchOptions(mode: mode, noAdRule: noAdRule, noTieRule: noTieRule))
                    } label: {
                        ModeListItem(format: format)
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(Color.white.opacity(0.2))

                Toggle(String(localized: "mode_no_ad"), isOn: $noAdRule)
                    .font(.system(size: 15))
                    .tint(.green)

                Toggle(String(localized: "mode_no_tie"), isOn: $noTieRule)
                    .font(.system(size: 15))
                    .tint(.green)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutSessionView(onExit: {})
    }
}
```

- [ ] **Step 3: 기존 Session 폴더 파일 삭제**

```bash
rm /Users/yj/Workspace/tennis_counter/iOSApp/Features/Match/Session/MatchSessionView.swift
rm /Users/yj/Workspace/tennis_counter/iOSApp/Features/Match/Session/MatchSessionViewModel.swift
rmdir /Users/yj/Workspace/tennis_counter/iOSApp/Features/Match/Session
```

- [ ] **Step 4: iOS ModeView/ModeViewModel 삭제**

```bash
rm /Users/yj/Workspace/tennis_counter/iOSApp/Features/Match/Mode/ModeView.swift
rm /Users/yj/Workspace/tennis_counter/iOSApp/Features/Match/Mode/ModeViewModel.swift
```

Note: `Mode/Components/ModeListItem.swift`는 `WorkoutSessionView.modeSelectionContent`에서 계속 사용하므로 삭제하지 않는다.

- [ ] **Step 5: 빌드 확인 (예상 에러: MatchSessionView, MatchSessionViewModel 미발견)**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|Build succeeded"
```

---

### Task 2: ScoreView/ScoreViewModel — MatchOptions 수신

**Files:**
- Modify: `iOSApp/Features/Match/Score/ScoreViewModel.swift`
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift`

- [ ] **Step 1: ScoreViewModel — MatchOptions 수신 + noAdRule/noTieRule 적용**

`ScoreViewModel.swift` 전체 교체:

```swift
import Combine
import Foundation

@MainActor
final class ScoreViewModel: ObservableObject {
    let options: MatchOptions

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    var isTieBreak: Bool { score.gameMode == .tieBreak }

    var hasProgress: Bool {
        myGameScore > 0 || yourGameScore > 0 ||
        mySetScore > 0 || yourSetScore > 0 ||
        !completedSets.isEmpty ||
        score.lastAction != .none
    }

    private var cancellable: AnyCancellable?
    private let connectivity = WatchConnectivityService.shared

    init(options: MatchOptions = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) {
        self.options = options
        self.score.noAdRule = options.noAdRule
        cancellable = score.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func addPoint(_ side: PlayerSide) {
        guard !isMatchOver else { return }
        guard score.addPoint(side) != nil else { return }
        if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
        score.resetData()
        sendScoreUpdate()
        checkSetUpdate()
        // 6-6이고 타이브레이크 활성화 시 타이브레이크 모드 전환
        if myGameScore == 6 && yourGameScore == 6 && !options.noTieRule {
            score.setTieBreakMode()
        }
    }

    func undo() {
        score.undo()
    }

    func resetAll() {
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        currentSetNumber = 1
        completedSets = []
        isMatchOver = false
        didWin = false
        score.noAdRule = options.noAdRule
        score.resetData()
    }

    private func checkSetUpdate() {
        guard isSetComplete() else { return }

        let myWonSet = myGameScore > yourGameScore
        completedSets.append((my: myGameScore, your: yourGameScore))

        if myWonSet { mySetScore += 1 } else { yourSetScore += 1 }

        myGameScore = 0
        yourGameScore = 0
        currentSetNumber += 1

        if mySetScore >= options.mode.setsToWin {
            didWin = true
            isMatchOver = true
        } else if yourSetScore >= options.mode.setsToWin {
            didWin = false
            isMatchOver = true
        }
    }

    private func isSetComplete() -> Bool {
        let maxGames = max(myGameScore, yourGameScore)
        let minGames = min(myGameScore, yourGameScore)
        // 타이브레이크 세트: 7-6 완료
        if maxGames == 7 && minGames == 6 { return true }
        return maxGames >= 6 && (maxGames - minGames) >= 2
    }

    private func sendScoreUpdate() {
        connectivity.sendScoreUpdate(ScoreUpdate(
            myScore: score.myScore,
            yourScore: score.yourScore,
            myGameScore: myGameScore,
            yourGameScore: yourGameScore
        ))
    }
}
```

> **변경 포인트:**
> - `format: MatchFormat` → `options: MatchOptions`
> - `init`에서 `score.noAdRule = options.noAdRule` 적용
> - `addPoint`에서 6-6 도달 시 `score.setTieBreakMode()` 호출 (noTieRule이 false일 때)
> - `isTieBreak`를 `score.gameMode == .tieBreak`로 변경 (게임 상태 기반으로 정확하게)
> - `isSetComplete()`에 7-6 타이브레이크 종료 케이스 추가
> - `resetAll()`에서 `score.noAdRule` 재적용

- [ ] **Step 2: ScoreView — MatchOptions 수신**

`ScoreView.swift` 수정 — `format: MatchFormat` → `options: MatchOptions`:

```swift
import SwiftUI

struct ScoreView: View {
    let options: MatchOptions
    let onMatchFinished: (Bool, [(my: Int, your: Int)]) -> Void
    let onProgressChanged: (Bool) -> Void

    @StateObject private var viewModel: ScoreViewModel
    @State private var showEditSheet = false

    init(options: MatchOptions,
         onMatchFinished: @escaping (Bool, [(my: Int, your: Int)]) -> Void,
         onProgressChanged: @escaping (Bool) -> Void = { _ in }) {
        self.options = options
        self.onMatchFinished = onMatchFinished
        self.onProgressChanged = onProgressChanged
        _viewModel = StateObject(wrappedValue: ScoreViewModel(options: options))
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

            VStack(spacing: 15) {
                if options.mode == .bestOfThree {
                    SetScores(
                        mySetScore: viewModel.mySetScore,
                        yourSetScore: viewModel.yourSetScore
                    )
                }
                GameScores(
                    myGameScore: viewModel.myGameScore,
                    yourGameScore: viewModel.yourGameScore,
                    isTieBreak: viewModel.isTieBreak
                )
            }
            .padding(.bottom, 300)

            if viewModel.score.lastAction != .none {
                VStack {
                    Spacer()
                    UndoButton(action: { viewModel.undo() })
                        .padding(.bottom, 150)
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: viewModel.isMatchOver) { _, isOver in
            if isOver { onMatchFinished(viewModel.didWin, viewModel.completedSets) }
        }
        .onChange(of: viewModel.hasProgress) { _, hasProgress in
            onProgressChanged(hasProgress)
        }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score)
        }
    }
}

#Preview {
    NavigationStack {
        ScoreView(
            options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
            onMatchFinished: { _, _ in }
        )
    }
}
```

> **변경 포인트:**
> - `format: MatchFormat` → `options: MatchOptions`
> - `ScoreViewModel(options: options)` 전달
> - `format == .bestOfThree` → `options.mode == .bestOfThree`

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|Build succeeded"
```

---

### Task 3: MatchResultView — 타입 참조 업데이트

**Files:**
- Modify: `iOSApp/Features/Match/Result/MatchResultView.swift`

- [ ] **Step 1: MatchResultView의 MatchSessionViewModel → WorkoutSessionViewModel 교체**

`MatchResultView.swift` 내 타입 참조만 변경:

```swift
// 변경 전
@ObservedObject var viewModel: MatchSessionViewModel

// 변경 후
@ObservedObject var viewModel: WorkoutSessionViewModel
```

Preview 블록도 업데이트:
```swift
// 변경 전
MatchResultView(session: session, viewModel: MatchSessionViewModel())

// 변경 후
MatchResultView(session: session, viewModel: WorkoutSessionViewModel())
```

---

### Task 4: iOSApp.swift — WorkoutSessionView로 참조 변경

**Files:**
- Modify: `iOSApp/iOSApp.swift`

- [ ] **Step 1: MatchSessionView → WorkoutSessionView 참조 교체**

`iOSApp.swift` 내 변경:

```swift
// 변경 전
MatchSessionView(onExit: {
    selectedTab = 1
    withAnimation { isMatchActive = false }
})

// 변경 후
WorkoutSessionView(onExit: {
    selectedTab = 1
    withAnimation { isMatchActive = false }
})
```

---

### Task 5: 최종 빌드 확인 및 로그 기록

- [ ] **Step 1: iOS 앱 풀 빌드**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|warning:|Build succeeded"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 린트 체크**

```bash
make lint
```

Expected: 에러 없음 (또는 기존 warning만)

- [ ] **Step 3: 변경 내용 로그 기록**

`docs/superpowers/logs/WORK_LOG.md` 또는 새 로그 파일에 변경 내용 기록.

---

## 추가 리팩토링 항목 (발견된 것)

| 항목 | 현재 상태 | 수정 방향 |
|---|---|---|
| `noAdRule` 미적용 버그 | `ModeView`에서 설정해도 `ScoreViewModel`에 전달 안 됨 | Task 2에서 수정 |
| `noTieRule` 미구현 | 6-6 타이브레이크 UI 표시만 있고 실제 점수 계산 없음 | Task 2에서 `setTieBreakMode()` 연결 + `isSetComplete` 7-6 케이스 추가 |
| `isTieBreak` 부정확 | `myGameScore == 6 && yourGameScore == 6` (항상 true at 6-6, noTieRule 무시) | Task 2에서 `score.gameMode == .tieBreak` 기반으로 변경 |
| `MatchSessionViewModel` 네이밍 | `MatchSession`은 이미 Shared Model 이름과 충돌 | Task 1에서 `WorkoutSessionViewModel`로 rename |
