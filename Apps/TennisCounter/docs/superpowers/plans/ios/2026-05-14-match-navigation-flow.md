# iOS Match Navigation Flow 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 경기 네비게이션 플로우를 재설계하고, ScoreViewModel 이름 변경, MatchResultView를 Watch 패턴(session + SaveButton + RematchButton)으로 재구현한다. ScoreInfo를 Watch처럼 GameScores / SetScores 독립 컴포넌트로 분리한다.

**Architecture:** MatchSessionViewModel이 MatchSession 생명주기(생성·수정·저장)를 전담한다. ScoreView 는 점수 렌더링만, MatchResultView 는 결과 표시와 저장 트리거만 담당한다. Workout 종료는 WorkoutTab 에서만 가능하다.

**Tech Stack:** SwiftUI, SwiftData (MatchPersistenceService), WatchConnectivity, Swift Testing

---

## 파일 변경 목록

| 파일 | 작업 |
|---|---|
| `iOSApp/Features/Match/Score/MatchViewModel.swift` | → `ScoreViewModel.swift` 이름 변경 + 클래스명 변경 + 레거시 코드 제거 |
| `iOSApp/Features/Match/Score/ScoreView.swift` | ScoreViewModel 참조, onEnd 파라미터 제거 |
| `iOSApp/Features/Match/Session/MatchSessionViewModel.swift` | `_currentSession`, `saveCurrentMatch()`, `restartMatch()` 추가 |
| `iOSApp/Features/Match/Session/MatchSessionView.swift` | 네비게이션 플로우 전면 수정 |
| `iOSApp/Features/Match/Result/MatchResultView.swift` | Watch 패턴 재설계 |
| `iOSApp/Features/Match/Result/Components/SaveButton.swift` | 신규 생성 |
| `iOSApp/Features/Match/Result/Components/RematchButton.swift` | 신규 생성 |
| `iOSApp/en.lproj/Localizable.strings` | 신규 키 추가, early_end_button 제거 |
| `iOSApp/ko.lproj/Localizable.strings` | 동일 |
| `iOSApp/Features/Match/Score/Components/GameScores.swift` | 신규 생성 — 게임 스코어 컴포넌트 |
| `iOSApp/Features/Match/Score/Components/SetScores.swift` | 신규 생성 — 세트 스코어 컴포넌트 |
| `iOSApp/Features/Match/Score/Components/ScoreInfo.swift` | 삭제 — GameScores + SetScores 로 대체 |
| `iOSApp/Features/Match/Score/ScoreView.swift` | GameScores + SetScores 직접 사용 |
| `iOSApp/Features/Match/Score/ScoreViewModel.swift` | `isTieBreak` computed property 추가 |
| `iosTests/iosTests.swift` | ScoreViewModel 참조 업데이트 + 신규 테스트 추가 |

---

## Task 1: ScoreViewModel 이름 변경 + 레거시 코드 제거

**Files:**
- Rename: `iOSApp/Features/Match/Score/MatchViewModel.swift` → `ScoreViewModel.swift`
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift`
- Modify: `iosTests/iosTests.swift`

- [ ] **Step 1: MatchViewModel.swift → ScoreViewModel.swift 파일 이름 변경**

```bash
mv iOSApp/Features/Match/Score/MatchViewModel.swift \
   iOSApp/Features/Match/Score/ScoreViewModel.swift
```

- [ ] **Step 2: ScoreViewModel.swift 전체 재작성**

`iOSApp/Features/Match/Score/ScoreViewModel.swift` 를 아래 내용으로 교체한다.  
제거 항목: `saveMatch()`, `modelContext`, `injectContext()`, `healthKit`, `requestHealthKitAndStart()`, `confirmScore()`, `import SwiftData`, `import SwiftUI`

```swift
import Combine
import Foundation

@MainActor
final class ScoreViewModel: ObservableObject {
    let format: MatchFormat

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    private var cancellable: AnyCancellable?
    private let connectivity = WatchConnectivityService.shared

    init(format: MatchFormat = .oneSet) {
        self.format = format
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

        if mySetScore >= format.setsToWin {
            didWin = true
            isMatchOver = true
        } else if yourSetScore >= format.setsToWin {
            didWin = false
            isMatchOver = true
        }
    }

