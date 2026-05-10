# Fix Early End Navigation & Workout Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 무승부(early end) 후 화면 전환이 안 되는 버그와 운동 시작 시 경과 시간이 측정되지 않는 버그를 수정한다.

**Architecture:** 두 버그 모두 HealthKit 비동기 콜백에 로직이 의존하는 구조적 문제로 발생. `finishMatch`는 navigation을 즉시 처리하도록, `startWorkout`은 타이머를 HealthKit 콜백과 독립적으로 시작하도록 수정한다.

**Tech Stack:** Swift, SwiftUI, HealthKit, Swift Testing, watchOS

---

## Root Cause 요약

| 버그 | 원인 |
|------|------|
| 무승부 후 화면 전환 안 됨 | `finishMatch`에서 `phase = .finished(session)` 이 `await healthKit.averageHeartRate(...)` 완료 후에만 실행됨. HealthKit 권한 없음/시뮬레이터 제한 시 continuation이 영원히 대기 |
| 운동 시간 측정 안 됨 | `startTimer()`가 `builder.beginCollection()` 콜백 내부에서만 호출됨. HealthKit 세션이 정상 시작되지 않으면 콜백이 안 와 타이머가 시작되지 않음 |

## 파일 구조

| 파일 | 변경 사항 |
|------|----------|
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `finishMatch` 수정 — `phase` 즉시 설정, HealthKit는 background fetch |
| `Shared/Services/HealthKitService.swift` | `startWorkout` 수정 — `startDate` + `startTimer()` HealthKit 콜백과 독립 실행 |
| `watchosTests/watchosTests.swift` | `finishMatch` phase 전환 즉시성 단위 테스트 추가 |

---

## Task 1: `finishMatch` 즉시 navigation + set score 수정

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:39-55`
- Test: `watchosTests/watchosTests.swift`

### 현재 코드 (버그 있음)

```swift
func finishMatch(result: MatchResult, completedSets: [SetScore]) {
    guard let session = _currentSession else { return }
    session.endedAt = Date()
    session.result = result
    session.completedSets = completedSets
    session.kcalAtEnd = healthKit.currentCalories

    Task {
        session.averageHeartRate = await healthKit.averageHeartRate(
            from: session.startedAt,
            to: session.endedAt ?? Date()
        )
        await MainActor.run {
            phase = .finished(session)  // ← HealthKit가 안 끝나면 영원히 안 실행
        }
    }
}
```

추가 버그: `session.mySetScore`, `session.yourSetScore` 가 한 번도 설정되지 않아 결과 화면에서 항상 0-0으로 표시됨.

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/watchosTests.swift` 를 다음으로 교체:

```swift
import Testing
@testable import TennisCounter_Watch_App

struct watchosTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    @Test @MainActor func testFinishMatchSetsPhaseImmediately() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .draw, completedSets: [])

        guard case .finished = vm.phase else {
            Issue.record("Expected .finished phase immediately after finishMatch, got \(vm.phase)")
            return
        }
    }

    @Test @MainActor func testFinishMatchPopulatesSetScores() {
        let vm = WorkoutSessionViewModel()
        vm.startMatch(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false))

        let sets = [
            SetScore(my: 6, your: 3),
            SetScore(my: 2, your: 6),
        ]
        vm.finishMatch(result: .draw, completedSets: sets)

        guard case .finished(let session) = vm.phase else {
            Issue.record("Expected .finished phase")
            return
        }
        #expect(session.mySetScore == 1)
        #expect(session.yourSetScore == 1)
    }
}
```

- [ ] **Step 2: 테스트 실행 — FAIL 확인**

```bash
xcodebuild test \
  -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:watchosTests 2>&1 | tail -30
```

예상 결과: `testFinishMatchSetsPhaseImmediately` FAIL — phase가 `.playing`으로 남아있음.
`testFinishMatchPopulatesSetScores` FAIL — session.mySetScore == 0.

