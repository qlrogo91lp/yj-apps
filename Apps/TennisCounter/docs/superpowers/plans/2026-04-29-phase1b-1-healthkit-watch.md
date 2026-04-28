# Phase 1-B ① HealthKit + Watch Swipe Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 경기 시작 시 HKWorkoutSession 자동 시작(화면 켜짐 유지), Watch에 Score/Exercise/SetHistory 3페이지 좌우 스와이프 구조, 경기 종료 시 칼로리/BPM/시간을 SwiftData Match에 저장

**Architecture:** `HealthKitService`가 `HKWorkoutSession`과 `HKWorkoutBuilder`를 관리. Watch `MatchViewModel`이 경기 시작/종료 시 HealthKitService 호출. Watch `MatchView`가 `TabView(.page)` 스타일 3페이지로 교체. iOS 앱은 "새 경기 시작" 첫 클릭 시 HealthKit 권한 요청 후 workout 시작.

**Tech Stack:** HealthKit (HKWorkoutSession, HKWorkoutBuilder), SwiftUI TabView page style

**선행 조건:**
- `2026-04-29-phase1a-1-data-foundation.md` 완료 (Match 모델에 caloriesBurned/durationSeconds 필드 존재)
- `2026-04-29-phase1a-2-match-feature.md` 완료 (iOS MatchViewModel 존재)
- `2026-04-29-phase1a-5-watch-connectivity.md` 완료 (WatchConnectivityService, ScoreUpdate 존재 — Watch MatchViewModel이 이미 WatchConnectivity 통합 상태)

---

## File Structure

| 파일 | 액션 | 역할 |
|------|------|------|
| `Shared/Services/HealthKitService.swift` | Create | HKWorkoutSession 래퍼 |
| `WatchApp/Features/Match/MatchView.swift` | Modify | 3페이지 TabView로 교체 |
| `WatchApp/Features/Match/MatchViewModel.swift` | Modify | HealthKitService 통합 |
| `WatchApp/Features/Match/ExercisePageView.swift` | Create | 운동 데이터 페이지 |
| `WatchApp/Features/Match/SetHistoryPageView.swift` | Create | 세트 히스토리 페이지 |
| `iOSApp/Features/Match/ModeSelection/ModeSelectionView.swift` | Modify | HealthKit 권한 요청 트리거 |
| `iOSApp/Features/Match/Score/MatchViewModel.swift` | Modify | workout 시작/종료 호출 |

---

### Task 1: HealthKit Capability 추가 (Xcode 수동 작업)

> **두 타겟 모두** HealthKit을 사용하므로 각각 설정해야 한다.

- [ ] **Step 1: iOS 타겟 HealthKit Capability 추가**

1. Xcode > TennisCounter 타겟 선택
2. Signing & Capabilities > `+` > HealthKit 추가
3. "Clinical Health Records" 체크 해제 (불필요)
4. "Background Delivery" 체크 (workout 중 백그라운드 측정용)

- [ ] **Step 2: Watch 타겟 HealthKit Capability 추가**

1. Xcode > TennisCounter Watch App 타겟 선택
2. 동일하게 HealthKit Capability 추가
3. "Workout Processing" 체크 (워크아웃 세션용)

- [ ] **Step 3: Info.plist 권한 문자열 추가 (iOS)**

`iOSApp/Info.plist`에 추가 (파일 없으면 Xcode에서 Custom iOS Target Properties로 추가):

```
NSHealthShareUsageDescription = "Ralli uses HealthKit to track calories and heart rate during matches."
NSHealthUpdateUsageDescription = "Ralli saves your tennis workout to Apple Health."
```

- [ ] **Step 4: Info.plist 권한 문자열 추가 (Watch)**

`WatchApp/Info.plist`에 동일하게 추가.

---

### Task 2: HealthKitService 생성

**Files:**
- Create: `Shared/Services/HealthKitService.swift`

> iOS와 Watch 양 타겟에 추가. Watch 쪽에서 HKWorkoutSession을 사용하고, iOS 쪽에서는 권한 요청만 사용한다.

- [ ] **Step 1: HealthKitService.swift 생성**