    private func isSetComplete() -> Bool {
        let maxGames = max(myGameScore, yourGameScore)
        let minGames = min(myGameScore, yourGameScore)
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

- [ ] **Step 3: ScoreView.swift 에서 MatchViewModel → ScoreViewModel 교체 + 불필요 코드 제거**

`iOSApp/Features/Match/Score/ScoreView.swift` 를 아래 내용으로 교체한다.  
제거 항목: `import SwiftData`, `@Environment(\.modelContext)`, `viewModel.injectContext(modelContext)`, `onEnd` 파라미터, 툴바 "Early End" 버튼.  
`onEnd` 제거는 Task 5(MatchSessionView 수정)와 동시에 이루어지므로, 이 단계에서 `onEnd` 파라미터 제거를 포함한다.

```swift
import SwiftUI

struct ScoreView: View {
    let format: MatchFormat
    let onMatchFinished: (Bool, [(my: Int, your: Int)]) -> Void

    @StateObject private var viewModel: ScoreViewModel
    @State private var showEditSheet = false

    init(format: MatchFormat,
         onMatchFinished: @escaping (Bool, [(my: Int, your: Int)]) -> Void) {
        self.format = format
        self.onMatchFinished = onMatchFinished
        _viewModel = StateObject(wrappedValue: ScoreViewModel(format: format))
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

            VStack {
                ScoreInfo(
                    myGameScore: viewModel.myGameScore,
                    yourGameScore: viewModel.yourGameScore,
                    mySetScore: viewModel.mySetScore,
                    yourSetScore: viewModel.yourSetScore,
                    format: format
                )
                .padding(.top, 12)
                .allowsHitTesting(false)
                Spacer()
                if viewModel.score.lastAction != .none {
                    UndoButton(action: { viewModel.undo() })
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: viewModel.isMatchOver) { _, isOver in
            if isOver { onMatchFinished(viewModel.didWin, viewModel.completedSets) }
        }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score)
        }
    }
}

#Preview {
    NavigationStack {
        ScoreView(format: .oneSet, onMatchFinished: { _, _ in })
    }
}
```

- [ ] **Step 4: iosTests.swift 에서 MatchViewModel → ScoreViewModel 참조 업데이트**

`iosTests/iosTests.swift` 에서 `MatchViewModel` 을 `ScoreViewModel` 로 전체 치환한다.

```bash
sed -i '' 's/MatchViewModel/ScoreViewModel/g' iosTests/iosTests.swift
```

변경 후 해당 테스트들이 정상 빌드되는지 다음 단계에서 확인한다.

- [ ] **Step 5: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme TennisCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|warning:|BUILD"
```

Expected: `BUILD SUCCEEDED` (error 없음)

- [ ] **Step 6: Commit**

```bash
git add iOSApp/Features/Match/Score/ScoreViewModel.swift \
        iOSApp/Features/Match/Score/ScoreView.swift \
        iosTests/iosTests.swift
git commit -m "refactor: MatchViewModel → ScoreViewModel, remove legacy saveMatch"
```

---

## Task 2: MatchSessionViewModel — _currentSession, saveCurrentMatch, restartMatch

**Files:**
- Modify: `iOSApp/Features/Match/Session/MatchSessionViewModel.swift`
- Modify: `iosTests/iosTests.swift`

- [ ] **Step 1: iosTests.swift 에 실패 테스트 추가**

`iosTests/iosTests.swift` 의 `iosTests` struct 마지막에 아래를 추가한다.

```swift
// MARK: - MatchSessionViewModel 확장 테스트

@Test @MainActor func matchSessionRestartMatchUsesSameFormat() {
    let vm = MatchSessionViewModel()
    vm.startSession()
    vm.startMatch(format: .bestOfThree)
    vm.finishMatch(didWin: false, completedSets: [(my: 3, your: 6)])
    vm.restartMatch()
    guard case .playing(let options) = vm.phase else {
        Issue.record("Expected .playing after restartMatch, got \(vm.phase)")
        return
    }
    #expect(options.mode == .bestOfThree)
}

@Test @MainActor func matchSessionRestartWithoutMatchIsNoOp() {
    let vm = MatchSessionViewModel()
    vm.restartMatch()
    guard case .modeSelection = vm.phase else {
        Issue.record("Expected .modeSelection — restartMatch without prior match should be no-op")
        return
    }
}

@Test @MainActor func matchSessionSaveWithNoSessionDoesNotThrow() throws {
    let vm = MatchSessionViewModel()
    try vm.saveCurrentMatch()
}

@Test @MainActor func matchSessionFinishMatchStoresSession() {
    let vm = MatchSessionViewModel()
    vm.startSession()
    vm.startMatch(format: .oneSet)
    vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
    guard case .finished(let session) = vm.phase else {
        Issue.record("Expected .finished")
        return
    }
    #expect(session.result == .win)
    #expect(session.mySetScore == 1)
    #expect(session.yourSetScore == 0)
    #expect(session.completedSets.count == 1)
}

@Test @MainActor func matchSessionStartNewMatchClearsToModeSelection() {
    let vm = MatchSessionViewModel()
    vm.startSession()
    vm.startMatch(format: .oneSet)
    vm.finishMatch(didWin: true, completedSets: [(my: 6, your: 4)])
    vm.startNewMatch()
    guard case .modeSelection = vm.phase else {
        Issue.record("Expected .modeSelection after startNewMatch")
        return
    }
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj \
  -scheme TennisCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:iosTests 2>&1 | grep -E "Test.*failed|error:|passed|FAILED"
```

Expected: `restartMatch` 관련 테스트 실패 (메서드가 아직 없음)

- [ ] **Step 3: MatchSessionViewModel.swift 전체 교체**

```swift
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

    func startMatch(format: MatchFormat) {
        let mode = MatchMode(rawValue: format.rawValue) ?? .oneSet
        let options = MatchOptions(mode: mode, noAdRule: true, noTieRule: false)
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
        let format = MatchFormat(rawValue: options.mode.rawValue) ?? .oneSet
        startMatch(format: format)
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

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj \
  -scheme TennisCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:iosTests 2>&1 | grep -E "Test.*passed|Test.*failed|FAILED|Executed"
```

Expected: 모든 테스트 통과

- [ ] **Step 5: Commit**

```bash
git add iOSApp/Features/Match/Session/MatchSessionViewModel.swift \
        iosTests/iosTests.swift
git commit -m "feat: add _currentSession, saveCurrentMatch, restartMatch to MatchSessionViewModel"
```

---

## Task 3: SaveButton + RematchButton 컴포넌트 + Localizable 추가

**Files:**
- Create: `iOSApp/Features/Match/Result/Components/SaveButton.swift`
- Create: `iOSApp/Features/Match/Result/Components/RematchButton.swift`
- Modify: `iOSApp/en.lproj/Localizable.strings`
- Modify: `iOSApp/ko.lproj/Localizable.strings`

- [ ] **Step 1: SaveButton.swift 생성**

```swift
import SwiftUI

struct SaveButton: View {
    let saved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                Text(saved
                     ? String(localized: "result_saved")
                     : String(localized: "result_save"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(saved ? .gray : .green)
        .disabled(saved)
    }
}

#Preview {
    VStack(spacing: 16) {
        SaveButton(saved: false) {}
        SaveButton(saved: true) {}
    }
    .padding()
    .background(Color.black)
}
```

- [ ] **Step 2: RematchButton.swift 생성**

```swift
import SwiftUI

struct RematchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.2), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RematchButton {}
        .padding()
        .background(Color.black)
}
```

- [ ] **Step 3: iOSApp/en.lproj/Localizable.strings 에 신규 키 추가**

파일 말미 `/* Common */` 섹션 위에 아래를 삽입한다.

```
/* Match Result */
"result_save" = "Save";
"result_saved" = "Saved";

/* End Workout Dialog */
"end_workout_confirm_title" = "End Workout";
"end_workout_confirm_message" = "End this workout session?";
"end_workout_with_match_message" = "A match is in progress. Ending the workout will void the match result.";
```

- [ ] **Step 4: iOSApp/ko.lproj/Localizable.strings 에 신규 키 추가**

```
/* Match Result */
"result_save" = "저장";
"result_saved" = "저장됨";

/* End Workout Dialog */
"end_workout_confirm_title" = "운동 종료";
"end_workout_confirm_message" = "운동을 종료하시겠습니까?";
"end_workout_with_match_message" = "경기가 진행 중입니다. 운동을 종료하면 경기 결과가 무효됩니다.";
```

- [ ] **Step 5: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme TennisCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git add iOSApp/Features/Match/Result/Components/SaveButton.swift \
        iOSApp/Features/Match/Result/Components/RematchButton.swift \
        iOSApp/en.lproj/Localizable.strings \
        iOSApp/ko.lproj/Localizable.strings
git commit -m "feat: add SaveButton, RematchButton components and new localizable strings"
```

---

## Task 4: MatchResultView Watch 패턴 재설계

**Files:**
- Modify: `iOSApp/Features/Match/Result/MatchResultView.swift`

이 태스크는 MatchSessionView(Task 5)가 `MatchResultView` 의 새 인터페이스를 참조하기 전에 먼저 완료되어야 한다.

- [ ] **Step 1: MatchResultView.swift 전체 재작성**

```swift
import SwiftUI

struct MatchResultView: View {
    let session: MatchSession
    @ObservedObject var viewModel: MatchSessionViewModel

    @State private var saved = false
    @State private var saveError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text(resultTitle)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(resultColor)

                HStack(spacing: 12) {
                    Text("\(session.mySetScore)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                    Text(":")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(session.yourSetScore)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.orange)
                }

                if session.options.mode == .bestOfThree, !session.completedSets.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(session.completedSets.enumerated()), id: \.offset) { index, set in
                            HStack(spacing: 2) {
                                Text("\(set.my):\(set.your)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                if index < session.completedSets.count - 1 {
                                    Text("|")
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    SaveButton(saved: saved) { saveMatch() }
                    RematchButton { viewModel.restartMatch() }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private var resultTitle: String {
        switch session.result {
        case .win:  String(localized: "watch_victory")
        case .loss: String(localized: "watch_defeat")
        case .draw: String(localized: "result_draw")
        case nil:   ""
        }
    }

    private var resultColor: Color {
        switch session.result {
        case .win:  .green
        case .loss: .orange
        case .draw: .yellow
        case nil:   .white
        }
    }

    private func saveMatch() {
        do {
            try viewModel.saveCurrentMatch()
            withAnimation { saved = true }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    let session = MatchSession(
        workoutSessionId: UUID(),
        options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
        kcalAtStart: 0
    )
    session.mySetScore = 2
    session.yourSetScore = 1
    session.completedSets = [SetScore(my: 6, your: 4), SetScore(my: 3, your: 6), SetScore(my: 6, your: 3)]
    session.result = .win

    return NavigationStack {
        MatchResultView(session: session, viewModel: MatchSessionViewModel())
    }
}
```

> **Note:** `MatchResultView` 는 뒤로가기 버튼을 자체적으로 갖지 않는다. `MatchSessionView` 툴바에서 `finished` phase 의 백 버튼을 `viewModel.startNewMatch()` 로 처리한다 (Task 5).

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme TennisCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` (MatchSessionView 의 `MatchResultView` 호출부가 아직 구버전이라 타입 에러 발생 가능 — Task 5 에서 수정)

- [ ] **Step 3: Commit**

```bash
git add iOSApp/Features/Match/Result/MatchResultView.swift
git commit -m "feat: redesign MatchResultView with session+viewModel pattern (Watch parity)"
```

---

## Task 5: MatchSessionView 네비게이션 전면 수정 + Localizable early_end_button 제거

**Files:**
- Modify: `iOSApp/Features/Match/Session/MatchSessionView.swift`
- Modify: `iOSApp/en.lproj/Localizable.strings`
- Modify: `iOSApp/ko.lproj/Localizable.strings`

- [ ] **Step 1: Localizable 에서 early_end_button 키 제거 (양쪽)**

`iOSApp/en.lproj/Localizable.strings` 에서 아래 줄 삭제:
```
"early_end_button" = "Early End";
```

`iOSApp/ko.lproj/Localizable.strings` 에서 아래 줄 삭제:
```
"early_end_button" = "조기 종료";
```

- [ ] **Step 2: MatchSessionView.swift 전체 교체**

```swift
import SwiftUI

struct MatchSessionView: View {
    let onExit: () -> Void

    @StateObject private var viewModel = MatchSessionViewModel()
    @State private var selectedTab: Int = 1
    @State private var showEndMatchConfirm = false
    @State private var showEndWorkoutConfirm = false

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
                    BackButton { showEndMatchConfirm = true }
                case .finished:
                    BackButton { viewModel.startNewMatch() }
                }
            }
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEndMatchConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                viewModel.startNewMatch()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .confirmationDialog(
            String(localized: "end_workout_confirm_title"),
            isPresented: $showEndWorkoutConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                viewModel.endSession()
                onExit()
            }
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
            ModeView { format in
                viewModel.startMatch(format: format)
            }

