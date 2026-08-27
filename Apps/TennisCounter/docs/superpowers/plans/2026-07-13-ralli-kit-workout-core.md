# RalliKit Plan 1: 패키지 스캐폴딩 + WorkoutCore 추출 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ralli-kit` SPM 패키지를 신규 생성하고 `HealthKitService`를 `WorkoutCore` 라이브러리로 추출한 뒤, 테니스 Watch 앱을 첫 소비자로 마이그레이션한다.

**Architecture:** 별도 로컬 레포 `~/Workspace/Projects/ralli-kit`에 멀티 product SPM 패키지(이번 계획에서는 `WorkoutCore` 하나만)를 만든다. 싱글톤 `HealthKitService.shared`를 `WorkoutConfiguration` 주입 방식의 `WorkoutSessionService`(public init DI)로 전환하고, `.tennis` 하드코딩을 설정값으로 바꾼다. 테니스 앱은 Xcode 로컬 패키지 참조로 링크한다(원격 레포는 선택).

**Tech Stack:** Swift 5 language mode / swift-tools-version 6.0, HealthKit, Swift Testing, Xcode 16 `PBXFileSystemSynchronizedRootGroup`(테니스 쪽), XCLocalSwiftPackageReference(로컬 링크).

**연관 문서:** `docs/superpowers/ideas/workout-kit-spm-feasibility.md` (설계 확정본). 후속으로 Plan 2(ConnectivityCore), Plan 3(PersistenceCore)가 별도 작성된다 — 이 계획은 그 둘과 독립적으로 완결된다.

## Global Constraints

- 패키지 경로: `~/Workspace/Projects/ralli-kit` (테니스 레포의 형제 폴더). 패키지명 `RalliKit`, product/모듈명 `WorkoutCore`.
- `Package.swift` platforms: `.iOS(.v17), .watchOS(.v10), .macOS(.v14)` — macOS는 `swift test` 호스트 실행용 (HealthKit은 macOS 13+에서 사용 가능).
- 모든 타겟에 `.swiftLanguageMode(.v5)` — 기존 코드는 Swift 6 동시성 미정리 상태.
- 싱글톤(`static let shared`) 금지. `public init(configuration:)` DI만.
- `@Published`는 전부 `public private(set)`. 테스트·프리뷰 값 주입은 `#if DEBUG` 전용 `setLiveMetricsForTesting`으로만.
- 엔타이틀먼트·Info.plist(HealthKit capability, 권한 문구)는 앱 타겟 잔류. 패키지는 코드만.
- 각 태스크 종료 시점에 테니스 양 타겟 빌드+테스트 그린 유지.
- 테스트 프레임워크: Swift Testing (`@Test`, `#expect`).
- 커밋 메시지: 양 레포 모두 gitmoji + 한국어 (테니스 레포 기존 스타일).
- 이 계획 문서 자체는 사용자 검토 전까지 커밋하지 않는다 (CLAUDE.md Docs Conventions).

**이식 시 원본 대비 의도된 변경 3가지 (이외에는 로직 불변):**
1. `.tennis`/`.outdoor` 하드코딩 → `WorkoutConfiguration` 주입.
2. 미사용 프로퍼티 `private var workoutBuilder: HKWorkoutBuilder?` 삭제 (원본 `Shared/Services/HealthKitService.swift:21`의 죽은 코드).
3. `private var workoutSession: HKWorkoutSession?`을 `#if os(watchOS)` 블록 안으로 이동 — `HKWorkoutSession`은 macOS에 없어 macOS 테스트 빌드가 깨지기 때문. 모든 사용처(start/pause/resume/stop)가 이미 watchOS 블록 안에 있어 안전하다.

---

### Task 1: RalliKit 패키지 스캐폴딩 + WorkoutConfiguration

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/Package.swift`
- Create: `~/Workspace/Projects/ralli-kit/.gitignore`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutCore/WorkoutConfiguration.swift`
- Test: `~/Workspace/Projects/ralli-kit/Tests/WorkoutCoreTests/WorkoutConfigurationTests.swift`

