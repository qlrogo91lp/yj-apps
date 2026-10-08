# HaruchiFit 05 통계 화면 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 이 플랜은 현재 세션에서 직접 실행하는 방식을 기준으로 한다. 사용자 요청 없이 서브에이전트를 만들지 않는다.

**Goal:** 준비 중 화면을 선택 연도의 잔디·누적·운동 패턴·마일스톤을 보여주는 통계 화면으로 바꾼다.

**Architecture:** 영속 기록을 값 스냅샷으로 변환하고 Foundation 기반 `StatisticsBuilder`가 모든 집계를 만든다. iOS ViewModel은 선택 연도와 집계 결과만 관리한다. SwiftUI는 `@Query` 스냅샷 변화와 앱 활성화를 전달하고, 순수 컴포넌트는 값과 콜백만 받는다.

**Tech Stack:** SwiftUI · Swift Charts · SwiftData · Combine · Foundation · Swift Testing. iOS 17 / watchOS 10.

**Spec:** [05 통계 상세 스펙](../../../specs/ios/2026/2026-10-08-statistics.md)

작성일: 2026-10-08
상태: **플랜 검토 대기 — 구현 전**
예정 브랜치: `feat/haruchi-statistics`

## Global Constraints

- 대상은 iOS 17 이상 HaruchiFit 통계 탭이다.
- 운동 횟수와 부위 빈도는 세션 수로 센다. 잔디는 하루 한 칸이다.
- 연도를 바꾸면 잔디·요약·차트·배지가 함께 바뀐다.
- 통계만의 별도 농도 기준은 만들지 않는다.
- 부위 태그가 없으면 부위 섹션을 숨긴다.
- 전환 횟수는 표시하지 않는다.
- 기록 편집·상세 진입·차트 드릴다운·전년 비교·목표 설정·HealthKit 추가 쿼리·저장 모델 변경은 범위에 포함하지 않는다.
- 한국어 문구와 `HaruchiPalette` 토큰을 사용한다. 컴포넌트에 ViewModel을 넘기지 않는다.
- 홈 Feature 전용 컴포넌트를 통계에서 참조하지 않는다. 공통 집계 규칙만 재사용한다.
- `.xcodeproj`·YJKit·워치 동작 코드는 수정하지 않는다. 동기화 그룹으로 새 파일을 포함한다.
- 사용자 검토 전에는 커밋하지 않는다. 브랜치·커밋·PR은 플랜 승인 범위에 포함한다. 머지는 별도 요청 시 진행한다.

## Review Focus

1. 같은 영속 ID에서 부위·시간·세그먼트 값만 바뀌어도 통계가 다시 계산되어야 한다. Task 1 스냅샷 동등성 테스트 + Task 3 `onChange` 배선 + Task 4 탭 간 수정 확인.
2. 윤년·54열·서머타임·주 시작 변경에서 날짜 누락과 주 평균 오류가 없어야 한다. Task 1 달력 테스트 + Task 2 스크롤 확인.
3. 세그먼트 없는 기록과 0초/한 유형 구성이 NaN 또는 빈 바 크래시를 만들지 않아야 한다. Task 1 구성 테스트 + Task 3 조건부 표시.
4. 현재 연도 미래 기록 제외, 연도 전환, 마지막 과거 기록 삭제에서 선택지와 집계가 일치해야 한다. Task 1 연도 정규화 테스트 + Task 4 갱신 확인.
5. 글자 확대·VoiceOver에서 연도·차트·잔디·배지를 읽을 수 있어야 한다. Task 2/3 접근성 구현 + Task 4 수동 검증.

## 파일 구조

모든 아래 코드 경로는 `Apps/HaruchiFit/` 기준이다.

