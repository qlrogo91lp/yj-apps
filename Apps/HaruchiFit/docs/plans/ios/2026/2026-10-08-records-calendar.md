# 03a 기록 달력 구현 계획

> **For agentic workers:** `superpowers:executing-plans`로 단계별 실행한다. 별도 사용자 지시 없이 서브에이전트를 생성하지 않는다. 체크박스로 진행 상태를 기록한다.

**상태:** 코드 구현 · 로컬 검증 완료 (2026-10-08). 시뮬레이터 UI/실기기 통합 확인 대기.

**Goal:** 기록 탭에서 월별 농도와 운동 요약을 보고 날짜별 기록을 기존 상세 시트로 연다.

**Architecture:** Foundation 기반 월 빌더와 선택 상태를 Shared/Models에 둔다.
Records ViewModel이 모드·월·선택 날짜와 표시 결과를 소유한다.
SwiftUI LazyVGrid는 값과 콜백만 받아 7열을 그리고 기존 목록·상세·동기화 경로를 재사용한다.

**Tech Stack:** iOS 17+, SwiftUI, Foundation Calendar, SwiftData, Combine, Swift Testing.

**Spec:** [03a 기록 달력 상세 스펙](../../../specs/ios/2026/2026-10-08-records-calendar.md).
실행자는 루트와 앱 CLAUDE.md, 상세 스펙, 이 플랜을 모두 읽는다.

## Global Constraints

- 외부 달력 라이브러리·HealthKit 직접 쿼리·영속 집계 캐시·새 테스트 타깃을 추가하지 않는다.
- Calendar.current로 날짜를 해석하고 startedAt 기준으로 날짜와 월을 나눈다.
- 농도는 GrassAggregator·GrassIntensity.byTime, 색은 HaruchiPalette.grass를 그대로 사용한다.
- 횟수는 레코드 수다. 자정을 넘긴 세션은 시작 날짜에 전체 귀속한다.
- 첫 진입은 현재 월·오늘·달력 모드다. 데이터 갱신으로 상세를 자동으로 열지 않는다.
- 탭한 날 1개면 바로 상세, 2개 이상이면 아래 목록, 0개면 빈 상태다.
- 미래 월 탐색과 미래 날짜 선택을 제한한다. 현재 시각보다 미래에 시작한 기록은 제외한다.
- 모드와 선택은 프로세스 내에서 유지한다. 기록 삭제/이동 때문에 자동으로 날짜를 바꾸지 않는다.
- 수동 기록의 제자리 수정과 부위 편집까지 값 변화로 감지한다.
- 기존 상세의 삭제 후 모델 접근 방지·메모 초안·수동 편집 전환을 유지한다.
- 모든 빌드/테스트는 워크스페이스 기준, 시뮬레이터는 UDID를 지정한다.
- 브랜치·커밋·PR은 사용자 승인 범위 안에서만 수행한다. 검토 전 커밋하지 않는다.

## Review Focus

1. 월말에 한 달 이동할 때 31일 가산으로 두 달 건너뛰지 않는다 — Task 1 상태 테스트.
2. 동일 영속 ID의 날짜·시간 수정도 이전 칸/새 칸/월 요약에 반영된다 — Task 1·3 값 스냅샷 테스트와 UI 확인.
3. 상세 삭제 후 닫힌 시트나 오래된 행이 삭제 모델을 읽지 않는다 — Task 3 삭제 전환 UI 확인.
4. 기록이 1개로 바뀌어도 import/삭제/월 이동만으로 상세가 뜨지 않는다 — Task 1 선택 테스트, Task 3 UI 확인.
5. 큰 글씨·작은 화면에서 월 요약과 날짜별 목록에 접근한다 — Task 2 UI 확인. 독립 List를 ScrollView 안에 넣지 않는다.

## 실행 전 준비와 Git 범위