        case .playing(let options):
            let format = MatchFormat(rawValue: options.mode.rawValue) ?? .oneSet
            ScoreView(
                format: format,
                onMatchFinished: { didWin, sets in
                    viewModel.finishMatch(didWin: didWin, completedSets: sets)
                }
            )

        case .finished(let session):
            MatchResultView(session: session, viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        MatchSessionView(onExit: {})
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme TennisCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: lint 실행**

```bash
make lint 2>&1 | grep -E "error:|warning:" | head -20
```

경고가 있으면 `make fix` 로 자동 수정 후 변경사항 확인.

- [ ] **Step 5: 전체 테스트 실행**

```bash
xcodebuild test -project TennisCounter.xcodeproj \
  -scheme TennisCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:iosTests 2>&1 | grep -E "Test.*passed|Test.*failed|Executed|FAILED"
```

Expected: 모든 테스트 통과

- [ ] **Step 6: Commit**

```bash
git add iOSApp/Features/Match/Session/MatchSessionView.swift \
        iOSApp/en.lproj/Localizable.strings \
        iOSApp/ko.lproj/Localizable.strings
git commit -m "feat: redesign match navigation flow — back button dialogs, workout/match separation"
```

---

---

## Task 6: GameScores + SetScores 컴포넌트 분리 (ScoreInfo 대체)

**Files:**
- Create: `iOSApp/Features/Match/Score/Components/GameScores.swift`
- Create: `iOSApp/Features/Match/Score/Components/SetScores.swift`
- Delete: `iOSApp/Features/Match/Score/Components/ScoreInfo.swift`
- Modify: `iOSApp/Features/Match/Score/ScoreViewModel.swift` (`isTieBreak` 추가)
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift` (ScoreInfo → GameScores + SetScores)

현재 `ScoreInfo` 는 세트 스코어와 게임 스코어를 하나의 컴포넌트에 합쳐놓은 구조다. Watch 앱처럼 각각 독립 컴포넌트로 분리해 단일 책임 원칙을 지킨다.

- [ ] **Step 1: ScoreViewModel 에 isTieBreak 추가**

`iOSApp/Features/Match/Score/ScoreViewModel.swift` 에 아래 computed property 를 `didWin` 선언 바로 아래에 추가한다.

```swift
var isTieBreak: Bool { myGameScore == 6 && yourGameScore == 6 }
```

- [ ] **Step 2: GameScores.swift 생성**

iPhone 화면 크기에 맞게 Watch(size 15) 보다 크게 조정한다.

```swift
import SwiftUI

struct GameScores: View {
    let myGameScore: Int
    let yourGameScore: Int
    let isTieBreak: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(myGameScore)")
                .foregroundColor(.green)
                .contentTransition(.numericText())
            Text(isTieBreak ? String(localized: "set_tiebreak") : ":")
                .foregroundColor(.white)
            Text("\(yourGameScore)")
                .foregroundColor(.orange)
                .contentTransition(.numericText())
        }
        .font(.system(size: 20, weight: .bold))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.75))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 12) {
        GameScores(myGameScore: 3, yourGameScore: 2, isTieBreak: false)
        GameScores(myGameScore: 6, yourGameScore: 6, isTieBreak: true)
    }
    .padding()
    .background(Color.black)
}
```

> **Localizable 확인:** `set_tiebreak` 키가 iOS Localizable.strings 에 없으면 추가한다.
> ```
> "set_tiebreak" = "TB";   // en
> "set_tiebreak" = "TB";   // ko
> ```

- [ ] **Step 3: `set_tiebreak` 키 존재 여부 확인 및 추가**

```bash
grep "set_tiebreak" iOSApp/en.lproj/Localizable.strings iOSApp/ko.lproj/Localizable.strings
```

없으면 각 파일에 `/* Match Score */` 섹션에 추가한다.

- [ ] **Step 4: SetScores.swift 생성**

세트 스코어가 0:0 이면 숨긴다 (Watch 동일 로직).

```swift
import SwiftUI

