# WorkoutUI 추출 Implementation Plan (Plan A — 동작 무변경)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RalliKit에 `WorkoutUI` product를 신설하고 테니스 앱의 워크아웃 화면을 그리로 옮긴다. 세 앱(테니스·골프·헬스)이 같은 화면을 공유할 기반을 만든다.

**Architecture:** `WorkoutMetrics` 값 타입을 `WorkoutCore`로 승격하고, 와이어 직렬화를 `WorkoutMetricsMessage`로 패키지에 흡수한다(`WorkoutCore → ConnectivityCore` 의존 추가). `WorkoutUI`는 `WorkoutCore`에만 의존하며 플랫폼별 폴더(`Shared/`·`Watch/`·`iOS/`)로 나누고 파일 단위 `#if os()`로 감싼다. 화면은 값과 콜백만 받는 순수 뷰다.

**Tech Stack:** Swift 6 toolchain (language mode v5), SwiftUI, Swift Testing (`@Test`/`#expect`), SPM 멀티 product 패키지, Xcode `PBXFileSystemSynchronizedRootGroup`

## Global Constraints

- **동작 무변경**: 이 플랜은 코드 이동·구조 변경만 한다. 칼로리 기준·앵커 시간·pause 동기화는 **Plan B**(후속)에서 다룬다. 와이어 포맷은 키 하나도 바꾸지 않는다.
- **표시 항목 4개 고정**: 경과시간·활동 kcal·총 kcal·BPM. iOS "경기 수" 카드는 제거한다. 걸음수·거리는 표시하지 않는다.
- **네이밍**: 화면은 `View` suffix (`WorkoutMetricsView`, `WorkoutDashboardView`). Components 폴더의 순수 컴포넌트는 suffix 없음. 한 파일 = 한 타입.
- **플랫폼 폴더 규칙**: `Watch/`와 `iOS/`는 서로 import 금지. 공유가 필요하면 `Shared/`로 올린다. `Watch/`·`iOS/` 아래 모든 파일은 `#if os(watchOS)` / `#if os(iOS)`로 감싼다 (SPM은 타겟 내 모든 파일을 모든 플랫폼에 컴파일한다).
- **패키지 문자열은 `bundle: .module` 필수**: `String(localized: "key", bundle: .module)`. 빠뜨리면 키 이름이 그대로 화면에 뜬다.
- **색상은 하드코딩**: 노랑 타이머·빨강 하트·초록/노랑 링. 테마 주입 없음.
- **플랫폼 최소 버전**: iOS 17.0, watchOS 10.0. macOS는 고려·검증 대상 아님.
- **`.xcodeproj` 직접 편집 금지**: 파일 생성·삭제는 파일시스템 조작만으로 충분하다. 단 **패키지 product를 타겟에 링크하는 것은 Xcode GUI 수동 작업**이며 Task 6에서 사용자가 직접 수행한다.
- **Swift Testing 사용**: `@Test`/`#expect`. ViewModel 테스트는 `@MainActor`. View는 테스트하지 않는다.
- **커밋**: 각 Task 끝에서 커밋. 테니스 레포는 `feature/workout-ui-shared` 브랜치, ralli-kit은 새 브랜치 `feat/workout-ui`.

### 검증 명령

시뮬레이터 UDID는 **머신마다 다르다.** 매 세션 시작 시 다시 확인할 것:

```bash
xcrun simctl list devices available | grep -E "iPhone 17 Pro|Apple Watch Series 11"
```

이 플랜 작성 시점 값 (2026-08-05 머신):
- iPhone 17 Pro: `C29B5911-545A-4FD0-853B-9B219A300025`
- Apple Watch Series 11 (46mm): `74666695-204D-45AC-8787-2CFEA2CE0C51`

```bash
# ralli-kit 테스트 ("RalliKit" 아닌 "RalliKit-Package" 스킴)
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package \
  -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025'

# 테니스 iOS
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 테니스 Watch (이름 매칭 실패함 — 반드시 UDID)
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51'
```

---

## File Structure

**ralli-kit** (`~/Workspace/Projects/ralli-kit`)

| 파일 | 책임 |
|---|---|
| `Sources/WorkoutCore/WorkoutMetrics.swift` | 진행 중 스냅샷 값 타입 + 경과시간 포맷 |
| `Sources/WorkoutCore/Messages/WorkoutMetricsMessage.swift` | 워치→폰 메트릭 와이어 포맷 |
| `Sources/WorkoutUI/Shared/HeartRateIcon.swift` | 심박 아이콘 + 펄스 애니메이션 (양 플랫폼) |
| `Sources/WorkoutUI/Shared/MetricValueLabel.swift` | "245 kcal" 수치+단위 타이포 (양 플랫폼) |
| `Sources/WorkoutUI/Watch/WorkoutMetricsView.swift` | 워치 메트릭 화면 (세로 4항목) |
| `Sources/WorkoutUI/Watch/WorkoutControlsView.swift` | 워치 컨트롤 화면 (pause/end) |
| `Sources/WorkoutUI/Watch/Components/StackedLabel.swift` | 공백 split 세로 라벨 |
| `Sources/WorkoutUI/iOS/WorkoutDashboardView.swift` | 폰 대시보드 (링 + 그리드 + 컨트롤) |
| `Sources/WorkoutUI/iOS/Components/MetricCard.swift` | 카드 컨테이너 |
| `Sources/WorkoutUI/iOS/Components/WorkoutTimerRing.swift` | 경과시간 링 |
| `Sources/WorkoutUI/iOS/Components/WorkoutControls.swift` | pause/end 버튼 쌍 |
| `Sources/WorkoutUI/Resources/{en,ko}.lproj/Localizable.strings` | 패키지 소유 라벨 |
| `Package.swift` | `defaultLocalization`, `WorkoutUI` product, 의존 2건 |

**tennis-counter**