- [ ] 로컬 변경을 확인한다. 기존 TODO.md의 통계 로컬 확인 변경은 사용자 소유이므로 보존한다.
- [ ] #46 머지 커밋을 포함한 최신 원격 main을 기준으로 삼는다. 현재 계획 작성 체크아웃은 #45까지다.
- [ ] 플랜 승인 시 feat/haruchi-records-calendar 브랜치와 형제 경로 ../yj-apps-worktrees/haruchi-records-calendar의 전용 워크트리 생성을 포함한다. 이미 적절한 워크트리가 있으면 재사용한다.
- [ ] 원본 체크아웃을 강제로 pull/reset하지 않는다. git fetch origin 후 최신 origin/main 기준 워크트리에서 진행한다.
- [ ] 검토 중인 스펙/플랜은 원본에서 보존하고 실행 워크트리에 반영한다. 구현 결과 검토 전 자동 커밋·push·PR 생성은 하지 않는다.

## Task 1 — 월 집계·날짜 선택·값 변경 감지

**Files** (경로는 Apps/HaruchiFit 기준):

- Create: Shared/Models/RecordCalendarDay.swift — 날짜·농도·횟수·시간·오늘/미래·접근성 문구.
- Create: Shared/Models/RecordCalendarMonth.swift — 월 제목·요약·요일·빈칸 포함 cells·선택 날짜 제목·행·빈 상태.
- Create: Shared/Models/RecordCalendarBuilder.swift — 기간 필터, 잔디 재사용, 날짜 배치, 날짜별 행과 월 요약.
- Create: Shared/Models/RecordsCalendarState.swift — 표시 월·선택 날짜와 월 이동/명시적 날짜 탭 규칙.
- Create: Shared/Models/RecordDisplayInput.swift — ID와 표시 입력의 Equatable 값 스냅샷.
- Modify: Shared/Models/RecordListBuilder.swift — rows에 기본값 false인 includeStartTime 옵션 추가. 주 섹션/홈 출력 유지.
- Create: watchosTests/Models/RecordCalendarBuilderTests.swift — 배치·집계·행·빈 상태.
- Create: watchosTests/Models/RecordsCalendarStateTests.swift — 이동·선택·초기 상태.
- Create: watchosTests/Models/RecordDisplayInputTests.swift — 동일 ID 수정과 레코드 교체의 변경 감지.
- Modify: watchosTests/Models/RecordListBuilderTests.swift — 시작 시각 옵션과 기존 출력 보존.

**Interfaces:**

```swift
struct RecordCalendarDay: Identifiable {
    let date: Date
    let level: GrassLevel
    let sessionCount: Int
    let totalSeconds: Int
    let isToday: Bool
    let isFuture: Bool
    let accessibilityLabel: String
    var id: Date { date }
}

struct RecordCalendarMonth {
    let monthStart: Date
    let title: String
    let summary: String
    let weekdays: [String]
    let cells: [RecordCalendarDay?]
    let selectedDayTitle: String
    let selectedRows: [RecordListRow]
    let emptyMessage: String?
    let emptyDescription: String?
    let canMoveNext: Bool
}

// RecordCalendarBuilder의 순수 함수. SwiftUI를 import하지 않는다.
static func month(from records: [WorkoutRecord], displayedMonth: Date,
                  selectedDay: Date, now: Date = Date(),
                  calendar: Calendar = .current,
                  locale: Locale = Locale(identifier: "ko_KR"),
                  intensity: GrassIntensity = .byTime) -> RecordCalendarMonth

// RecordsCalendarState의 API. 월과 날짜는 calendar로 정규화한다.
init(now: Date, calendar: Calendar = .current)
mutating func moveMonth(by offset: Int, records: [WorkoutRecord], now: Date,
                       calendar: Calendar = .current)
mutating func select(day: Date, records: [WorkoutRecord], now: Date,
                     calendar: Calendar = .current) -> WorkoutRecord?
// stored properties: private(set) month: Date, private(set) selectedDay: Date

// 기존 RecordListBuilder API에 추가하는 기본값 있는 인자.
static func rows(for records: [WorkoutRecord], calendar: Calendar = .current,
                 locale: Locale = Locale(identifier: "ko_KR"),
                 includeStartTime: Bool = false) -> [RecordListRow]
```