| 작업 | 파일 | 책임 |
|---|---|---|
| Create | `Shared/Models/StatisticsRecordInput.swift` | 집계 입력 스냅샷과 영속 기록 변환 |
| Create | `Shared/Models/StatisticsDashboard.swift` | 집계 결과 값 타입과 작은 중첩 타입 |
| Create | `Shared/Models/StatisticsBuilder.swift` | 연도 선택·기간·차트·배지·잔디 날짜 배치 |
| Create | `watchosTests/Models/StatisticsBuilderTests.swift` | 집계·기간·동등성 테스트 |
| Create | `iOSApp/Features/Statistics/StatisticsViewModel.swift` | 선택 연도·결과 상태와 rebuild 배선 |
| Create | `iOSApp/Features/Statistics/Components/StatisticsYearPicker.swift` | 가로 연도 선택 |
| Create | `iOSApp/Features/Statistics/Components/AnnualGrass.swift` | 연 그리드·월 눈금·범례·초기 스크롤 |
| Create | `iOSApp/Features/Statistics/Components/AnnualSummary.swift` | 3칸 요약·주 평균 정보 |
| Create | `iOSApp/Features/Statistics/Components/StatisticsFrequencyChart.swift` | 월/요일 회수 차트, 종류별 축·강조 |
| Create | `iOSApp/Features/Statistics/Components/AnnualComposition.swift` | 구간 시간 비율·범례·0초 안내 |
| Create | `iOSApp/Features/Statistics/Components/BodyPartFrequencyChart.swift` | 부위별 수평 막대·설명 |
| Create | `iOSApp/Features/Statistics/Components/AnnualMilestones.swift` | 달성 배지·다음 목표 |
| Modify | `iOSApp/Features/Statistics/StatisticsView.swift` | Query·갱신·refresh·전체 섹션 조립·프리뷰 |
| Modify | `docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md` | 완료 시 05절에 상세 스펙 링크와 가변 주 수 반영 |
| Modify | `docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md` | 완료 상태·검증 대기 항목 |
| Modify | `CLAUDE.md` | 통계 구현 상태·구조 설명 |
| Modify | 루트 `TODO.md` | 문서 링크·완료/수동 확인 상태 |
| Modify | 이 플랜 | 진행 체크박스·검증 결과 |

홈 `GrassViewModel`은 Feature 경계 때문에 재사용하지 않는다. 통계 입력의 일별 합계를
기존 `DailyAggregate`로 만들어 `GrassIntensity.byTime.level(for:)`을 호출한다.
기록→일별 합계는 `GrassAggregator.fold` 결과를 입력 스냅샷 변환 시 함께 제공하여
통계에서 동일한 농도 합산을 다시 구현하지 않는다.

## Task 1 — 입력 스냅샷과 순수 집계 (TDD)

**Files:** Create `StatisticsRecordInput.swift`, `StatisticsDashboard.swift`, `StatisticsBuilder.swift`, `StatisticsBuilderTests.swift`.

**Interfaces:** 다음 이름과 필드를 이후 태스크에서 동일하게 사용한다.

```swift
struct StatisticsRecordInput: Equatable {
    struct SegmentInput: Equatable {
        let kind: SegmentKind
        let durationSeconds: Int
    }
    let startedAt: Date
    let totalSeconds: Int
    let totalCalories: Double?
    let bodyParts: [BodyPart]
    let segments: [SegmentInput]
    init(record: WorkoutRecord)
}

struct StatisticsDashboard: Equatable {
    struct Frequency: Equatable, Identifiable {
        let id: Int          // 월 1...12, 요일 1...7(월...일)
        let title: String
        let count: Int
        let isFuture: Bool
        let isHighlighted: Bool
    }
    struct BodyFrequency: Equatable, Identifiable {
        let part: BodyPart
        let count: Int
        var id: BodyPart { part }
    }
    struct Composition: Equatable {
        let strengthSeconds: Int
        let cardioSeconds: Int
        let strengthPercent: Int
        let cardioPercent: Int
        let strengthText: String
        let cardioText: String
    }
    struct Milestone: Equatable, Identifiable {
        let target: Int
        let remaining: Int
        let isAchieved: Bool
        var id: Int { target }
    }
    let year: Int
    let availableYears: [Int]
    let countText: String
    let durationText: String
    let weeklyAverageText: String
    let weeklyAverageExplanation: String
    let isCurrentYear: Bool
    let emptyMessage: String?
    let months: [Frequency]
    let weekdays: [Frequency]
    let composition: Composition? // 구간 합 0이면 nil
    let bodyParts: [BodyFrequency]
    let milestones: [Milestone]
    let gridDays: [Date]          // 연도 밖 자리도 날짜로 유지
    let grassLevels: [Date: GrassLevel]
    let monthColumns: [Int: Int]  // 월 → 0 기반 주 열
    let initialColumn: Int       // 현재 연도 오늘 열 / 과거 0
    let today: Date
}

enum StatisticsBuilder {
    static func dashboard(from inputs: [StatisticsRecordInput],
                          aggregates: [DailyAggregate],
                          selectedYear: Int?, now: Date,
                          calendar: Calendar) -> StatisticsDashboard
}
```