**Interfaces:**
- Consumes: 없음 (신규 레포 최초 태스크)
- Produces: `public struct WorkoutConfiguration { public let activityType: HKWorkoutActivityType; public let locationType: HKWorkoutSessionLocationType; public init(activityType:locationType:) }` — Task 2의 서비스와 Task 4의 앱 확장(`WorkoutConfiguration.tennis`)이 사용.

- [x] **Step 1: 폴더 구조 + Package.swift + .gitignore 생성**

```bash
mkdir -p ~/Workspace/Projects/ralli-kit/Sources/WorkoutCore
mkdir -p ~/Workspace/Projects/ralli-kit/Tests/WorkoutCoreTests
```

`~/Workspace/Projects/ralli-kit/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RalliKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WorkoutCore", targets: ["WorkoutCore"]),
    ],
    targets: [
        .target(
            name: "WorkoutCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "WorkoutCoreTests",
            dependencies: ["WorkoutCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

`~/Workspace/Projects/ralli-kit/.gitignore`:

```
.DS_Store
.build/
.swiftpm/
xcuserdata/
```

- [x] **Step 2: 실패하는 테스트 작성**

`Tests/WorkoutCoreTests/WorkoutConfigurationTests.swift`:

```swift
import HealthKit
import Testing
@testable import WorkoutCore

struct WorkoutConfigurationTests {
    @Test func initStoresActivityType() {
        let config = WorkoutConfiguration(activityType: .tennis)
        #expect(config.activityType == .tennis)
    }

    @Test func locationTypeDefaultsToOutdoor() {
        let config = WorkoutConfiguration(activityType: .golf)
        #expect(config.locationType == .outdoor)
    }

    @Test func locationTypeCanBeOverridden() {
        let config = WorkoutConfiguration(
            activityType: .traditionalStrengthTraining,
            locationType: .indoor
        )
        #expect(config.locationType == .indoor)
    }
}
```

`Sources/WorkoutCore/`에 소스가 아직 없으므로 이 시점엔 컴파일 자체가 실패한다.

- [x] **Step 3: 테스트 실패 확인**

Run: `cd ~/Workspace/Projects/ralli-kit && swift test`
Expected: FAIL — `cannot find 'WorkoutConfiguration' in scope` (또는 WorkoutCore 타겟 소스 없음 에러)

- [x] **Step 4: WorkoutConfiguration 구현**

`Sources/WorkoutCore/WorkoutConfiguration.swift`:

```swift
import HealthKit

/// 앱별 워크아웃 종목 설정. 소비자 앱이 자기 종목으로 만들어 서비스에 주입한다.
public struct WorkoutConfiguration {
    public let activityType: HKWorkoutActivityType
    public let locationType: HKWorkoutSessionLocationType

    public init(activityType: HKWorkoutActivityType,
                locationType: HKWorkoutSessionLocationType = .outdoor)
    {
        self.activityType = activityType
        self.locationType = locationType
    }
}
```

- [x] **Step 5: 테스트 통과 확인**

Run: `cd ~/Workspace/Projects/ralli-kit && swift test`
Expected: PASS — 3 tests passed

- [x] **Step 6: git init + 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git init
git add -A
git commit -m "🎉 RalliKit 패키지 스캐폴딩 + WorkoutConfiguration

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: WorkoutResult + WorkoutSessionService 이식

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutCore/WorkoutResult.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutCore/WorkoutSessionService.swift`
- Test: `~/Workspace/Projects/ralli-kit/Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift`
- 원본 참조: `tennis-counter/Shared/Services/HealthKitService.swift` (이 태스크에서는 읽기만, 삭제는 Task 4)