| 파일 | 변경 |
|---|---|
| `Shared/Models/WorkoutMetrics.swift` | **삭제** (코어로 승격) |
| `Shared/Services/ConnectivityMessages.swift` | `extension WorkoutMetrics: ConnectivityMessage` 삭제 |
| `Shared/Services/MatchConnectivity.swift` | `WorkoutMetricsMessage` 사용으로 교체 |
| `WatchApp/Features/Workout/` | **폴더 전체 삭제** (데드코드 `WorkoutMetric.swift` 포함) |
| `WatchApp/Features/WorkoutSession/WorkoutSessionView.swift` | 패키지 뷰 호출, 부모가 `healthKit` 관찰 |
| `iOSApp/Features/Workout/` | **폴더 전체 삭제** |
| `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` | `WorkoutDashboardView` 호출 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `completedMatchCount` 제거, `activeCalories` 개명 반영 |
| `iosTests/Shared/WorkoutMetricsTests.swift` | **삭제** (패키지 테스트로 이관) |
| `WatchApp/{en,ko}.lproj/Localizable.strings` | `metrics_*`·`workout_pause/resume/end` 제거 |
| `iOSApp/{en,ko}.lproj/Localizable.strings` | `workout_metric_*`·`workout_elapsed_label` 제거 |

---

## Task 1: WorkoutMetrics를 WorkoutCore로 승격

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutCore/WorkoutMetrics.swift`
- Test: `~/Workspace/Projects/ralli-kit/Tests/WorkoutCoreTests/WorkoutMetricsTests.swift`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: `public struct WorkoutMetrics: Equatable, Sendable`  
  - `init(elapsedSeconds: TimeInterval = 0, activeCalories: Double = 0, totalCalories: Double = 0, heartRate: Double = 0)`
  - 프로퍼티: `elapsedSeconds: TimeInterval`, `activeCalories: Double`, `totalCalories: Double`, `heartRate: Double`
  - `var formattedElapsed: String`
  - `static func formatSeconds(_ seconds: Int) -> String`

> 이 태스크는 패키지에만 타입을 추가한다. 테니스 앱에도 같은 이름의 타입이 남아 있지만, Swift는 현재 모듈의 선언을 import된 것보다 우선하므로 앱은 그대로 컴파일된다. 앱 쪽 정리는 Task 6에서 한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/WorkoutCoreTests/WorkoutMetricsTests.swift`:

```swift
import Testing
@testable import WorkoutCore

struct WorkoutMetricsTests {
    @Test func formatsUnderOneHourAsMinutesSeconds() {
        #expect(WorkoutMetrics.formatSeconds(0) == "00:00")
        #expect(WorkoutMetrics.formatSeconds(59) == "00:59")
        #expect(WorkoutMetrics.formatSeconds(600) == "10:00")
    }

    @Test func formatsOneHourBoundaryWithHours() {
        #expect(WorkoutMetrics.formatSeconds(3599) == "59:59")
        #expect(WorkoutMetrics.formatSeconds(3600) == "1:00:00")
        #expect(WorkoutMetrics.formatSeconds(3661) == "1:01:01")
    }

    @Test func formattedElapsedUsesElapsedSeconds() {
        let metrics = WorkoutMetrics(elapsedSeconds: 1523)
        #expect(metrics.formattedElapsed == "25:23")
    }

    @Test func defaultsAreZero() {
        let metrics = WorkoutMetrics()
        #expect(metrics.elapsedSeconds == 0)
        #expect(metrics.activeCalories == 0)
        #expect(metrics.totalCalories == 0)
        #expect(metrics.heartRate == 0)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `cannot find 'WorkoutMetrics' in scope`

- [ ] **Step 3: 최소 구현**

`Sources/WorkoutCore/WorkoutMetrics.swift`:

```swift
import Foundation

/// 워크아웃 진행 중 스냅샷. 종료 시 요약인 `WorkoutResult`의 진행 중 버전이다.
public struct WorkoutMetrics: Equatable, Sendable {
    public let elapsedSeconds: TimeInterval
    /// 활동 에너지(activeEnergyBurned)만.
    public let activeCalories: Double
    /// 활동 + 휴식(basalEnergyBurned).
    public let totalCalories: Double
    public let heartRate: Double

    public init(elapsedSeconds: TimeInterval = 0,
                activeCalories: Double = 0,
                totalCalories: Double = 0,
                heartRate: Double = 0)
    {
        self.elapsedSeconds = elapsedSeconds
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.heartRate = heartRate
    }

    public var formattedElapsed: String {
        Self.formatSeconds(Int(elapsedSeconds))
    }

