# iOS 경기 화면 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 경기 탭에 Watch 스타일 탭 기반 경기 화면 구현 — 전체화면 진입, [운동|경기] 탭, Watch 연동 시 메트릭 표시.

**Architecture:** `ModeSelectionView` → `NavigationLink` → `MatchContainerView`. `MatchContainerView`는 `.toolbar(.hidden, for: .tabBar)`로 앱 탭바를 숨기고 매치 전용 `TabView([운동|경기])`를 표시한다. `WatchConnectivityService`가 Watch 메트릭을 수신하면 운동 탭에 표시, 미연결 시 운동 탭 자체를 숨긴다.

**Tech Stack:** SwiftUI, SwiftData, WatchConnectivity, Combine, Swift Testing

---

## 파일 구조

```
신규 생성:
  Shared/Models/WorkoutMetrics.swift
  iOSApp/Features/Match/Session/MatchContainerView.swift
  iOSApp/Features/Match/Session/MatchContainerViewModel.swift
  iOSApp/Features/Match/Session/Workout/WorkoutTabView.swift
  iOSApp/Features/Match/Session/Score/ScoreTabView.swift
  iOSApp/Features/Match/Session/Score/Components/PlayerScoreZone.swift
  iOSApp/Features/Match/Session/Score/Components/ScoreOverlay.swift
  iOSApp/Features/Match/Session/Score/Components/ScoreEditSheet.swift

수정:
  Shared/Services/WatchConnectivityService.swift  — isWatchReachable, receivedMetrics 추가
  iOSApp/Features/Match/Score/MatchViewModel.swift — addPoint(), undo() 추가
  iOSApp/Features/Match/Mode/ModeSelectionView.swift — NavigationLink 대상 변경
  iosTests/iosTests.swift — 테스트 추가
```

---

### Task 1: WorkoutMetrics 모델 + WatchConnectivityService 확장

**Files:**
- Create: `Shared/Models/WorkoutMetrics.swift`
- Modify: `Shared/Services/WatchConnectivityService.swift`
- Test: `iosTests/iosTests.swift`

- [ ] **Step 1: WorkoutMetrics 모델 작성**

`Shared/Models/WorkoutMetrics.swift` 생성:

```swift
import Foundation

struct WorkoutMetrics {
    var elapsedSeconds: TimeInterval
    var calories: Double
    var heartRate: Double

    static let messageKey = "workoutMetrics"
    private static let keysElapsed = "elapsed"
    private static let keysCalories = "calories"
    private static let keysHeartRate = "heartRate"

    func toDictionary() -> [String: Any] {
        [Self.keysElapsed: elapsedSeconds,
         Self.keysCalories: calories,
         Self.keysHeartRate: heartRate]
    }

    init(elapsedSeconds: TimeInterval = 0, calories: Double = 0, heartRate: Double = 0) {
        self.elapsedSeconds = elapsedSeconds
        self.calories = calories
        self.heartRate = heartRate
    }

    init?(from dict: [String: Any]) {
        guard let elapsed = dict[Self.keysElapsed] as? TimeInterval else { return nil }
        elapsedSeconds = elapsed
        calories = dict[Self.keysCalories] as? Double ?? 0
        heartRate = dict[Self.keysHeartRate] as? Double ?? 0
    }

    var formattedElapsed: String {
        let total = Int(elapsedSeconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
```

- [ ] **Step 2: WatchConnectivityService 확장**

`Shared/Services/WatchConnectivityService.swift` 수정 — `@Published` 프로퍼티 2개 추가, delegate 메서드 확장:

```swift
import Combine
import Foundation
import WatchConnectivity

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var receivedScoreUpdate: ScoreUpdate?
    @Published var isWatchReachable: Bool = false        // 추가
    @Published var receivedMetrics: WorkoutMetrics?      // 추가

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendScoreUpdate(_ update: ScoreUpdate) {
        guard WCSession.default.activationState == .activated else { return }
        #if os(iOS)
        guard WCSession.default.isWatchAppInstalled else { return }
        #endif

        let message = update.toDictionary()

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let metricsDict = message[WorkoutMetrics.messageKey] as? [String: Any],
               let metrics = WorkoutMetrics(from: metricsDict) {
                self.receivedMetrics = metrics
            } else if let update = ScoreUpdate(from: message) {
                self.receivedScoreUpdate = update
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedScoreUpdate = ScoreUpdate(from: applicationContext)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}

// ScoreUpdate — 기존 유지
struct ScoreUpdate {
    let myScore: Int
    let yourScore: Int
    let myGameScore: Int
    let yourGameScore: Int

    func toDictionary() -> [String: Any] {
        ["my": myScore, "your": yourScore, "myGame": myGameScore, "yourGame": yourGameScore]
    }

    init(myScore: Int, yourScore: Int, myGameScore: Int, yourGameScore: Int) {
        self.myScore = myScore
        self.yourScore = yourScore
        self.myGameScore = myGameScore
        self.yourGameScore = yourGameScore
    }

    init?(from dict: [String: Any]) {
        guard let my = dict["my"] as? Int,
              let your = dict["your"] as? Int,
              let myGame = dict["myGame"] as? Int,
              let yourGame = dict["yourGame"] as? Int else { return nil }
        myScore = my
        yourScore = your
        myGameScore = myGame
        yourGameScore = yourGame
    }
}
```

- [ ] **Step 3: 테스트 작성**

`iosTests/iosTests.swift` 수정:

```swift
import Testing
@testable import TennisCounter

struct iosTests {
    @Test func example() async throws {}

    // MARK: - WorkoutMetrics

    @Test func workoutMetricsParseValidDict() {
        let dict: [String: Any] = ["elapsed": 123.0, "calories": 456.0, "heartRate": 78.0]
        let metrics = WorkoutMetrics(from: dict)
        #expect(metrics != nil)
        #expect(metrics?.elapsedSeconds == 123.0)
        #expect(metrics?.calories == 456.0)
        #expect(metrics?.heartRate == 78.0)
    }

    @Test func workoutMetricsParsePartialDict() {
        let dict: [String: Any] = ["elapsed": 60.0]
        let metrics = WorkoutMetrics(from: dict)
        #expect(metrics != nil)
        #expect(metrics?.calories == 0)
        #expect(metrics?.heartRate == 0)
    }

    @Test func workoutMetricsParseEmptyDict() {
        let metrics = WorkoutMetrics(from: [:])
        #expect(metrics == nil)
    }

    @Test func workoutMetricsFormattedElapsed() {
        let metrics = WorkoutMetrics(elapsedSeconds: 3724)
        #expect(metrics.formattedElapsed == "62:04")
    }
}
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add Shared/Models/WorkoutMetrics.swift Shared/Services/WatchConnectivityService.swift iosTests/iosTests.swift
git commit -m "feat: WorkoutMetrics 모델 및 WatchConnectivity 메트릭 수신 추가"
```

---

### Task 2: iOS MatchViewModel — addPoint / undo 추가

**Files:**
- Modify: `iOSApp/Features/Match/Score/MatchViewModel.swift`
- Test: `iosTests/iosTests.swift`

- [ ] **Step 1: 테스트 먼저 작성**

`iosTests/iosTests.swift` 의 `struct iosTests` 안에 추가:

```swift
// MARK: - MatchViewModel addPoint

@Test func addPointWinsGame() {
    let vm = MatchViewModel(format: .oneSet)
    // 4번 탭하면 게임 승리 (noAdRule=true 기본값: 0→15→30→40→win)
    vm.addPoint(.me)
    vm.addPoint(.me)
    vm.addPoint(.me)
    vm.addPoint(.me)
    #expect(vm.myGameScore == 1)
    #expect(vm.score.myDisplayScore == "0")
}

@Test func addPointOpponentWinsGame() {
    let vm = MatchViewModel(format: .oneSet)
    vm.addPoint(.opponent)
    vm.addPoint(.opponent)
    vm.addPoint(.opponent)
    vm.addPoint(.opponent)
    #expect(vm.yourGameScore == 1)
}

@Test func addPointUndoResetsScore() {
    let vm = MatchViewModel(format: .oneSet)
    vm.addPoint(.me) // 15-0
    vm.undo()
    #expect(vm.score.myDisplayScore == "0")
    #expect(vm.score.lastAction == .none)
}

@Test func addPointMatchOver() {
    let vm = MatchViewModel(format: .oneSet)
    // oneSet: 6게임 이기면 매치 종료
    for _ in 0..<6 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
    }
    #expect(vm.isMatchOver == true)
    #expect(vm.didWin == true)
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "addPoint|FAILED|error:"
```

Expected: `addPointWinsGame` 등 실패 (addPoint 미구현)

- [ ] **Step 3: MatchViewModel에 addPoint / undo 추가**

`iOSApp/Features/Match/Score/MatchViewModel.swift` 에서 `confirmScore()` 아래에 추가:

```swift
func addPoint(_ side: PlayerSide) {
    guard score.addPoint(side) != nil else { return }
    if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
    score.resetData()
    sendScoreUpdate()
    checkSetUpdate()
}

func undo() {
    score.undo()
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test.*passed|FAILED"
```

Expected: 추가한 4개 테스트 모두 passed

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/Score/MatchViewModel.swift iosTests/iosTests.swift
git commit -m "feat: iOS MatchViewModel에 addPoint / undo 추가"
```

---

### Task 3: PlayerScoreZone 컴포넌트

**Files:**
- Create: `iOSApp/Features/Match/Session/Score/Components/PlayerScoreZone.swift`

- [ ] **Step 1: PlayerScoreZone 작성**

```swift
import SwiftUI

struct PlayerScoreZone: View {
    let displayScore: String
    let playerLabel: String
    let color: Color
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack {
            color.opacity(0.15)
            VStack(spacing: 8) {
                Text(playerLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                Text(displayScore)
                    .font(.system(size: 72, weight: .heavy))
                    .foregroundColor(color)
                    .contentTransition(.numericText())
            }
        }
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
    }
}

#Preview {
    HStack(spacing: 0) {
        PlayerScoreZone(displayScore: "40", playerLabel: "나", color: .green, onTap: {}, onLongPress: {})
        PlayerScoreZone(displayScore: "15", playerLabel: "상대", color: .orange, onTap: {}, onLongPress: {})
    }
    .ignoresSafeArea()
    .background(.black)
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/Match/Session/Score/Components/PlayerScoreZone.swift
git commit -m "feat: PlayerScoreZone 컴포넌트 추가"
```

---

### Task 4: ScoreOverlay 컴포넌트

**Files:**
- Create: `iOSApp/Features/Match/Session/Score/Components/ScoreOverlay.swift`

- [ ] **Step 1: ScoreOverlay 작성**

```swift
import SwiftUI

struct ScoreOverlay: View {
    let myGameScore: Int
    let yourGameScore: Int
    let mySetScore: Int
    let yourSetScore: Int
    let format: MatchFormat
    let showUndo: Bool
    let onUndo: () -> Void

    var body: some View {
        VStack {
            scoreInfo
                .padding(.top, 12)
            Spacer()
            if showUndo {
                undoButton
                    .padding(.bottom, 20)
            }
        }
        .allowsHitTesting(false)
    }