**Interfaces:**
- Consumes: Task 1의 `WorkoutConfiguration`
- Produces:
  - `public struct WorkoutResult { public let durationSeconds: Int; public let caloriesBurned: Double; public let averageHeartRate: Double?; public init(...) }`
  - `public final class WorkoutSessionService: NSObject, ObservableObject` — `public init(configuration: WorkoutConfiguration)`, `@Published public private(set) var isWorkoutActive/isPaused: Bool`, `currentHeartRate/currentCalories: Double`, `elapsedSeconds: Int`, `public private(set) var startDate: Date?`, `public var isAvailable: Bool`, `public func requestAuthorization() async -> Bool`, `public func formattedElapsed() -> String`, `public func averageHeartRate(from:to:) async -> Double?`, watchOS 한정 `public func startWorkout()/pauseWorkout()/resumeWorkout()`, `public func stopWorkout() async -> WorkoutResult?`
  - `#if DEBUG` 한정 `public func setLiveMetricsForTesting(heartRate:calories:elapsedSeconds:)` — Task 4의 앱 테스트·프리뷰가 사용.

- [x] **Step 1: 실패하는 테스트 작성**

`Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift`:

```swift
import HealthKit
import Testing
@testable import WorkoutCore

struct WorkoutSessionServiceTests {
    @Test @MainActor func formattedElapsedStartsAtZero() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.formattedElapsed() == "00:00")
    }

    @Test @MainActor func formattedElapsedFormatsMinutesSeconds() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        service.setLiveMetricsForTesting(elapsedSeconds: 605)
        #expect(service.formattedElapsed() == "10:05")
    }

    @Test @MainActor func formattedElapsedIncludesHoursWhenOverAnHour() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        service.setLiveMetricsForTesting(elapsedSeconds: 3661)
        #expect(service.formattedElapsed() == "1:01:01")
    }

    @Test @MainActor func setLiveMetricsInjectsDisplayValues() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .golf))
        service.setLiveMetricsForTesting(heartRate: 140, calories: 250)
        #expect(service.currentHeartRate == 140)
        #expect(service.currentCalories == 250)
    }

    @Test func workoutResultStoresValues() {
        let result = WorkoutResult(durationSeconds: 90, caloriesBurned: 12.5, averageHeartRate: nil)
        #expect(result.durationSeconds == 90)
        #expect(result.caloriesBurned == 12.5)
        #expect(result.averageHeartRate == nil)
    }
}
```

- [x] **Step 2: 테스트 실패 확인**

Run: `cd ~/Workspace/Projects/ralli-kit && swift test`
Expected: FAIL — `cannot find 'WorkoutSessionService' in scope`, `cannot find 'WorkoutResult' in scope` (Task 1의 3개 테스트는 계속 PASS)

- [x] **Step 3: WorkoutResult 구현**

`Sources/WorkoutCore/WorkoutResult.swift`:

```swift
import Foundation

public struct WorkoutResult {
    public let durationSeconds: Int
    public let caloriesBurned: Double
    public let averageHeartRate: Double?

    public init(durationSeconds: Int, caloriesBurned: Double, averageHeartRate: Double?) {
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
    }
}
```

- [x] **Step 4: WorkoutSessionService 구현**

원본 `HealthKitService`의 로직을 그대로 옮기되 Global Constraints의 "의도된 변경 3가지"만 적용한다.

`Sources/WorkoutCore/WorkoutSessionService.swift`:

```swift
import Foundation
import HealthKit

public final class WorkoutSessionService: NSObject, ObservableObject {
    @Published public private(set) var isWorkoutActive = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var currentHeartRate: Double = 0
    @Published public private(set) var currentCalories: Double = 0
    @Published public private(set) var elapsedSeconds: Int = 0

    public let configuration: WorkoutConfiguration

    private let store = HKHealthStore()
    #if os(watchOS)
        private var workoutSession: HKWorkoutSession?
        private var liveWorkoutBuilder: HKLiveWorkoutBuilder?
    #endif
    public private(set) var startDate: Date?
    private var timer: Timer?
    private var timerPausedAt: Date?

    private let typesToShare: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]

    public init(configuration: WorkoutConfiguration) {
        self.configuration = configuration
        super.init()
    }

    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            return false
        }
    }

    #if os(watchOS)
        public func startWorkout() {
            guard isAvailable, workoutSession == nil else { return }

            let config = HKWorkoutConfiguration()
            config.activityType = configuration.activityType
            config.locationType = configuration.locationType

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

        public func pauseWorkout() {
            guard let session = workoutSession else { return }
            session.pause()
            DispatchQueue.main.async { self.isPaused = true }
            timerPausedAt = Date()
            timer?.invalidate()
            timer = nil
        }

        public func resumeWorkout() {
            guard let session = workoutSession else { return }
            session.resume()
            DispatchQueue.main.async { self.isPaused = false }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.elapsedSeconds += 1
                }
            }
            timerPausedAt = nil
        }

        public func stopWorkout() async -> WorkoutResult? {
            guard let session = workoutSession,
                  let builder = liveWorkoutBuilder,
                  let start = startDate else { return nil }

            workoutSession = nil
            liveWorkoutBuilder = nil
            startDate = nil

            session.end()
            stopTimer()

            let elapsed = Int(Date().timeIntervalSince(start))
            let endDate = Date()

            await withCheckedContinuation { continuation in
                builder.endCollection(withEnd: endDate) { _, _ in continuation.resume() }
            }

            let calories = await collectCalories(builder: builder)
            let heartRate = await collectAverageHeartRate(builder: builder)

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

    public func averageHeartRate(from startDate: Date, to endDate: Date) async -> Double? {
        #if os(watchOS)
            let hrType = HKQuantityType(.heartRate)
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            return await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: hrType,
                    quantitySamplePredicate: predicate,
                    options: .discreteAverage
                ) { _, stats, _ in
                    let value = stats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: value)
                }
                store.execute(query)
            }
        #else
            return nil
        #endif
    }

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    public func formattedElapsed() -> String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#if os(watchOS)
    extension WorkoutSessionService: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
        public func workoutSession(_: HKWorkoutSession,
                                   didChangeTo toState: HKWorkoutSessionState,
                                   from _: HKWorkoutSessionState,
                                   date _: Date)
        {
            DispatchQueue.main.async {
                self.isWorkoutActive = toState == .running
                self.isPaused = toState == .paused
            }
        }

        public func workoutSession(_: HKWorkoutSession, didFailWithError _: Error) {}

        public func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}

        public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf _: Set<HKSampleType>) {
            DispatchQueue.main.async {
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate)) {
                    self.currentHeartRate = stats.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? self.currentHeartRate
                }
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned)) {
                    self.currentCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.currentCalories
                }
            }
        }
    }
#endif

#if DEBUG
    public extension WorkoutSessionService {
        /// 테스트·프리뷰 전용: HealthKit 세션 없이 표시 값을 주입한다. 릴리즈 빌드에는 포함되지 않는다.
        func setLiveMetricsForTesting(heartRate: Double? = nil, calories: Double? = nil, elapsedSeconds: Int? = nil) {
            if let heartRate { currentHeartRate = heartRate }
            if let calories { currentCalories = calories }
            if let elapsedSeconds { self.elapsedSeconds = elapsedSeconds }
        }
    }
#endif
```

- [x] **Step 5: 테스트 통과 확인 (macOS 호스트)**

Run: `cd ~/Workspace/Projects/ralli-kit && swift test`
Expected: PASS — 8 tests passed (Task 1의 3개 + 이번 5개)

만약 macOS 빌드에서 HealthKit 심볼 availability 에러가 나면(예: `HKWorkoutSessionLocationType` unavailable), 해당 심볼만 `#if os(watchOS) || os(iOS)`로 가드하고 다음 fallback으로 테스트를 돌린다:
`xcodebuild test -scheme RalliKit-Package -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`

