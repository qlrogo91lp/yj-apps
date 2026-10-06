# 하루치 핏 Phase 4 #7 — 02 홈 대시보드 구현 플랜

작성일: 2026-10-06
상태: **구현 완료 — 워치 테스트·iOS 빌드·lint 통과 · 시뮬레이터(Task 4)·실기기 확인 대기**

구현 중 자체 리뷰로 한 건을 고쳤다 — 상세 시트에서 삭제한 직후 `onFinish` 로 목록을 다시 만들면 지워진 모델이 든 `@Query` 결과를 읽어 크래시할 수 있어,
삭제로 닫힌 때는 `onFinish` 를 부르지 않는다 (기록 탭의 원래 동작). HealthKit 권한 시트가 시뮬레이터를 막아 Task 4 는 직접 확인이 필요하다.

작업 브랜치(예정): `feat/haruchi-home-dashboard`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홈 탭의 임시 잔디 확인 화면을 스펙 02절 대시보드로 바꾼다. 위에서부터 잔디 히어로 → 축적 스탯 2개 →
이번 주 운동 구성 바(기록 3회 미만이면 마일스톤 한 줄) → 최근 기록 2개 순서다. 최근 기록을 탭하면 기록 상세 시트가 열린다.

**Architecture:** 표시 규칙(스탯 · 주간 구성 · 마일스톤 · 잔디 칸 날짜 · 헤더 월)은 `Shared/Models/HomeDashboardBuilder` 에 순수 함수로 둔다.
iOS 테스트 타깃이 없어서 워치 테스트(`HaruchiFitWatchTests`)가 닿는 곳은 `Shared/` 뿐이기 때문이다. `RecordListBuilder`·`RecordDetailBuilder` 와 같은 이유다.
홈과 기록 탭이 함께 쓰게 되는 것은 계층을 한 칸 올린다.
- `RecordRow` → 앱 루트 `Components/`
- 상세 시트를 띄우는 배선 → `RecordDetailSheet` modifier
- 삭제 → `ModelContext` 확장

**Tech Stack:** SwiftUI (iOS 17) · SwiftData `@Query` · Swift Testing (watchOS 테스트 타깃)