`selectedYear == nil` 또는 유효 선택지에 없으면 현재 연도로 정규화한다.
`StatisticsDashboard.year`가 정규화된 선택 연도다. 미래 기록은 input과 aggregates 모두에서
제외해야 하므로 호출부는 `startedAt <= now`인 기록에 `GrassAggregator.fold`를 적용한다.
빌더도 입력의 미래 시각을 제외하여 집계를 보호한다. 타입 추가 시 중첩 타입 외에는 파일당 한 타입을 유지한다.

- [ ] **Step 1:** 아래 테스트를 Swift Testing으로 작성한다. `GrassFixture.makeContext()`를 사용하고
  각 테스트는 컨테이너가 살아 있는 context에서 레코드를 만든다. 날짜는 `GrassFixture.date`와
  명시한 calendar를 사용한다. SwiftData 입력은 `@MainActor`에서 읽는다.

```swift
@Test func sameDayCountsTwoSessionsAndOneGrassDay() throws {
    let context = try GrassFixture.makeContext()
    let records = [
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 900),
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6, 18), totalSeconds: 900)
    ]
    let now = GrassFixture.date(2026, 10, 8)
    let result = StatisticsBuilder.dashboard(
        from: records.map(StatisticsRecordInput.init(record:)),
        aggregates: GrassAggregator.fold(records, calendar: GrassFixture.seoul),
        selectedYear: 2026, now: now, calendar: GrassFixture.seoul)
    #expect(result.countText == "2회")
    #expect(result.months[9].count == 2)
    #expect(result.weekdays[1].count == 2)
    #expect(result.grassLevels.count == 1)
    #expect(result.grassLevels[GrassFixture.date(2026, 10, 6)] == .medium)
}
```

| 추가 테스트 | 구체적 입력과 기대 |
|---|---|
| `emptyHistory` | 현재 연도 하나, 0회/0분/주 0.0회, 전체 빈 안내 |
| `emptyCurrentYearWithOlderHistory` | 과거 기록만 있으면 현재/과거 선택지, 현재 연도 빈 안내 |
| `yearsSkipGapsAndFuture` | 2023·2025·2027 기록, now 2026 → [2026,2025,2023] |
| `deletedYearFallsBack` | selected 2025, records [] → year 2026 |
| `newYearKeepsValidSelection` | now 2027, selected 2026과 2026 기록 → 선택 2026 유지 |
| `crossYearUsesStart` | 2025/12/31 23:40 시작·2026 종료 → 2025 1회, 2026 0회 |
| `futureStartsExcluded` | 오늘 18시 now 12시 → 횟수·구성·부위·잔디 모두 제외 |
| `januaryFirstAverage` | 1/1 1회 → 주 7.0회 |
| `pastLeapYearAverage` | 2024 52회 → 52 / (366 / 7), 소수 첫째 자리 |
| `dstUsesCalendarDays` | America/Los_Angeles 2026/3/9, 1회 → 68일 분모 |
| `gridCoversLeapYear` | 2024, 연도 내 날짜 366개·중복 0·첫 열 주 시작 |
| `gridAllows54Columns` | 2012 일요일 시작 → 54열, 1/1·12/31 둘 다 포함 |
| `mondayGridAndMonthColumns` | firstWeekday 2, 각 월 1일의 index / 7과 눈금 일치 |
| `durationFormatting` | 0/2400/5400초 → 0분/40분/1.5시간 |
| `zeroAndMissingSegments` | 0초 또는 segments nil → composition nil, 누적 시간 유지 |
| `oneKindAndRounding` | 근력만 → 100/0, 1:2 → 33/67, 범례 둘 다 있음 |
| `bodyTagsCountSessions` | 중복·미지 raw 태그 + 멀티 → 중복 제거·유효 부위 각 +1 |
| `bodyTieUsesCaseOrder` | 등/가슴 동률 → 가슴 먼저, 0회 부위 없음 |
| `weekdayTiesAndZero` | 월·수 각 2회 → 둘 강조, 빈 기록 → 강조 없음 |
| `milestoneBoundaries` | 9/10/25/142/500건 → 다음 10/25/50/200/없음, 남은 수 1/15/25/58 |
| `snapshotSeesInPlaceEdits` | 같은 모델의 시간·태그·구간 변경 전후 snapshot != |

