# 잔디 일별 집계 — 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `WorkoutRecord` 들을 날짜 한 칸씩으로 접는 순수 집계를 만들고, 농도 컷이 실제 데이터와 맞는지 눈으로 볼 임시 화면을 붙인다.

**Architecture:** 규칙은 전부 `Shared/Models/` 의 순수 타입(`DailyAggregate` · `GrassIntensity` · `GrassAggregator`)이 갖는다. `iOSApp/Features/Home/GrassViewModel` 은 배선만 하고, 계산을 View `body` 밖에 두는 것이 존재 이유다. **영속 캐시를 두지 않는다.**

**Tech Stack:** Swift 6 · SwiftUI · SwiftData · Combine · swift-testing (`@Test`/`#expect`) · iOS 17 / watchOS 10

**Spec:** [`docs/specs/shared/2026/2026-09-09-grass-daily-aggregate.md`](../../specs/shared/2026/2026-09-09-grass-daily-aggregate.md)

## Global Constraints

- **`Packages/YJKit` 을 한 줄도 고치지 않는다.** 이 작업은 앱 레이어에만 있다
- **순수 규칙은 `Shared/Models/` 에 둔다.** `Shared/` 가 iOS·워치 양쪽 타깃에 붙어 있어 `HaruchiFitWatchTests` 에서 그대로 테스트된다 (pbxproj 확인). `iOSApp/` 은 iOS 타깃 전용이라 **거기 둔 것은 유닛 테스트가 불가능하다**
- **ViewModel 은 UI 프레임워크를 import 하지 않는다** (루트 `CLAUDE.md`). `import Combine` + `Foundation` 만
- **집계기는 필터를 갖지 않는다.** 들어온 건 다 센다 — D-M5 의 "근력·유산소만 반영" 은 #2 HealthKit import 가 매핑 표로 입구에서 지킨다 (스펙 4.5)
- **농도 계산이 `WorkoutSource` 를 보지 않는다** (스펙 4.4). 수동 기록이라고 무조건 최소 농도로 떨어뜨리면 사용자가 손으로 넣은 90분이 1단계가 된다
- **농도 경계는 이상/미만이다** — 정확히 30분은 2단계. 레코드가 하나라도 있으면 아무리 짧아도 1단계 이상
- **하루의 경계는 시작 시각이다** (스펙 4.1). 23:40 에 시작해 00:30 에 끝난 세션은 전부 시작한 날 칸에 들어간다
- **영속 캐시(`@Model`)를 만들지 않는다** (스펙 3절)
- 빌드·테스트는 **워크스페이스 기준**이다. 시뮬레이터는 이름이 아니라 UDID 로 지정한다
- 커밋 메시지는 gitmoji prefix (`✨ feat` / `✅ test` / `📝 docs`)

**명령** (저장소 루트에서):

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

# 순수 규칙 테스트
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test

# iOS — 테스트 타깃이 없다. 빌드만.
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
```

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `Shared/Models/DailyAggregate.swift` | 잔디 한 칸의 값. 아무것도 모른다 | **생성** |
| `Shared/Models/GrassLevel.swift` | 농도 4단계 + 빈 칸 | **생성** |
| `Shared/Models/GrassIntensity.swift` | 어떤 값으로 재고 어디서 끊을지 | **생성** |
| `Shared/Models/GrassAggregator.swift` | 날짜별로 접는 순수 함수 | **생성** |
| `iOSApp/Features/Home/GrassViewModel.swift` | 배선만. 규칙 없음 | **생성** |
| `iOSApp/ContentView.swift` | 임시 확인 화면 — 잔디 그리드로 교체 | 수정 |
| `watchosTests/Support/GrassFixture.swift` | 인메모리 컨테이너 + 고정 타임존 | **생성** |
| `watchosTests/Models/GrassIntensityTests.swift` | 농도 컷 | **생성** |
| `watchosTests/Models/GrassAggregatorTests.swift` | 접기 규칙 | **생성** |
| `docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md` | 5절 캐시 문단 정정 | 수정 |
| `TODO.md` | 진행 상태 | 수정 |

`Shared/` 에 `Models/` 가 새로 생긴다 — 지금은 `Persistence/` 와 `Services/` 둘뿐이다. 루트 `CLAUDE.md` 의 폴더 배치 기준이 *"플랫폼 독립 데이터 모델 → `Shared/Models/`"* 로 정한 자리이고, 스펙 2절이 명시적으로 이 경로를 지정했다.

**`GrassViewModel` 에는 유닛 테스트가 없다.** `iOSApp/` 은 iOS 타깃에만 붙고 하루치엔 iOS 테스트 타깃이 없다 (새로 만들면 타깃 규약 문서까지 따라온다 — 스펙 2절). 그래서 **규칙을 한 줄도 넣지 않는 것**이 이 타입의 설계 제약이다. 검증은 Task 4 의 시뮬레이터 확인이 맡는다.

---

## Task 0: 워크트리와 브랜치를 판다

**Files:** 없음

- [ ] **Step 1: 워크트리 생성**

네이티브 도구(`EnterWorktree` 등)가 있으면 그걸 쓰되, **경로는 형제 폴더**여야 한다 (루트 `CLAUDE.md`). 네이티브 도구가 저장소 안에 만든다면 아래로 만들고 `path` 로 진입한다.

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin
git worktree add ../yj-apps-worktrees/grass-daily-aggregate -b feat/haruchi-grass-aggregate origin/main
```