- [ ] 먼저 날짜·집계 테스트를 만들고 미정의 타입 때문에 실패하는 것을 확인한다. 핵심 테스트 예:

```swift
@MainActor
@Test func foldsTwoSessionsIntoOneDay() throws {
    let context = try GrassFixture.makeContext()
    let first = GrassFixture.record(in: context,
        startedAt: GrassFixture.date(2026, 10, 8, 7), totalSeconds: 1800)
    let second = GrassFixture.record(in: context,
        startedAt: GrassFixture.date(2026, 10, 8, 19), totalSeconds: 3600)
    let day = GrassFixture.seoul.startOfDay(for: first.startedAt)
    let result = RecordCalendarBuilder.month(from: [first, second],
        displayedMonth: day, selectedDay: day,
        now: GrassFixture.date(2026, 10, 9), calendar: GrassFixture.seoul)
    let cell = try #require(result.cells.compactMap { $0 }.first { $0.date == day })
    #expect(cell.sessionCount == 2)
    #expect(cell.level == .peak)
    #expect(result.summary == "2회 · 1.5시간")
    #expect(result.selectedRows.map(\.id) == [second.persistentModelID, first.persistentModelID])
}
```

- [ ] 배치 인자 테스트: 2021년 2월(월요일 시작)은 28일/28칸, 2024년 2월은 29일, 2026년 8월(일요일 시작)은 31일/42칸. 실제 날짜는 중복 없고 요일 라벨 첫 항목은 firstWeekday와 맞는다.
- [ ] 0초, 1799/1800/3600/5400초, 월/연도 경계·미래 시작, 전체 0건/빈 월/빈 날짜, 59분/60분 표기를 테스트한다. 시작 시각 옵션의 형식은 M월 d일 (E) · a h:mm이다.
- [ ] 선택 테스트: init은 오늘, 10월 31일→이전 달은 9월, 빈 과거 월은 1일, 기록 있는 과거 월은 최신 날짜, 현재 월은 오늘, 미래 월 이동은 무시한다. 미래/다른 월의 날짜 탭은 무시하고, 0/2건이면 nil, 1건이면 해당 레코드만 반환한다.
- [ ] RecordDisplayInput은 PersistentIdentifier, startedAt, totalSeconds, totalCalories, bodyParts, ordered segment의 kind/duration을 값으로 갖는다. 같은 ID의 시간·날짜·유형·부위 변경과 같은 값의 다른 ID 교체에서 불일치하는 테스트를 만든다. 메모는 행/농도에 표시하지 않아 감지 값에 포함하지 않는다.
- [ ] 순수 로직을 구현한다. 월 시작을 구한 뒤 월을 더하며 월 범위는 반개구간으로 판정한다.

```swift
let start = calendar.dateInterval(of: .month, for: displayedMonth)!.start
let end = calendar.date(byAdding: .month, value: 1, to: start)!
let visible = records.filter {
    $0.startedAt >= start && $0.startedAt < end && $0.startedAt <= now
}
let folded = GrassAggregator.fold(visible, calendar: calendar)
let daily = Dictionary(uniqueKeysWithValues: folded.map { ($0.day, $0) })
let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
// 날짜 수는 calendar.range(of: .day, in: .month, for: start)로 계산한다.
// 앞뒤는 nil로 채우고 count가 7의 배수가 되도록 끝에 nil을 추가한다.
// 빈 월도 요일과 모든 날짜를 생성한다. 농도는 daily[day]가 없으면 .none이다.
```