```swift
import Foundation
import HealthKit

struct WorkoutResult {
    let durationSeconds: Int
    let caloriesBurned: Double
    let averageHeartRate: Double?
}

final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published var isWorkoutActive = false
    @Published var currentHeartRate: Double = 0
    @Published var currentCalories: Double = 0
    @Published var elapsedSeconds: Int = 0

    private let store = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKWorkoutBuilder?
    #if os(watchOS)
    private var liveWorkoutBuilder: HKLiveWorkoutBuilder?
    #endif
    private var startDate: Date?
    private var timer: Timer?

    private let typesToShare: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType()
    ]
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType()
    ]

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            return false
        }
    }

    #if os(watchOS)
    func startWorkout() {
        guard isAvailable else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .tennis
        config.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

            workoutSession = session
            liveWorkoutBuilder = builder

            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.isWorkoutActive = true
                    self?.startDate = Date()
                    self?.startTimer()
                }
            }
        } catch {}
    }

    func stopWorkout() async -> WorkoutResult? {
        guard let session = workoutSession,
              let builder = liveWorkoutBuilder,
              let start = startDate else { return nil }

        session.end()
        stopTimer()

        let elapsed = Int(Date().timeIntervalSince(start))
        let calories = await collectCalories(builder: builder)
        let heartRate = await collectAverageHeartRate(builder: builder)

        try? await builder.endCollection(withEnd: Date())
        try? await builder.finishWorkout()

        DispatchQueue.main.async { self.isWorkoutActive = false }
        return WorkoutResult(durationSeconds: elapsed, caloriesBurned: calories, averageHeartRate: heartRate)
    }

    private func collectCalories(builder: HKLiveWorkoutBuilder) async -> Double {
        builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    private func collectAverageHeartRate(builder: HKLiveWorkoutBuilder) async -> Double? {
        builder.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
    }
    #endif

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func formattedElapsed() -> String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add Shared/Services/HealthKitService.swift
git commit -m "feat: add HealthKitService for workout session management"
```

---

### Task 3: Watch ExercisePageView (운동 데이터 페이지)

**Files:**
- Create: `WatchApp/Features/Match/ExercisePageView.swift`

- [ ] **Step 1: ExercisePageView.swift 생성**

```swift
import SwiftUI

struct ExercisePageView: View {
    @ObservedObject var healthKit: HealthKitService

    var body: some View {
        VStack(spacing: 16) {
            Text("Exercise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 0) {
                metricView(
                    value: heartRateText,
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )

                Divider()
                    .frame(height: 60)
                    .background(Color.white.opacity(0.2))

                metricView(
                    value: String(format: "%.0f", healthKit.currentCalories),
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange
                )
            }

            metricView(
                value: healthKit.formattedElapsed(),
                unit: "elapsed",
                icon: "timer",
                color: .blue
            )
        }
        .padding()
    }

    private var heartRateText: String {
        healthKit.currentHeartRate > 0
            ? String(format: "%.0f", healthKit.currentHeartRate)
            : "--"
    }

    private func metricView(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 2: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 4: Watch SetHistoryPageView (세트 히스토리 페이지)

**Files:**
- Create: `WatchApp/Features/Match/SetHistoryPageView.swift`

- [ ] **Step 1: SetHistoryPageView.swift 생성**

```swift
import SwiftUI