    private var scoreInfo: some View {
        VStack(spacing: 4) {
            if format == .bestOfThree {
                HStack(spacing: 8) {
                    Text("\(mySetScore)")
                        .foregroundColor(.green)
                    Text("–")
                        .foregroundColor(.secondary)
                    Text("\(yourSetScore)")
                        .foregroundColor(.orange)
                }
                .font(.system(size: 16, weight: .bold))
            }
            HStack(spacing: 8) {
                Text("\(myGameScore)")
                    .foregroundColor(.green.opacity(0.7))
                Text("–")
                    .foregroundColor(.secondary)
                Text("\(yourGameScore)")
                    .foregroundColor(.orange.opacity(0.7))
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var undoButton: some View {
        Button(action: onUndo) {
            Label(String(localized: "btn_undo"), systemImage: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.white.opacity(0.1), in: Capsule())
        }
        .allowsHitTesting(true)
    }
}
```

- [ ] **Step 2: `btn_undo` 로컬라이제이션 키 확인**

```bash
grep -r "btn_undo" iOSApp/ --include="*.strings" --include="*.xcstrings"
```

없으면 strings 파일에 추가: `"btn_undo" = "되돌리기";`

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Session/Score/Components/ScoreOverlay.swift
git commit -m "feat: ScoreOverlay 컴포넌트 추가"
```

---

### Task 5: ScoreEditSheet 컴포넌트

**Files:**
- Create: `iOSApp/Features/Match/Session/Score/Components/ScoreEditSheet.swift`

- [ ] **Step 1: ScoreEditSheet 작성**

`Score.myIndex` / `Score.yourIndex` 는 0-4 범위의 writable 프로퍼티 (0=0, 1=15, 2=30, 3=40, 4=AD).

```swift
import SwiftUI

struct ScoreEditSheet: View {
    @ObservedObject var score: Score
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text(String(localized: "score_edit_title"))
                .font(.headline)
                .padding(.top, 8)

            HStack(spacing: 32) {
                stepperGroup(
                    label: String(localized: "watch_score_me"),
                    color: .green,
                    displayScore: score.myDisplayScore,
                    onMinus: { score.myIndex = max(0, score.myIndex - 1) },
                    onPlus:  { score.myIndex = min(4, score.myIndex + 1) }
                )
                stepperGroup(
                    label: String(localized: "watch_score_opp"),
                    color: .orange,
                    displayScore: score.yourDisplayScore,
                    onMinus: { score.yourIndex = max(0, score.yourIndex - 1) },
                    onPlus:  { score.yourIndex = min(4, score.yourIndex + 1) }
                )
            }
            .padding(.horizontal, 32)

            Button(String(localized: "btn_confirm")) { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 8)
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }

    private func stepperGroup(
        label: String,
        color: Color,
        displayScore: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            HStack(spacing: 16) {
                Button(action: onMinus) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(color.opacity(0.7))
                }
                Text(displayScore)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(color)
                    .frame(minWidth: 44)
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(color.opacity(0.7))
                }
            }
        }
    }
}
```

- [ ] **Step 2: localisation 키 확인 — `score_edit_title` 키가 없으면 추가**

```bash
grep -r "score_edit_title" iOSApp/ --include="*.strings" --include="*.xcstrings"
```

키가 없으면 기존 `.xcstrings` 또는 `Localizable.strings` 파일에 `"score_edit_title" = "점수 수정";` 추가.

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Session/Score/Components/ScoreEditSheet.swift
git commit -m "feat: ScoreEditSheet (long press 점수 수정 시트) 추가"
```

---

### Task 6: ScoreTabView

**Files:**
- Create: `iOSApp/Features/Match/Session/Score/ScoreTabView.swift`

- [ ] **Step 1: ScoreTabView 작성**

매치 종료 시 결과 화면은 기존 `MatchView.matchOverView` 패턴을 인라인으로 유지한다. `MatchResultView`는 별도 스펙에서 구현 예정.

```swift
import SwiftData
import SwiftUI

struct ScoreTabView: View {
    let format: MatchFormat

    @StateObject private var viewModel: MatchViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showEarlyEndConfirm = false

    init(format: MatchFormat) {
        self.format = format
        _viewModel = StateObject(wrappedValue: MatchViewModel(format: format))
    }

    var body: some View {
        Group {
            if viewModel.isMatchOver {
                matchOverView
            } else {
                scoreView
            }
        }
        .onAppear { viewModel.injectContext(modelContext) }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score)
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEarlyEndConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                dismiss()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
    }

    // MARK: - Score view

    private var scoreView: some View {
        ZStack {
            HStack(spacing: 0) {
                PlayerScoreZone(
                    displayScore: viewModel.score.myDisplayScore,
                    playerLabel: String(localized: "watch_score_me"),
                    color: .green,
                    onTap: { viewModel.addPoint(.me) },
                    onLongPress: { showEditSheet = true }
                )
                PlayerScoreZone(
                    displayScore: viewModel.score.yourDisplayScore,
                    playerLabel: String(localized: "watch_score_opp"),
                    color: .orange,
                    onTap: { viewModel.addPoint(.opponent) },
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
                Button(String(localized: "early_end_button")) {
                    showEarlyEndConfirm = true
                }
                .font(.system(size: 14))
            }
        }
    }

    // MARK: - Match over view

    private var matchOverView: some View {
        VStack(spacing: 20) {
            Text(viewModel.didWin
                 ? String(localized: "match_over_win")
                 : String(localized: "match_over_lose"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(viewModel.didWin ? .green : .orange)

            HStack(spacing: 24) {
                ForEach(viewModel.completedSets.indices, id: \.self) { idx in
                    let set = viewModel.completedSets[idx]
                    VStack(spacing: 2) {
                        Text("Set \(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text("\(set.my)").foregroundColor(.green)
                            Text("–").foregroundColor(.secondary)
                            Text("\(set.your)").foregroundColor(.orange)
                        }
                        .font(.system(size: 18, weight: .bold))
                    }
                }
            }

            Button(action: {
                viewModel.resetAll()
                dismiss()
            }) {
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
        }
        .padding()
    }
}
```

- [ ] **Step 2: `early_end_button` 로컬라이제이션 키 확인**

```bash
grep -r "early_end_button\|early_end_confirm" iOSApp/ --include="*.strings" --include="*.xcstrings"
```

없으면 기존 strings 파일에 추가:
- `"early_end_button" = "조기 종료";`
- `"early_end_confirm_title"`, `"early_end_confirm_yes"`, `"early_end_confirm_message"` 가 없으면 동일하게 추가.

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Session/Score/ScoreTabView.swift
git commit -m "feat: ScoreTabView (Watch 스타일 탭 기반 스코어 화면) 추가"
```

---

### Task 7: WorkoutTabView

**Files:**
- Create: `iOSApp/Features/Match/Session/Workout/WorkoutTabView.swift`

- [ ] **Step 1: WorkoutTabView 작성**

Watch `WorkoutMetricsView`와 동일한 색상 및 레이아웃. `metrics`는 `MatchContainerViewModel`에서 주입받는다.

```swift
import SwiftUI

struct WorkoutTabView: View {
    let metrics: WorkoutMetrics
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            metricsList
            Spacer()
            controlButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black.ignoresSafeArea())
    }

    private var metricsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metrics.formattedElapsed)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)
                .contentTransition(.numericText())

            HStack(alignment: .bottom, spacing: 6) {
                Text(String(format: "%.0f", metrics.calories))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("kcal")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.bottom, 4)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .bottom, spacing: 6) {
                Text(metrics.heartRate > 0 ? String(format: "%.0f", metrics.heartRate) : "--")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Image(systemName: metrics.heartRate > 0 ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .padding(.bottom, 4)
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: onPauseResume) {
                Label(String(localized: "workout_pause"), systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.yellow)

            Button(role: .destructive, action: onEnd) {
                Label(String(localized: "workout_end"), systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

#Preview {
    WorkoutTabView(
        metrics: WorkoutMetrics(elapsedSeconds: 1523, calories: 245, heartRate: 102),
        onPauseResume: {},
        onEnd: {}
    )
}
```

- [ ] **Step 2: 로컬라이제이션 키 확인**

```bash
grep -r "workout_pause\|workout_end" iOSApp/ --include="*.strings" --include="*.xcstrings"
```

없으면 strings 파일에 추가:
- `"workout_pause" = "일시정지";`
- `"workout_end" = "운동 종료";`

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Session/Workout/WorkoutTabView.swift
git commit -m "feat: WorkoutTabView (운동 메트릭 + 제어 버튼) 추가"
```

---

### Task 8: MatchContainerViewModel + MatchContainerView

**Files:**
- Create: `iOSApp/Features/Match/Session/MatchContainerViewModel.swift`
- Create: `iOSApp/Features/Match/Session/MatchContainerView.swift`

- [ ] **Step 1: MatchContainerViewModel 작성**

```swift
import Combine
import Foundation

@MainActor
final class MatchContainerViewModel: ObservableObject {
    @Published var watchConnected: Bool = false
    @Published var metrics: WorkoutMetrics = WorkoutMetrics()

    private var cancellables = Set<AnyCancellable>()

    init() {
        let service = WatchConnectivityService.shared

        service.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$watchConnected)

        service.$receivedMetrics
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .assign(to: &$metrics)
    }
}
```

- [ ] **Step 2: MatchContainerView 작성**

```swift
import SwiftUI

struct MatchContainerView: View {
    let format: MatchFormat

    @StateObject private var viewModel = MatchContainerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 앱 하단 탭 숨김: MatchContainerView가 NavigationStack에 push될 때
        // .toolbar(.hidden, for: .tabBar)를 outer TabView(앱 탭바)에 전달한다.
        // inner TabView 자체에 붙이면 inner 탭바를 숨길 위험이 있으므로
        // Group으로 래핑해서 modifier를 분리한다.
        Group {
            TabView {
                if viewModel.watchConnected {
                    WorkoutTabView(
                        metrics: viewModel.metrics,
                        onPauseResume: {},
                        onEnd: { dismiss() }
                    )
                    .tabItem {
                        Label(String(localized: "tab_workout"), systemImage: "figure.run")
                    }
                }

                ScoreTabView(format: format)
                    .tabItem {
                        Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                    }
            }
        }
        .toolbar(.hidden, for: .tabBar)        // 앱 하단 탭 숨김 (outer TabView 대상)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MatchContainerView(format: .bestOfThree)
    }
}
```

- [ ] **Step 3: `tab_workout` 로컬라이제이션 키 확인**

```bash
grep -r "tab_workout\|tab_match" iOSApp/ --include="*.strings" --include="*.xcstrings"
```

`tab_workout`이 없으면 strings 파일에 추가: `"tab_workout" = "운동";`
`tab_match`는 기존에 있으면 유지.

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/Session/MatchContainerViewModel.swift \
        iOSApp/Features/Match/Session/MatchContainerView.swift
git commit -m "feat: MatchContainerView / MatchContainerViewModel 추가"
```

---

### Task 9: ModeSelectionView 연결

**Files:**
- Modify: `iOSApp/Features/Match/Mode/ModeSelectionView.swift`

현재 `ModeSelectionView.swift`의 `navigationDestination` 대상을 `MatchContainerView`로 교체한다.

- [ ] **Step 1: ModeSelectionView 수정**

```swift
// 기존:
.navigationDestination(for: MatchFormat.self) { format in
    MatchView(format: format)
}

// 변경:
.navigationDestination(for: MatchFormat.self) { format in
    MatchContainerView(format: format)
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 전체 테스트 실행**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "passed|failed|error:"
```

Expected: 전체 테스트 passed

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Mode/ModeSelectionView.swift
git commit -m "feat: 경기 탭 매치 진입 → MatchContainerView로 연결"
```