- [ ] 행 문자열은 RecordListBuilder.rows의 includeStartTime: true로 기존 칩/부위/kcal를 재사용한다. summary는 홈과 같은 1시간 미만 정수 분, 이상 소수 첫째 자리 시간이다. 월 이동에서는 상세 반환 함수를 호출하지 않는다.
- [ ] 새 스위트 3개와 기존 RecordListBuilderTests를 실행한다. 기대 결과는 모두 PASS다.

```bash
HARUCHI_WATCH_ID=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests \
  -destination "id=$HARUCHI_WATCH_ID" \
  -only-testing:HaruchiFitWatchTests/RecordCalendarBuilderTests \
  -only-testing:HaruchiFitWatchTests/RecordsCalendarStateTests \
  -only-testing:HaruchiFitWatchTests/RecordDisplayInputTests \
  -only-testing:HaruchiFitWatchTests/RecordListBuilderTests test
```

## Task 2 — 값과 콜백으로 구성하는 월 달력 UI

**Files:**

- Create: iOSApp/Features/Records/Calendar/RecordsCalendarView.swift — 하나의 ScrollView로 월/요일/그리드/선택 날짜 행 조합.
- Create: iOSApp/Features/Records/Calendar/Components/RecordMonthHeader.swift — 월 이동·제목·요약.
- Create: iOSApp/Features/Records/Calendar/Components/RecordCalendarGrid.swift — 7열과 요일 라벨.
- Create: iOSApp/Features/Records/Calendar/Components/RecordDayCell.swift — 농도·날짜·오늘/선택 표시·접근성.

**Interfaces:** 각 View의 입력 계약이다.

```swift
RecordsCalendarView(month: RecordCalendarMonth, selectedDay: Date,
                    onPrevious: () -> Void, onNext: () -> Void,
                    onSelectDay: (Date) -> Void,
                    onSelectRecord: (WorkoutRecord) -> Void)
RecordMonthHeader(title: String, summary: String, canMoveNext: Bool,
                  onPrevious: () -> Void, onNext: () -> Void)
RecordCalendarGrid(weekdays: [String], cells: [RecordCalendarDay?],
                   selectedDay: Date, onSelect: (Date) -> Void)
RecordDayCell(day: RecordCalendarDay, isSelected: Bool, onSelect: () -> Void)
```

- [ ] 헤더는 ViewThatFits(in: .horizontal)로 같은 행/두 줄을 전환한다. 이동 버튼은 44pt 이상, 현재 월 다음 버튼은 disabled다.
- [ ] 다음 구조로 그리드를 구현한다. 날짜 규칙을 View에서 다시 계산하지 않는다.

```swift
LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
    ForEach(cells.indices, id: \.self) { index in
        if let day = cells[index] {
            RecordDayCell(day: day, isSelected: day.date == selectedDay) {
                onSelect(day.date)
            }
        } else {
            Color.clear.frame(minHeight: 44).accessibilityHidden(true)
        }
    }
}
```

- [ ] 날짜 칸은 Button이고 배경은 HaruchiPalette.grass(day.level)다. 미래는 opacity 0.3/disabled. 오늘과 선택은 농도 배경을 덮지 않는 다른 테두리로 표시한다. 날짜 글씨는 농도마다 대비를 확인한다.
- [ ] 320pt 폭에서 7×44pt 탭 영역과 열 간격 2pt를 확보하려면 그리드 좌우 여백은 0이어야 한다. 그리드에 고정 16pt 여백을 적용하지 않고 가용 폭에 맞춰 여백을 줄인다. 날짜 Button은 최소 44pt 폭/높이를 갖고 다른 영역의 여백과 독립적으로 배치한다.
- [ ] selectedRows는 일반 VStack/LazyVStack의 Button + RecordRow로 그린다. 내부 List는 만들지 않는다. 카드 배경과 여백을 주고 시작 시각이 포함된 dateTitle은 줄바꿈한다.
- [ ] emptyMessage/emptyDescription으로 전체·월·날짜 빈 상태를 구분한다. 빈 상태에도 스크롤을 유지하며 자식 컴포넌트에 ViewModel을 넘기지 않는다.
- [ ] iOS 빌드로 타입과 타깃 포함을 확인한다. 기존 동기화 루트 아래 파일이므로 pbxproj 직접 편집은 하지 않는다.
- [ ] UI 확인: 320pt 폭, 접근성 글씨 크기, VoiceOver에서 44pt 탭 영역·요일·오늘/선택·미래 선택 불가·날짜 없는 빈 자리 제외를 확인한다. 7열을 유지하고 행 높이를 늘린다. GUI가 없으면 미실시로 기록한다.