- [ ] **Step 2: 베이스라인 확인**

```bash
cd "$(git rev-parse --show-toplevel)"
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **TEST SUCCEEDED, 39개 통과.** 워크트리가 새로 생겼으므로 DerivedData 를 통째로 만드는 풀 빌드가 한 번 돈다.

여기서 실패하면 멈추고 보고한다. 베이스라인이 더러우면 이후 실패가 전부 모호해진다.

---

## Task 1: 농도 규칙

**Files:**
- Create: `Apps/HaruchiFit/Shared/Models/DailyAggregate.swift`
- Create: `Apps/HaruchiFit/Shared/Models/GrassLevel.swift`
- Create: `Apps/HaruchiFit/Shared/Models/GrassIntensity.swift`
- Test: `Apps/HaruchiFit/watchosTests/Models/GrassIntensityTests.swift`

**Interfaces:**
- Consumes: 없음 (순수)
- Produces:
  - `struct DailyAggregate: Equatable, Identifiable` — `day: Date` · `totalSeconds: Int` · `strengthSeconds: Int` · `cardioSeconds: Int` · `totalCalories: Double?` · `sessionCount: Int`. 멤버와이즈 `init` 사용
  - `enum GrassLevel: Int, CaseIterable, Comparable` — `.none = 0` · `.light = 1` · `.medium = 2` · `.heavy = 3` · `.peak = 4`
  - `struct GrassIntensity` — `init(value: @escaping (DailyAggregate) -> Double?, cuts: [Double])` · `static let byTime` · `func level(for: DailyAggregate) -> GrassLevel`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`watchosTests/Models/GrassIntensityTests.swift` 를 새로 만든다.

```swift
import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// 농도 컷이 **이상/미만**으로 끊기는지, 그리고 **레코드가 있으면 절대 0단계로 떨어지지 않는지**.
///
/// 0단계는 "그날 레코드가 아예 없다" 는 뜻이라 집계 결과에는 나타나지 않는다.
/// 1초짜리 기록이 빈 칸으로 보이면 사용자에겐 "기록이 사라졌다" 가 된다.
struct GrassIntensityTests {
    private func aggregate(seconds: Int, calories: Double? = nil) -> DailyAggregate {
        DailyAggregate(day: Date(timeIntervalSince1970: 0),
                       totalSeconds: seconds,
                       strengthSeconds: seconds,
                       cardioSeconds: 0,
                       totalCalories: calories,
                       sessionCount: 1)
    }