    public static func formatSeconds(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: PASS

- [ ] **Step 5: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit && git checkout -b feat/workout-ui
git add Sources/WorkoutCore/WorkoutMetrics.swift Tests/WorkoutCoreTests/WorkoutMetricsTests.swift
git commit -m "✨ WorkoutCore에 WorkoutMetrics 값 타입 추가"
```

---

## Task 2: WorkoutMetricsMessage — 와이어 포맷을 패키지로

**Files:**
- Modify: `~/Workspace/Projects/ralli-kit/Package.swift` (WorkoutCore에 ConnectivityCore 의존 추가)
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutCore/Messages/WorkoutMetricsMessage.swift`
- Test: `~/Workspace/Projects/ralli-kit/Tests/WorkoutCoreTests/WorkoutMetricsMessageTests.swift`

**Interfaces:**
- Consumes: `WorkoutMetrics` (Task 1)
- Produces: `public struct WorkoutMetricsMessage: ConnectivityMessage`
  - `static let messageType = "metrics"`
  - `init(metrics: WorkoutMetrics)`
  - `let metrics: WorkoutMetrics`

> 와이어 키는 앱 시절과 **완전히 동일**하다: `elapsed`, `calories`, `totalCalories`, `heartRate`. 구버전 워치 폴백(`totalCalories` 없으면 `calories`)도 그대로 이식한다. `type`/`sentAt`은 `ConnectivityService`가 스탬프하므로 `toDictionary()`에 넣지 않는다.

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/WorkoutCoreTests/WorkoutMetricsMessageTests.swift`:

```swift
import Testing
@testable import WorkoutCore

struct WorkoutMetricsMessageTests {
    @Test func roundTripsThroughDictionary() {
        let original = WorkoutMetrics(elapsedSeconds: 1523,
                                      activeCalories: 245,
                                      totalCalories: 310,
                                      heartRate: 142)
        let dict = WorkoutMetricsMessage(metrics: original).toDictionary()
        let restored = WorkoutMetricsMessage(from: dict)
        #expect(restored?.metrics == original)
    }

    @Test func missingElapsedFailsInit() {
        #expect(WorkoutMetricsMessage(from: ["calories": 100.0]) == nil)
    }

    /// 구버전 워치는 totalCalories 키를 안 보낸다 — 활동 칼로리로 폴백해야 한다.
    @Test func legacyPayloadWithoutTotalCaloriesFallsBackToActive() {
        let dict: [String: Any] = ["elapsed": 600.0, "calories": 120.0, "heartRate": 130.0]
        let message = WorkoutMetricsMessage(from: dict)
        #expect(message?.metrics.totalCalories == 120)
        #expect(message?.metrics.activeCalories == 120)
    }

    @Test func messageTypeIsMetrics() {
        #expect(WorkoutMetricsMessage.messageType == "metrics")
    }

    @Test func wireKeysMatchLegacyFormat() {
        let dict = WorkoutMetricsMessage(
            metrics: WorkoutMetrics(elapsedSeconds: 10, activeCalories: 20, totalCalories: 30, heartRate: 40)
        ).toDictionary()
        #expect(dict["elapsed"] as? Double == 10)
        #expect(dict["calories"] as? Double == 20)
        #expect(dict["totalCalories"] as? Double == 30)
        #expect(dict["heartRate"] as? Double == 40)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `cannot find 'WorkoutMetricsMessage' in scope`

- [ ] **Step 3: Package.swift에 의존 추가**

`Package.swift`의 WorkoutCore 타겟을 다음으로 교체:

```swift
        .target(
            name: "WorkoutCore",
            dependencies: ["ConnectivityCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
```

- [ ] **Step 4: 메시지 타입 구현**

`Sources/WorkoutCore/Messages/WorkoutMetricsMessage.swift`:

```swift
import ConnectivityCore
import Foundation

/// 워치 → 폰 워크아웃 메트릭 브로드캐스트.
/// 와이어 키는 앱에 있던 시절 포맷을 그대로 유지한다 (구버전 앱과 호환).
public struct WorkoutMetricsMessage: ConnectivityMessage {
    public static let messageType = "metrics"

    public let metrics: WorkoutMetrics

    public init(metrics: WorkoutMetrics) {
        self.metrics = metrics
    }

    public init?(from dictionary: [String: Any]) {
        guard let elapsed = dictionary["elapsed"] as? TimeInterval else { return nil }
        let active = dictionary["calories"] as? Double ?? 0
        // 구버전 워치는 totalCalories를 안 보낸다 — 활동 칼로리로 폴백.
        let total = dictionary["totalCalories"] as? Double ?? active
        metrics = WorkoutMetrics(elapsedSeconds: elapsed,
                                 activeCalories: active,
                                 totalCalories: total,
                                 heartRate: dictionary["heartRate"] as? Double ?? 0)
    }

    public func toDictionary() -> [String: Any] {
        ["elapsed": metrics.elapsedSeconds,
         "calories": metrics.activeCalories,
         "totalCalories": metrics.totalCalories,
         "heartRate": metrics.heartRate]
    }
}
```

- [ ] **Step 5: 통과 확인**

```bash
cd ~/Workspace/Projects/ralli-kit && xcodebuild test -scheme RalliKit-Package -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: PASS

- [ ] **Step 6: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add Package.swift Sources/WorkoutCore/Messages/ Tests/WorkoutCoreTests/WorkoutMetricsMessageTests.swift
git commit -m "✨ WorkoutMetricsMessage — 메트릭 와이어 포맷을 WorkoutCore로"
```

---

## Task 3: WorkoutUI 타겟 신설 + 공용 컴포넌트

**Files:**
- Modify: `~/Workspace/Projects/ralli-kit/Package.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/Shared/HeartRateIcon.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/Shared/MetricValueLabel.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/Resources/en.lproj/Localizable.strings`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/Resources/ko.lproj/Localizable.strings`

**Interfaces:**
- Consumes: `WorkoutMetrics` (Task 1)
- Produces:
  - `public struct HeartRateIcon: View` — `init(heartRate: Double, size: CGFloat = 20)`
  - `public struct MetricValueLabel: View` — `init(value: String, unit: String, valueSize: CGFloat = 32, unitSize: CGFloat = 14)`
  - 라벨 키: `metrics_active_kcal`, `metrics_total_kcal`, `metrics_bpm`, `metrics_elapsed`, `workout_pause`, `workout_resume`, `workout_end`

> View는 테스트하지 않는다 (프로젝트 규칙). 이 태스크의 검증은 **두 플랫폼 빌드 성공**이다.

- [ ] **Step 1: Package.swift에 WorkoutUI 추가**

`Package.swift` 전체를 다음으로 교체:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RalliKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WorkoutCore", targets: ["WorkoutCore"]),
        .library(name: "WorkoutUI", targets: ["WorkoutUI"]),
        .library(name: "ConnectivityCore", targets: ["ConnectivityCore"]),
        .library(name: "PersistenceCore", targets: ["PersistenceCore"]),
    ],
    targets: [
        .target(
            name: "WorkoutCore",
            dependencies: ["ConnectivityCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "WorkoutUI",
            dependencies: ["WorkoutCore"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "ConnectivityCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "PersistenceCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "WorkoutCoreTests",
            dependencies: ["WorkoutCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ConnectivityCoreTests",
            dependencies: ["ConnectivityCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PersistenceCoreTests",
            dependencies: ["PersistenceCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

- [ ] **Step 2: 리소스 파일 생성**

`Sources/WorkoutUI/Resources/en.lproj/Localizable.strings`:

```
"metrics_active_kcal" = "ACTIVE KCAL";
"metrics_total_kcal" = "TOTAL KCAL";
"metrics_bpm" = "BPM";
"metrics_elapsed" = "Elapsed";
"workout_pause" = "Pause";
"workout_resume" = "Resume";
"workout_end" = "End Workout";
```

`Sources/WorkoutUI/Resources/ko.lproj/Localizable.strings`:

```
"metrics_active_kcal" = "ACTIVE KCAL";
"metrics_total_kcal" = "TOTAL KCAL";
"metrics_bpm" = "BPM";
"metrics_elapsed" = "운동 시간";
"workout_pause" = "일시정지";
"workout_resume" = "계속하기";
"workout_end" = "운동 종료";
```

- [ ] **Step 3: HeartRateIcon 구현**

`Sources/WorkoutUI/Shared/HeartRateIcon.swift` — iOS의 `HeartRateIcon`(scale 1.3)과 워치 인라인 구현(scale 1.2)을 통합한다. 통합 스케일은 **1.3**:

```swift
import SwiftUI

/// 심박이 잡히면 채워진 하트가 맥동하고, 0이면 빈 하트로 정지한다.
public struct HeartRateIcon: View {
    private let heartRate: Double
    private let size: CGFloat

    @State private var scale: CGFloat = 1.0

    public init(heartRate: Double, size: CGFloat = 20) {
        self.heartRate = heartRate
        self.size = size
    }

    public var body: some View {
        Image(systemName: heartRate > 0 ? "heart.fill" : "heart")
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(.red)
            .scaleEffect(scale)
            .onAppear {
                guard heartRate > 0 else { return }
                startPulse()
            }
            .onChange(of: heartRate > 0) { _, isActive in
                if isActive {
                    startPulse()
                } else {
                    withAnimation(.default) { scale = 1.0 }
                }
            }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            scale = 1.3
        }
    }
}
```

- [ ] **Step 4: MetricValueLabel 구현**

`Sources/WorkoutUI/Shared/MetricValueLabel.swift`:

```swift
import SwiftUI

/// "245 kcal" 형태의 수치 + 단위. 단위가 수치의 마지막 텍스트 베이스라인에 정렬된다.
public struct MetricValueLabel: View {
    private let value: String
    private let unit: String
    private let valueSize: CGFloat
    private let unitSize: CGFloat

    public init(value: String, unit: String, valueSize: CGFloat = 32, unitSize: CGFloat = 14) {
        self.value = value
        self.unit = unit
        self.valueSize = valueSize
        self.unitSize = unitSize
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: unitSize, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
```

- [ ] **Step 5: 두 플랫폼 빌드 검증**

```bash
cd ~/Workspace/Projects/ralli-kit
xcodebuild build -scheme WorkoutUI -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
xcodebuild build -scheme WorkoutUI -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: 둘 다 BUILD SUCCEEDED

> 스킴 `WorkoutUI`가 목록에 없으면 `xcodebuild -list`로 확인할 것. SPM은 product마다 스킴을 자동 생성한다.

- [ ] **Step 6: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add Package.swift Sources/WorkoutUI/
git commit -m "✨ WorkoutUI product 신설 + 공용 컴포넌트(HeartRateIcon, MetricValueLabel)"
```

---

## Task 4: WorkoutUI Watch 화면 2개

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/Watch/Components/StackedLabel.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/Watch/WorkoutMetricsView.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/Watch/WorkoutControlsView.swift`

**Interfaces:**
- Consumes: `WorkoutMetrics` (Task 1), `HeartRateIcon` (Task 3)
- Produces:
  - `public struct WorkoutMetricsView: View` — `init(metrics: WorkoutMetrics, isPaused: Bool)`
  - `public struct WorkoutControlsView: View` — `init(isPaused: Bool, isPauseAvailable: Bool = true, onPauseResume: @escaping () -> Void, onEnd: @escaping () -> Void)`

> 기존 워치 `WorkoutControlsView`는 ViewModel을 직접 받았다. 패키지 버전은 값 + 콜백만 받는다.
> 기존 워치 화면의 툴바 자리채움(`Color.clear.frame(width: 36, height: 36)`)은 앱 네비게이션 사정이므로 패키지로 옮기지 않는다 — 앱에서 감싼다.

- [ ] **Step 1: StackedLabel 구현**

`Sources/WorkoutUI/Watch/Components/StackedLabel.swift`:

```swift
#if os(watchOS)
    import SwiftUI

    /// 공백으로 구분된 라벨을 단어마다 한 줄씩 세로로 쌓는다.
    /// 워치의 좁은 폭에서 "ACTIVE KCAL" 같은 두 단어 라벨을 숫자 옆에 붙이기 위한 것.
    struct StackedLabel: View {
        let text: String
        let font: Font
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(text.split(separator: " ").map(String.init), id: \.self) { word in
                    Text(word)
                        .font(font)
                        .foregroundColor(color)
                }
            }
        }
    }
#endif
```

- [ ] **Step 2: WorkoutMetricsView 구현**

`Sources/WorkoutUI/Watch/WorkoutMetricsView.swift`:

```swift
#if os(watchOS)
    import SwiftUI
    import WorkoutCore

    /// 워치 워크아웃 메트릭 화면 — 경과시간·활동 kcal·총 kcal·BPM을 세로로 나열한다.
    public struct WorkoutMetricsView: View {
        private let metrics: WorkoutMetrics
        private let isPaused: Bool

        public init(metrics: WorkoutMetrics, isPaused: Bool) {
            self.metrics = metrics
            self.isPaused = isPaused
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(metrics.formattedElapsed)
                    .font(.system(size: 45, weight: .semibold, design: .rounded))
                    .foregroundColor(isPaused ? Color.yellow.opacity(0.5) : .yellow)
                    .contentTransition(.numericText())

                HStack(alignment: .bottom, spacing: 6) {
                    Text(String(format: "%.0f", metrics.activeCalories))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    StackedLabel(text: String(localized: "metrics_active_kcal", bundle: .module),
                                 font: .system(size: 12, weight: .semibold),
                                 color: .white)
                        .padding(.bottom, 5)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    Text(String(format: "%.0f", metrics.totalCalories))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    StackedLabel(text: String(localized: "metrics_total_kcal", bundle: .module),
                                 font: .system(size: 11, weight: .medium),
                                 color: .white.opacity(0.5))
                        .padding(.bottom, 2)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    Text(heartRateText)
                        .font(.system(size: 35, weight: .bold, design: .rounded))
                    HeartRateIcon(heartRate: metrics.heartRate)
                        .padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .background(Color.black.ignoresSafeArea())
        }

        private var heartRateText: String {
            metrics.heartRate > 0 ? String(format: "%.0f", metrics.heartRate) : "--"
        }
    }

    #Preview {
        WorkoutMetricsView(
            metrics: WorkoutMetrics(elapsedSeconds: 1523, activeCalories: 245, totalCalories: 303, heartRate: 102),
            isPaused: false
        )
    }
#endif
```

- [ ] **Step 3: WorkoutControlsView 구현**

`Sources/WorkoutUI/Watch/WorkoutControlsView.swift`:

```swift
#if os(watchOS)
    import SwiftUI

    /// 워치 워크아웃 컨트롤 화면 — 일시정지/재개, 운동 종료.
    public struct WorkoutControlsView: View {
        private let isPaused: Bool
        private let isPauseAvailable: Bool
        private let onPauseResume: () -> Void
        private let onEnd: () -> Void

        public init(isPaused: Bool,
                    isPauseAvailable: Bool = true,
                    onPauseResume: @escaping () -> Void,
                    onEnd: @escaping () -> Void)
        {
            self.isPaused = isPaused
            self.isPauseAvailable = isPauseAvailable
            self.onPauseResume = onPauseResume
            self.onEnd = onEnd
        }

        public var body: some View {
            VStack(spacing: 12) {
                Button(action: onPauseResume) {
                    Label(
                        isPaused
                            ? String(localized: "workout_resume", bundle: .module)
                            : String(localized: "workout_pause", bundle: .module),
                        systemImage: isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .tint(.yellow)
                .disabled(!isPauseAvailable)

                Button(role: .destructive, action: onEnd) {
                    Label(String(localized: "workout_end", bundle: .module), systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }

    #Preview {
        WorkoutControlsView(isPaused: false, onPauseResume: {}, onEnd: {})
    }
#endif
```

- [ ] **Step 4: 두 플랫폼 빌드 검증**

```bash
cd ~/Workspace/Projects/ralli-kit
xcodebuild build -scheme WorkoutUI -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
xcodebuild build -scheme WorkoutUI -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: 둘 다 BUILD SUCCEEDED (iOS 빌드에서는 `#if os(watchOS)`로 전부 제외됨)

- [ ] **Step 5: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add Sources/WorkoutUI/Watch/
git commit -m "✨ WorkoutUI Watch 화면 — 메트릭·컨트롤"
```

---

## Task 5: WorkoutUI iOS 대시보드

**Files:**
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/iOS/Components/MetricCard.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/iOS/Components/WorkoutTimerRing.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/iOS/Components/WorkoutControls.swift`
- Create: `~/Workspace/Projects/ralli-kit/Sources/WorkoutUI/iOS/WorkoutDashboardView.swift`

**Interfaces:**
- Consumes: `WorkoutMetrics` (Task 1), `HeartRateIcon`·`MetricValueLabel` (Task 3)
- Produces: `public struct WorkoutDashboardView: View` — `init(metrics: WorkoutMetrics, isPaused: Bool, isPauseAvailable: Bool = true, onPauseResume: @escaping () -> Void, onEnd: @escaping () -> Void)`

> 그리드는 **4칸이 아니라 3칸**이다 — 경과시간은 링이 담당하고, 카드는 BPM·활동 kcal·총 kcal 세 개다. "경기 수" 카드는 제거된다 (Global Constraints). 3칸이므로 2열 그리드가 아니라 **1행 3열**로 배치해 빈 칸이 생기지 않게 한다.

- [ ] **Step 1: MetricCard 구현**

`Sources/WorkoutUI/iOS/Components/MetricCard.swift`:

```swift
#if os(iOS)
    import SwiftUI

    /// 대시보드 지표 카드의 공통 컨테이너.
    struct MetricCard<Content: View>: View {
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                content()
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
#endif
```

- [ ] **Step 2: WorkoutTimerRing 구현**

`Sources/WorkoutUI/iOS/Components/WorkoutTimerRing.swift`:

```swift
#if os(iOS)
    import SwiftUI

    /// 경과시간을 감싸는 링. 일시정지면 노랑, 진행 중이면 초록.
    struct WorkoutTimerRing: View {
        let formattedElapsed: String
        let isPaused: Bool

        private var ringColor: Color {
            isPaused ? .yellow : .green
        }

        var body: some View {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 240, height: 240)
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(String(localized: "metrics_elapsed", bundle: .module))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                    Text(formattedElapsed)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .frame(width: 180)
                }
            }
        }
    }
#endif
```

- [ ] **Step 3: WorkoutControls 구현**

`Sources/WorkoutUI/iOS/Components/WorkoutControls.swift`:

```swift
#if os(iOS)
    import SwiftUI

    /// 일시정지/재개 + 종료 버튼 쌍.
    struct WorkoutControls: View {
        let isPaused: Bool
        let isPauseAvailable: Bool
        let onPauseResume: () -> Void
        let onEnd: () -> Void

        private var pauseTitle: String {
            isPaused
                ? String(localized: "workout_resume", bundle: .module)
                : String(localized: "workout_pause", bundle: .module)
        }

        var body: some View {
            HStack(spacing: 12) {
                Button(action: onPauseResume) {
                    HStack(spacing: 8) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(pauseTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isPauseAvailable ? Color.yellow : Color.yellow.opacity(0.3))
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                }
                .disabled(!isPauseAvailable)
                .accessibilityLabel(pauseTitle)

                Button(role: .destructive, action: onEnd) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .frame(width: 56, height: 56)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "workout_end", bundle: .module))
            }
            .padding(.bottom, 16)
        }
    }
#endif
```

- [ ] **Step 4: WorkoutDashboardView 구현**

`Sources/WorkoutUI/iOS/WorkoutDashboardView.swift`:

```swift
#if os(iOS)
    import SwiftUI
    import WorkoutCore

    /// 폰 워크아웃 대시보드 — 경과시간 링 + 지표 3칸 + 컨트롤.
    public struct WorkoutDashboardView: View {
        private let metrics: WorkoutMetrics
        private let isPaused: Bool
        private let isPauseAvailable: Bool
        private let onPauseResume: () -> Void
        private let onEnd: () -> Void

        public init(metrics: WorkoutMetrics,
                    isPaused: Bool,
                    isPauseAvailable: Bool = true,
                    onPauseResume: @escaping () -> Void,
                    onEnd: @escaping () -> Void)
        {
            self.metrics = metrics
            self.isPaused = isPaused
            self.isPauseAvailable = isPauseAvailable
            self.onPauseResume = onPauseResume
            self.onEnd = onEnd
        }

        public var body: some View {
            VStack {
                WorkoutTimerRing(formattedElapsed: metrics.formattedElapsed, isPaused: isPaused)

                Spacer()

                metricsRow
                    .padding(.horizontal, 20)

                Spacer()

                WorkoutControls(isPaused: isPaused,
                                isPauseAvailable: isPauseAvailable,
                                onPauseResume: onPauseResume,
                                onEnd: onEnd)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }

        private var metricsRow: some View {
            HStack(spacing: 12) {
                MetricCard {
                    HStack(spacing: 4) {
                        HeartRateIcon(heartRate: metrics.heartRate, size: 13)
                        Text(String(localized: "metrics_bpm", bundle: .module))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    MetricValueLabel(
                        value: metrics.heartRate > 0 ? String(format: "%.0f", metrics.heartRate) : "--",
                        unit: "bpm",
                        valueSize: 26
                    )
                }
                MetricCard {
                    Text(String(localized: "metrics_active_kcal", bundle: .module))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    MetricValueLabel(value: String(format: "%.0f", metrics.activeCalories),
                                     unit: "kcal",
                                     valueSize: 26)
                }
                MetricCard {
                    Text(String(localized: "metrics_total_kcal", bundle: .module))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    MetricValueLabel(value: String(format: "%.0f", metrics.totalCalories),
                                     unit: "kcal",
                                     valueSize: 26)
                }
            }
        }
    }

    #Preview {
        WorkoutDashboardView(
            metrics: WorkoutMetrics(elapsedSeconds: 1980, activeCalories: 245, totalCalories: 310, heartRate: 142),
            isPaused: false,
            onPauseResume: {},
            onEnd: {}
        )
        .preferredColorScheme(.dark)
    }
#endif
```

- [ ] **Step 5: 두 플랫폼 빌드 검증**

```bash
cd ~/Workspace/Projects/ralli-kit
xcodebuild build -scheme WorkoutUI -destination 'platform=iOS Simulator,id=C29B5911-545A-4FD0-853B-9B219A300025' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
xcodebuild build -scheme WorkoutUI -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: 둘 다 BUILD SUCCEEDED

- [ ] **Step 6: Release 빌드도 검증** (Plan 1 교훈 — `#Preview`가 Release에서 깨진 전례)

```bash
cd ~/Workspace/Projects/ralli-kit
xcodebuild build -scheme WorkoutUI -configuration Release -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: 커밋**

```bash
cd ~/Workspace/Projects/ralli-kit
git add Sources/WorkoutUI/iOS/
git commit -m "✨ WorkoutUI iOS 대시보드 — 링 + 지표 3칸 + 컨트롤"
```

---

## Task 6: 테니스 앱 — WorkoutMetrics 스왑

**Files:**
- Delete: `Shared/Models/WorkoutMetrics.swift`
- Delete: `iosTests/Shared/WorkoutMetricsTests.swift`
- Modify: `Shared/Services/ConnectivityMessages.swift` (맨 아래 `extension WorkoutMetrics: ConnectivityMessage` 제거)
- Modify: `Shared/Services/MatchConnectivity.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`

**Interfaces:**
- Consumes: `WorkoutMetrics`·`WorkoutMetricsMessage` (Task 1·2)
- Produces: 앱 전체가 `WorkoutCore.WorkoutMetrics`를 사용. `MatchConnectivity.receivedMetrics: WorkoutMetrics?` 표면은 불변.

### ⚠️ Step 0은 사용자 수동 작업 — 에이전트는 여기서 멈추고 요청할 것

- [ ] **Step 0: Xcode GUI에서 WorkoutUI 링크 (사용자)**

Xcode에서 `TennisCounter.xcodeproj`를 열고, 다음 두 타겟의 **General → Frameworks, Libraries, and Embedded Content**에 `WorkoutUI`를 추가한다:
- `TennisCounter` (iOS)
- `TennisCounter Watch App`

`project.pbxproj` 자동 편집 도구는 사용하지 않는다 (프로젝트 규칙). 완료되면 다음 단계로.

- [ ] **Step 1: 앱 타입·테스트 삭제**

```bash
rm Shared/Models/WorkoutMetrics.swift iosTests/Shared/WorkoutMetricsTests.swift
```

- [ ] **Step 2: ConnectivityMessages.swift에서 conformance 제거**

파일 맨 아래 다음 블록을 삭제한다:

```swift
// MARK: - 기존 모델 conformance

extension WorkoutMetrics: ConnectivityMessage {
    static let messageType = "metrics"
}
```

- [ ] **Step 3: MatchConnectivity를 WorkoutMetricsMessage로 교체**

`Shared/Services/MatchConnectivity.swift` 상단 import에 `WorkoutCore` 추가:

```swift
import Combine
import ConnectivityCore
import Foundation
import WorkoutCore
```

`init` 안의 metrics 수신 등록을 교체:

```swift
        service.onReceive(WorkoutMetricsMessage.self) { [weak self] in self?.receivedMetrics = $0.metrics }
```

`sendMetrics`를 교체:

```swift
    func sendMetrics(_ metrics: WorkoutMetrics) {
        service.send(WorkoutMetricsMessage(metrics: metrics), via: .realtimeOnly)
    }
```

- [ ] **Step 4: `calories` → `activeCalories` 호출부 수정**

```bash
grep -rn "metrics\.calories\|WorkoutMetrics(" --include="*.swift" . | grep -v .worktrees
```

발견되는 곳을 전부 `activeCalories`로 바꾼다. 이 시점의 알려진 위치:
- `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` — `broadcastMetrics()`의 `calories:` 인자
- `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` — `receivedMetrics` 핸들러, `startTimer()`, `finishMatch()`의 `session.kcalAtEnd = metrics.calories`

**동작은 바꾸지 않는다** — 델타 계산도 `guard case .playing`도 이 태스크에서는 그대로 둔다.

- [ ] **Step 5: 두 타겟 테스트**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: 둘 다 TEST SUCCEEDED

- [ ] **Step 6: 커밋**

```bash
git add -A
git commit -m "♻️ WorkoutMetrics를 WorkoutCore 타입으로 스왑"
```

---

## Task 7: 테니스 Watch — 화면 스왑

**Files:**
- Delete: `WatchApp/Features/Workout/` (폴더 전체)
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionView.swift`
- Modify: `WatchApp/en.lproj/Localizable.strings`, `WatchApp/ko.lproj/Localizable.strings`
- Test: `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `WorkoutUI.WorkoutMetricsView`·`WorkoutControlsView` (Task 4)
- Produces: `WorkoutSessionViewModel.currentMetrics: WorkoutMetrics` (`@Published private(set)`) — 워치 View가 서비스를 직접 관찰하지 않고 이 값을 읽는다.

> 기존에는 `WorkoutMetricsView`가 `@ObservedObject healthKit`으로 **직접 관찰**했다. 패키지 뷰는 값만 받으므로 관찰 주체를 옮겨야 한다.
>
> **⚠️ View에 `@ObservedObject var healthKit`을 추가하는 방식은 쓰지 않는다.** `init`에서
> `WorkoutSessionViewModel()`을 만들어 `vm.healthKit`을 `ObservedObject(wrappedValue:)`에 넘기면,
> View struct가 재생성될 때마다 **새 VM(따라서 새 서비스 인스턴스)** 이 만들어져 `StateObject`가
> 보유한 실제 서비스가 아닌 일회용 객체를 관찰하게 된다. 대신 **VM이 `@Published currentMetrics`로
> 노출**한다 — View는 서비스를 몰라도 되고, 테스트도 가능해진다.

- [ ] **Step 1: 앱 화면 폴더 삭제**

```bash
rm -rf WatchApp/Features/Workout/
```

- [ ] **Step 2: VM에 currentMetrics 파이프라인 추가 — 실패하는 테스트 먼저**

`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 추가:

```swift
    @MainActor
    @Test func currentMetricsReflectsHealthKitValues() async throws {
        let healthKit = WorkoutSessionService(configuration: .tennis)
        let viewModel = WorkoutSessionViewModel(healthKit: healthKit)

        healthKit.setLiveMetricsForTesting(heartRate: 142, calories: 245, basalCalories: 58, elapsedSeconds: 1523)
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.currentMetrics.elapsedSeconds == 1523)
        #expect(viewModel.currentMetrics.activeCalories == 245)
        #expect(viewModel.currentMetrics.totalCalories == 303)
        #expect(viewModel.currentMetrics.heartRate == 142)
    }
```

실패 확인:

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|Testing failed"
```

Expected: FAIL — `value of type 'WorkoutSessionViewModel' has no member 'currentMetrics'`

- [ ] **Step 3: VM에 currentMetrics 구현**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에 프로퍼티 추가 (`lastMetrics` 선언 근처):

```swift
    @Published private(set) var currentMetrics = WorkoutMetrics()
```

`init`의 `healthKit.$isPaused` 파이프라인 바로 아래에 추가:

```swift
        Publishers.CombineLatest4(
            healthKit.$elapsedSeconds,
            healthKit.$currentCalories,
            healthKit.$currentBasalCalories,
            healthKit.$currentHeartRate
        )
        .receive(on: DispatchQueue.main)
        .map { elapsed, active, basal, heartRate in
            WorkoutMetrics(elapsedSeconds: TimeInterval(elapsed),
                           activeCalories: active,
                           totalCalories: active + basal,
                           heartRate: heartRate)
        }
        .assign(to: &$currentMetrics)
```

통과 확인:

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
```

Expected: TEST SUCCEEDED

- [ ] **Step 4: WorkoutSessionView 교체**

`WatchApp/Features/WorkoutSession/WorkoutSessionView.swift` 전체를 다음으로 교체:

```swift
import SwiftUI
import WorkoutCore
import WorkoutUI

struct WorkoutSessionView: View {
    let remoteSession: SessionStartMessage?

    @StateObject private var viewModel: WorkoutSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1

    init(remoteSession: SessionStartMessage? = nil) {
        self.remoteSession = remoteSession
        _viewModel = StateObject(wrappedValue: WorkoutSessionViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            controlsTab
                .tag(0)
            centerView
                .tag(1)
            metricsTab
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear {
            viewModel.startWorkout()
            if let remote = remoteSession {
                viewModel.startMatch(options: remote.options, sessionId: remote.sessionId, isRemote: true)
            }
        }
        .onChange(of: viewModel.remoteWorkoutEnded) {
            if viewModel.remoteWorkoutEnded { dismiss() }
        }
    }

    private var controlsTab: some View {
        WorkoutControlsView(
            isPaused: viewModel.isPaused,
            onPauseResume: {
                if viewModel.isPaused {
                    viewModel.resumeWorkout()
                } else {
                    viewModel.pauseWorkout()
                }
            },
            onEnd: {
                viewModel.endWorkout()
                dismiss()
            }
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Color.clear.frame(width: 36, height: 36)
            }
        }
    }

    private var metricsTab: some View {
        WorkoutMetricsView(metrics: viewModel.currentMetrics, isPaused: viewModel.isPaused)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
    }

    @ViewBuilder
    private var centerView: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView(viewModel: viewModel)
        case .playing:
            ScoreView(viewModel: viewModel.scoreVM, flowViewModel: viewModel)
        case let .finished(session):
            MatchResultView(session: session, flowViewModel: viewModel)
        }
    }
}
```

> **주의**: 워치 메트릭 화면이 표시하는 칼로리는 기존과 동일한 **워크아웃 누적값**이다 (`currentCalories` 원시값). 동작 무변경 원칙 유지.

- [ ] **Step 5: 워치 로컬라이즈 키 제거**

`WatchApp/en.lproj/Localizable.strings`와 `WatchApp/ko.lproj/Localizable.strings`에서 다음 줄을 삭제한다 (패키지로 이동했음):

```
"workout_pause" = ...;
"workout_resume" = ...;
"workout_end" = ...;
"metrics_elapsed" = ...;
"metrics_paused" = ...;
"metrics_kcal" = ...;
"metrics_active_kcal" = ...;
"metrics_total_kcal" = ...;
"metrics_bpm" = ...;
```

- [ ] **Step 6: 남은 참조 확인**

```bash
grep -rn "metrics_\|workout_pause\|workout_resume\|workout_end" --include="*.swift" WatchApp/ | grep -v .worktrees
```

Expected: 결과 없음 (있으면 삭제 누락 — 해당 파일 수정)

- [ ] **Step 7: Watch 타겟 테스트 + Release 빌드**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
xcodebuild build -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -configuration Release -destination 'platform=watchOS Simulator,id=74666695-204D-45AC-8787-2CFEA2CE0C51' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: TEST SUCCEEDED + BUILD SUCCEEDED

- [ ] **Step 8: 커밋**

```bash
git add -A
git commit -m "♻️ 워치 워크아웃 화면을 WorkoutUI로 교체"
```

---

## Task 8: 테니스 iOS — 화면 스왑 + 경기 수 카드 제거

**Files:**
- Delete: `iOSApp/Features/Workout/` (폴더 전체)
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `iOSApp/en.lproj/Localizable.strings`, `iOSApp/ko.lproj/Localizable.strings`
- Test: `iosTests/Match/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `WorkoutUI.WorkoutDashboardView` (Task 5)
- Produces: iOS 앱이 패키지 대시보드를 사용. `completedMatchCount`는 제거된다.

- [ ] **Step 1: completedMatchCount 참조 테스트가 있는지 먼저 확인**

```bash
grep -rn "completedMatchCount" iosTests/ | grep -v .worktrees
```

결과가 있으면 해당 테스트를 삭제한다 (프로퍼티 자체가 사라지므로).

- [ ] **Step 2: 앱 화면 폴더 삭제**

```bash
rm -rf iOSApp/Features/Workout/
```

- [ ] **Step 3: ViewModel에서 completedMatchCount 제거**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서 다음 3곳을 삭제한다:
- 선언: `@Published var completedMatchCount: Int = 0`
- `receivedMatchEnd` 핸들러의 `completedMatchCount += 1`
- `finishMatch(result:completedSets:)`의 `completedMatchCount += 1`

- [ ] **Step 4: WorkoutSessionView의 탭 0 교체**

`iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` 상단 import에 추가:

```swift
import WorkoutUI
```

`WorkoutTabView(...)` 호출을 다음으로 교체:

```swift
            WorkoutDashboardView(
                metrics: viewModel.metrics,
                isPaused: viewModel.isPaused,
                onPauseResume: {
                    viewModel.isPaused ? viewModel.resumeSession() : viewModel.pauseSession()
                },
                onEnd: { showEndWorkoutConfirm = true }
            )
```

> `isPauseAvailable`은 이 플랜에서 넘기지 않는다 (기본값 `true`). 워치 연결 여부에 따른 비활성화는 pause 동기화가 들어가는 **Plan B**에서 붙인다.

- [ ] **Step 5: iOS 로컬라이즈 키 제거**

`iOSApp/en.lproj/Localizable.strings`와 `iOSApp/ko.lproj/Localizable.strings`에서 삭제:

```
"workout_pause" = ...;
"workout_resume" = ...;
"workout_end" = ...;
"workout_elapsed_label" = ...;
"workout_metric_heartrate" = ...;
"workout_metric_calories" = ...;
"workout_metric_total_calories" = ...;
"workout_metric_matches" = ...;
"workout_metric_matches_unit" = ...;
```

`workout_in_progress`·`workout_paused`·`end_workout_confirm_*`는 **남긴다** (앱의 다른 화면이 사용).

- [ ] **Step 6: 남은 참조 확인**

```bash
grep -rn "workout_metric_\|workout_elapsed_label\|WorkoutTabView\|completedMatchCount" --include="*.swift" iOSApp/ iosTests/ | grep -v .worktrees
```

Expected: 결과 없음

- [ ] **Step 7: iOS 테스트 + Release 빌드**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Testing failed|TEST SUCCEEDED"
xcodebuild build -project TennisCounter.xcodeproj -scheme "TennisCounter" -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```

Expected: TEST SUCCEEDED + BUILD SUCCEEDED

- [ ] **Step 8: 린트·포맷**

```bash
make fix && make lint
```

Expected: 위반 없음

- [ ] **Step 9: 커밋**

```bash
git add -A
git commit -m "♻️ iOS 워크아웃 화면을 WorkoutUI로 교체 + 경기 수 카드 제거"
```

---

## 완료 후 확인

- [ ] ralli-kit `feat/workout-ui` 브랜치에 5개 커밋 (Task 1~5)
- [ ] tennis-counter `feature/workout-ui-shared` 브랜치에 3개 커밋 (Task 6~8)
- [ ] 두 앱 타겟 Debug + Release 빌드 통과
- [ ] 시뮬레이터에서 육안 확인: 워치 메트릭 3번째 탭, 워치 컨트롤 1번째 탭, iOS 워크아웃 탭
- [ ] **와이어 호환 확인**: 구버전 워치 ↔ 신버전 폰 조합에서 메트릭이 정상 표시되는지 (실기기)

## Plan B 예고 (이 플랜 완료 후 별도 작성)

동작 통일은 다음 플랜에서 다룬다. 범위:

1. `WorkoutAnchor` 순수 함수 (WorkoutCore) — `elapsed = anchorElapsed + (isPaused ? 0 : now - sentAt)`
2. `WorkoutMetricsMessage`에 `isPaused` 키 + `sentAt` 노출 추가
3. `WorkoutPauseMessage` 신설 (폰→워치, `.reliable`)
4. 워치 `broadcastMetrics()` — 델타 계산 제거(누적 전송) + `guard case .playing` 제거
5. **칼로리 저장 회귀 수정** — iOS `kcalAtStart = 0` → `metrics.activeCalories` 캡처. **재현 테스트 선행**
6. iOS 자체 타이머 제거 → 앵커 기반 경과시간
7. iOS `isPauseAvailable: watchConnected` 연결
8. ralli-kit README에 `## WorkoutUI 사용법` 섹션 (Task #9)