## Task 3 — 기록 탭 연결과 편집/삭제 갱신

**Files:**

- Modify: iOSApp/Features/Records/RecordsViewModel.swift — 모드, 달력 상태/월 표시, 기존 주 sections, 이벤트.
- Modify: iOSApp/Features/Records/RecordsView.swift — 항상 보이는 세그먼트, 모드 분기, 값 감지, 시트 연결.
- Modify: watchosTests/Models/RecordCalendarBuilderTests.swift — 제자리 수동 편집으로 다른 월 이동 후 집계.

**Interfaces:**

```swift
// RecordsViewModel 안에 중첩하고 다른 Feature로 전달하지 않는다.
enum DisplayMode: String, CaseIterable { case calendar, list }
// VM stored properties:
@Published var mode: DisplayMode = .calendar
@Published private(set) var calendarState: RecordsCalendarState
@Published private(set) var month: RecordCalendarMonth
@Published private(set) var sections: [RecordListSection] = []
// API:
func rebuild(from records: [WorkoutRecord], now: Date = Date())
func moveMonth(by offset: Int, from records: [WorkoutRecord], now: Date = Date())
func select(day: Date, from records: [WorkoutRecord], now: Date = Date()) -> WorkoutRecord?
```

- [ ] 제자리 수정 테스트를 먼저 추가한다. ID는 유지하면서 startedAt을 10월→9월로 바꾸고 totalSeconds를 1800→5400으로 바꾸면 10월은 0회, 9월은 1회/peak다. 기존 값 스냅샷과 새 값 스냅샷이 다르게 비교된다.
- [ ] VM은 init에서 빈 현재 월을 빌더로 만든다. rebuild는 선택을 바꾸지 않고 월 표시와 주 sections를 재생성한다. moveMonth는 상태의 월 이동 규칙만 실행하며 select만 단일 기록을 반환한다. VM은 Combine/Foundation만 import한다.
- [ ] RecordsView 상단에 pickerStyle(.segmented)의 달력/목록을 항상 표시하고 아래에서 달력과 기존 List/빈 상태를 분기한다. refreshable은 각 스크롤 면에서 기존 sync를 호출한다.
- [ ] 감지를 값 스냅샷으로 바꾸고 기존 onAppear/scenePhase/시트 onFinish를 유지한다.

```swift
private var displayInputs: [RecordDisplayInput] {
    records.map(RecordDisplayInput.init(record:))
}
// View chain:
.onChange(of: displayInputs) { _, _ in viewModel.rebuild(from: records) }
// Calendar callback:
onSelectDay: { day in
    if let record = viewModel.select(day: day, from: records) {
        selected = record
    }
}
// 명시적인 행 탭도 selected = row.record로 연결한다.
// rebuild/moveMonth 안에서 selected를 설정하지 않는다.
```