- [x] **Step 6: watchOS 컴파일 확인**

watchOS 전용 블록(`HKWorkoutSession`, `HKLiveWorkoutBuilder`)은 macOS `swift test`로 검증되지 않으므로 별도 확인:

Run: `cd ~/Workspace/Projects/ralli-kit && xcodebuild -scheme WorkoutCore -destination 'generic/platform=watchOS Simulator' build`
Expected: BUILD SUCCEEDED

- [x] **Step 7: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add -A
git commit -m "✨ WorkoutSessionService 이식 — HealthKitService의 DI·설정 주입 버전

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: [사용자 수동] 테니스 Xcode 프로젝트에 로컬 패키지 링크

**⚠️ 이 태스크는 Xcode GUI 작업이라 사용자가 직접 수행한다. 에이전트는 안내 후 대기하고, 완료 확인(Step 3)만 수행한다.**

**Files:**
- Modify: `tennis-counter/TennisCounter.xcodeproj/project.pbxproj` (Xcode가 자동 수정 — `XCLocalSwiftPackageReference` 추가. 커밋은 Task 4에서 마이그레이션과 함께)

**Interfaces:**
- Consumes: Task 2까지 완성된 `~/Workspace/Projects/ralli-kit` 패키지
- Produces: "TennisCounter Watch App" 타겟에서 `import WorkoutCore` 가능한 상태

- [x] **Step 1: [사용자] 로컬 패키지 추가**

1. `TennisCounter.xcodeproj`를 Xcode로 연다.
2. **File → Add Package Dependencies… → Add Local…** 클릭.
3. `~/Workspace/Projects/ralli-kit` 폴더 선택 → **Add Package**.
4. Product 선택 다이얼로그에서 `WorkoutCore`를 **"TennisCounter Watch App" 타겟에만** 추가한다. (iOS 타겟은 HealthKitService를 참조하지 않으므로 링크 불필요 — Plan 2·3에서 필요해지면 그때 추가)

다이얼로그에서 타겟 지정을 놓쳤다면: 프로젝트 설정 → "TennisCounter Watch App" 타겟 → General → **Frameworks, Libraries, and Embedded Content** → `+` → `WorkoutCore` 추가.

- [x] **Step 2: [사용자] 프로젝트 네비게이터에서 `RalliKit` 로컬 패키지가 보이는지 확인**

- [x] **Step 3: 링크 상태 빌드 확인 (에이전트)**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`
Expected: BUILD SUCCEEDED (아직 import 없음 — 링크가 빌드를 깨지 않는지만 확인)

---

### Task 4: 테니스 Watch 앱 마이그레이션 (HealthKitService → WorkoutCore)

**Files:**
- Create: `tennis-counter/WatchApp/Features/WorkoutSession/WorkoutConfiguration+Tennis.swift`
- Modify: `tennis-counter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (11행, 33-35행, import)
- Modify: `tennis-counter/WatchApp/Features/Workout/Metrics/WorkoutMetricsView.swift` (4행 타입, 57-63행 프리뷰, import)
- Modify: `tennis-counter/watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` (141-158행, import)
- Delete: `tennis-counter/Shared/Services/HealthKitService.swift`
- Commit 포함: `TennisCounter.xcodeproj/project.pbxproj` (Task 3에서 Xcode가 수정한 것)

**Interfaces:**
- Consumes: Task 2의 `WorkoutSessionService`, `WorkoutConfiguration`, `setLiveMetricsForTesting(heartRate:calories:elapsedSeconds:)`
- Produces: 앱 내부 확장 `extension WorkoutConfiguration { static let tennis }` (WatchApp 모듈 internal), `WorkoutSessionViewModel.init(healthKit:metricsThrottle:ackTimeoutSeconds:)` — 기존 호출부 `WorkoutSessionViewModel()`은 기본값으로 그대로 컴파일된다.