    @Test("29분59초는 1단계 — 30분 컷에 닿지 않았다")
    func justUnderFirstCutIsLight() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 1799)) == .light)
    }

    @Test("정확히 30분은 2단계 — 경계는 이상/미만이다")
    func exactlyThirtyMinutesIsMedium() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 1800)) == .medium)
    }

    @Test("정확히 60분은 3단계")
    func exactlySixtyMinutesIsHeavy() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 3600)) == .heavy)
    }

    @Test("정확히 90분은 4단계")
    func exactlyNinetyMinutesIsPeak() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 5400)) == .peak)
    }

    @Test("90분을 넘어도 4단계에서 멈춘다")
    func wellOverNinetyStaysPeak() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 36000)) == .peak)
    }

    @Test("1초짜리 기록도 1단계 — 0단계로 떨어지지 않는다")
    func oneSecondIsStillLight() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 1)) == .light)
    }

    @Test("기준 값이 0이면 1단계")
    func zeroValueFallsBackToLight() {
        #expect(GrassIntensity.byTime.level(for: aggregate(seconds: 0)) == .light)
    }

    @Test("칼로리 기준에서 값이 없으면 1단계 — 수동 기록이 여기 해당한다")
    func missingCalorieValueFallsBackToLight() {
        let byCalories = GrassIntensity(value: { $0.totalCalories }, cuts: [200, 400, 600])

        #expect(byCalories.level(for: aggregate(seconds: 5400, calories: nil)) == .light)
    }

    @Test("칼로리 기준도 같은 컷 규칙을 쓴다 — 분기가 따로 없다")
    func calorieCutsUseTheSameRule() {
        let byCalories = GrassIntensity(value: { $0.totalCalories }, cuts: [200, 400, 600])

        #expect(byCalories.level(for: aggregate(seconds: 60, calories: 199)) == .light)
        #expect(byCalories.level(for: aggregate(seconds: 60, calories: 200)) == .medium)
        #expect(byCalories.level(for: aggregate(seconds: 60, calories: 600)) == .peak)
    }

    @Test("농도는 크기로 비교된다")
    func levelsAreComparable() {
        #expect(GrassLevel.none < GrassLevel.light)
        #expect(GrassLevel.heavy < GrassLevel.peak)
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **컴파일 실패** — `cannot find 'DailyAggregate' in scope`, `cannot find 'GrassIntensity' in scope`

- [ ] **Step 3: `DailyAggregate` 를 만든다**

`Shared/Models/DailyAggregate.swift`:

```swift
import Foundation

/// 잔디 한 칸. `WorkoutRecord` 여러 건을 **하루 단위로 접은** 결과다 (D3).
///
/// 농도에 쓰는 건 `totalSeconds` 하나지만 나머지도 같은 한 번의 순회에서 나온다 —
/// Phase 4 의 홈 "이번 주 운동 구성 바" · 달력 월 요약("12회 · 9.2시간") · 통계 비율이
/// 전부 이 값을 쓴다. 농도만 내는 타입을 만들면 그때 타입을 다시 고치게 된다 (스펙 2절).
struct DailyAggregate: Equatable, Identifiable {
    /// 자정으로 정규화된 날짜. **칸의 정체성이다.**
    let day: Date
    /// 농도 계산의 입력. 세그먼트 합이 아니라 레코드의 `totalSeconds` 합이다 —
    /// 수동 기록과 HealthKit import 기록은 세그먼트가 없을 수 있다 (스펙 4.2).
    let totalSeconds: Int
    let strengthSeconds: Int
    let cardioSeconds: Int
    /// 칼로리 기준으로 전환했을 때의 입력. 칼로리를 가진 레코드가 하나도 없으면 nil 이다.
    let totalCalories: Double?
    /// 달력 월 요약과 통계 세션 카운트 (D2).
    let sessionCount: Int

    var id: Date { day }
}
```

- [ ] **Step 4: `GrassLevel` 을 만든다**

`Shared/Models/GrassLevel.swift`:

```swift
import Foundation

/// 잔디 칸의 농도.
///
/// **`.none` 은 그날 레코드가 아예 없다는 뜻이라 집계 결과에 나타나지 않는다** —
/// 칸이 없는 날을 화면이 `.none` 으로 그린다 (스펙 4.3). 스펙은 1~4단계만 정의했고
/// 0단계는 그 문서에서 채웠다.
enum GrassLevel: Int, CaseIterable, Comparable {
    case none = 0
    case light = 1
    case medium = 2
    case heavy = 3
    case peak = 4

    static func < (lhs: GrassLevel, rhs: GrassLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

- [ ] **Step 5: `GrassIntensity` 를 만든다**

`Shared/Models/GrassIntensity.swift`:

```swift
import Foundation

/// 농도 기준. **어떤 값으로 재고 어디서 끊을지**를 함께 들고 있다.
///
/// 값 추출을 주입받으므로 `level(for:)` 이 `WorkoutSource` 를 **아예 보지 않는다** (스펙 4.4).
/// `source == .manual` 이면 무조건 최소 농도로 읽으면 틀린 값이 나온다 — 08 수동 기록은
/// 사용자가 시간을 직접 입력하고, 90분을 손으로 넣었는데 1단계로 찍히면 fallback 이 아니라
/// 버그다. 반대로 칼로리 기준으로 전환하면 수동 기록엔 칼로리가 없어 자연히 1단계로 떨어진다 —
/// 제품 스펙 D4 의 괄호가 가리키는 게 정확히 그 상황이다.
struct GrassIntensity {
    /// 농도의 입력이 되는 값. 없거나 0 이하면 최소 농도로 간다.
    let value: (DailyAggregate) -> Double?
    /// 오름차순 컷 3개. **이상/미만**으로 끊는다 — 정확히 30분은 2단계다.
    let cuts: [Double]

    /// D-M6 확정값 — 30 / 60 / 90분.
    ///
    /// 칼로리 기준 컷은 **실제 데이터가 없어 정할 근거가 없다** (스펙 9절). 여기 상수를
    /// 하나 더하는 것으로 끝나도록 자리만 열어 둔다.
    static let byTime = GrassIntensity(value: { Double($0.totalSeconds) },
                                       cuts: [1800, 3600, 5400])

    /// 레코드가 하나라도 있으면 **아무리 짧아도 1단계 이상**이다 (스펙 4.3).
    func level(for aggregate: DailyAggregate) -> GrassLevel {
        guard let value = value(aggregate), value > 0 else { return .light }
        let step = cuts.reduce(1) { $0 + (value >= $1 ? 1 : 0) }
        return GrassLevel(rawValue: step) ?? .peak
    }
}
```

- [ ] **Step 6: 테스트 통과를 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **모두 PASS.** 기존 39개 + 신규 10개 = 49개.

- [ ] **Step 7: 커밋**

```bash
git add Apps/HaruchiFit/Shared/Models/ Apps/HaruchiFit/watchosTests/Models/
git commit -m "✨ 잔디 농도 규칙을 값 타입으로 만든다"
```

---

## Task 2: 날짜별로 접는다

**Files:**
- Create: `Apps/HaruchiFit/Shared/Models/GrassAggregator.swift`
- Create: `Apps/HaruchiFit/watchosTests/Support/GrassFixture.swift`
- Test: `Apps/HaruchiFit/watchosTests/Models/GrassAggregatorTests.swift`

**Interfaces:**
- Consumes: Task 1 의 `DailyAggregate`
- Produces:
  - `enum GrassAggregator` — `static func fold(_ records: [WorkoutRecord], calendar: Calendar = .current) -> [DailyAggregate]`. 결과는 **날짜 오름차순**이고 레코드가 없는 날은 들어 있지 않다
  - `enum GrassFixture` (테스트 전용) — `static func makeContext() throws -> ModelContext` · `static func record(in:startedAt:totalSeconds:totalCalories:segments:) -> WorkoutRecord` · `static let seoul: Calendar` · `static func date(_:_:_:_:_:) -> Date`

- [ ] **Step 1: 픽스처를 만든다**

`watchosTests/Support/GrassFixture.swift`:

```swift
import Foundation
import SwiftData
@testable import HaruchiFit_Watch_App

/// 잔디 테스트가 쓰는 레코드 생성기.
///
/// **인메모리 컨테이너를 띄운다.** `@Model` 인스턴스를 컨텍스트 없이 만들면 to-many 관계
/// 대입의 동작이 보장되지 않는다. 컨테이너 하나 띄우는 비용이 그 불확실성보다 싸다.
///
/// **타임존을 고정한다.** 집계가 `Calendar.current` 를 쓰므로 고정하지 않으면 하루 경계
/// 테스트가 기계마다 다른 답을 낸다.
@MainActor
enum GrassFixture {
    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutRecord.self, Segment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// `segments` 는 (종류, 시작 오프셋, 길이) 튜플이다.
    @discardableResult
    static func record(in context: ModelContext,
                       startedAt: Date,
                       totalSeconds: Int,
                       totalCalories: Double? = nil,
                       segments: [(SegmentKind, Int, Int)] = []) -> WorkoutRecord
    {
        let record = WorkoutRecord(startedAt: startedAt,
                                   totalSeconds: totalSeconds,
                                   totalCalories: totalCalories)
        context.insert(record)
        record.segments = segments.map {
            Segment(kind: $0.0, startOffset: $0.1, durationSeconds: $0.2)
        }
        return record
    }

    static let seoul: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int,
                     _ hour: Int = 12, _ minute: Int = 0) -> Date
    {
        seoul.date(from: DateComponents(year: year, month: month, day: day,
                                        hour: hour, minute: minute))!
    }
}
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`watchosTests/Models/GrassAggregatorTests.swift`:

```swift
import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// 레코드를 하루 한 칸으로 접는 규칙.
///
/// **하루의 경계는 시작 시각이다** — 통계가 세션 카운트 기준(D2)이고 기록 목록도 세션
/// 단위라, 한 세션을 날짜별로 쪼개면 잔디만 다른 수를 갖게 된다 (스펙 4.1).
@MainActor
struct GrassAggregatorTests {
    @Test("같은 날 두 세션은 한 칸으로 합쳐진다")
    func sameDaySessionsCollapseIntoOneCell() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14, 7), totalSeconds: 1800)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14, 19), totalSeconds: 2400)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.count == 1)
        #expect(days.first?.totalSeconds == 4200) // 70분
        #expect(days.first?.sessionCount == 2)
        // 스펙 8절이 이 케이스에 농도까지 못박았다 — 70분은 60 컷을 넘고 90 컷에 못 닿는다
        #expect(GrassIntensity.byTime.level(for: try #require(days.first)) == .heavy)
    }

    @Test("자정을 넘긴 세션은 전부 시작한 날 칸에 들어간다")
    func sessionCrossingMidnightLandsOnStartDay() throws {
        let context = try GrassFixture.makeContext()
        // 23:40 에 시작해 50분 — 00:30 에 끝난다
        GrassFixture.record(in: context,
                            startedAt: GrassFixture.date(2026, 9, 14, 23, 40),
                            totalSeconds: 3000)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.count == 1)
        #expect(days.first?.day == GrassFixture.seoul.startOfDay(for: GrassFixture.date(2026, 9, 14)))
        #expect(days.first?.totalSeconds == 3000) // 50분 전부
    }

    @Test("구간이 종목별로 갈려 담긴다")
    func segmentsSplitByKind() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context,
                            startedAt: GrassFixture.date(2026, 9, 14),
                            totalSeconds: 1800,
                            segments: [(.strength, 0, 1200), (.cardio, 1200, 600)])

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.first?.strengthSeconds == 1200)
        #expect(days.first?.cardioSeconds == 600)
    }

    @Test("세그먼트가 없는 레코드도 총 시간은 그대로 센다 — 수동 기록과 import 가 그렇다")
    func recordWithoutSegmentsStillCountsTotal() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14), totalSeconds: 2700)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.first?.totalSeconds == 2700)
        #expect(days.first?.strengthSeconds == 0)
        #expect(days.first?.cardioSeconds == 0)
    }

    @Test("칼로리는 값을 가진 레코드만 더한다. 하나도 없으면 nil 이다")
    func caloriesSumOnlyWhenPresent() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14, 7),
                            totalSeconds: 1800, totalCalories: 120)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14, 19),
                            totalSeconds: 1800, totalCalories: nil)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 15),
                            totalSeconds: 1800, totalCalories: nil)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.first?.totalCalories == 120)
        #expect(days.last?.totalCalories == nil)
    }

    @Test("레코드가 없는 날은 칸이 아예 없다")
    func daysWithoutRecordsAreAbsent() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14), totalSeconds: 1800)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 17), totalSeconds: 1800)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.count == 2) // 15·16일 칸은 없다
    }

    @Test("결과는 날짜 오름차순이다")
    func resultIsSortedByDayAscending() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 17), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 15), totalSeconds: 600)

        let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                        calendar: GrassFixture.seoul)

        #expect(days.map(\.day) == days.map(\.day).sorted())
    }

    @Test("빈 입력은 빈 결과다. 크래시하지 않는다")
    func emptyInputGivesEmptyResult() {
        #expect(GrassAggregator.fold([], calendar: GrassFixture.seoul).isEmpty)
    }
}
```

- [ ] **Step 3: 실패를 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **컴파일 실패** — `cannot find 'GrassAggregator' in scope`

- [ ] **Step 4: 최소 구현**

`Shared/Models/GrassAggregator.swift`:

```swift
import Foundation

/// `WorkoutRecord` 들을 **날짜 한 칸씩으로 접는다.** 홈 잔디·기록 달력·통계 연 잔디가
/// 같은 결과를 나눠 쓴다 — 화면부터 만들면 셋이 각자 계산하게 되고, 규칙이 갈린 뒤에
/// 합치는 건 훨씬 비싸다 (스펙 "왜 화면보다 먼저인가").
///
/// **필터를 갖지 않는다.** 들어온 건 다 센다. D-M5 의 "근력·유산소로 분류되는 워크아웃만
/// 반영" 은 #2 HealthKit import 가 매핑 표로 **입구에서** 지킨다 — 두 곳에서 거르면
/// 규칙이 갈린다 (스펙 4.5).
enum GrassAggregator {
    /// 하루의 경계는 **시작 시각**이다 (스펙 4.1). 23:40 에 시작해 00:30 에 끝난 세션은
    /// 전부 시작한 날 칸에 들어간다.
    ///
    /// 타임존은 호출부가 준 `calendar` 를 따른다. 앱은 `.current` 를 쓰므로 해외에 나가면
    /// 과거 칸이 한 칸 움직여 보일 수 있다 — 기록 시점의 타임존을 저장하는 대안은 모델에
    /// 필드를 늘리는 값에 비해 얻는 게 없다. v1 은 이대로 간다 (스펙 4.1).
    ///
    /// 결과는 날짜 오름차순이고, **레코드가 없는 날은 아예 들어 있지 않다** (0단계).
    static func fold(_ records: [WorkoutRecord],
                     calendar: Calendar = .current) -> [DailyAggregate]
    {
        var buckets: [Date: Bucket] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.startedAt)
            buckets[day, default: Bucket()].add(record)
        }
        return buckets
            .map { $0.value.aggregate(on: $0.key) }
            .sorted { $0.day < $1.day }
    }

    /// 한 칸이 쌓이는 동안의 중간 상태. **한 번의 순회로 다섯 값을 전부 낸다.**
    private struct Bucket {
        var totalSeconds = 0
        var strengthSeconds = 0
        var cardioSeconds = 0
        var calories: Double?
        var sessionCount = 0

        mutating func add(_ record: WorkoutRecord) {
            totalSeconds += record.totalSeconds
            sessionCount += 1

            for segment in record.orderedSegments {
                switch segment.kind {
                case .strength: strengthSeconds += segment.durationSeconds
                case .cardio: cardioSeconds += segment.durationSeconds
                }
            }

            // 값을 가진 레코드가 하나도 없으면 nil 로 남는다 — 칼로리 기준으로 전환했을 때
            // 그 날이 최소 농도로 떨어져야 하기 때문이다 (스펙 4.4).
            if let value = record.totalCalories {
                calories = (calories ?? 0) + value
            }
        }

        func aggregate(on day: Date) -> DailyAggregate {
            DailyAggregate(day: day,
                           totalSeconds: totalSeconds,
                           strengthSeconds: strengthSeconds,
                           cardioSeconds: cardioSeconds,
                           totalCalories: calories,
                           sessionCount: sessionCount)
        }
    }
}
```

- [ ] **Step 5: 테스트 통과를 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **모두 PASS.** 49개 + 신규 8개 = 57개.

- [ ] **Step 6: 커밋**

```bash
git add Apps/HaruchiFit/Shared/Models/GrassAggregator.swift \
        Apps/HaruchiFit/watchosTests/Support/GrassFixture.swift \
        Apps/HaruchiFit/watchosTests/Models/GrassAggregatorTests.swift
git commit -m "✨ 기록을 날짜 한 칸씩으로 접는다"
```

---

## Task 3: 배선과 임시 확인 화면

**Files:**
- Create: `Apps/HaruchiFit/iOSApp/Features/Home/GrassViewModel.swift`
- Modify: `Apps/HaruchiFit/iOSApp/ContentView.swift` (전체 교체)

**Interfaces:**
- Consumes: Task 1·2 의 `DailyAggregate` · `GrassLevel` · `GrassIntensity.byTime` · `GrassAggregator.fold(_:calendar:)`
- Produces:
  - `@MainActor final class GrassViewModel: ObservableObject` — `init(calendar: Calendar = .current, intensity: GrassIntensity = .byTime)` · `@Published private(set) var days: [DailyAggregate]` · `func rebuild(from: [WorkoutRecord])` · `func refresh()` · `func aggregate(on: Date) -> DailyAggregate?` · `func level(on: Date) -> GrassLevel`

**유닛 테스트가 없는 이유** — `iOSApp/` 은 iOS 타깃에만 붙고 하루치엔 iOS 테스트 타깃이 없다 (스펙 2절). **그래서 이 타입에 규칙을 한 줄도 넣지 않는다.** 검증은 Step 4 의 시뮬레이터 확인이 맡는다.

- [ ] **Step 1: `GrassViewModel` 을 만든다**

`iOSApp/Features/Home/GrassViewModel.swift`:

```swift
import Combine
import Foundation

/// 홈 잔디의 배선. **규칙은 하나도 들고 있지 않다** — 전부 `GrassAggregator` 와
/// `GrassIntensity` 에 있다 (스펙 2절). 이 타입은 유닛 테스트가 닿지 않는 자리라
/// (iOS 테스트 타깃이 없다) 규칙을 여기 두면 아무도 검증하지 못한다.
///
/// 계산을 View `body` 밖에 두는 것이 존재 이유다. 비용이 작아도 `body` 안에서 접으면
/// 잔디와 무관한 이유로(스탯 갱신, 최근 기록 스크롤) 딸려 돈다. `@StateObject` 로 살아
/// 있으면 `body` 가 몇 번 재평가되든 결과는 배열 읽기다 (스펙 3절).
///
/// **영속 캐시가 아니다.** `@Model` 캐시는 CloudKit 스키마에 올라가 기기 간 충돌 대상이
/// 되고, 무효화 시점이 이미 넷이라 진실과 어긋나면 사용자에겐 "잔디가 틀렸다" 로 보인다.
@MainActor
final class GrassViewModel: ObservableObject {
    /// 날짜 오름차순. 레코드가 없는 날은 들어 있지 않다.
    @Published private(set) var days: [DailyAggregate] = []

    private let calendar: Calendar
    private let intensity: GrassIntensity
    private var records: [WorkoutRecord] = []
    private var byDay: [Date: DailyAggregate] = [:]

    init(calendar: Calendar = .current, intensity: GrassIntensity = .byTime) {
        self.calendar = calendar
        self.intensity = intensity
    }

    /// View 가 `@Query` 로 읽은 결과를 밀어넣는다.
    func rebuild(from records: [WorkoutRecord]) {
        self.records = records
        refresh()
    }

    /// 들고 있는 레코드로 다시 접는다.
    ///
    /// **원소 집합이 그대로인 채 값만 바뀌는 경우**를 위해 공개해 둔다 — `@Query` 는
    /// `persistentModelID` 로 비교하므로 그런 변경을 못 잡는다. 구멍은 그 하나뿐이고
    /// 그걸 여는 화면이 아직 없다. Phase 5 의 08 수동 기록이 편집 저장 직후 이걸 부른다
    /// (스펙 5절).
    func refresh() {
        let folded = GrassAggregator.fold(records, calendar: calendar)
        byDay = Dictionary(folded.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        days = folded
    }

    /// 그 날 칸의 값. 레코드가 없는 날은 nil 이다.
    func aggregate(on day: Date) -> DailyAggregate? {
        byDay[calendar.startOfDay(for: day)]
    }

    /// 그 날 칸의 농도. 레코드가 없으면 `.none` — 빈 칸으로 그린다.
    func level(on day: Date) -> GrassLevel {
        guard let aggregate = aggregate(on: day) else { return .none }
        return intensity.level(for: aggregate)
    }
}
```

- [ ] **Step 2: `ContentView` 를 잔디 그리드로 교체한다**

`iOSApp/ContentView.swift` 를 통째로 아래로 바꾼다. 기존 리스트와 `summary(of:)` · `segmentLine(of:)` 는 지운다.

```swift
import SwiftData
import SwiftUI

/// 농도 컷이 실제 데이터와 맞는지 **눈으로 보는 것**이 이 화면의 유일한 목적이다.
///
/// **제품 화면이 아니다** — Phase 3 탭 셸이 대체한다 (스펙 7절). 애니메이션·스와이프·스탯을
/// 넣지 않는다. 지금까지 이 파일에 달려 있던 "저장 확인용 임시 화면" 이라는 성격을 그대로 잇는다.
struct ContentView: View {
    /// **기간을 좁혀 읽는다.** 홈이 실제로 쓰는 건 4개월치뿐이라 전체를 읽을 이유가 없다 (스펙 5절).
    @Query private var records: [WorkoutRecord]
    @StateObject private var grass = GrassViewModel()
    @State private var selected: Date?

    private let calendar = Calendar.current
    private let weeks = 17

    init() {
        let since = Calendar.current.date(byAdding: .weekOfYear, value: -17, to: Date())
            ?? .distantPast
        _records = Query(filter: #Predicate<WorkoutRecord> { $0.startedAt >= since },
                         sort: \WorkoutRecord.startedAt)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                grid
                detail
                Spacer()
            }
            .padding(.top)
            .navigationTitle("하루치 핏")
            .onAppear { grass.rebuild(from: records) }
            .onChange(of: records) { _, updated in grass.rebuild(from: updated) }
        }
    }

    /// 17주 × 7일. 왼쪽 위가 가장 오래된 날이다.
    private var grid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(16), spacing: 3), count: 7),
                      spacing: 3)
            {
                ForEach(gridDays, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: grass.level(on: day)))
                        .frame(width: 16, height: 16)
                        .overlay {
                            if selected == day {
                                RoundedRectangle(cornerRadius: 3).stroke(.primary, lineWidth: 1.5)
                            }
                        }
                        .onTapGesture { selected = day }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder private var detail: some View {
        if let selected {
            VStack(alignment: .leading, spacing: 4) {
                Text(selected.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                if let aggregate = grass.aggregate(on: selected) {
                    Text("\(aggregate.totalSeconds / 60)분 · \(aggregate.sessionCount)회 · 농도 \(grass.level(on: selected).rawValue)단계")
                    Text("근력 \(aggregate.strengthSeconds / 60)분 · 유산소 \(aggregate.cardioSeconds / 60)분")
                        .foregroundStyle(.secondary)
                } else {
                    Text("기록 없음").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .padding(.horizontal)
        } else {
            Text("칸을 탭하면 그날 값이 나온다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    /// 오늘이 든 주를 오른쪽 끝에 두고 17주를 거슬러 올라간다.
    private var gridDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let start = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek)
        else { return [] }
        return (0 ..< weeks * 7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    /// **임시 색이다.** 디자인 토큰은 Phase 3 #3 에서 들어온다 (스펙 7절).
    private func color(for level: GrassLevel) -> Color {
        switch level {
        case .none: Color.secondary.opacity(0.15)
        case .light: Color.orange.opacity(0.3)
        case .medium: Color.orange.opacity(0.5)
        case .heavy: Color.orange.opacity(0.75)
        case .peak: Color.orange
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutRecord.self, Segment.self], inMemory: true)
}
```