- [ ] #46의 recordDetailSheet를 그대로 사용하고 수동 편집 후 onFinish에서 월/주 목록을 재생성한다. 삭제 시 기존 modifier가 수행하는 시트 종료 후 삭제와 @Query 변경을 기다리고, 삭제 모델이 든 입력을 즉시 재생성하지 않는다.
- [ ] 기존 confirmationDialog와 수동/비수동 삭제 문구·실패 alerts·주 목록 스와이프 삭제를 보존한다.
- [ ] UI 확인: 단일 날짜 직접 상세, 여러 날짜의 모든 기록/행 탭, 상세 닫기/삭제/수동 편집, 월 이동/탭 왕복, 다른 탭 추가/편집, 빈 상태 새로고침, 동기화 실패의 선택 유지. 기록 2→1 갱신만으로 상세가 뜨지 않는지 확인한다.
- [ ] 저장 실패를 UI에서 주입할 수 없으면 기존 save/rollback·alert 경로를 코드로 검토하고 실기기 확인 항목에 남긴다. 실패 결과를 확인하지 않고 테스트 통과로 보고하지 않는다.

## Task 4 — 전체 검증과 문서

**Files:**

- Modify: Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md — 03a에서 상세 스펙 링크.
- Modify: Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md — #8 구현/검증 상태.
- Modify: Apps/HaruchiFit/CLAUDE.md — 기록 탭 모드와 Calendar 폴더 반영.
- Modify: Apps/HaruchiFit/docs/plans/ios/2026/2026-10-08-records-calendar.md — 실행 결과와 미실시 UI/실기기 확인.
- Modify: 루트 TODO.md — #8 상태와 스펙/플랜 링크. 기존 사용자 변경 보존.

- [ ] 워크스페이스의 워치 전체 테스트와 iOS 빌드를 실행한다. Shared 새 모델이 워치에 포함되므로 전체 테스트를 수행한다.

```bash
HARUCHI_WATCH_ID=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
HARUCHI_IOS_ID=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests \
  -destination "id=$HARUCHI_WATCH_ID" test
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit \
  -destination "id=$HARUCHI_IOS_ID" build
```

- [ ] 앱 폴더에서 swiftlint lint --quiet, swiftformat --lint .를 실행하고 루트에서 git diff --check를 실행한다. 변경 때문에 실패한 항목은 수정하고 필요한 검증을 다시 실행한다.
- [ ] 스펙 9절의 UI 확인 결과를 기록한다. GUI/실기기가 없는 항목을 실시한 것으로 쓰지 않는다. 실기기 통합 확인은 다른 기능과 묶을 수 있다.
- [ ] 새 파일/수정 파일을 검토하고 pbxproj·YJKit·워치 세션 코드에 의도하지 않은 변경이 없는지 확인한다.
- [ ] 코드와 로컬 검증 결과를 사용자에게 제시한다. 커밋 메시지 제안은 ✨ 하루치 기록 탭에 월 달력을 추가한다. 커밋·push·PR 생성은 검토 결과와 기존 승인 범위를 확인한 후 진행한다.

## 완료 조건

승인 스펙의 모든 조작이 구현되고 순수 규칙 테스트·워치 전체 테스트·iOS 빌드·lint/format이 통과한다.
기존 기록 목록·홈의 RecordRow·상세 삭제/수동 편집이 정상 동작한다.
UI/실기기 확인의 실시 상태를 문서에 남기고 완료 보고에서 미실시 항목을 밝힌다.

## 실행 결과

- `feat/haruchi-records-calendar` 전용 워크트리에서 #46이 포함된 `origin/main` 기준으로 구현했다.
- 순수 모델 테스트는 월 그리드 배치, 같은 날 다중 기록 합산, 미래 기록 제외, 월 이동의 선택 날짜,
  단일 기록 상세 진입, 제자리 수동 기록 편집 감지, 시작 시각 표시를 검증한다.
- `HaruchiFitWatchTests` 전체 테스트와 `HaruchiFit` iOS 시뮬레이터 빌드, `swiftlint lint --quiet`,
  `swiftformat --lint .`, `git diff --check`를 통과했다.
- 이 환경에는 Simulator GUI가 없어 320pt 폭·Dynamic Type·VoiceOver·시트 전환·삭제와
  수동 편집의 실제 화면 동작은 확인하지 못했다. 실기기 통합 확인 때 함께 확인한다.