struct SetScores: View {
    let mySetScore: Int
    let yourSetScore: Int

    var body: some View {
        if mySetScore > 0 || yourSetScore > 0 {
            HStack(spacing: 8) {
                Text("\(mySetScore)")
                    .foregroundColor(.green.opacity(0.85))
                Text(String(localized: "watch_set_label"))
                    .foregroundColor(.white.opacity(0.45))
                Text("\(yourSetScore)")
                    .foregroundColor(.orange.opacity(0.85))
            }
            .font(.system(size: 18, weight: .medium))
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SetScores(mySetScore: 0, yourSetScore: 0) // 숨겨짐
        SetScores(mySetScore: 1, yourSetScore: 0)
        SetScores(mySetScore: 1, yourSetScore: 1)
    }
    .padding()
    .background(Color.black)
}
```

> **Localizable 확인:** `watch_set_label` 키가 iOS Localizable.strings 에 없으면 추가한다.
> ```
> "watch_set_label" = "SET";   // en
> "watch_set_label" = "SET";   // ko
> ```

- [ ] **Step 5: `watch_set_label` 키 존재 여부 확인 및 추가**

```bash
grep "watch_set_label" iOSApp/en.lproj/Localizable.strings iOSApp/ko.lproj/Localizable.strings
```

없으면 각 파일에 추가한다.

- [ ] **Step 6: ScoreView.swift 에서 ScoreInfo → GameScores + SetScores 교체**

`ScoreView.body` 의 VStack 안에서 `ScoreInfo(...)` 호출 부분을 아래로 교체한다.

```swift
// 변경 전
ScoreInfo(
    myGameScore: viewModel.myGameScore,
    yourGameScore: viewModel.yourGameScore,
    mySetScore: viewModel.mySetScore,
    yourSetScore: viewModel.yourSetScore,
    format: format
)
.padding(.top, 12)
.allowsHitTesting(false)

// 변경 후
VStack(spacing: 6) {
    if format == .bestOfThree {
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
.padding(.top, 12)
.allowsHitTesting(false)
```

- [ ] **Step 7: ScoreInfo.swift 파일 삭제**

```bash
rm iOSApp/Features/Match/Score/Components/ScoreInfo.swift
```

- [ ] **Step 8: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme TennisCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 9: Commit**

```bash
git add iOSApp/Features/Match/Score/Components/GameScores.swift \
        iOSApp/Features/Match/Score/Components/SetScores.swift \
        iOSApp/Features/Match/Score/ScoreView.swift \
        iOSApp/Features/Match/Score/ScoreViewModel.swift \
        iOSApp/en.lproj/Localizable.strings \
        iOSApp/ko.lproj/Localizable.strings
git rm iOSApp/Features/Match/Score/Components/ScoreInfo.swift
git commit -m "refactor: split ScoreInfo into GameScores + SetScores components (Watch parity)"
```

---

## 자가 검토 결과

**스펙 커버리지:**

| 스펙 요구사항 | 태스크 |
|---|---|
| modeSelection 뒤로가기 → WorkoutTab | Task 5 (toolbar modeSelection case) |
| playing 뒤로가기 → "경기 종료" 다이얼로그 → ModeView | Task 5 (showEndMatchConfirm) |
| ScoreView "조기 종료" 버튼 제거 | Task 1 (ScoreView rewrite) |
| WorkoutTab End → phase별 다이얼로그 | Task 5 (showEndWorkoutConfirm) |
| MatchResultView → session + viewModel 패턴 | Task 4 |
| SaveButton (저장 + 중복 방지) | Task 3 + Task 4 |
| RematchButton (같은 포맷 재시작) | Task 3 + Task 4 |
| MatchResultView 종료 → ModeView (Workout 유지) | Task 4 (navigationBarBackButtonHidden) + Task 5 (finished back button) |
| MatchViewModel → ScoreViewModel 이름 변경 | Task 1 |
| saveMatch() 레거시 제거 | Task 1 |
| MatchSessionViewModel _currentSession 추가 | Task 2 |
| 신규 Localizable 키 | Task 3, 5 |
| 테스트: restartMatch, saveCurrentMatch, finishMatch | Task 2 |
| GameScores 컴포넌트 (isTieBreak 지원) | Task 6 |
| SetScores 컴포넌트 (0:0 숨김) | Task 6 |
| ScoreInfo 삭제 + ScoreView 교체 | Task 6 |
| isTieBreak computed property (ScoreViewModel) | Task 6 |
