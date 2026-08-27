# 총 칼로리 (활동/총 구분) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 애플 운동 앱처럼 **활동 칼로리**와 **총 칼로리(활동+휴식)**를 구분해 라이브 화면과 경기 기록 양쪽에 보여준다.

**Architecture:** `HKLiveWorkoutDataSource`는 테니스 종목에서 `basalEnergyBurned`(휴식 에너지)를 이미 자동 수집한다. ralli-kit `WorkoutCore`가 그 통계를 `currentBasalCalories`로 노출하고, Watch의 `WorkoutSessionViewModel`이 활동+휴식을 합쳐 브로드캐스트한다. 앱 레이어의 `WorkoutMetrics`·`MatchEndMessage`·`Match`에 총 칼로리 필드를 **하위호환으로** 추가한다 (키가 없으면 활동 칼로리로 폴백).

**Tech Stack:** HealthKit(`HKLiveWorkoutBuilder`), Swift Package(ralli-kit `WorkoutCore`), SwiftData, WatchConnectivity, Swift Testing.

**연관 문서:** `docs/superpowers/specs/2026-07-30-post-persistence-app-improvements-design.md` (① 절)

## Global Constraints

- **선행 조건**: `docs/superpowers/plans/2026-07-30-ralli-kit-persistence-core.md`(Plan 3) 완료. `docs/superpowers/plans/2026-07-30-match-wide-undo.md`(② undo)는 파일이 겹치지 않으므로 순서 의존은 없다.
- **이 머신의 destination** (2026-07-30 확인. 배포 타겟 26.4라 26.5 런타임 사용. 이름이 여러 런타임에 중복되므로 **반드시 `id=`로 지정**):
  - `<IOS_DEST>` = `platform=iOS Simulator,id=CB44AC14-F009-482F-9F4B-712B87A1CB72` (iPhone 17 Pro, iOS 26.5)
  - `<WATCH_DEST>` = `platform=watchOS Simulator,id=D7B72A34-B290-40CE-ADF1-6076F5DB23D0` (Apple Watch Series 11 46mm, watchOS 26.5)
- **ralli-kit 로컬 클론**: `/Users/yj/Workspace/ralli-kit` (테니스 레포의 형제 폴더여야 pbxproj의 `XCLocalSwiftPackageReference "../ralli-kit"`가 해석된다). Task 1은 **이 레포에서** 작업하고 **별도로 커밋**한다.
- **칼로리 의미 규약** (화면마다 기존 이웃 값과 같은 스코프를 쓴다 — 이 계획에서 통일하지 않는다):
  - Watch 메트릭 화면: **워크아웃 전체** 누적 (`healthKit.currentCalories` 기준, 기존 그대로)
  - 브로드캐스트 `WorkoutMetrics` / 경기 기록 `Match`: **경기 구간** (시작값 차감, 기존 그대로)
- **`basalEnergyBurned`를 `typesToShare`·`typesToRead` 양쪽에 넣는다.** 라이브 빌더가 수집한 샘플을 워크아웃에 저장하려면 share 권한이 필요하다. 이 변경으로 **기존 사용자에게 HealthKit 권한 시트가 다시 뜬다** — 의도된 동작이다.
- **시뮬레이터로는 basal 수집을 검증할 수 없다.** HealthKit 워크아웃 세션이 시뮬레이터에서 동작하지 않으므로, 실제 값 확인은 Task 7(실기기)에서만 가능하다. 그 전 태스크들은 직렬화·계산·표시 로직만 검증한다.
- 테스트 프레임워크: Swift Testing. ViewModel 테스트는 `@Test @MainActor`.
- 각 태스크 종료 시 관련 타겟 빌드 + 테스트 그린. 마지막 코드 태스크에서 양 타겟 Release 빌드 확인.
- 린트/포맷: 각 코드 태스크 마지막에 `make fix && make lint` 위반 0건 (테니스 레포). SwiftFormat — 4-space indent, max width 150, 알파벳 순 import.
- 커밋: gitmoji + 한국어. 계획·스펙 문서는 사용자 검토 전까지 커밋하지 않는다.

## File Structure

| 파일 | 역할 | 태스크 |
|---|---|---|
| `~/Workspace/ralli-kit/Sources/WorkoutCore/WorkoutSessionService.swift` | basal 통계 수집·노출 | 1 |
| `~/Workspace/ralli-kit/Sources/WorkoutCore/WorkoutResult.swift` | 종료 결과에 총 칼로리 | 1 |
| `~/Workspace/ralli-kit/Tests/WorkoutCoreTests/*` | 패키지 테스트 | 1 |
| `~/Workspace/ralli-kit/README.md` | 사용법 갱신 | 1 |
| `Shared/Models/WorkoutMetrics.swift` | `totalCalories` 추가, 죽은 `steps` 제거 | 2, 3 |
| `Shared/Models/MatchSession.swift` | 경기 구간 총 칼로리 시작·종료값 | 2 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 총 칼로리 계산·브로드캐스트 | 2 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 수신 반영 + 저장 경로 | 2, 4 |
| `WatchApp/Features/Workout/Metrics/WorkoutMetricsView.swift` | Watch 총 칼로리 줄 | 3 |
| `iOSApp/Features/Workout/Components/WorkoutMetricsGrid.swift` | 걸음 카드 → 총 칼로리 카드 | 3 |
| `{iOSApp,WatchApp}/{en,ko}.lproj/Localizable.strings` | 문자열 추가·제거 | 3 |
| `Shared/Services/ConnectivityMessages.swift` | `MatchEndMessage.totalCalories` | 4 |
| `Shared/Persistence/Match.swift` | `totalCaloriesBurned` | 4 |
| `iOSApp/Features/History/Components/MatchDetailSheet.swift` | 기록 상세 표시 | 4 |

**태스크 경계의 근거**: Task 1은 별도 레포라 자연스러운 경계. Task 2는 데이터가 흐르게 만드는 최소 단위(모델+계산+전송)로, 여기까지는 화면에 안 보인다. Task 3에서 눈에 보이게 하고 동시에 죽은 `steps`를 치운다. Task 4는 영속화라 실패해도 라이브 표시는 살아남는다. Task 5(Summary 집계)는 Task 4의 저장 필드에만 의존하는 표시 계층이라 마지막에 붙인다.

| 태스크 | 산출물 |
|---|---|
| 1 | ralli-kit이 basal을 노출 (별도 레포 커밋) |
| 2 | 총 칼로리가 워치→폰으로 흐름 (아직 화면엔 없음) |
| 3 | 라이브 화면에 표시 + 걸음 제거 |
| 4 | 경기 기록에 저장 + History 상세 표시 |
| 5 | Summary 집계 |
| 6 | CLAUDE.md 갱신 |
| 7 | 실기기 검증 (게이트) |