- [x] **Step 1: 테스트를 새 주입 API로 먼저 수정 (실패 상태 만들기)**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` 상단 import에 추가:

```swift
import WorkoutCore
```

141-158행의 두 테스트를 싱글톤 변조 방식에서 인스턴스 주입 방식으로 교체:

```swift
@Test @MainActor func metricsHeartRateReflectsHealthKit() {
    let healthKit = WorkoutSessionService(configuration: .tennis)
    healthKit.setLiveMetricsForTesting(heartRate: 140)
    let vm = WorkoutSessionViewModel(healthKit: healthKit)
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.broadcastMetrics()
    #expect(vm.lastMetrics?.heartRate == 140)
}

@Test @MainActor func metricsCaloriesAreNetOfStart() {
    let healthKit = WorkoutSessionService(configuration: .tennis)
    healthKit.setLiveMetricsForTesting(calories: 100)
    let vm = WorkoutSessionViewModel(healthKit: healthKit)
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    healthKit.setLiveMetricsForTesting(calories: 150)
    vm.broadcastMetrics()
    #expect(vm.lastMetrics?.calories == 50)
}
```

(`defer` 원복 코드는 삭제 — 주입 인스턴스라 전역 상태 오염이 없다.)

- [x] **Step 2: 테스트 컴파일 실패 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'`
Expected: FAIL — `cannot find 'WorkoutSessionService' in scope` (VM에 `init(healthKit:)`이 아직 없음)

- [x] **Step 3: 테니스 프리셋 확장 생성**

`WatchApp/Features/WorkoutSession/WorkoutConfiguration+Tennis.swift`:

```swift
import HealthKit
import WorkoutCore

extension WorkoutConfiguration {
    /// Ralli의 워크아웃 프리셋. 서비스 생성 지점에서만 참조한다.
    static let tennis = WorkoutConfiguration(activityType: .tennis)
}
```