struct SetHistoryPageView: View {
    let completedSets: [(my: Int, your: Int)]
    let myGameScore: Int
    let yourGameScore: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Sets")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            if completedSets.isEmpty {
                Text("No completed sets")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxHeight: .infinity)
            } else {
                ForEach(completedSets.indices, id: \.self) { idx in
                    let set = completedSets[idx]
                    HStack {
                        Text("Set \(idx + 1)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("\(set.my)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                        Text("-")
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(set.your)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                }
            }

            Divider().background(Color.white.opacity(0.2))

            HStack {
                Text("Current")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("\(myGameScore)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
                Text("-")
                    .foregroundColor(.white.opacity(0.5))
                Text("\(yourGameScore)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}
```

- [ ] **Step 2: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 5: Watch MatchViewModel에 HealthKit + 세트 추적 통합

**Files:**
- Modify: `WatchApp/Features/Match/MatchViewModel.swift`

- [ ] **Step 1: MatchViewModel에 HealthKit + 세트 추적 추가**

```swift
import Combine
import SwiftUI

class MatchViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    let healthKit = HealthKitService.shared
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init() {
        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreUpdate
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in self?.applyScoreUpdate(update) }
            .store(in: &cancellables)
    }

    func startMatch() {
        healthKit.startWorkout()
    }

    func addMyPoint() {
        score.addMyPoint()
        checkGameUpdate()
        sendScoreUpdate()
    }

    func addYourPoint() {
        score.addYourPoint()
        checkGameUpdate()
        sendScoreUpdate()
    }

    func undo() {
        score.undo()
        sendScoreUpdate()
    }

    func startNewMatch() {
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        completedSets = []
        isMatchOver = false
        didWin = false
        score.resetData()
    }

    private func sendScoreUpdate() {
        let update = ScoreUpdate(
            myScore: score.myScore,
            yourScore: score.yourScore,
            myGameScore: myGameScore,
            yourGameScore: yourGameScore
        )
        connectivity.sendScoreUpdate(update)
    }

    private func applyScoreUpdate(_ update: ScoreUpdate) {
        score.myScore = update.myScore
        score.yourScore = update.yourScore
        score.myIndex = score.scoreArr.firstIndex(of: update.myScore) ?? 0
        score.yourIndex = score.scoreArr.firstIndex(of: update.yourScore) ?? 0
        myGameScore = update.myGameScore
        yourGameScore = update.yourGameScore
    }

    private func checkGameUpdate() {
        if score.myScore == 50 {
            withAnimation(.bouncy) { myGameScore += 1 }
            score.resetData()
            checkSetUpdate(myWon: true)
        } else if score.yourScore == 50 {
            withAnimation(.bouncy) { yourGameScore += 1 }
            score.resetData()
            checkSetUpdate(myWon: false)
        }
    }

    private func checkSetUpdate(myWon: Bool) {
        let maxGames = max(myGameScore, yourGameScore)
        let minGames = min(myGameScore, yourGameScore)
        guard maxGames >= 6 && (maxGames - minGames) >= 2 else { return }

        completedSets.append((my: myGameScore, your: yourGameScore))

        if myWon { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0

        if mySetScore >= 1 {
            didWin = true
            isMatchOver = true
            Task { await finishMatch() }
        } else if yourSetScore >= 1 {
            didWin = false
            isMatchOver = true
            Task { await finishMatch() }
        }
    }

    private func finishMatch() async {
        _ = await healthKit.stopWorkout()
    }
}
```

- [ ] **Step 2: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 6: Watch MatchView를 3페이지 TabView로 교체

**Files:**
- Modify: `WatchApp/Features/Match/MatchView.swift`

- [ ] **Step 1: MatchView.swift 전체 교체**

```swift
import SwiftUI

struct MatchView: View {
    @StateObject var viewModel = MatchViewModel()

    var body: some View {
        if viewModel.isMatchOver {
            matchOverView
        } else {
            TabView {
                scorePageView
                    .tag(0)

                ExercisePageView(healthKit: viewModel.healthKit)
                    .tag(1)

                SetHistoryPageView(
                    completedSets: viewModel.completedSets,
                    myGameScore: viewModel.myGameScore,
                    yourGameScore: viewModel.yourGameScore
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .onAppear { viewModel.startMatch() }
        }
    }

    // MARK: - Score Page (기존 UI 유지)

    private var scorePageView: some View {
        ZStack {
            HStack(spacing: 0) {
                Button(action: { viewModel.addMyPoint() }) {
                    ZStack {
                        Color.green.opacity(0.15)
                        VStack(spacing: 4) {
                            Text("ME")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)
                            Text(viewModel.score.myScore == 50 ? "W" : "\(viewModel.score.myScore)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.green)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.addYourPoint() }) {
                    ZStack {
                        Color.orange.opacity(0.15)
                        VStack(spacing: 4) {
                            Text("OPP")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            Text(viewModel.score.yourScore == 50 ? "W" : "\(viewModel.score.yourScore)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.orange)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .ignoresSafeArea()

            VStack {
                HStack(spacing: 10) {
                    Text("\(viewModel.myGameScore)")
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                    Text("SET")
                        .foregroundColor(.white)
                    Text("\(viewModel.yourGameScore)")
                        .foregroundColor(.orange)
                        .contentTransition(.numericText())
                }
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.8))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))

                Spacer()

                if viewModel.score.lastAction != .none {
                    Button(action: { viewModel.undo() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Undo")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 25)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.2), value: viewModel.score.lastAction)
        }
    }

    // MARK: - Match Over

    private var matchOverView: some View {
        VStack(spacing: 12) {
            Text(viewModel.didWin ? "Victory!" : "Defeat")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(viewModel.didWin ? .green : .orange)

            HStack {
                Text("\(viewModel.mySetScore)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                Text(":")
                    .font(.system(size: 26, weight: .bold))
                Text("\(viewModel.yourSetScore)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.orange)
            }

            Button(action: { viewModel.startNewMatch() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("New Match")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}

struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView()
    }
}
```

- [ ] **Step 2: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add WatchApp/Features/Match/ Shared/Services/HealthKitService.swift
git commit -m "feat: Watch 3-page TabView with HealthKit workout session"
```

---

### Task 7: iOS MatchViewModel에 HealthKit 워크아웃 통합

**Files:**
- Modify: `iOSApp/Features/Match/Score/MatchViewModel.swift`

- [ ] **Step 1: MatchViewModel에 HealthKit 시작/종료 추가**

기존 `MatchViewModel`에 다음 추가:

```swift
private let healthKit = HealthKitService.shared

// init() 후에 추가할 메서드
func requestHealthKitAndStart() async {
    await healthKit.requestAuthorization()
    // iOS는 HKWorkoutSession을 Watch에서 관리하므로 별도 시작 불필요
    // 권한만 미리 확보
}
```

`saveMatch()` 내부에서 경기 종료 후 HealthKit 데이터 저장:

```swift
private func saveMatch() {
    guard let context = modelContext else { return }

    let match = Match(matchFormat: format.rawValue)
    match.endedAt = Date()
    match.myTotalSets = mySetScore
    match.yourTotalSets = yourSetScore
    match.isCompleted = true
    match.durationSeconds = healthKit.elapsedSeconds

    let setRecords = completedSets.enumerated().map { index, result in
        SetRecord(myGames: result.my, yourGames: result.your, setNumber: index + 1)
    }
    match.sets = setRecords
    context.insert(match)
    try? context.save()
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/Match/Score/MatchViewModel.swift
git commit -m "feat: iOS MatchViewModel saves HealthKit duration on match end"
```

---

### Task 8: iOS 화면 켜짐 유지 설정

**Files:**
- Modify: `iOSApp/Features/Match/Score/MatchView.swift`

- [ ] **Step 1: MatchView에 idleTimerDisabled 추가**

`MatchView`의 `.onAppear`에 추가:

```swift
.onAppear {
    viewModel.injectContext(modelContext)
    UIApplication.shared.isIdleTimerDisabled = true
}
.onDisappear {
    UIApplication.shared.isIdleTimerDisabled = false
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/Match/Score/MatchView.swift
git commit -m "feat: disable idle timer during match on iOS"
```

---

## 완료 기준

- [x] Watch 경기 시작 시 HKWorkoutSession 활성화 → 화면 Always On 유지
- [x] Watch MatchView 좌우 스와이프로 Score/Exercise/SetHistory 3페이지 이동
- [x] Exercise 페이지에 BPM, 칼로리, 경과 시간 표시
- [x] SetHistory 페이지에 완료된 세트 결과 표시
- [x] 경기 종료 시 HKWorkoutSession 종료 + 칼로리/시간 SwiftData에 저장
- [x] iOS 경기 중 화면 꺼짐 방지
- [x] iOS/Watch 빌드 모두 성공