---

### Task 1: ralli-kit WorkoutCore에 basal(휴식) 칼로리 추가

**⚠️ 작업 디렉터리가 `/Users/yj/Workspace/ralli-kit`다.** 테니스 레포가 아니다.

**Files:**
- Modify: `Sources/WorkoutCore/WorkoutSessionService.swift`
- Modify: `Sources/WorkoutCore/WorkoutResult.swift`
- Modify: `Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift`
- Modify: `Tests/WorkoutCoreTests/WorkoutConfigurationTests.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: 없음 (이 계획의 시작점)
- Produces: `WorkoutSessionService.currentBasalCalories: Double` (`@Published public private(set)`), `WorkoutResult.totalCaloriesBurned: Double`, `setLiveMetricsForTesting(heartRate:calories:basalCalories:elapsedSeconds:)`(DEBUG 전용). Task 2의 Watch `WorkoutSessionViewModel`이 `currentBasalCalories`를 읽는다.

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift`의 마지막 `}` 앞에 다음을 추가:

```swift
    @Test @MainActor func basalCaloriesStartAtZero() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.currentBasalCalories == 0)
    }

    @Test @MainActor func basalCaloriesReflectInjectedValue() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        service.setLiveMetricsForTesting(calories: 120, basalCalories: 45)
        #expect(service.currentCalories == 120)
        #expect(service.currentBasalCalories == 45)
    }
```

`Tests/WorkoutCoreTests/WorkoutConfigurationTests.swift`의 `resultEqualWhenAllFieldsMatch` 뒤에 다음을 추가:

```swift
    @Test func resultTotalCaloriesDefaultsToZero() {
        let result = WorkoutResult(durationSeconds: 60, caloriesBurned: 100, averageHeartRate: 120)
        #expect(result.totalCaloriesBurned == 0)
    }

    @Test func resultCarriesTotalCalories() {
        let result = WorkoutResult(durationSeconds: 60, caloriesBurned: 100, averageHeartRate: 120, totalCaloriesBurned: 145)
        #expect(result.totalCaloriesBurned == 145)
        #expect(result.caloriesBurned == 100)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `cd /Users/yj/Workspace/ralli-kit && swift test 2>&1 | tail -20`
Expected: 컴파일 실패 — `value of type 'WorkoutSessionService' has no member 'currentBasalCalories'`

- [ ] **Step 3: WorkoutResult에 총 칼로리 추가**

`Sources/WorkoutCore/WorkoutResult.swift` 전체를 다음으로 교체:

```swift
import Foundation

public struct WorkoutResult: Equatable, Sendable {
    public let durationSeconds: Int
    /// 활동 에너지(activeEnergyBurned)만.
    public let caloriesBurned: Double
    /// 활동 + 휴식(basalEnergyBurned). 소비자가 값을 주지 않으면 0.
    public let totalCaloriesBurned: Double
    public let averageHeartRate: Double?

    public init(durationSeconds: Int,
                caloriesBurned: Double,
                averageHeartRate: Double?,
                totalCaloriesBurned: Double = 0)
    {
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.totalCaloriesBurned = totalCaloriesBurned
    }
}
```

(`totalCaloriesBurned`를 **마지막 인자 + 기본값**으로 둬서 기존 3-인자 호출부와 테스트가 그대로 컴파일된다.)

- [ ] **Step 4: WorkoutSessionService에 basal 수집 추가**

`Sources/WorkoutCore/WorkoutSessionService.swift`를 다음 6곳 수정한다.

① `@Published public private(set) var currentCalories: Double = 0` 바로 뒤에 한 줄 추가:

```swift
    @Published public private(set) var currentBasalCalories: Double = 0
```

② `typesToShare`를 다음으로 교체 (basal 추가 — 라이브 빌더가 수집한 basal 샘플을 워크아웃에 저장하려면 share 권한이 필요하다):

```swift
    private let typesToShare: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]
```

③ `typesToRead`를 다음으로 교체:

```swift
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]
```

④ `stopWorkout()` 안에서 `let calories = await collectCalories(builder: builder)` 다음 줄에 한 줄 추가하고, 반환문을 교체:

```swift
            let calories = await collectCalories(builder: builder)
            let basal = await collectBasalCalories(builder: builder)
            let heartRate = await collectAverageHeartRate(builder: builder)

            try? await builder.finishWorkout()

            DispatchQueue.main.async { self.isWorkoutActive = false }
            return WorkoutResult(durationSeconds: elapsed,
                                 caloriesBurned: calories,
                                 averageHeartRate: heartRate,
                                 totalCaloriesBurned: calories + basal)
```

⑤ `collectCalories(builder:)` 바로 뒤에 새 헬퍼를 추가:

```swift
        private func collectBasalCalories(builder: HKLiveWorkoutBuilder) async -> Double {
            builder.statistics(for: HKQuantityType(.basalEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }
```

⑥ `workoutBuilder(_:didCollectDataOf:)` 안의 activeEnergy 블록 뒤에 basal 블록을 추가:

```swift
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned)) {
                    self.currentCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.currentCalories
                }
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.basalEnergyBurned)) {
                    self.currentBasalCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.currentBasalCalories
                }
```

그리고 파일 맨 아래 DEBUG 확장의 `setLiveMetricsForTesting`을 다음으로 교체:

```swift
#if DEBUG
    public extension WorkoutSessionService {
        /// 테스트·프리뷰 전용: HealthKit 세션 없이 표시 값을 주입한다. 릴리즈 빌드에는 포함되지 않는다.
        func setLiveMetricsForTesting(heartRate: Double? = nil,
                                      calories: Double? = nil,
                                      basalCalories: Double? = nil,
                                      elapsedSeconds: Int? = nil)
        {
            if let heartRate { currentHeartRate = heartRate }
            if let calories { currentCalories = calories }
            if let basalCalories { currentBasalCalories = basalCalories }
            if let elapsedSeconds { self.elapsedSeconds = elapsedSeconds }
        }
    }