**Spec:** [제품 스펙 02절 · 3절 · D3 · D5](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) ·
[잔디 집계 스펙](../../../specs/shared/2026/2026-09-09-grass-daily-aggregate.md) ·
[로드맵 Phase 4 #7 · 2차 1번](../../../specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md)

## Global Constraints

- iOS 17 최소 버전. `Packages/YJKit/` · `WatchApp/` · `.xcodeproj` 는 수정하지 않는다 (폴더 추가는 동기화 그룹이 알아서 잡는다)
- **차트는 통계 전용이다.** 홈에서 예외로 허용하는 차트는 이번 주 비율 바 하나뿐이다 (스펙 3절). 다른 그래프를 더하지 않는다
- **연 단위로 리셋되는 숫자를 두지 않는다** (`올해 누적` 기각, 스펙 02절)
- 잔디 규칙은 `GrassAggregator` · `GrassIntensity` 를 그대로 쓴다. 같은 규칙을 홈에 다시 쓰지 않는다
- 주의 경계는 `calendar` 의 `.weekOfYear` 를 따른다. 기록 목록의 `이번 주` 와 같은 주다
- 문구는 한국어로 하드코딩한다. 색은 `HaruchiPalette` 토큰만 쓴다 (근력 `accent` · 유산소 `cardio`)
- **ViewModel 전달은 단방향.** 컴포넌트는 VM 을 받지 않고 값과 콜백만 받는다. `전체 보기` 는 `ContentView` 가 탭을 바꾸는 콜백이다
- **작동하지 않는 버튼은 노출하지 않는다** (탭 셸 · 목록 · 상세 플랜과 같은 원칙)
- 테스트 저장소는 `GrassFixture` 를 쓴다 (테스트마다 고유 이름 · `cloudKitDatabase: .none` · 컨테이너 보관)

## Review Focus

스펙에 적혀 있지 않지만 사용자가 실제로 만날 입력과 상황이다. 터질 가능성이 높은 순서로 적었다.

1. **기록이 0개 · 1~2개인 첫 사용자.** 이 앱을 처음 여는 사람은 전부 여기에 걸린다. 스탯은 `0회`, 구성 바 자리는 마일스톤, 최근 기록은 빈 문구가 나와야 하고 화면이 무너지면 안 된다.
   → Task 1 `emptyHistoryShowsFirstMilestone` · `twoRecordsStillShowMilestone` · Task 4 시뮬레이터 항목
2. **기록은 3회 이상인데 이번 주에는 없다** (월요일 아침). 비율 바를 0 대 0 으로 그리면 깨진다.
   → Task 1 `emptyWeekHasNoComposition` 은 바 대신 `이번 주는 아직 기록이 없어요` 한 줄을 낸다
3. **구간이 없는 기록** (건강 앱 import 이전 데이터 · 이후의 수동 기록). 주간 총시간은 `totalSeconds` 합이고 바는 구간 합이라서, 총시간과 범례 합이 다를 수 있다.
   → Task 1 `weekTotalUsesTotalSecondsNotSegments` 로 규칙을 못박는다 (결정 D4)
4. **홈 시트에서 기록을 지우거나 부위를 바꾼다.** 기록 탭과 같은 크래시 경로(떠 있는 시트가 지워진 모델을 읽음)와 같은 갱신 누락(`@Query` 동일성 비교)이 홈에도 생긴다.
   → Task 2 에서 상세 시트 배선을 하나로 합쳐 두 탭이 같은 코드를 탄다 (결정 D6)
5. **월말·연말 경계와 일요일 시작 주.** `이번 달` 은 오늘이 속한 달의 1일 0시부터 센다. 주는 기기 달력의 시작 요일을 따른다.
   → Task 1 `monthStatCountsFromFirstOfMonth` · `weekFollowsCalendarFirstWeekday`
6. **스탯을 전체 기록으로 계산한다.** 지금 홈 `@Query` 는 26주로 잘려 있어서 `전체 누적` 이 틀린다.
   → Task 3 에서 `@Query` 필터를 걷어낸다 (결정 D3)

---

## 목표와 범위

| 스펙 02절 항목 | 이번 작업 | 비고 |
|---|---|---|
| 상단 바 중앙 — `8월 2026` | ✅ | 결정 D1 |
| 상단 바 좌 ⚙ 설정 · 우 `+` 수동 추가 | ❌ | 결정 D1. 각각 #10 · #11 이 붙인다 |
| 1 잔디 히어로 — 26주 × 7일, 좌우 스와이프, 오늘 칸 펄스 | ✅ | 결정 D2 |
| 2 축적 스탯 — `이번 달` / `전체 누적`, 세로 구분선 | ✅ | 결정 D3 |
| 3 이번 주 운동 구성 바 + 주간 총시간 + 범례 | ✅ | 결정 D4 |
| 엠프티 — 3회 미만이면 바 자리에 마일스톤 한 줄 | ✅ | 결정 D5 |
| 4 최근 기록 2개 + `전체 보기 ›` | ✅ | 결정 D6 · D7 |

### 검토 때 확인할 결정

플랜을 승인하면 아래 결정도 함께 승인하는 것이다. 바꾸고 싶은 것이 있으면 검토 때 말해 달라.

- **D1. 상단 바에는 중앙 월 제목만 둔다.** 표기는 스펙 그대로 `10월 2026` 이고 **오늘이 속한 달**이다. 잔디를 스크롤해도 바뀌지 않는다.
  잔디는 26주가 한 덩어리라서 "보고 있는 달"이 하나로 정해지지 않는다. ⚙ 와 `+` 는 열 화면이 아직 없어서 두지 않는다.
  설정(#10)과 수동 기록(#11) 플랜이 각각 자기 버튼을 붙인다
- **D2. 잔디 히어로는 지금 그리드를 컴포넌트로 옮긴 것이다.** 26주를 가로 스크롤로 보여 주고 처음 위치는 오른쪽 끝(오늘)이다.
  - **오늘 칸**은 테두리가 천천히 밝아졌다 어두워지는 펄스를 반복한다. 손쉬운 사용의 *동작 줄이기*가 켜져 있으면 고정 테두리로 그린다
  - **칸 탭 → 그날 값 텍스트**는 임시 확인용이었으므로 없앤다. 스펙에 없다. 날짜별 열람은 03a 달력(#8)이 맡는다
  - **26주보다 과거**는 스크롤되지 않는다. "최근 약 6개월"이 스펙이다
- **D3. 축적 스탯은 횟수가 크게, 시간이 작게 나온다.** 칸마다 큰 숫자 `12회`, 그 아래 `9.2시간`, 라벨 `이번 달` / `전체 누적` 이다.
  - 스펙 D5 가 축적형 지표를 *"누적 횟수·시간"* 으로 정했고, 03a 달력 월 요약(`12회 · 9.2시간`)과 같은 표기다
  - 횟수는 세션 수(D2), 시간은 `totalSeconds` 합을 시간 단위로 바꿔 소수 첫째 자리까지 쓴다. 1시간 미만이면 `40분` 으로 쓴다
  - `전체 누적` 때문에 홈 `@Query` 의 26주 필터를 걷어내고 전체 기록을 읽는다. 잔디는 같은 결과에서 26주만 쓴다. 집계는 O(n) 한 번이라 수백 건이면 문제없다
- **D4. 이번 주 구성 바는 구간 시간으로 비율을 내고, 총시간은 기록 시간을 쓴다.**
  - 바와 범례(`근력 4.2h` / `유산소 2.0h`)는 이번 주 기록의 구간 합이다. 우측 총시간(`6.2h`)은 `totalSeconds` 합이라 잔디·스탯과 같은 값이다
  - 구간이 없는 기록이 섞이면 범례 합이 총시간보다 작을 수 있다. 이것은 정상이다 (Review Focus 3)
  - 범례에서 0인 종류는 뺀다. 표기는 스펙대로 `h` 를 쓰고 소수 첫째 자리까지 쓴다
  - 이번 주 기록이 없으면 바 대신 `이번 주는 아직 기록이 없어요` 한 줄을 낸다
- **D5. 마일스톤 한 줄은 전체 기록이 3회 미만일 때 나온다.**
  - 0회: `워치에서 첫 운동을 기록해 보세요`
  - 1~2회: `3번째 운동을 기록하면 이번 주 구성이 보여요 · N회 남음`
  - 통계(#9)의 마일스톤 배지(`🔒 200회 · 58 남음`)와는 별개다. 홈의 이 한 줄은 *비율 바를 대신하는 안내*이므로 배지 체계와 엮지 않는다
- **D6. 기록 상세 시트 배선을 `RecordDetailSheet` modifier 하나로 합친다.**
  - 지금은 `RecordsView` 가 메모 초안 보관, 시트가 내려간 뒤 삭제, 닫힐 때 목록 갱신을 직접 들고 있다. 홈이 이 코드를 복사하면 같은 버그를 두 번 고치게 된다
  - modifier 는 기록 기능의 `Detail/` 에 둔다. 홈은 `selected` 바인딩과 콜백만 넘긴다. 다른 기능의 화면을 조합할 때 값과 콜백만 넘긴다는 규칙에 맞는다
  - **삭제는 `ModelContext.deleteRecord(_:)` 확장으로 `Shared/Persistence/` 에 옮긴다.** `RecordsViewModel.delete` 에서 옮기는 것이다. 두 탭이 같이 쓰고, 이참에 워치 테스트가 닿게 된다
- **D7. 최근 기록 행은 기록 탭 행과 같은 `RecordRow` 다.** 날짜·시간대, 구간 칩, 부위 한 줄, kcal 이 들어간다.
  - 스펙은 홈 행에 *부위 칩*을 적었지만 목록 플랜 D5 가 칩 대신 한 줄 텍스트로 정했으므로 그것을 따른다
  - `RecordRow` 는 두 기능이 쓰게 되므로 앱 루트 `Components/` 로 올린다
  - 행 문자열은 `RecordListBuilder.row(for:)` 를 공개해서 쓴다
  - `전체 보기 ›` 는 기록 탭으로 전환한다. `ContentView` 가 `TabView(selection:)` 을 갖고 홈에 `onShowAllRecords` 콜백을 넘긴다

### 범위 밖

- ⚙ 설정 진입 — #10 · `+` 수동 추가 — #11 (D1)
- 잔디 칼로리 기준 전환 — #10 설정. 홈은 `GrassIntensity.byTime` 고정
- 날짜 칸 탭 → 그날 기록 — #8 달력 (D2)
- 오늘 칸 펄스의 실기기 체감 조정 — 시뮬레이터에서 정한 값으로 시작하고, 어색하면 실기기 확인 때 고친다

---

## 파일 구조

| 파일 | 작업 | 역할 |
|---|---|---|
| `Shared/Models/HomeDashboard.swift` | 새로 | 화면이 그대로 찍을 값. `monthTitle` · `monthStat` · `totalStat` · `week: WeekComposition?` · `milestone: String?` · `emptyWeekText: String?` |
| `Shared/Models/HomeDashboardBuilder.swift` | 새로 | `[WorkoutRecord]` + `now` + `calendar` → `HomeDashboard`. 잔디 칸 날짜 `gridDays(weeks:now:calendar:)` 도 여기로 옮긴다 (지금은 `HomeView` 안에 있다) |
| `Shared/Persistence/ModelContext+RecordDeletion.swift` | 새로 | `deleteRecord(_:) -> Bool`. `RecordsViewModel.delete` 의 본문을 옮긴 것이다 (D6) |
| `Shared/Models/RecordListBuilder.swift` | 수정 | `row(for:formatter:)` → `rows(for:calendar:locale:)` 공개 (D7) |
| `watchosTests/Models/HomeDashboardBuilderTests.swift` | 새로 | Task 1 |
| `watchosTests/Models/RecordDeletionTests.swift` | 새로 | Task 2. 삭제하면 구간도 함께 사라진다(cascade) |
| `iOSApp/Components/RecordRow.swift` | 이동 | `Features/Records/Components/` 에서 옮긴다 (`git mv`) |
| `iOSApp/Features/Records/Detail/RecordDetailSheet.swift` | 새로 | modifier. 메모 초안 · 내려간 뒤 삭제 · 실패 알림 · `onFinish` (D6) |
| `iOSApp/Features/Records/RecordsView.swift` | 수정 | 시트 배선을 modifier 로 바꾸고 삭제는 `deleteRecord` 를 쓴다 |
| `iOSApp/Features/Records/RecordsViewModel.swift` | 수정 | `delete` 제거 |
| `iOSApp/Features/Home/HomeViewModel.swift` | 새로 | `rebuild(from:)` 가 `HomeDashboardBuilder` 를 부르고, `GrassViewModel` 과 나란히 `@StateObject` 로 산다. 규칙은 들지 않는다 |
| `iOSApp/Features/Home/Components/GrassHero.swift` | 새로 | 칸 날짜 · 농도 · 오늘 날짜를 값으로 받는다. 펄스 · 동작 줄이기 처리 (D2) |
| `iOSApp/Features/Home/Components/AccumulationStats.swift` | 새로 | 두 칸 + 세로 구분선 (D3) |
| `iOSApp/Features/Home/Components/WeekCompositionBar.swift` | 새로 | 비율 바 · 총시간 · 범례. 마일스톤과 빈 주 문구도 같은 자리에 그린다 (D4 · D5) |
| `iOSApp/Features/Home/Components/RecentRecordsSection.swift` | 새로 | 헤더 `최근 기록` + `전체 보기 ›` + 행 2개. 기록이 없으면 빈 문구 (D7) |
| `iOSApp/Features/Home/HomeView.swift` | 다시 씀 | `@Query` 전체 · 네 섹션 배치 · 월 제목 툴바 · 당겨서 새로고침 유지 · `RecordDetailSheet` |
| `iOSApp/ContentView.swift` | 수정 | `TabView(selection:)` + `HomeView(onShowAllRecords:)` |
| 로드맵 · 루트 `TODO.md` · 하루치 `CLAUDE.md` 구조 절 | 수정 (완료 시) | #7 취소선 · 실기기 확인 항목 · `iOSApp/Components/` 추가 |

---

## Task 1 — `HomeDashboardBuilder` (TDD, 워치 테스트 타깃)

- [ ] **Step 1: 실패하는 테스트 작성.** `now` 는 `GrassFixture.date(2026, 10, 6)`(화), 달력은 `GrassFixture.seoul` 이다

| 테스트 | 입력 | 기대 |
|---|---|---|
| `monthTitleIsCurrentMonth` | — | `10월 2026` |
| `emptyHistoryShowsFirstMilestone` | 기록 0 | 스탯 `0회` · `0분`, `week == nil`, 마일스톤 `워치에서 첫 운동을…` |
| `twoRecordsStillShowMilestone` | 기록 2 | 마일스톤 `… · 1회 남음`, `week == nil` |
| `threeRecordsShowComposition` | 이번 주 3건 | 마일스톤 nil, `week` 있음 |
| `monthStatCountsFromFirstOfMonth` | 9/30 23:50 · 10/1 00:10 시작 | 이번 달 1회 · 전체 2회 |
| `totalStatSpansAllHistory` | 1년 전 기록 포함 | 전체 누적에 포함된다 |
| `hoursUnderOneShowMinutes` | 40분 | `40분` · 90분이면 `1.5시간` |
| `weekCompositionSumsSegments` | 근력 50분 + 유산소 20분, 근력 30분 | 근력 80분 · 유산소 20분 · 범례 `근력 1.3h` · `유산소 0.3h` |
| `weekTotalUsesTotalSecondsNotSegments` | 구간 없는 60분 기록 + 위 기록 | 총시간에는 들어가고 바 비율에는 안 들어간다 |
| `zeroKindIsDroppedFromLegend` | 근력만 | 범례에 근력 하나 |
| `emptyWeekHasNoComposition` | 지난주에만 3건 | `week == nil` · `emptyWeekText` 있음 · 마일스톤 nil |
| `weekFollowsCalendarFirstWeekday` | 일요일 시작 달력과 월요일 시작 달력 | 일요일 기록의 이번 주 포함 여부가 달력을 따른다 |
| `gridDaysEndOnThisWeek` | 26주 | 182칸, 마지막 주에 오늘이 들어 있고 첫 칸은 주 시작 요일 |

- [ ] **Step 2: RED 확인**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test \
  -only-testing:HaruchiFitWatchTests/HomeDashboardBuilderTests
```

- [ ] **Step 3: `HomeDashboard` · `HomeDashboardBuilder` 구현.** 월 · 주 경계는 `calendar.dateInterval(of:for:)`, 날짜 포맷은 `RecordListBuilder.formatter` 를 쓴다
- [ ] **Step 4: GREEN.** 전체 워치 테스트를 돌려 기존 테스트도 통과하는지 본다
- [ ] **Step 5: 커밋.** `✨ 하루치 홈 대시보드 표시 규칙을 추가한다`

## Task 2 — 공유 계층 올리기 (`RecordRow` · 삭제 · 상세 시트)

동작은 바뀌지 않는다. 기록 탭이 지금과 똑같이 움직여야 한다.

- [ ] **Step 1: `RecordDeletionTests` 작성 → RED.** 구간 2개를 가진 기록을 지우면 기록과 구간이 모두 사라진다
- [ ] **Step 2:** `ModelContext+RecordDeletion.swift` 를 만들고 `RecordsViewModel.delete` 본문을 옮긴다(실패하면 rollback 하고 false) → GREEN
- [ ] **Step 3:** `RecordListBuilder.rows(for:calendar:locale:)` 를 공개한다. `sections` 도 같은 경로로 행을 만든다
- [ ] **Step 4:** `git mv iOSApp/Features/Records/Components/RecordRow.swift iOSApp/Components/RecordRow.swift`. 빈 폴더가 남으면 지운다
- [ ] **Step 5:** `RecordDetailSheet` modifier 를 만들고 `RecordsView` 의 시트 · `memoDrafts` · `deleteAfterDismiss` · `finishDetail` 을 그리로 옮긴다
  - 시그니처: `.recordDetailSheet(item: Binding<WorkoutRecord?>, onFinish: @escaping () -> Void)`
  - 실패 알림은 modifier 가 `AppAlertCenter` 를 environment 에서 꺼내 쓴다
- [ ] **Step 6: 빌드 · lint · 기록 탭 회귀 확인** (시뮬레이터)
  - 행을 탭하면 시트가 열린다
  - 부위를 바꾸고 닫으면 행에 반영된다
  - 시트에서 삭제하면 크래시 없이 행이 사라진다
  - 스와이프 삭제가 된다
- [ ] **Step 7: 커밋.** `♻️ 기록 행 · 상세 시트 · 삭제를 홈과 함께 쓰도록 올린다`

## Task 3 — 홈 화면

- [ ] **Step 1:** `HomeViewModel` 을 만든다. `@Published private(set) var dashboard: HomeDashboard` 와 `recentRows: [RecordListRow]`(최신 2개)를 둔다
- [ ] **Step 2:** 컴포넌트 4개를 만든다. 전부 값과 콜백만 받는다
  - `GrassHero(days:level:today:)`: `level` 은 `(Date) -> GrassLevel` 클로저다. 펄스는 `@Environment(\.accessibilityReduceMotion)` 이면 끈다
  - `AccumulationStats(month:total:)`
  - `WeekCompositionBar(week:milestone:emptyText:)`: 셋 중 하나만 그린다
  - `RecentRecordsSection(rows:onSelect:onShowAll:)`: 행이 0이면 `아직 기록이 없어요`
- [ ] **Step 3:** `HomeView` 를 다시 쓴다
  - `@Query(sort: \WorkoutRecord.startedAt, order: .reverse)` 로 필터 없이 읽는다
  - `onAppear` · `onChange(of: records)` · `scenePhase == .active` 에서 두 VM 을 `rebuild` 한다. `scenePhase` 를 넣는 이유는 자정을 넘겨 앱에 돌아왔을 때 `이번 주` · 오늘 칸을 다시 계산하기 위해서다
  - `.toolbar { ToolbarItem(placement: .principal) { Text(dashboard.monthTitle) } }` 를 쓰고 `navigationTitle` 은 지운다
  - `.refreshable { await sync.sync() }` 는 그대로 둔다
  - `.recordDetailSheet(item: $selected, onFinish: rebuild)` 를 붙인다
- [ ] **Step 4:** `ContentView` 에 `@State private var tab: AppTab = .home` 과 `TabView(selection:)` 을 넣고, `HomeView(onShowAllRecords: { tab = .records })` 를 넘긴다
- [ ] **Step 5: 빌드 · lint**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
make lint && make format
```

- [ ] **Step 6: 커밋.** `✨ 하루치 홈을 잔디 · 축적 스탯 · 이번 주 구성 · 최근 기록 대시보드로 바꾼다`

## Task 4 — 시뮬레이터 확인

시뮬레이터에는 워치 기록이 없다. 프리뷰 컨테이너, 또는 건강 앱에 운동을 손으로 넣고 import 하는 방법으로 아래 경우를 만든다.

- [ ] **기록 0 · 2 · 5건.** 스탯 `0회`, 마일스톤 두 문구, 3건이 넘으면 구성 바로 바뀌는지, 최근 기록 빈 문구
- [ ] **이번 주 0건 · 전체 3건 이상.** `이번 주는 아직 기록이 없어요`
- [ ] **잔디.** 처음 위치가 오른쪽 끝인지, 오늘 칸 펄스, 설정 › 손쉬운 사용 › 동작 줄이기를 켜면 펄스가 멈추는지
- [ ] **최근 기록.** 탭하면 시트가 열린다. 시트에서 부위를 바꾸면 홈 행에 반영된다. 시트에서 삭제하면 크래시 없이 사라지고 스탯 · 잔디 칸이 줄어든다
- [ ] **`전체 보기 ›`.** 기록 탭으로 전환된다
- [ ] **큰 글자 크기(접근성 XL)에서** 스탯 두 칸과 범례가 잘리지 않는지
- [ ] **당겨서 새로고침**이 그대로 동작하는지

## Task 5 — 문서 갱신 · PR

- [ ] 로드맵 #7 행에 취소선과 PR 번호를 넣고 우선순위 표의 1순위에 완료를 표시한다. 이 플랜의 상태를 갱신한다
- [ ] 루트 `TODO.md` 의 2차 1번 행에 취소선을 긋고, `집 맥북에서 할 것` 에 **홈 실기기 확인**을 추가한다
  - 워치 저장 직후 홈 스탯 · 이번 주 바 · 최근 기록이 재실행 없이 바뀌는지
  - 펄스 체감
- [ ] 하루치 `CLAUDE.md` 의 구조 절에 `iOSApp/Components/` 를 더하고, 홈 설명을 "임시 잔디"에서 대시보드로 바꾼다
- [ ] 커밋 `📝 하루치 홈 대시보드 완료를 로드맵·TODO 에 반영한다` → PR (`gh pr create`) → CI 통과 확인