- [ ] **Step 2:** RED 확인. 정의되지 않은 통계 타입 때문에 실패하는지 확인한다.

```bash
HARUCHI_WATCH_ID=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests \
  -destination "id=$HARUCHI_WATCH_ID" -only-testing:HaruchiFitWatchTests/StatisticsBuilderTests test
```

- [ ] **Step 3:** 인터페이스대로 구현한다. 입력 변환 시 `bodyParts`와 `orderedSegments`를 값으로 복사한다.
  연도 경계는 `calendar.dateInterval(of: .year, for:)`, 날짜 수는 startOfDay 사이 `.day` 차 +1이다.
  월은 month-1, 요일은 `(weekday + 5) % 7` 인덱스로 누적한다. 부위 정렬 동률은 allCases index다.
  구성 비율은 합 >0일 때만 계산하며 근력 반올림 후 유산소를 100에서 뺀다.
  연 잔디는 시작/끝 주 경계 사이를 calendar의 일 단위로 순회하고 연도 밖 칸을 UI에서 숨긴다.
  aggregates를 선택 연도·오늘 이하 날짜로 제한하고 `GrassIntensity.byTime`으로 levels를 만든다.
- [ ] **Step 4:** 위 테스트를 다시 실행해 GREEN 확인. 순수 결과에 영속 모델 참조가 남지 않았는지 확인한다.
- [ ] **Step 5:** 승인 범위에서 커밋 `✨ 하루치 연간 통계 집계 규칙을 추가한다`.

## Task 2 — 연도 선택과 연 잔디

**Files:** Create `StatisticsYearPicker.swift`, `AnnualGrass.swift`.

**Interfaces:**

```swift
StatisticsYearPicker(years: [Int], selectedYear: Int, onSelect: (Int) -> Void)
AnnualGrass(dashboard: StatisticsDashboard)
```

- [ ] **Step 1:** 연도 선택은 가로 ScrollView와 Button으로 구현한다. 최소 높이 44pt,
  선택에 accent와 `.accessibilityAddTraits(.isSelected)`를 적용한다.
- [ ] **Step 2:** AnnualGrass는 열별 VStack 7칸을 HStack으로 배치한다. 열 ID는 0부터 시작한다.
  날짜 비교는 dashboard.today와 연도이며, 연도 밖 자리는 clear, 미래 칸은 opacity 0.3이다.
  monthColumns를 열 아래 눈금 배치에 사용한다. 칸 크기 16pt·간격 3pt를 기본으로 하고
  1·4·7·10·12월 눈금이 다른 열에 겹치지 않게 고정 19pt 열 간격에 맞춘다.
- [ ] **Step 3:** ScrollViewReader에서 initialColumn로 scrollTo한다. 연도 변경 시
  `.id(dashboard.year)`로 스크롤 컨테이너를 재생성하여 초기 위치를 적용한다.
  현재 연도는 오늘 열이 화면 우측에 오게 `.trailing`, 과거는 첫 열 `.leading`이다.
- [ ] **Step 4:** 오늘 테두리·4단계 범례·날짜/농도 VoiceOver를 추가한다.
  미래·연도 밖 칸은 accessibilityHidden이다. 빈 과거 칸은 날짜 + `운동 없음`을 읽는다.
- [ ] **Step 5:** 프리뷰에서 2026 현재/2024 윤년/2012 54열을 확인하고 iOS 빌드를 실행한다.
  주 평균이나 차트 규칙을 컴포넌트에 새로 넣지 않는다.