#endif
```

(`basalCalories`를 `elapsedSeconds` **앞**에 넣었다. 기존 호출부는 전부 레이블 인자를 쓰므로 순서 변경의 영향이 없다.)

- [ ] **Step 5: 패키지 테스트 통과 확인**

Run: `cd /Users/yj/Workspace/ralli-kit && swift test 2>&1 | tail -10`
Expected: `Test run with 33 tests in 5 suites passed` (기존 29개 + 신규 4개). 숫자가 다르면 실제 출력을 그대로 기록하고, **실패가 0인지**를 기준으로 판단한다.

- [ ] **Step 6: README 갱신**

`README.md`의 WorkoutCore 절에서 `WorkoutSessionService`가 노출하는 `@Published` 목록에 다음 줄을 추가한다 (`currentCalories` 설명 바로 뒤):

```markdown
- `currentBasalCalories` — 휴식 에너지(basalEnergyBurned) 누적 kcal. 총 칼로리는 `currentCalories + currentBasalCalories`.
  `HKLiveWorkoutDataSource`가 종목에 따라 basal을 자동 수집하며, 수집되지 않는 종목에서는 0으로 남는다.
```

`WorkoutResult` 설명이 있으면 `totalCaloriesBurned` 한 줄을 같은 방식으로 추가한다.

- [ ] **Step 7: 커밋 (ralli-kit 레포)**

```bash
cd /Users/yj/Workspace/ralli-kit
git add Sources/WorkoutCore Tests/WorkoutCoreTests README.md
git commit -m "✨ WorkoutCore에 휴식 에너지(basal) 수집 추가

라이브 데이터소스가 이미 basalEnergyBurned를 수집하므로 통계만 노출한다.
총 칼로리 = currentCalories + currentBasalCalories.
WorkoutResult.totalCaloriesBurned는 기본값 0인 마지막 인자라 기존 호출부 무영향.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: 총 칼로리 데이터 흐름 (모델 + 계산 + 전송)

**작업 디렉터리가 `/Users/yj/Workspace/tennis_counter`로 돌아온다.**

**Files:**
- Modify: `Shared/Models/WorkoutMetrics.swift`
- Modify: `Shared/Models/MatchSession.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `iosTests/Shared/WorkoutMetricsTests.swift`

**Interfaces:**
- Consumes: Task 1의 `WorkoutSessionService.currentBasalCalories`
- Produces: `WorkoutMetrics.totalCalories: Double` (직렬화 키 `"totalCalories"`, 없으면 `calories`로 폴백), `MatchSession.totalKcalAtStart: Double` / `totalKcalAtEnd: Double?`. Task 3(UI)과 Task 4(영속화)가 둘 다 쓴다.
- 이 태스크에서 `steps`는 **건드리지 않는다** — Task 3에서 제거한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Shared/WorkoutMetricsTests.swift`의 마지막 `}` 앞에 다음을 추가:

```swift
    @Test func workoutMetricsParsesTotalCalories() {
        let dict: [String: Any] = ["elapsed": 100.0, "calories": 200.0, "totalCalories": 260.0]
        let metrics = WorkoutMetrics(from: dict)
        #expect(metrics?.calories == 200.0)
        #expect(metrics?.totalCalories == 260.0)
    }

    /// 구버전 워치가 보낸 딕셔너리에는 totalCalories 키가 없다 — 활동 칼로리로 폴백해야
    /// 화면에 0이 뜨지 않는다.
    @Test func workoutMetricsFallsBackToActiveWhenTotalMissing() {
        let dict: [String: Any] = ["elapsed": 100.0, "calories": 200.0]
        let metrics = WorkoutMetrics(from: dict)
        #expect(metrics?.totalCalories == 200.0)
    }

    @Test func workoutMetricsRoundTripsTotalCalories() {
        let original = WorkoutMetrics(elapsedSeconds: 90, calories: 210, totalCalories: 275, heartRate: 130)
        let restored = WorkoutMetrics(from: original.toDictionary())
        #expect(restored?.totalCalories == 275)
        #expect(restored?.calories == 210)
        #expect(restored?.heartRate == 130)
    }

    @Test func workoutMetricsTotalDefaultsToZero() {
        let metrics = WorkoutMetrics(elapsedSeconds: 10)
        #expect(metrics.totalCalories == 0)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -30`
Expected: 컴파일 실패 — `value of type 'WorkoutMetrics' has no member 'totalCalories'`

- [ ] **Step 3: WorkoutMetrics에 totalCalories 추가**

`Shared/Models/WorkoutMetrics.swift`에서 다음 4곳을 수정한다 (`steps`는 그대로 둔다).

① 프로퍼티 선언에 한 줄 추가 (`calories` 바로 뒤):

```swift
struct WorkoutMetrics {
    var elapsedSeconds: TimeInterval
    var calories: Double
    /// 활동 + 휴식. 구버전 페이로드에는 없어서 calories로 폴백된다.
    var totalCalories: Double
    var heartRate: Double
    var steps: Int
```

② 키 상수에 한 줄 추가 (`keysCalories` 뒤):

```swift
    private static let keysTotalCalories = "totalCalories"
```

③ `toDictionary()`를 교체:

```swift
    func toDictionary() -> [String: Any] {
        ["type": "metrics",
         Self.keysElapsed: elapsedSeconds,
         Self.keysCalories: calories,
         Self.keysTotalCalories: totalCalories,
         Self.keysHeartRate: heartRate,
         Self.keysSteps: steps]
    }
```

④ 두 이니셜라이저를 교체:

```swift
    init(elapsedSeconds: TimeInterval = 0, calories: Double = 0, totalCalories: Double = 0,
         heartRate: Double = 0, steps: Int = 0)
    {
        self.elapsedSeconds = elapsedSeconds
        self.calories = calories
        self.totalCalories = totalCalories
        self.heartRate = heartRate
        self.steps = steps
    }

    init?(from dict: [String: Any]) {
        guard let elapsed = dict[Self.keysElapsed] as? TimeInterval else { return nil }
        elapsedSeconds = elapsed
        calories = dict[Self.keysCalories] as? Double ?? 0
        // 구버전 워치는 totalCalories를 안 보낸다 — 활동 칼로리로 폴백.
        totalCalories = dict[Self.keysTotalCalories] as? Double ?? calories
        heartRate = dict[Self.keysHeartRate] as? Double ?? 0
        steps = dict[Self.keysSteps] as? Int ?? 0
    }
```

- [ ] **Step 4: MatchSession에 총 칼로리 구간값 추가**

`Shared/Models/MatchSession.swift` 전체를 다음으로 교체:

```swift
import Foundation

class MatchSession {
    let id: UUID
    let workoutSessionId: UUID
    let options: MatchOptions
    let startedAt: Date
    var endedAt: Date?
    var result: MatchResult?

    var mySetScore: Int = 0
    var yourSetScore: Int = 0
    var completedSets: [SetScore] = []

    /// 활동 에너지 기준 경기 구간 계산용 시작·종료값.
    let kcalAtStart: Double
    var kcalAtEnd: Double?
    /// 활동 + 휴식 기준. 경기 구간 총 칼로리 = totalKcalAtEnd - totalKcalAtStart.
    let totalKcalAtStart: Double
    var totalKcalAtEnd: Double?
    var averageHeartRate: Double?

    init(id: UUID = UUID(), workoutSessionId: UUID, options: MatchOptions,
         startedAt: Date = Date(), kcalAtStart: Double, totalKcalAtStart: Double = 0)
    {
        self.id = id
        self.workoutSessionId = workoutSessionId
        self.options = options
        self.startedAt = startedAt
        self.kcalAtStart = kcalAtStart
        self.totalKcalAtStart = totalKcalAtStart
    }
}
```

(`totalKcalAtStart`에 기본값 0을 줘서 기존 호출부 3곳이 그대로 컴파일된다 — 아래 스텝에서 Watch 쪽만 실제 값을 넘기도록 고친다.)

- [ ] **Step 5: Watch가 총 칼로리를 계산해 브로드캐스트**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서 3곳을 수정한다.

① `startMatch(options:sessionId:isRemote:)`의 `MatchSession` 생성을 교체:

```swift
        let session = MatchSession(
            workoutSessionId: id,
            options: options,
            kcalAtStart: healthKit.currentCalories,
            totalKcalAtStart: healthKit.currentCalories + healthKit.currentBasalCalories
        )
```

② `finishMatch(result:completedSets:)`의 `session.kcalAtEnd = healthKit.currentCalories` 바로 뒤에 한 줄 추가:

```swift
        session.kcalAtEnd = healthKit.currentCalories
        session.totalKcalAtEnd = healthKit.currentCalories + healthKit.currentBasalCalories
```

③ `broadcastMetrics()` 전체를 교체:

```swift
    func broadcastMetrics() {
        guard case .playing = phase else { return }
        let kcalStart = _currentSession?.kcalAtStart ?? 0
        let totalStart = _currentSession?.totalKcalAtStart ?? 0
        let metrics = WorkoutMetrics(
            elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
            calories: healthKit.currentCalories - kcalStart,
            totalCalories: (healthKit.currentCalories + healthKit.currentBasalCalories) - totalStart,
            heartRate: healthKit.currentHeartRate,
            steps: 0
        )
        lastMetrics = metrics
        connectivity.sendMetrics(metrics)
    }
```

- [ ] **Step 6: iOS가 수신한 총 칼로리를 반영**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서 2곳을 수정한다.

① `setupConnectivityBindings()`의 `receivedMetrics` sink 안(73-78행)을 교체:

```swift
                metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(elapsedSeconds),
                    calories: received.calories,
                    totalCalories: received.totalCalories,
                    heartRate: received.heartRate,
                    steps: received.steps
                )
```

② `startTimer()`의 타이머 클로저 안(340-345행)을 교체 (1초 타이머가 경과 시간만 갱신하면서 나머지 값을 보존하는 자리다 — 총 칼로리도 보존해야 한다):

```swift
                metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(elapsedSeconds),
                    calories: metrics.calories,
                    totalCalories: metrics.totalCalories,
                    heartRate: metrics.heartRate,
                    steps: metrics.steps
                )
```