- [ ] **Step 3: `finishMatch` 수정**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` 의 `finishMatch` 전체를 교체:

```swift
func finishMatch(result: MatchResult, completedSets: [SetScore]) {
    guard let session = _currentSession else { return }
    session.endedAt = Date()
    session.result = result
    session.completedSets = completedSets
    session.kcalAtEnd = healthKit.currentCalories
    session.mySetScore = completedSets.filter { $0.my > $0.your }.count
    session.yourSetScore = completedSets.filter { $0.your > $0.my }.count

    phase = .finished(session)

    Task {
        session.averageHeartRate = await healthKit.averageHeartRate(
            from: session.startedAt,
            to: session.endedAt ?? Date()
        )
    }
}
```

- [ ] **Step 4: 테스트 실행 — PASS 확인**

```bash
xcodebuild test \
  -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:watchosTests 2>&1 | tail -30
```

예상 결과: `testFinishMatchSetsPhaseImmediately` PASS, `testFinishMatchPopulatesSetScores` PASS.

- [ ] **Step 5: 빌드 확인**

```bash
xcodebuild \
  -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -10
```

예상 결과: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 커밋**

```bash
git add watchosTests/watchosTests.swift \
        WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
git commit -m "fix: finishMatch navigates immediately, populate session set scores"
```

---

## Task 2: `startWorkout` 타이머 독립 시작 수정

**Files:**
- Modify: `Shared/Services/HealthKitService.swift:55-81`

### 현재 코드 (버그 있음)

```swift
func startWorkout() {
    guard isAvailable else { return }

    let config = HKWorkoutConfiguration()
    config.activityType = .tennis
    config.locationType = .outdoor

    do {
        let session = try HKWorkoutSession(healthStore: store, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

        session.delegate = self
        builder.delegate = self

        workoutSession = session
        liveWorkoutBuilder = builder

        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.isWorkoutActive = true
                self?.startDate = Date()       // ← 콜백이 안 오면 startDate 미설정
                self?.startTimer()             // ← 콜백이 안 오면 타이머 미시작
            }
        }
    } catch {}
}
```

- [ ] **Step 1: `startWorkout` 수정**

`Shared/Services/HealthKitService.swift` 의 `startWorkout()` 함수 전체를 교체:

```swift
func startWorkout() {
    guard isAvailable else { return }

    let config = HKWorkoutConfiguration()
    config.activityType = .tennis
    config.locationType = .outdoor

    do {
        let session = try HKWorkoutSession(healthStore: store, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

        session.delegate = self
        builder.delegate = self

        workoutSession = session
        liveWorkoutBuilder = builder

        let now = Date()
        startDate = now
        startTimer()

        session.startActivity(with: now)
        builder.beginCollection(withStart: now) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.isWorkoutActive = true
            }
        }
    } catch {}
}
```

변경 요약:
- `startDate = now` 와 `startTimer()` 를 콜백 밖으로 이동 → `startWorkout()` 호출 즉시 타이머 시작
- `session.startActivity(with:)` 와 `builder.beginCollection(withStart:)` 에 동일한 `now` 사용 (일관성)
- `beginCollection` 콜백은 `isWorkoutActive` 플래그만 담당

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild \
  -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -10
```

예상 결과: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 수동 테스트**

워치 시뮬레이터에서:
1. 앱 실행 → "운동 시작" 버튼 탭
2. **WorkoutMetricsView**(오른쪽 탭)에서 경과 시간 `00:01`, `00:02`... 증가 확인
3. **MatchView**(중앙 탭)에서 모드 선택 후 경기 진행
4. EarlyEndButton(뒤로가기 버튼) 탭 → 확인 다이얼로그에서 "네" 선택
5. **MatchResultView**가 즉시 표시되고 무승부(Draw) 결과 확인

- [ ] **Step 4: 커밋**

```bash
git add Shared/Services/HealthKitService.swift
git commit -m "fix: start elapsed timer immediately on workout start, independent of HealthKit callback"
```