- [x] **Step 4: WorkoutSessionViewModel DI 전환**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`:

import 블록에 추가 (alphabetical — SwiftFormat 규칙):

```swift
import Combine
import Foundation
import WidgetKit
import WorkoutCore
```

11행 교체:

```swift
// 변경 전
let healthKit = HealthKitService.shared
// 변경 후
let healthKit: WorkoutSessionService
```

33행 init 시그니처 교체 및 첫 줄에 대입 추가:

```swift
// 변경 전
init(metricsThrottle: TimeInterval = 5, ackTimeoutSeconds: TimeInterval = 8) {
    self.metricsThrottle = metricsThrottle
// 변경 후
init(healthKit: WorkoutSessionService = WorkoutSessionService(configuration: .tennis),
     metricsThrottle: TimeInterval = 5, ackTimeoutSeconds: TimeInterval = 8)
{
    self.healthKit = healthKit
    self.metricsThrottle = metricsThrottle
```

나머지 본문은 변경 없음 (`healthKit.` 호출 17곳은 프로퍼티명이 같아 그대로 동작).

- [x] **Step 5: WorkoutMetricsView 타입 교체 + 프리뷰 수정**

`WatchApp/Features/Workout/Metrics/WorkoutMetricsView.swift`:

```swift
// 변경 전 (1-4행)
import SwiftUI

struct WorkoutMetricsView: View {
    @ObservedObject var healthKit: HealthKitService
// 변경 후
import SwiftUI
import WorkoutCore

struct WorkoutMetricsView: View {
    @ObservedObject var healthKit: WorkoutSessionService
```

프리뷰(57-63행) 교체 — `private(set)` 전환으로 직접 대입이 불가해졌으므로 DEBUG 세터 사용:

```swift
#Preview("Active") {
    let service = WorkoutSessionService(configuration: .tennis)
    service.setLiveMetricsForTesting(heartRate: 102, calories: 245, elapsedSeconds: 1523)
    return WorkoutMetricsView(healthKit: service, isPaused: false)
}
```

- [x] **Step 6: 원본 서비스 삭제**

```bash
rm ~/Workspace/Projects/tennis-counter/Shared/Services/HealthKitService.swift
```

(`PBXFileSystemSynchronizedRootGroup`이라 pbxproj 수동 편집 불필요.)

- [x] **Step 7: Watch 테스트 통과 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'`
Expected: PASS — 기존 스위트 전체 그린 (metrics 2개 테스트 포함)

- [x] **Step 8: 린트/포맷 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && make fix && make lint`
Expected: 위반 0건

- [x] **Step 9: 커밋 (pbxproj 링크 변경 포함)**

```bash
cd ~/Workspace/Projects/tennis-counter
git add WatchApp watchosTests Shared/Services TennisCounter.xcodeproj/project.pbxproj
git commit -m "♻️ HealthKitService → RalliKit WorkoutCore 전환

- 로컬 패키지 ralli-kit 링크 (Watch 타겟)
- 싱글톤 → WorkoutConfiguration 주입 DI
- 테니스 종목 프리셋은 WorkoutConfiguration+Tennis.swift로 분리

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: iOS 회귀 확인 + 소비자 가이드 README

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/README.md`
- 회귀 확인: 테니스 iOS 타겟 (HealthKitService는 iOS에서 참조가 없었지만 Shared 소속이라 컴파일은 되던 파일 — 삭제 영향 확인)

**Interfaces:**
- Consumes: Task 4까지 완료된 상태
- Produces: 소비자 앱(골프·헬스) 온보딩 문서. Plan 2·3이 이 README에 섹션을 추가한다.

- [x] **Step 1: iOS 빌드 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [x] **Step 2: iOS 테스트 확인**

Run: `cd ~/Workspace/Projects/tennis-counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS — 기존 스위트 전체 그린

- [x] **Step 3: README 작성**

`~/Workspace/Projects/ralli-kit/README.md`:

```markdown
# RalliKit

Ralli(테니스 카운터)에서 추출한 iOS+watchOS 워크아웃 앱 인프라. 독립 라이브러리를 필요한 것만 골라 의존한다.

| Product | 역할 | 상태 |
|---|---|---|
| `WorkoutCore` | HealthKit 워크아웃 세션·칼로리·심박 측정 | ✅ |
| `ConnectivityCore` | 폰↔워치 전송 (실시간/큐잉/컨텍스트) | 예정 |
| `PersistenceCore` | SwiftData + CloudKit 컨테이너/서비스 | 예정 |

## WorkoutCore 사용법

```swift
import WorkoutCore

// 앱 루트에서 한 번 생성해 주입 (싱글톤 없음)
let workout = WorkoutSessionService(
    configuration: WorkoutConfiguration(activityType: .tennis)          // 테니스
    // .init(activityType: .golf)                                       // 골프
    // .init(activityType: .traditionalStrengthTraining, locationType: .indoor)  // 근력운동
)
```

- `startWorkout()/pauseWorkout()/resumeWorkout()/stopWorkout()`은 watchOS 전용.
- `stopWorkout()`은 `WorkoutResult`(시간·칼로리·평균심박) 반환.
- 테스트·프리뷰에서는 `#if DEBUG` 전용 `setLiveMetricsForTesting(heartRate:calories:elapsedSeconds:)`로 표시 값 주입.

## 소비자 앱 체크리스트 (패키지가 대신 못 해주는 것)

- [ ] 타겟 Capability에 **HealthKit** 추가 (엔타이틀먼트)
- [ ] Info.plist에 `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` 문구
- [ ] watchOS 타겟 최소 버전 10.0, iOS 17.0

## 개발 워크플로

- 로컬 개발: 소비자 앱 Xcode 프로젝트에 **Add Local…** 로 이 폴더를 추가하면 원격 참조를 오버라이드한다.
  ⚠️ 로컬 오버라이드를 남겨두면 원격 태그가 조용히 무시된다 — 검증 후 제거할 것.
- 배포: 초기에는 `branch: "main"` 참조, 앱 스토어 릴리즈 시점에 semver 태그.
```

- [x] **Step 4: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add README.md
git commit -m "📝 소비자 가이드 README — WorkoutCore 사용법·엔타이틀먼트 체크리스트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [x] **Step 5: [사용자, 선택] GitHub 원격 레포 생성 + push**

로컬 링크만으로 개발이 가능하므로 필수는 아니다. 원격이 필요해지는 시점(다른 앱에서 원격 참조)에:

```bash
gh repo create qlrogo91lp/ralli-kit --private --source ~/Workspace/Projects/ralli-kit --push
```

---

## 완료 기준 (Plan 1 Definition of Done)

1. `swift test` (ralli-kit) 그린 — WorkoutCore 8개 테스트
2. 테니스 Watch 빌드+테스트 그린, iOS 빌드+테스트 그린
3. `Shared/Services/HealthKitService.swift` 삭제됨, 앱 어디에도 `HealthKitService` 참조 없음 (`grep -rn "HealthKitService" --include="*.swift" .` 결과 0건)
4. 실기기 스모크 테스트는 사용자 몫: 워치에서 운동 시작 → 심박/칼로리 표기 → 종료 (Plan 2의 실기기 회귀와 묶어서 해도 됨)

---

## 실행 기록 (2026-07-14 완료)

- 실행 방식: subagent-driven-development. Task 1~5 전부 태스크 리뷰 통과, 최종 전체 브랜치 리뷰(fable) 판정 **"Ready to merge: Yes"**.
- 커밋: ralli-kit `a665e8f`(스캐폴딩) → `3333fc2`(서비스 이식) → `67406f9`(README) / tennis `3b4f027`(마이그레이션) + `a4cb39c`(Release 픽스).
- 검증: ralli-kit `swift test` 8/8, Watch 테스트·빌드(Debug/Release) 그린, iOS 테스트 그린, `HealthKitService` 참조 양 레포 0건.

### 계획과 달랐던 점

1. **프리뷰 `#if DEBUG` 래핑 추가 (`a4cb39c`, 계획에 없던 수정)** — Task 4 Step 5의 계획 코드는 `#Preview`가 DEBUG 전용 `setLiveMetricsForTesting`을 참조하는데, `#Preview` 본문은 Release에서도 컴파일되므로 Watch **Release 빌드(아카이브)가 실패**한다. 최종 리뷰어가 실제 Release 빌드로 실증 → 프리뷰 블록 전체를 `#if DEBUG`로 감싸 해결. 근본 원인: 이 계획의 DoD가 Debug 구성만 검증했다.
2. **watchOS destination** — `name=Apple Watch Series 11 (46mm)` 매칭이 이 머신에서 실패. 빌드·테스트 모두 `id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1` 사용.

### 후속 작업 (Plan 2·3 작성 시 반영)

- **Plan 2 DoD에 Release 구성 빌드 추가** — Debug 전용 검증이 아카이브 실패를 숨겼다.
- **ralli-kit GitHub 푸시** — 현재 3커밋이 로컬 디스크에만 존재(백업 없음). Plan 2 선행 단계로. 릴리즈 전에는 테니스를 원격 참조로 전환하고 로컬 오버라이드 제거(README 경고 참조).
- ralli-kit 하이지니 커밋(선택): `timerPausedAt` 데드코드 제거, `WorkoutConfiguration`·`WorkoutResult`에 `Sendable`/`Equatable`, 서비스 `deinit`에서 timer invalidate.
- 실기기 스모크 테스트(DoD #4)는 미실행 — Plan 2의 실기기 2대 회귀와 병행 예정.