- [ ] **Step 7: 양 타겟 테스트 통과 확인**

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -20
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' 2>&1 | tail -20
```

Expected: 둘 다 TEST SUCCEEDED — 신규 `WorkoutMetrics` 테스트 4개 포함

- [ ] **Step 8: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add Shared iOSApp/Features/WorkoutSession WatchApp/Features/WorkoutSession iosTests/Shared/WorkoutMetricsTests.swift
git commit -m "✨ 총 칼로리(활동+휴식) 데이터 흐름 추가

WorkoutMetrics·MatchSession에 총 칼로리 필드를 하위호환으로 추가하고
워치가 활동+휴식을 합쳐 브로드캐스트한다. 구버전 페이로드는
totalCalories 키가 없어 활동 칼로리로 폴백된다. 표시는 다음 커밋.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: 총 칼로리 표시 + 죽은 걸음(steps) 제거

**Files:**
- Modify: `WatchApp/Features/Workout/Metrics/WorkoutMetricsView.swift`
- Modify: `iOSApp/Features/Workout/Components/WorkoutMetricsGrid.swift`
- Modify: `Shared/Models/WorkoutMetrics.swift` (`steps` 제거)
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (`steps: 0` 인자 제거)
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (`steps:` 인자 2곳 제거)
- Modify: `iOSApp/en.lproj/Localizable.strings`, `iOSApp/ko.lproj/Localizable.strings`
- Modify: `iosTests/Shared/WorkoutMetricsTests.swift` (steps 참조 있으면 제거)

**Interfaces:**
- Consumes: Task 2의 `WorkoutMetrics.totalCalories`, Task 1의 `WorkoutSessionService.currentBasalCalories`
- Produces: 없음 (표시 계층). `WorkoutMetrics`에서 `steps` 프로퍼티와 `"steps"` 직렬화 키가 사라진다 — Task 4는 이를 전제한다.

**걸음을 제거하는 이유**: `broadcastMetrics`가 항상 `steps: 0`을 보내므로 수집된 적이 없는 값이다. 카드 자리를 총 칼로리에 내주면서 모델에서도 같이 지워 2×2 그리드를 유지한다.

- [ ] **Step 1: 로컬라이제이션 문자열 교체**

**⚠️ 기존 `summary_total_calories`의 값이 "총 kcal"인데, 이건 원래 "여러 경기 kcal의 합계"라는 뜻이었다.** 이제 "총 칼로리(활동+휴식)"라는 새 개념이 들어오므로 그대로 두면 두 의미가 충돌한다. 기존 키의 **값만** 바꿔 "활동"임을 명시하고, 활동+휴식용 키를 새로 만든다. (키 이름은 유지 — 참조하는 코드가 3곳 있어 이름까지 바꾸면 변경 범위가 불필요하게 커진다.)

`iOSApp/ko.lproj/Localizable.strings`에서:

① 다음 두 줄을 삭제:

```
"workout_metric_steps" = "걸음 수";
"workout_metric_steps_unit" = "걸음";
```

② 같은 자리에 다음 한 줄을 추가 (iOS 워크아웃 라이브 그리드 카드용):

```
"workout_metric_total_calories" = "총 칼로리";
```

③ 기존 줄의 **값을** 교체:

```
"summary_total_calories" = "활동 kcal";
```

④ 그 바로 뒤에 새 줄을 추가 (StatCard용 — 활동+휴식):

```
"summary_total_energy" = "총 kcal";
```

`iOSApp/en.lproj/Localizable.strings`에서 같은 4가지를 대응 적용한다 — `workout_metric_steps`·`workout_metric_steps_unit` 삭제 후:

```
"workout_metric_total_calories" = "Total Calories";
"summary_total_calories" = "Active kcal";
"summary_total_energy" = "Total kcal";
```

`WatchApp/ko.lproj/Localizable.strings`에 다음을 추가 (Watch 메트릭 화면의 단위 라벨):

```
"watch_metric_total_kcal" = "총 kcal";
```

`WatchApp/en.lproj/Localizable.strings`에 대응 문자열을 추가:

```
"watch_metric_total_kcal" = "total kcal";
```

- [ ] **Step 2: iOS 워크아웃 그리드에서 걸음 카드를 총 칼로리 카드로 교체**

`iOSApp/Features/Workout/Components/WorkoutMetricsGrid.swift`의 걸음 `MetricCard` 블록(28-33행)을 다음으로 교체:

```swift
            MetricCard {
                Text(String(localized: "workout_metric_total_calories"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                metricValue(text: String(format: "%.0f", metrics.totalCalories), unit: "kcal")
            }
```

- [ ] **Step 3: Watch 메트릭 화면에 총 칼로리 줄 추가**

`WatchApp/Features/Workout/Metrics/WorkoutMetricsView.swift`의 kcal `HStack` 블록(16-22행) **바로 뒤에** 총 칼로리 줄을 추가한다. 워치 화면이 좁으므로 총 칼로리는 한 단계 작은 폰트로 둔다:

```swift
            HStack(alignment: .bottom, spacing: 6) {
                Text(String(format: "%.0f", healthKit.currentCalories))
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                Text("kcal")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.bottom, 5)
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.0f", healthKit.currentCalories + healthKit.currentBasalCalories))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Text(String(localized: "watch_metric_total_kcal"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 2)
            }
```

그리고 파일 아래 `#Preview`의 주입 호출을 교체해 프리뷰에서도 총 칼로리가 보이게 한다:

```swift
        service.setLiveMetricsForTesting(heartRate: 102, calories: 245, basalCalories: 58, elapsedSeconds: 1523)
```

- [ ] **Step 4: WorkoutMetrics에서 steps 제거**

`Shared/Models/WorkoutMetrics.swift`에서 다음을 삭제한다:
- 프로퍼티 `var steps: Int`
- 키 상수 `private static let keysSteps = "steps"`
- `toDictionary()`의 `Self.keysSteps: steps` 항목
- 지정 이니셜라이저의 `steps: Int = 0` 인자와 `self.steps = steps` 할당
- `init?(from:)`의 `steps = dict[Self.keysSteps] as? Int ?? 0`

삭제 후 두 이니셜라이저와 `toDictionary()`는 이렇게 된다:

```swift
    func toDictionary() -> [String: Any] {
        ["type": "metrics",
         Self.keysElapsed: elapsedSeconds,
         Self.keysCalories: calories,
         Self.keysTotalCalories: totalCalories,
         Self.keysHeartRate: heartRate]
    }

    init(elapsedSeconds: TimeInterval = 0, calories: Double = 0, totalCalories: Double = 0, heartRate: Double = 0) {
        self.elapsedSeconds = elapsedSeconds
        self.calories = calories
        self.totalCalories = totalCalories
        self.heartRate = heartRate
    }

    init?(from dict: [String: Any]) {
        guard let elapsed = dict[Self.keysElapsed] as? TimeInterval else { return nil }
        elapsedSeconds = elapsed
        calories = dict[Self.keysCalories] as? Double ?? 0
        // 구버전 워치는 totalCalories를 안 보낸다 — 활동 칼로리로 폴백.
        totalCalories = dict[Self.keysTotalCalories] as? Double ?? calories
        heartRate = dict[Self.keysHeartRate] as? Double ?? 0
    }
```

- [ ] **Step 5: steps 호출부 정리**

```bash
cd /Users/yj/Workspace/tennis_counter
grep -rn "steps" --include="*.swift" . | grep -v "\.build/"
```

나오는 곳을 전부 고친다. 예상 위치는 3곳이다:

- `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` `broadcastMetrics()` → `steps: 0` 줄 삭제
- `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` `receivedMetrics` sink → `steps: received.steps` 줄 삭제
- `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` `startTimer()` → `steps: metrics.steps` 줄 삭제

`iosTests/Shared/WorkoutMetricsTests.swift`에도 `steps` 참조가 있으면 해당 `#expect`를 지운다.

- [ ] **Step 6: 양 타겟 테스트 + Release 빌드 확인**

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -20
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' 2>&1 | tail -20
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' -configuration Release build 2>&1 | tail -5
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' -configuration Release build 2>&1 | tail -5
```

Expected: 테스트 2개 TEST SUCCEEDED, Release 빌드 2개 BUILD SUCCEEDED

- [ ] **Step 7: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add Shared iOSApp WatchApp iosTests
git commit -m "✨ 총 칼로리 표시 + 수집한 적 없는 걸음 항목 제거

워치 메트릭 화면에 총 kcal 줄을 넣고, iOS 그리드의 항상 0이던
걸음 카드를 총 칼로리 카드로 교체했다. steps는 broadcastMetrics가
줄곧 0을 보내던 죽은 필드라 모델에서도 지운다.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: 경기 기록에 총 칼로리 영속화 + 상세 표시

**Files:**
- Modify: `Shared/Services/ConnectivityMessages.swift` (`MatchEndMessage`)
- Modify: `Shared/Persistence/Match.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (`makeMatchEndMessage`)
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (`buildMatchFromMessage`, `buildMatchFromSession`, `buildSession`, `finishMatch`)
- Modify: `iOSApp/Features/History/Components/MatchDetailSheet.swift`
- Modify: `iosTests/Shared/MatchEndMessageTests.swift`

**Interfaces:**
- Consumes: Task 2의 `MatchSession.totalKcalAtStart`/`totalKcalAtEnd`, `WorkoutMetrics.totalCalories`
- Produces: `MatchEndMessage.totalCalories: Double?` (직렬화 키 `"totalCalories"`, 없으면 nil), `Match.totalCaloriesBurned: Double?`. 이 계획의 마지막 코드 변경이다.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Shared/MatchEndMessageTests.swift`의 마지막 `}` 앞에 다음을 추가:

```swift
    @Test func matchEndMessageRoundTripsTotalCalories() {
        let msg = MatchEndMessage(
            sessionId: UUID(), result: "win", completedSets: [[6, 4]],
            startedAt: Date(timeIntervalSince1970: 1000),
            endedAt: Date(timeIntervalSince1970: 4600),
            durationSeconds: 3600, calories: 320, averageHeartRate: 135,
            mode: "one_set", noAdRule: true, totalCalories: 415
        )
        let restored = MatchEndMessage(from: msg.toDictionary())
        #expect(restored?.totalCalories == 415)
        #expect(restored?.calories == 320)
    }

    /// 구버전 워치 페이로드에는 totalCalories 키가 없다 — nil이어야 저장 시
    /// "값 없음"과 "0 kcal"을 구분할 수 있다.
    @Test func matchEndMessageTotalCaloriesIsNilWhenKeyMissing() {
        let dict: [String: Any] = [
            "type": "matchEnd",
            "sessionId": UUID().uuidString,
            "result": "win",
            "sets": [[6, 4]],
            "startedAt": 1000.0,
            "endedAt": 4600.0,
            "durationSeconds": 3600,
            "calories": 320.0,
            "mode": "one_set",
            "noAdRule": true,
        ]
        let restored = MatchEndMessage(from: dict)
        #expect(restored?.totalCalories == nil)
        #expect(restored?.calories == 320)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -30`
Expected: 컴파일 실패 — `extra argument 'totalCalories' in call`

- [ ] **Step 3: MatchEndMessage에 totalCalories 추가**

`Shared/Services/ConnectivityMessages.swift`의 `MatchEndMessage`를 4곳 수정한다.

① 프로퍼티 선언에 한 줄 추가 (`calories` 뒤):

```swift
    let calories: Double
    /// 활동 + 휴식. 구버전 워치 페이로드에는 없으므로 optional.
    let totalCalories: Double?
```

② `dictionary(type:)`에서 `if let hr = ...` 줄 앞에 한 줄 추가:

```swift
        if let total = totalCalories { dict["totalCalories"] = total }
        if let hr = averageHeartRate { dict["heartRate"] = hr }
        return dict
```

③ `init?(from:)`의 `calories = ...` 다음 줄에 한 줄 추가:

```swift
        calories = dict["calories"] as? Double ?? 0
        totalCalories = dict["totalCalories"] as? Double
```

④ 지정 이니셜라이저에 인자를 추가한다. **마지막 인자 + 기본값 nil**로 둬서 기존 호출부가 그대로 컴파일되게 한다:

```swift
    init(sessionId: UUID, result: String, completedSets: [[Int]], startedAt: Date,
         endedAt: Date, durationSeconds: Int, calories: Double, averageHeartRate: Double?,
         mode: String, noAdRule: Bool, totalCalories: Double? = nil)
```

본문 마지막에 `self.totalCalories = totalCalories`를 추가한다.

- [ ] **Step 4: Match 모델에 총 칼로리 필드 추가**

`Shared/Persistence/Match.swift`의 `var caloriesBurned: Double?` 바로 뒤에 한 줄 추가:

```swift
    var caloriesBurned: Double?
    /// 활동 + 휴식. CloudKit 요구사항상 optional이며, 총 칼로리 도입 전 기록은 nil이다.
    var totalCaloriesBurned: Double?
```

(SwiftData 라이트웨이트 마이그레이션 — optional 필드 추가는 기존 스토어와 호환된다. 기존 기록은 nil로 남고 UI에서 `–`로 표시된다.)

- [ ] **Step 5: Watch가 총 칼로리를 메시지에 실어 보냄**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 `makeMatchEndMessage(session:)` 전체를 교체:

```swift
    private func makeMatchEndMessage(session: MatchSession) -> MatchEndMessage {
        MatchEndMessage(
            sessionId: session.workoutSessionId,
            result: session.result?.rawValue ?? "win",
            completedSets: session.completedSets.map { [$0.my, $0.your] },
            startedAt: session.startedAt,
            endedAt: session.endedAt ?? Date(),
            durationSeconds: healthKit.elapsedSeconds,
            calories: (session.kcalAtEnd ?? 0) - session.kcalAtStart,
            averageHeartRate: session.averageHeartRate,
            mode: session.options.mode.rawValue,
            noAdRule: session.options.noAdRule,
            totalCalories: session.totalKcalAtEnd.map { $0 - session.totalKcalAtStart }
        )
    }
```

- [ ] **Step 6: iOS 저장 경로 3곳 반영**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서 4곳을 수정한다.

① `finishMatch(result:completedSets:)`의 `session.kcalAtEnd = metrics.calories` 뒤에 한 줄 추가:

```swift
        session.kcalAtEnd = metrics.calories
        session.totalKcalAtEnd = metrics.totalCalories
```

(폰이 driver인 경로에서 `metrics`는 이미 경기 구간 값이므로 `MatchSession`의 시작값은 0이다 — 차감이 항등이 된다.)

② `buildMatchFromMessage(_:)`의 `match.caloriesBurned = msg.calories` 뒤에 한 줄 추가:

```swift
        match.caloriesBurned = msg.calories
        match.totalCaloriesBurned = msg.totalCalories
```

③ `buildMatchFromSession(_:)`의 `match.caloriesBurned = ...` 뒤에 한 줄 추가:

```swift
        match.caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
        match.totalCaloriesBurned = session.totalKcalAtEnd.map { $0 - session.totalKcalAtStart }
```

④ `buildSession(from:)`의 `session.kcalAtEnd = msg.calories` 뒤에 한 줄 추가:

```swift
        session.kcalAtEnd = msg.calories
        session.totalKcalAtEnd = msg.totalCalories
```

- [ ] **Step 7: 경기 상세에 총 칼로리 표시**

`iOSApp/Features/History/Components/MatchDetailSheet.swift`의 워크아웃 `Section` 안 `LazyVGrid`를 교체한다. 3열 그리드에 카드가 하나 늘어 2행이 되므로 열 수는 그대로 두고 카드만 추가한다:

```swift
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        StatCard(
                            title: String(localized: "summary_total_calories"),
                            value: match.caloriesBurned.map { String(format: "%.0f", $0) } ?? "–",
                            color: .white
                        )
                        StatCard(
                            title: String(localized: "summary_total_energy"),
                            value: match.totalCaloriesBurned.map { String(format: "%.0f", $0) } ?? "–",
                            color: .white
                        )
                        StatCard(
                            title: String(localized: "summary_duration"),
                            value: matchDurationString,
                            color: .white
                        )
                        StatCard(
                            title: String(localized: "summary_avg_heartrate"),
                            value: match.averageHeartRate.map { String(format: "%.0f", $0) } ?? "–",
                            color: .white
                        )
                    }
```

(`StatCard`의 값에는 단위 suffix를 붙이지 않는다 — 단위는 타이틀에만. 프로젝트 규약.)

- [ ] **Step 8: 양 타겟 테스트 + Release 빌드 확인**

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -20
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' 2>&1 | tail -20
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' -configuration Release build 2>&1 | tail -5
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' -configuration Release build 2>&1 | tail -5
```

Expected: 테스트 2개 TEST SUCCEEDED (신규 `MatchEndMessage` 테스트 2개 포함), Release 빌드 2개 BUILD SUCCEEDED

- [ ] **Step 9: 시뮬레이터 스모크 — 기존 스토어 마이그레이션**

`Match`에 optional 필드를 추가했으므로 기존 스토어가 열리는지 본다. **앱을 지우지 말고** 이전 빌드가 설치된 상태에서 새 빌드를 올려 실행한다.

시뮬레이터에서 앱 실행 → History 탭 → 기존 기록 목록이 그대로 보이고 상세를 열면 총 칼로리가 `–`로 표시되는지 확인.

Expected: 크래시 없이 기존 기록이 보이고, 총 칼로리만 `–`.

- [ ] **Step 10: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add Shared iOSApp WatchApp iosTests
git commit -m "✨ 경기 기록에 총 칼로리 영속화 + 상세 표시

MatchEndMessage.totalCalories는 optional이라 구버전 워치 페이로드와
호환되고, Match.totalCaloriesBurned도 optional이라 기존 기록은 nil로
남아 상세에서 –로 표시된다.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Summary 워크아웃 통계에 총 칼로리 집계

**Files:**
- Modify: `iOSApp/Features/Summary/SummaryViewModel.swift` (`SummaryStats` + `stats(from:)`)
- Modify: `iOSApp/Features/Summary/Components/WorkoutStatsGrid.swift`
- Modify: `iosTests/Summary/SummaryViewModelTests.swift`

**Interfaces:**
- Consumes: Task 4의 `Match.totalCaloriesBurned`
- Produces: `SummaryStats.totalEnergy: Double?`와 `formattedTotalEnergy: String`. 표시 계층만 쓰므로 이후 태스크가 의존하지 않는다.

**레이아웃 결정**: 카드가 3개 → 4개가 되므로 3열 그리드에 넣으면 두 번째 줄에 1개만 남아 어색하다. **2열 그리드로 바꿔 2×2**로 배치한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Summary/SummaryViewModelTests.swift`의 마지막 `}` 앞에 다음을 추가:

```swift
    @Test func statsAggregatesTotalEnergy() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let match1 = Match()
        match1.startedAt = Date()
        match1.caloriesBurned = 300
        match1.totalCaloriesBurned = 385

        let match2 = Match()
        match2.startedAt = Date()
        match2.caloriesBurned = 200
        match2.totalCaloriesBurned = 265

        let stats = vm.stats(from: [match1, match2])

        #expect(stats.totalCalories == 500)
        #expect(stats.totalEnergy == 650)
        #expect(stats.formattedTotalEnergy == "650")
    }

    /// 총 칼로리 도입 이전 기록은 totalCaloriesBurned가 nil이다 — 그런 기록만 있으면
    /// 0이 아니라 "값 없음"이어야 사용자가 오해하지 않는다.
    @Test func statsTotalEnergyIsNilForLegacyRecords() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .week

        let legacy = Match()
        legacy.startedAt = Date()
        legacy.caloriesBurned = 300

        let stats = vm.stats(from: [legacy])

        #expect(stats.totalCalories == 300)
        #expect(stats.totalEnergy == nil)
        #expect(stats.formattedTotalEnergy == "–")
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -30`
Expected: 컴파일 실패 — `value of type 'SummaryStats' has no member 'totalEnergy'`

- [ ] **Step 3: SummaryStats에 집계 추가**

`iOSApp/Features/Summary/SummaryViewModel.swift`에서 2곳을 수정한다.

① `SummaryStats` 선언에 필드와 포매터를 추가:

```swift
struct SummaryStats {
    let totalMatches: Int
    let wins: Int
    let winRate: Double
    /// 활동 에너지 합계.
    let totalCalories: Double?
    /// 활동 + 휴식 합계. 총 칼로리 도입 이전 기록만 있으면 nil.
    let totalEnergy: Double?
    let totalDuration: Int?
    let avgHeartRate: Double?

    var formattedCalories: String {
        totalCalories.map { String(format: "%.0f", $0) } ?? "–"
    }

    var formattedTotalEnergy: String {
        totalEnergy.map { String(format: "%.0f", $0) } ?? "–"
    }

    var formattedDuration: String {
        totalDuration.map { WorkoutMetrics.formatSeconds($0) } ?? "–"
    }

    var formattedHeartRate: String {
        avgHeartRate.map { String(format: "%.0f", $0) } ?? "–"
    }
}
```

② `stats(from:)`에서 `let totalCalories: Double? = ...` 다음에 두 줄을 추가하고, `return SummaryStats(...)`에 인자를 끼워 넣는다:

```swift
        let calories = filtered.compactMap(\.caloriesBurned)
        let totalCalories: Double? = calories.isEmpty ? nil : calories.reduce(0, +)

        let energies = filtered.compactMap(\.totalCaloriesBurned)
        let totalEnergy: Double? = energies.isEmpty ? nil : energies.reduce(0, +)
```

```swift
        return SummaryStats(
            totalMatches: total,
            wins: wins,
            winRate: winRate,
            totalCalories: totalCalories,
            totalEnergy: totalEnergy,
            totalDuration: totalDuration,
            avgHeartRate: avgHeartRate
        )
```

- [ ] **Step 4: WorkoutStatsGrid를 2×2로 재배치**

`iOSApp/Features/Summary/Components/WorkoutStatsGrid.swift`의 `LazyVGrid` 블록 전체를 다음으로 교체:

```swift
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                StatCard(
                    title: String(localized: "summary_total_calories"),
                    value: stats.formattedCalories,
                    color: .green
                )
                StatCard(
                    title: String(localized: "summary_total_energy"),
                    value: stats.formattedTotalEnergy,
                    color: .green
                )
                StatCard(
                    title: String(localized: "summary_duration"),
                    value: stats.formattedDuration,
                    color: .green
                )
                StatCard(
                    title: String(localized: "summary_avg_heartrate"),
                    value: stats.formattedHeartRate,
                    color: .green
                )
            }
```

그리고 같은 파일 위쪽 `#Preview`의 `SummaryStats` 생성에 새 인자를 추가한다 (안 그러면 프리뷰가 컴파일되지 않는다):

```swift
    WorkoutStatsGrid(stats: SummaryStats(
        totalMatches: 12,
        wins: 8,
        winRate: 0.67,
        totalCalories: 1240,
        totalEnergy: 1585,
        totalDuration: 4980,
        avgHeartRate: 138
    ))
```

- [ ] **Step 5: iOS 테스트 + Release 빌드 확인**

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -20
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' -configuration Release build 2>&1 | tail -5
```

Expected: TEST SUCCEEDED (신규 Summary 테스트 2개 포함), BUILD SUCCEEDED

- [ ] **Step 6: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add iOSApp/Features/Summary iosTests/Summary
git commit -m "✨ Summary 워크아웃 통계에 총 칼로리 집계 추가

카드가 4개가 되어 3열 그리드에 1개가 고아로 남으므로 2×2로 재배치했다.
총 칼로리 이전 기록만 있으면 합계가 0이 아니라 nil(–)이다.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: CLAUDE.md 갱신

**Files:**
- Modify: `CLAUDE.md` (Architecture 트리의 `WorkoutMetrics.swift` 설명)

- [ ] **Step 1: 트리 설명 갱신**

`CLAUDE.md`에서 기존 줄을 교체한다.

기존:

```
│   └── WorkoutMetrics.swift # HealthKit 메트릭 (칼로리, BPM, 시간)
```

교체:

```
│   └── WorkoutMetrics.swift # HealthKit 메트릭 (활동/총 칼로리, BPM, 시간)
```

- [ ] **Step 2: 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
git add CLAUDE.md
git commit -m "📝 총 칼로리 도입 반영 — CLAUDE.md 트리

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: [사용자 수동] 실기기 검증 — 이 계획의 핵심 게이트

**⚠️ 시뮬레이터에서는 HealthKit 워크아웃 세션이 동작하지 않아 basal 수집 여부를 전혀 알 수 없다.** 지금까지의 태스크는 "basal이 수집된다면" 값이 올바르게 흐르는지만 검증했다. **테니스 종목에서 `HKLiveWorkoutDataSource`가 실제로 `basalEnergyBurned`를 수집하는가**는 여기서만 확인된다.

- [ ] **Step 1: [사용자] iPhone + Apple Watch에 설치 후 확인**

- [ ] **권한 시트**: 첫 실행 시 HealthKit 권한 시트에 **"휴식 에너지"** 항목이 새로 보이고 허용할 수 있다
- [ ] **워치 라이브**: 워크아웃 시작 후 5분 이상 진행 → 워치 메트릭 화면의 "총 kcal"이 활동 kcal **보다 크고** 시간이 갈수록 늘어난다
  - **총 kcal이 활동 kcal과 계속 같다면** basal이 수집되지 않는 것이다 → Step 2로
- [ ] **폰 라이브**: 폰 워크아웃 탭 그리드에 총 칼로리 카드가 보이고 값이 갱신된다 (걸음 카드는 사라졌다)
- [ ] **기록 저장**: 경기 종료 → 저장 → History 상세에 "활동 kcal"과 "총 kcal"이 둘 다 숫자로 보인다
- [ ] **Summary 집계**: Summary 탭 운동 섹션이 2×2 카드로 보이고 총 kcal이 활동 kcal보다 크다
- [ ] **기존 기록**: 이번 변경 이전에 저장된 경기의 상세에서 총 칼로리가 `–`로 보이고 크래시가 없다
- [ ] **피트니스 앱**: 애플 피트니스 앱에서 해당 운동 상세를 열면 "총 킬로칼로리"가 활동 칼로리보다 크게 표시된다

- [ ] **Step 2: basal이 수집되지 않는 경우의 대응**

총 kcal이 활동 kcal과 같게 나오면 `HKLiveWorkoutDataSource`가 테니스 종목에서 basal을 수집하지 않는 것이다. 그때는 이 계획을 되돌리지 말고 **수집 경로만 교체**한다: `WorkoutSessionService`에서 `dataSource.enableCollection(for: HKQuantityType(.basalEnergyBurned), predicate: nil)`을 `startWorkout()`의 `builder.dataSource` 설정 직후에 호출하고 재검증한다. 그래도 0이면 `HKStatisticsQuery`로 워크아웃 구간의 basal을 직접 조회하는 경로를 별도 계획으로 만든다.

- [ ] **Step 3: 결과 기록**

결과를 `docs/superpowers/logs/2026-07-30-total-calories.md`에 남긴다 — 특히 basal 수집 여부와 실제 활동:총 비율(예: 활동 320 / 총 415)을 적어 둔다. 이 값은 피트니스 목록 지표 스파이크의 실험 변수이기도 하다.

---

## 완료 기준 (Definition of Done)

1. ralli-kit `swift test` 그린 (실패 0), `currentBasalCalories`·`WorkoutResult.totalCaloriesBurned` 존재
2. `grep -rn "steps" --include="*.swift" .` → 0건 (걸음 완전 제거)
3. `grep -rn "totalCalories\|totalCaloriesBurned\|totalKcal\|totalEnergy" --include="*.swift" .` → `WorkoutMetrics`·`MatchSession`·`MatchEndMessage`·`Match`·양 `WorkoutSessionViewModel`·`WorkoutMetricsGrid`·`MatchDetailSheet`·`SummaryViewModel`·`WorkoutStatsGrid`에 존재
4. iOS·Watch 테스트 스위트 그린 — `WorkoutMetrics` 신규 4개 + `MatchEndMessage` 신규 2개 + `SummaryViewModel` 신규 2개 포함
5. 양 타겟 **Release 빌드** 그린
6. `make lint` 위반 0건
7. 하위호환 확인 (테스트로 고정): `totalCalories` 키 없는 딕셔너리 → `WorkoutMetrics.totalCalories == calories`, `MatchEndMessage.totalCalories == nil`, `totalCaloriesBurned`가 없는 기록만 있을 때 `SummaryStats.totalEnergy == nil`
8. 라벨 충돌 해소: `summary_total_calories`의 값이 "활동 kcal"/"Active kcal"로 바뀌고, `summary_total_energy`가 신설됐다
9. Task 7 실기기 검증 완료 — **basal 실제 수집 여부가 확인되기 전까지 이 계획은 완료가 아니다**