- [ ] **Step 6:** 커밋 `✨ 하루치 연도 선택과 연간 잔디를 추가한다`.

## Task 3 — 차트·요약·ViewModel·통계 탭 연결

**Files:** Create `StatisticsViewModel.swift`, 나머지 5개 표시 컴포넌트. Modify `StatisticsView.swift`.

**Interfaces:**

```swift
@MainActor final class StatisticsViewModel: ObservableObject {
    @Published private(set) var dashboard: StatisticsDashboard
    func rebuild(from records: [WorkoutRecord], now: Date = Date(), calendar: Calendar = .current)
    func select(year: Int, from records: [WorkoutRecord], now: Date = Date(), calendar: Calendar = .current)
}
AnnualSummary(dashboard: StatisticsDashboard)
StatisticsFrequencyChart(title: String, values: [StatisticsDashboard.Frequency])
AnnualComposition(composition: StatisticsDashboard.Composition?)
BodyPartFrequencyChart(values: [StatisticsDashboard.BodyFrequency])
AnnualMilestones(values: [StatisticsDashboard.Milestone])
```

- [ ] **Step 1:** ViewModel은 초기 빈 dashboard를 빌더로 생성한다. rebuild는 현재 선택을
  빌더에 넘기고 정규화된 year를 유지한다. select는 요청 연도를 넘긴다.
  각 호출에서 now 이하 records만 `GrassAggregator.fold`에 전달한다.
- [ ] **Step 2:** AnnualSummary는 횟수/누적/주 평균 3칸, 주 평균 정보 버튼의 popover를 구현한다.
  큰 글자에서는 ViewThatFits로 세로 배치를 허용한다. 라벨은 isCurrentYear에 따라 교체한다.
- [ ] **Step 3:** 월/요일 차트는 Swift Charts `BarMark(x: .value("항목", id), y: .value("횟수", count))`를 쓴다.
  전체 x축 범주를 유지하고 title로 축 눈금을 매핑한다. y축은 최소 상한 1, 정수 눈금만 표시한다.
  future opacity, highlighted accent/dim을 입력으로 적용하고 각 막대에 항목/횟수 접근성 라벨을 둔다.
  월 values는 빌더에서 전부 highlighted true, 요일은 최댓값 동률만 true다.
- [ ] **Step 4:** 구성은 GeometryReader 너비를 구간 시간 비율로 분할한다. nil이면
  `구성 시간이 있는 기록이 없어요`. 두 범례를 항상 표시한다.
  부위는 `BarMark(x: count, y: title)`로 입력 순서와 정수 축을 유지하고 설명 문구를 붙인다.
  마일스톤은 ViewThatFits 또는 적응형 LazyVGrid로 줄바꿈하고 잠긴 목표 남은 수를 읽게 한다.
- [ ] **Step 5:** StatisticsView를 다음 배선으로 바꾼다. 스냅샷은 body의 관찰 범위에서 생성하여
  SwiftData 속성 변경을 추적한다. snapshot 비교는 시간·태그·구간 변경까지 포함한다.

```swift
@Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]
@Environment(\.scenePhase) private var scenePhase
@EnvironmentObject private var sync: WorkoutSyncCoordinator
@StateObject private var statistics = StatisticsViewModel()

private var inputs: [StatisticsRecordInput] {
    records.map(StatisticsRecordInput.init(record:))
}

// ScrollView에 적용:
// .onAppear { statistics.rebuild(from: records) }
// .onChange(of: inputs) { statistics.rebuild(from: records) }
// .onChange(of: scenePhase) { _, phase in
//     if phase == .active { statistics.rebuild(from: records) }
// }
// .refreshable { await sync.sync() }
```

  연도 picker 콜백은 `statistics.select(year: $0, from: records)`에 연결한다.
  잔디/요약 뒤 emptyMessage가 있으면 스펙의 빈 안내만 표시한다.
  없으면 월·구성·요일·부위(비어 있지 않을 때만)·마일스톤 순서로 조립한다.
  화면 제목·배경·toolbar 스타일은 기존 HaruchiPalette를 따른다.