- [ ] **Step 3: iOS 빌드를 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
```

기대: **BUILD SUCCEEDED.**

- [ ] **Step 4: 시뮬레이터에서 눈으로 본다**

iOS 시뮬레이터에서 `HaruchiFit` 을 실행한다. 기록이 없으면 전부 빈 칸이다 — **그 자체가 확인 항목 하나다** (크래시 없이 격자가 그려지는지).

확인할 것:

- 17주 × 7일 격자가 가로 스크롤로 그려진다
- 칸을 탭하면 아래에 그날 값이 뜨고, 기록 없는 날은 "기록 없음"
- 오늘이 든 주가 오른쪽 끝에 있다

기록을 넣어 보려면 워치 시뮬레이터에서 운동을 짧게 한 번 돌려 저장한다 (폰 시뮬레이터와 페어링된 워치). **폰을 켜 둔 채로 칸이 채워지는지**가 스펙 8절의 "눈으로" 항목이다.

- [ ] **Step 5: lint · format**

```bash
cd "$(git rev-parse --show-toplevel)"
make fix
git diff --stat
```

- [ ] **Step 6: 커밋**

```bash
git add Apps/HaruchiFit/iOSApp/
git commit -m "✨ 임시 홈을 잔디 그리드로 바꾼다"
```

---

## Task 4: 문서를 맞춘다

**Files:**
- Modify: `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md:244-251`
- Modify: `TODO.md`

- [ ] **Step 1: 아키텍처 5절의 캐시 문단을 뒤집는다**

스펙 10절이 지시한 정정이다. 아키텍처 문서의 이 두 문단을

```markdown
집계는 `WorkoutRecord`에서 파생하되, 홈 잔디(약 4개월 = 119칸)와 통계 잔디(1년 = 371칸)를
매번 전체 스캔하지 않도록 **일별 집계 캐시**를 두는 편이 낫다. 캐시 무효화 시점은
레코드 생성·수정·삭제 + 농도 기준 설정 변경이다.
```

그리고

```markdown
연도 세그먼트를 바꾸면 잔디·요약·차트가 전부 교체된다. 연 단위 쿼리가 반복되므로
**연도별 집계도 캐시 대상**이다. 과거 연도는 더 이상 변하지 않으므로 한 번 계산하면 고정이다.
```

아래로 바꾼다.

```markdown
집계는 `WorkoutRecord` 에서 파생한다. **영속 캐시는 두지 않는다** — 2026-09-09
[잔디 집계 스펙](2026-09-09-grass-daily-aggregate.md) 3절에서 뒤집었다. 이 문단은 데이터가
0건이던 시점의 추정이었다.

- 주 3회 × 3년 = 레코드 약 470건. 홈이 실제로 읽는 건 predicate 로 좁힌 **4개월치 50건
  남짓**이다. 비싼 쪽은 *칸 수*(119·371)가 아니라 레코드 수고, 그건 훨씬 적다
- 무효화 시점이 이미 넷이고(생성·수정·삭제·기준 변경) CloudKit 이 붙으면 다섯이다.
  캐시가 진실과 어긋나면 사용자에겐 "잔디가 틀렸다" 로 보이고 복구 수단이 없다
- `@Model` 캐시는 **CloudKit 스키마에 같이 올라가 기기 간 충돌 대상이 된다.** 파생 데이터를
  동기화하는 건 손해다

대신 계산을 View `body` 밖(`GrassViewModel`)에 둔다. 프로파일링이 요구하면 같은 순수 함수
위에 캐시를 얹을 수 있고, 그때 화면 코드는 안 바뀐다.

### 통계 연도 아카이브

연도 세그먼트를 바꾸면 잔디·요약·차트가 전부 교체된다. **연도별 집계 캐시도 같은 근거로
미룬다** — 과거 연도가 고정이라는 것은 맞지만, 캐시를 두는 비용(무효화·CloudKit 충돌)이
레코드 수백 건을 다시 접는 비용보다 크다.
```

기존 `### 통계 연도 아카이브` 헤더는 위 블록이 대체하므로 **중복해서 남기지 않는다.**

- [ ] **Step 2: TODO 를 갱신한다**