- [ ] **Step 6:** StatisticsView 파일 private preview helper에 고유 이름/CloudKit .none의
  인메모리 컨테이너를 만든다. 0건/현재 1건/과거 포함/멀티 태그 샘플과 sync·alerts environment를 넣는다.
  제품 실행 경로에 샘플 기록 또는 임시 디버그 버튼을 넣지 않는다.
- [ ] **Step 7:** iOS 빌드와 앱 lint/format 검사. 실패한 항목만 수정하고 다시 검사한다.

```bash
HARUCHI_IOS_ID=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$HARUCHI_IOS_ID" build
(cd Apps/HaruchiFit && swiftlint && swiftformat --lint .)
```

- [ ] **Step 8:** 커밋 `✨ 하루치 통계 탭에 연간 차트와 마일스톤을 연결한다`.

## Task 4 — 전체 검증·문서·PR

**Files:** 이 플랜, 제품 스펙, 로드맵, 앱 CLAUDE.md, 루트 TODO.md.

- [ ] **Step 1:** 전체 HaruchiFitWatchTests를 한 번 실행한다. Shared 변경 회귀가 없는지 확인한다.
  Task 3 이후 코드 수정이 없으면 통과한 iOS 빌드/lint를 불필요하게 반복하지 않는다.

```bash
HARUCHI_WATCH_ID=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$HARUCHI_WATCH_ID" test
```

- [ ] **Step 2:** 프리뷰와 시뮬레이터에서 아래 항목을 확인한다. 환경 때문에 확인하지 못한 항목은
  완료로 표시하지 않고 해당 이유와 수동 확인 항목을 플랜에 남긴다.
  - 0건/1건/멀티 유형/태그 없는 기록: 섹션 노출과 0값.
  - 현재/과거 연도 전환: 모든 섹션과 잔디 초기 위치 함께 변경.
  - 다른 탭 상세에서 부위 수정 후 통계 복귀: 부위 횟수 즉시 반영.
  - 선택한 과거 연도의 마지막 기록 삭제: 현재 연도 복귀.
  - 당겨서 새로고침 및 기록 추가: 선택 연도 유지, 새 데이터 반영.
  - 접근성 XL: 요약·범례·배지 잘림 없음, 연도 탭 44pt.
  - VoiceOver: 연도 선택 상태, 월/요일/부위 횟수, 잔디 날짜/농도, 목표 남은 수.
  - 시스템 시간 변경을 쓰지 않고 주입 프리뷰로 연말→새해 선택 유지 확인.
- [ ] **Step 3:** 제품 스펙 05절의 고정 53주 문구를 실제 필요한 주 수로 바꾸고 상세 스펙 링크를 추가한다.
  로드맵 #9와 TODO를 구현 완료·수동 검증 상태에 맞게 갱신한다. 앱 CLAUDE의 통계 설명을 갱신한다.
  이 플랜에 실행한 명령·결과·남은 실기기 검증을 기록한다.
- [ ] **Step 4:** `git diff --check`, 변경 파일 범위와 스펙 10절 검증 기준을 자체 리뷰한다.
  상세 스펙·플랜은 사용자 검토 완료 상태로 코드/문서 커밋에 함께 포함한다.
- [ ] **Step 5:** 커밋 `📝 하루치 통계 구현과 검증 상태를 기록한다`.
  승인된 브랜치를 push하고 PR을 만든다. PR에는 연간 통계 동작·주 평균 분모·검증 결과와
  아직 확인하지 못한 실기기 항목을 기재한다. 사용자에게 PR과 결과를 전달한다.

## 승인 범위와 다음 단계

이 문서는 구현 전 검토용이다. 승인 시 `feat/haruchi-statistics` 브랜치 생성, 위 파일 구현·검증·문서 갱신,
커밋·push·PR 작성까지 진행한다. 현재 세션 직접 실행을 권장한다. 집계 결과 인터페이스를
공유하는 한 화면 작업이므로 한 구현자가 순서대로 진행하면 충분하다.
PR 머지와 실기기 확인 완료 처리는 별도 사용자 요청/실제 확인 뒤 진행한다.