> **PR 번호가 필요하므로 이 Step 은 Task 5 Step 3(PR 생성) 뒤에 한다.** Step 1(아키텍처
> 정정)은 번호가 필요 없으니 먼저 커밋해도 된다. 지난번(PR #26)에 같은 순서로 처리했다.

`## HaruchiFit` 「예정사항」 표의 #1 행을

```markdown
| 2 데이터 | 1 | 잔디 집계 (일별 집계 캐시) | **다음** · 스펙 완료 · 선행(정지 제외) 구현 완료, 실기기 확인만 남음 | ... |
```

아래로 바꾼다. **캐시를 안 만들기로 했으므로 항목 이름에서 "캐시" 를 뺀다.**

```markdown
| 2 데이터 | 1 | 잔디 집계 (일별 집계) | **완료** (PR #<번호>) · 영속 캐시는 두지 않기로 확정 | ... |
```

「예정사항 (남은 12개)」 제목을 **「예정사항 (남은 11개)」** 로 고치고, #2 HealthKit import 행의 상태를 **`**다음**`** 으로 바꾼다.

「집 맥북에서 할 것」에 한 줄 더한다.

```markdown
- [ ] **잔디 농도 컷 눈으로 확인** — 실기기 기록이 쌓인 뒤 임시 화면에서 농도가 실제 운동
      시간과 맞는지. 컷은 30/60/90분 (D-M6)
```

- [ ] **Step 3: 커밋**

```bash
git add Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md TODO.md
git commit -m "📝 집계 캐시를 두지 않기로 한 결론을 아키텍처와 TODO 에 반영한다"
```

---

## Task 5: PR 을 낸다

- [ ] **Step 1: 전체 테스트를 한 번 더 돌린다**

```bash
cd "$(git rev-parse --show-toplevel)"
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
make lint
make format
```

기대: **테스트 57개 통과 · BUILD SUCCEEDED · 0 violations.**

- [ ] **Step 2: 푸시**

```bash
git push -u origin feat/haruchi-grass-aggregate
```

- [ ] **Step 3: PR 생성**

```bash
gh pr create --title "✨ 잔디 일별 집계" --body "$(cat <<'BODY'
## 무엇을

`WorkoutRecord` 들을 날짜 한 칸씩으로 접는 순수 집계를 만들고, 임시 `ContentView` 를 17주 잔디 그리드로 바꿨다.

## 왜

홈·달력·통계 **셋이 같은 집계를 쓴다.** 화면부터 만들면 셋이 각자 계산하게 되고, 규칙이 갈린 뒤에 합치는 건 훨씬 비싸다.

## 어떻게

- 규칙은 전부 `Shared/Models/` 의 순수 타입이 갖는다 — `Shared/` 가 워치 타깃에도 붙어 있어 `HaruchiFitWatchTests` 에서 그대로 테스트된다
- `GrassViewModel` 은 **배선만** 한다. iOS 테스트 타깃이 없어 유닛 테스트가 닿지 않는 자리라, 규칙을 넣으면 아무도 검증하지 못한다
- 농도 계산이 `WorkoutSource` 를 **보지 않는다** — 값 추출을 주입받으므로 칼로리 기준으로 전환할 때 분기가 하나도 늘지 않는다

## 아키텍처 문서를 한 군데 뒤집었다

5절의 *"일별 집계 캐시를 두는 편이 낫다"* 를 **캐시를 두지 않는다**로 고쳤다. 데이터가 0건이던 시점의 추정이었고, 홈이 실제로 읽는 건 4개월치 50건 남짓이다. 무효화 시점이 이미 넷이고, `@Model` 캐시는 CloudKit 스키마에 올라가 기기 간 충돌 대상이 된다.

## 검증

- 워치 유닛 테스트 **57개 통과** (신규 18개)
- iOS BUILD SUCCEEDED · `make lint`·`make format` 0 violations
- 시뮬레이터에서 격자 렌더·칸 탭·빈 칸 확인

## 다음에 지켜야 할 것

**#2 HealthKit import 는 `healthKitUUID` 가 이미 있는 레코드를 건드리지 않는다.** 건드리면 워치가 잰 값(정지 제외)이 HealthKit 값으로 덮여 **과거 잔디 농도가 소급해서 바뀐다** (스펙 6절).

## 문서

[스펙](Apps/HaruchiFit/docs/specs/shared/2026/2026-09-09-grass-daily-aggregate.md) · [플랜](Apps/HaruchiFit/docs/plans/shared/2026/2026-09-20-grass-daily-aggregate.md)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

- [ ] **Step 4: CI 통과 확인 후 머지**

```bash
gh pr checks --watch
gh pr merge --merge --delete-branch
```

`--delete-branch` 는 로컬 정리 단계에서 실패할 수 있다 — 워크트리가 그 브랜치를 잡고 있으면 gh 가 `main` 으로 옮기지 못한다. 그때는 원격만 따로 지운다.

```bash
git push origin --delete feat/haruchi-grass-aggregate
```

- [ ] **Step 5: 워크트리 정리**

트랙이 끝났으면 워크트리와 **그 DerivedData 를 같이** 지운다. 안 지우면 수백 MB 짜리 고아만 남는다.

```bash
cd "$(git rev-parse --show-toplevel)"
git worktree remove ../yj-apps-worktrees/grass-daily-aggregate
git pull --ff-only
git branch -d feat/haruchi-grass-aggregate
make dd-prune        # 목록 확인
make dd-prune-apply  # 실제로 지운다
```

---

## 나중으로 미룬 것 (스펙 9절)

| 항목 | 언제 |
|---|---|
| 칼로리 기준 컷 | 실데이터가 쌓인 뒤. `GrassIntensity` 상수 하나 추가로 끝난다 |
| 시간↔칼로리 전환 UI | Phase 5 · 07 설정 |
| `refresh()` 호출부 | Phase 5 · 08 수동 기록 편집 저장 직후 |
| `.refreshable` | Phase 2 #2 · "건강 앱에서 다시 가져오기". 지금 붙이면 당겨도 99% 같은 결과가 나와 "고장난 것 같다" 는 인상만 준다 |
| 집계 결과 캐싱 | 프로파일링이 요구하면. 순수 함수 위에 얹으면 되고 화면은 안 바뀐다 |
| 제품 홈 화면 (02절) | Phase 4 · #7 |
