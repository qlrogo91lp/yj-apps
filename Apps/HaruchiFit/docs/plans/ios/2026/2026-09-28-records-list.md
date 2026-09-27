# 하루치 핏 Phase 3 #4 — 03b 기록 목록 구현 플랜

작성일: 2026-09-28
상태: **구현 완료 — 사용자 검토·커밋 전**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 탭 셸의 빈 기록 탭을 주 단위 섹션의 최신순 목록으로 채우고, 스와이프 삭제와 앱 전역 실패 알림을 붙인다.

**Architecture:** 섹션·행 표시 규칙은 `Shared/Models/RecordListBuilder` 에 순수 함수로 둔다. iOS 테스트 타깃이 없어서
워치 테스트(`HaruchiFitWatchTests`)가 `@testable import` 로 검증할 수 있는 자리는 여기뿐이다 — `GrassAggregator` 와
같은 이유다. `RecordsViewModel` 은 `GrassViewModel` 처럼 `@Query` 결과를 받아 빌더를 부르는 배선만 맡는다.
실패 알림은 `AppAlertCenter` 하나로 모아 `ContentView` 가 띄운다.

**Tech Stack:** SwiftUI · SwiftData `@Query` · Swift Testing (watchOS 테스트 타깃)

**Spec:** [제품 스펙 03b절](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) ·
[로드맵 Phase 3 #4](../../../specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md)

## Global Constraints

- iOS 17 / watchOS 10 최소 버전. 새 API는 이 범위 안에서만 쓴다
- 기록 탭에는 **집계도 차트도 없다** (스펙 03b). 섹션 헤더에 주간 합계를 넣지 않는다
- 전환 횟수를 표시하지 않는다 (D7). 칩은 구간 종류별 합계만 보여준다
- 색은 `HaruchiPalette` 토큰만 쓴다 — 근력 `accent`, 유산소 `cardio`
- 문구는 한국어 하드코딩. 이 앱은 String Catalog 를 쓰지 않는다 (`InfoPlist.xcstrings` 만 있다)
- iOS 앱은 **HealthKit 읽기 전용**을 유지한다. `toShare` 권한을 추가하지 않는다
- `Packages/YJKit/`, `WatchApp/`, `.xcodeproj` 는 수정하지 않는다

---

## 목표와 범위

스펙 03b절의 네 가지 중 셋을 이번에 한다.

| 스펙 항목 | 이번 작업 | 비고 |
|---|---|---|
| 최신순, 주 단위 섹션 (`이번 주` / `지난 주` / …) | ✅ | 그 전 주는 날짜 범위로 부른다 (아래 규칙) |
| 각 행: 날짜 `8월 22일 (토)` + 세그먼트·부위 칩 + 우측 kcal | ✅ 부위 칩 제외 | 부위 필드가 모델에 없다 — #5 에서 필드와 칩을 함께 붙인다 |
| 스와이프 삭제 | ✅ | 앱 저장소에서만 지운다 (2026-09-28 결정, 아래) |
| 아이템 탭 → 기록 상세 하프 시트 | ❌ | 시트가 #5 다. 작동하지 않는 탭을 미리 노출하지 않는다 (탭 셸 플랜과 같은 원칙) |

추가로 `iOSApp.save(_:)` 와 `WorkoutSyncCoordinator.sync()` 에 *"실패 알림은 기록 탭 플랜에서 붙인다"* 고
미뤄 둔 자리를 이번에 채운다 (2026-09-28 결정).

> ⚠️ **로드맵 #5 비고의 "모델엔 필드가 이미 있다" 는 절반만 맞다.** `WorkoutRecord` 에는 `memo` 만 있고
> 부위 필드는 없다. 이번 작업 끝에 로드맵 비고를 고친다 (Task 4).

### 결정 — 삭제는 앱 저장소에서만 (2026-09-28)

스와이프 삭제는 SwiftData 레코드(구간 포함, cascade)만 지우고 건강 앱의 워크아웃은 남긴다.

- iOS 앱이 HealthKit 읽기 전용이라는 현재 전제(`HealthKitWorkoutImporter` 주석)를 깨지 않는다
- 다시 가져오지 않는다 — 앵커드 쿼리의 앵커가 이미 그 워크아웃을 지나갔다
- **다시 나타나는 경로가 둘 남는다.** 받아들인다:
  1. 앵커가 사라질 때(재설치 등) — 전체 재import 로 `healthKitImport` 레코드가 되돌아온다
  2. 워치가 같은 기록을 재전송할 때 — `save(_:)` 가 upsert 하므로 새로 생긴다. `transferUserInfo` 는 배달이 끝나면 재전송하지 않아 실제로는 드물다
- 건강 앱과의 삭제 동기화(양방향)는 TODO 의 YJKit `HKDeletedObject` 항목에서 3개 앱이 함께 정한다.
  Ralli #10 은 반대 방향(앱에서 지우면 건강 앱도 지운다)으로 갔다 — 그 항목에서 맞출지 정한다

확인 다이얼로그 문구가 이 동작을 알린다: *"건강 앱의 운동 기록은 그대로 남아요."*

## 화면·표시 규칙

### 섹션

- 주의 경계는 `calendar.dateInterval(of: .weekOfYear, for:)` — 홈 잔디 그리드(`HomeView.gridDays`)와 같은 달력 규칙이다.
  한국 로케일에서는 **일요일 시작**이다
- 레코드가 속하는 주는 **시작 시각** 기준 (`GrassAggregator` 의 하루 경계 규칙과 같다)
- 섹션은 최신 주가 위, 섹션 안의 행도 최신이 위
- 제목:

  | 경우 | 제목 | 예 |
  |---|---|---|
  | `now` 가 든 주 | `이번 주` | |
  | 그 직전 주 | `지난 주` | |
  | 그 전, 시작일이 올해 | `M월 d일 – M월 d일` | `9월 13일 – 9월 19일` |
  | 시작일이 다른 해 | 시작에 연도를 붙인다 | `2025년 12월 21일 – 12월 27일` |
  | 주가 해를 넘는다 | 끝에도 연도를 붙인다 | `2025년 12월 28일 – 2026년 1월 3일` |

  "올해" 는 `now` 의 연도다. 레코드가 없는 주는 섹션을 만들지 않는다.

### 행

- 날짜: `M월 d일 (E)` — `9월 19일 (토)`. 로케일은 `ko_KR` 로 고정한다 (앱 문구가 전부 한국어다)
- 칩: 구간 종류별 합계를 **처음 나온 순서**로. `근력 54분` · `유산소 18분`. 분은 내림.
  **1분 미만인 종류는 칩을 만들지 않는다** — `유산소 0분` 은 정보가 아니다
- kcal: `totalCalories` 를 반올림해 `412 kcal`. 없으면 표시하지 않는다.
  `totalCalories` 를 쓰는 이유 — 잔디의 칼로리 기준(`GrassAggregator`)이 이 값이라 두 화면의 숫자가 갈리지 않는다
- 행을 탭해도 아무 일도 없다 (#5)

### 빈 상태 · 새로고침 · 알림

- 레코드가 없으면 `ContentUnavailableView` — *"아직 기록이 없어요"* / *"워치에서 운동을 저장하면 여기에 쌓여요."*
- 목록과 빈 상태 모두 당겨서 새로고침이 `sync.sync()` 를 부른다 (홈과 같다)
- 알림은 앱 루트(`ContentView`)가 띄운다. 워치 저장·동기화 실패는 어느 탭에 있든 생길 수 있다.
  떠 있는 알림이 있으면 새 알림이 덮지 않는다

| 알림 | 제목 | 본문 |
|---|---|---|
| `saveFailed` | 워치 기록을 저장하지 못했어요 | 다음 동기화 때 건강 앱에서 다시 가져와요. 근력·유산소 구분은 남지 않을 수 있어요. |
| `syncFailed` | 건강 앱 기록을 가져오지 못했어요 | 목록을 당겨서 다시 시도해 주세요. |
| `deleteFailed` | 기록을 삭제하지 못했어요 | 잠시 후 다시 시도해 주세요. |

`saveFailed` 본문 근거 — 워치 워크아웃은 건강 앱에 이미 저장돼 있어 다음 import 가 `healthKitImport`
레코드(구간 1개)로 가져온다 (`WorkoutRecord+Import`).

## 파일별 작업

| 파일 | 변경 | Task |
|---|---|---|
| `Apps/HaruchiFit/Shared/Models/RecordListSection.swift` | 생성 | 1 |
| `Apps/HaruchiFit/Shared/Models/RecordListRow.swift` | 생성 | 1 |
| `Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift` | 생성 | 1 |
| `Apps/HaruchiFit/watchosTests/Models/RecordListBuilderTests.swift` | 생성 | 1 |
| `Apps/HaruchiFit/iOSApp/AppAlert.swift` | 생성 | 2 |
| `Apps/HaruchiFit/iOSApp/AppAlertCenter.swift` | 생성 | 2 |
| `Apps/HaruchiFit/iOSApp/Services/WorkoutSyncCoordinator.swift` | 수정 | 2 |
| `Apps/HaruchiFit/iOSApp/iOSApp.swift` | 수정 | 2 |
| `Apps/HaruchiFit/iOSApp/ContentView.swift` | 수정 | 2 |
| `Apps/HaruchiFit/iOSApp/Features/Records/RecordsViewModel.swift` | 생성 | 3 |
| `Apps/HaruchiFit/iOSApp/Features/Records/Components/RecordRow.swift` | 생성 | 3 |
| `Apps/HaruchiFit/iOSApp/Features/Records/RecordsView.swift` | 수정 | 3 |
| `Apps/HaruchiFit/CLAUDE.md` | 수정 | 4 |
| `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md` | 수정 | 4 |
| `TODO.md` | 수정 | 4 |

- `Shared/` 는 iOS 앱·워치 앱 두 타깃에 붙는 동기화 폴더라 새 파일이 워치 테스트에서도 보인다. 워치 앱은 이 타입들을
  쓰지 않지만 컴파일만 된다 — `GrassAggregator` 도 같은 상태다
- `RecordRow` 는 홈 대시보드(#7)의 "최근 기록 2개" 가 다시 쓸 예정이다. 그때 앱 루트 `Components/` 로 올린다.
  지금은 쓰는 곳이 하나라 `Features/Records/Components/` 에 둔다
- 삭제는 `@Environment(\.modelContext)`(컨테이너의 main context)에서 한다. `@Query` 가 준 객체가 그 컨텍스트
  소속이기 때문이다. 워치 저장·import 가 쓰는 쓰기 컨텍스트와 다르지만, 그쪽은 삽입과 uuid 조회만 하고 조회는 저장소를
  다시 읽으므로 지운 레코드를 되살리지 않는다

---

## Task 0: 작업 트리

- [x] **Step 1: 워크트리와 브랜치를 만든다** (루트 `CLAUDE.md` 워크트리 규약 — 형제 폴더)

```bash
git -C /Users/yj/Workspace/Projects/yj-apps worktree add \
  ../yj-apps-worktrees/haruchi-records-list -b feat/haruchi-records-list main
```

이후 모든 명령은 `../yj-apps-worktrees/haruchi-records-list` 루트에서 실행한다.

- [x] **Step 2: 기준 상태를 확인한다**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
```

Expected: `** TEST SUCCEEDED **`. 실패하면 이번 변경 전의 문제이므로 멈추고 보고한다.

---

## Task 1: 섹션·행 빌더 (TDD)

**Files:**
- Create: `Apps/HaruchiFit/Shared/Models/RecordListSection.swift`
- Create: `Apps/HaruchiFit/Shared/Models/RecordListRow.swift`
- Create: `Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift`
- Test: `Apps/HaruchiFit/watchosTests/Models/RecordListBuilderTests.swift`

**Interfaces:**
- Consumes: `WorkoutRecord.startedAt` · `.orderedSegments` · `.totalCalories`, `SegmentKind.title`, 테스트 픽스처 `GrassFixture.makeContext()` · `.record(in:startedAt:totalSeconds:totalCalories:segments:)` · `.seoul` · `.date(_:_:_:_:_:)`
- Produces:
  - `struct RecordListSection: Identifiable { let weekStart: Date; let title: String; let rows: [RecordListRow]; var id: Date }`
  - `struct RecordListRow: Identifiable { let record: WorkoutRecord; let dateTitle: String; let chips: [Chip]; let caloriesText: String?; var id: PersistentIdentifier }`
  - `struct RecordListRow.Chip: Hashable { let kind: SegmentKind; let minutes: Int; var text: String }`
  - `static func RecordListBuilder.sections(from: [WorkoutRecord], now: Date, calendar: Calendar, locale: Locale) -> [RecordListSection]`

- [x] **Step 1: 실패하는 테스트를 쓴다**

`Apps/HaruchiFit/watchosTests/Models/RecordListBuilderTests.swift`:

```swift
import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

/// 기록 목록의 주 섹션과 행 표기 (제품 스펙 03b).
///
/// **주의 첫 요일을 일요일로 고정한다.** 식별자로 만든 달력의 `firstWeekday` 는 기계 로케일을 따라가서,
/// 고정하지 않으면 주 경계 테스트가 기계마다 다른 답을 낸다.
@MainActor
struct RecordListBuilderTests {
    private static let calendar: Calendar = {
        var calendar = GrassFixture.seoul
        calendar.firstWeekday = 1
        return calendar
    }()

    /// 2026-09-28 은 월요일이다. 이번 주 = 9/27(일) – 10/3(토).
    private let now = GrassFixture.date(2026, 9, 28)

    private func sections(_ context: ModelContext, now: Date? = nil) throws -> [RecordListSection] {
        try RecordListBuilder.sections(from: context.fetch(FetchDescriptor<WorkoutRecord>()),
                                       now: now ?? self.now,
                                       calendar: Self.calendar,
                                       locale: Locale(identifier: "ko_KR"))
    }

    @Test("레코드가 없으면 섹션도 없다")
    func emptyRecordsGiveNoSections() throws {
        let context = try GrassFixture.makeContext()
        #expect(try sections(context).isEmpty)
    }

    @Test("이번 주와 지난 주는 이름으로, 그 전은 날짜 범위로 부른다")
    func weekTitles() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 14), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 26), totalSeconds: 600)

        #expect(try sections(context).map(\.title) == ["이번 주", "지난 주", "9월 13일 – 9월 19일"])
    }

    @Test("주의 경계는 일요일 0시다")
    func weekStartsOnSunday() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 26, 23, 30), totalSeconds: 600) // 토
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 27, 0, 30), totalSeconds: 600) // 일

        let result = try sections(context)
        #expect(result.map(\.title) == ["이번 주", "지난 주"])
        #expect(result.map { $0.rows.map(\.dateTitle) } == [["9월 27일 (일)"], ["9월 26일 (토)"]])
    }

    @Test("섹션 안의 행은 최신이 위다")
    func rowsAreNewestFirst() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 27, 19), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 7), totalSeconds: 600)

        let rows = try #require(try sections(context).first).rows
        #expect(rows.map(\.dateTitle) == ["9월 28일 (월)", "9월 27일 (일)"])
    }

    @Test("시작일이 다른 해면 연도를 붙이고, 해를 넘는 주는 끝에도 붙인다")
    func otherYearTitlesCarryYear() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2025, 12, 22), totalSeconds: 600)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2025, 12, 30), totalSeconds: 600)

        // 2026-01-20(화) 기준 — 두 주 모두 "지난 주" 보다 앞이다
        let titles = try sections(context, now: GrassFixture.date(2026, 1, 20)).map(\.title)
        #expect(titles == ["2025년 12월 28일 – 2026년 1월 3일", "2025년 12월 21일 – 12월 27일"])
    }

    @Test("칩은 종류별 합계를 처음 나온 순서로 보여준다")
    func chipsSumByKindInFirstAppearanceOrder() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context,
                            startedAt: GrassFixture.date(2026, 9, 28),
                            totalSeconds: 4320,
                            segments: [(.strength, 0, 1800), (.cardio, 1800, 1080), (.strength, 2880, 1440)])

        let row = try #require(try sections(context).first?.rows.first)
        #expect(row.chips.map(\.text) == ["근력 54분", "유산소 18분"])
    }

    @Test("1분 미만인 종류는 칩을 만들지 않는다")
    func subMinuteKindHasNoChip() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context,
                            startedAt: GrassFixture.date(2026, 9, 28),
                            totalSeconds: 3040,
                            segments: [(.strength, 0, 3000), (.cardio, 3000, 40)])

        let row = try #require(try sections(context).first?.rows.first)
        #expect(row.chips.map(\.text) == ["근력 50분"])
    }

    @Test("kcal 은 반올림해 붙이고, 값이 없으면 비운다")
    func caloriesText() throws {
        let context = try GrassFixture.makeContext()
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 7),
                            totalSeconds: 600, totalCalories: 412.6)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 6),
                            totalSeconds: 600, totalCalories: nil)

        let rows = try #require(try sections(context).first).rows
        #expect(rows.map(\.caloriesText) == ["413 kcal", nil])
    }
}
```

- [x] **Step 2: 테스트가 실패하는지 확인한다**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" \
  test -only-testing:HaruchiFitWatchTests/RecordListBuilderTests
```

Expected: 컴파일 실패 — `cannot find 'RecordListBuilder' in scope`

- [x] **Step 3: 모델 두 개를 만든다**

`Apps/HaruchiFit/Shared/Models/RecordListSection.swift`:

```swift
import Foundation

/// 기록 목록의 한 주. 레코드가 없는 주는 만들지 않는다.
struct RecordListSection: Identifiable {
    /// 그 주 첫날 0시. 섹션의 정렬 키이자 식별자다.
    let weekStart: Date
    let title: String
    let rows: [RecordListRow]

    var id: Date { weekStart }
}
```

`Apps/HaruchiFit/Shared/Models/RecordListRow.swift`:

```swift
import Foundation
import SwiftData

/// 기록 목록의 한 행. 화면이 그대로 찍을 문자열까지 여기서 끝낸다 — View 에 규칙을 두면
/// iOS 테스트 타깃이 없어 아무도 검증하지 못한다.
struct RecordListRow: Identifiable {
    /// 삭제가 이 객체를 넘긴다.
    let record: WorkoutRecord
    let dateTitle: String
    let chips: [Chip]
    /// 칼로리 값이 없는 기록은 nil — 화면이 자리를 비운다.
    let caloriesText: String?

    var id: PersistentIdentifier { record.persistentModelID }

    /// 구간 종류 하나의 합계. 전환 횟수는 담지 않는다 (D7).
    struct Chip: Hashable {
        let kind: SegmentKind
        let minutes: Int

        var text: String { "\(kind.title) \(minutes)분" }
    }
}
```

- [x] **Step 4: 빌더를 만든다**

`Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift`:

```swift
import Foundation

/// 레코드를 **주 단위 섹션**으로 나누고 행 표기를 만든다 (제품 스펙 03b).
///
/// 주의 경계는 `calendar` 의 `.weekOfYear` 를 따른다 — 홈 잔디 그리드와 같은 규칙이다.
/// 레코드가 속하는 주는 **시작 시각** 기준이다 (`GrassAggregator` 의 하루 경계와 같다).
enum RecordListBuilder {
    static func sections(from records: [WorkoutRecord],
                         now: Date = Date(),
                         calendar: Calendar = .current,
                         locale: Locale = Locale(identifier: "ko_KR")) -> [RecordListSection]
    {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)
        let currentYear = calendar.component(.year, from: now)
        let rowFormatter = formatter("M월 d일 (E)", calendar: calendar, locale: locale)

        var buckets: [Date: [WorkoutRecord]] = [:]
        for record in records {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: record.startedAt)?.start else { continue }
            buckets[week, default: []].append(record)
        }

        return buckets.keys.sorted(by: >).map { week in
            let title: String = if week == thisWeek {
                "이번 주"
            } else if week == lastWeek {
                "지난 주"
            } else {
                rangeTitle(week: week, currentYear: currentYear, calendar: calendar, locale: locale)
            }
            let rows = (buckets[week] ?? [])
                .sorted { $0.startedAt > $1.startedAt }
                .map { row(for: $0, formatter: rowFormatter) }
            return RecordListSection(weekStart: week, title: title, rows: rows)
        }
    }

    /// `9월 13일 – 9월 19일`. 시작일이 올해가 아니면 연도를 붙이고, 해를 넘는 주는 끝에도 붙인다.
    private static func rangeTitle(week: Date, currentYear: Int,
                                   calendar: Calendar, locale: Locale) -> String
    {
        let end = calendar.date(byAdding: .day, value: 6, to: week) ?? week
        let startYear = calendar.component(.year, from: week)
        let endYear = calendar.component(.year, from: end)
        let start = formatter(startYear == currentYear ? "M월 d일" : "yyyy년 M월 d일",
                              calendar: calendar, locale: locale).string(from: week)
        let finish = formatter(endYear == startYear ? "M월 d일" : "yyyy년 M월 d일",
                               calendar: calendar, locale: locale).string(from: end)
        return "\(start) – \(finish)"
    }

    private static func row(for record: WorkoutRecord, formatter: DateFormatter) -> RecordListRow {
        var order: [SegmentKind] = []
        var seconds: [SegmentKind: Int] = [:]
        for segment in record.orderedSegments {
            if seconds[segment.kind] == nil { order.append(segment.kind) }
            seconds[segment.kind, default: 0] += segment.durationSeconds
        }
        // 1분 미만은 `유산소 0분` 이 되어 정보가 아니다
        let chips = order.compactMap { kind -> RecordListRow.Chip? in
            let minutes = (seconds[kind] ?? 0) / 60
            return minutes > 0 ? RecordListRow.Chip(kind: kind, minutes: minutes) : nil
        }
        // 잔디 칼로리 기준(GrassAggregator)과 같은 값을 쓴다
        let calories = record.totalCalories.map { "\(Int($0.rounded())) kcal" }
        return RecordListRow(record: record,
                             dateTitle: formatter.string(from: record.startedAt),
                             chips: chips,
                             caloriesText: calories)
    }

    private static func formatter(_ format: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }
}
```

- [x] **Step 5: 테스트가 통과하는지 확인한다**

Step 2 명령을 다시 실행한다. Expected: `RecordListBuilderTests` 8개 통과, `** TEST SUCCEEDED **`

- [x] **Step 6: 전체 워치 테스트로 회귀를 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
```

Expected: `** TEST SUCCEEDED **`

- [x] **Step 7: 커밋**

```bash
git add Apps/HaruchiFit/Shared/Models/RecordListSection.swift \
        Apps/HaruchiFit/Shared/Models/RecordListRow.swift \
        Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift \
        Apps/HaruchiFit/watchosTests/Models/RecordListBuilderTests.swift
git commit -m "✨ 하루치 기록 목록의 주 섹션·행 표기 규칙을 추가한다"
```

---

## Task 2: 앱 전역 실패 알림

**Files:**
- Create: `Apps/HaruchiFit/iOSApp/AppAlert.swift`
- Create: `Apps/HaruchiFit/iOSApp/AppAlertCenter.swift`
- Modify: `Apps/HaruchiFit/iOSApp/Services/WorkoutSyncCoordinator.swift:17-24, 41-44`
- Modify: `Apps/HaruchiFit/iOSApp/iOSApp.swift:12-26, 30-34, 67-70`
- Modify: `Apps/HaruchiFit/iOSApp/ContentView.swift`

**Interfaces:**
- Produces:
  - `enum AppAlert: String, Identifiable { case saveFailed, syncFailed, deleteFailed; var title: String; var message: String }`
  - `@MainActor final class AppAlertCenter: ObservableObject { @Published var current: AppAlert?; func report(_ alert: AppAlert) }`
  - `WorkoutSyncCoordinator.init(importer:anchors:context:alerts:)` — `alerts: AppAlertCenter` 가 필수 인자로 붙는다
  - 환경 객체 `AppAlertCenter` 가 `ContentView` 아래 전체에 주입된다 (Task 3 의 `RecordsView` 가 읽는다)

UI 배선이라 단위 테스트가 없다 (iOS 테스트 타깃 없음). 빌드와 Task 3 Step 6 의 시뮬레이터 확인이 검증이다.

- [x] **Step 1: 알림 종류를 만든다**

`Apps/HaruchiFit/iOSApp/AppAlert.swift`:

```swift
import Foundation

/// 사용자에게 알리는 실패. 어느 탭에 있든 생길 수 있어 앱 루트가 띄운다.
enum AppAlert: String, Identifiable {
    case saveFailed
    case syncFailed
    case deleteFailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveFailed: "워치 기록을 저장하지 못했어요"
        case .syncFailed: "건강 앱 기록을 가져오지 못했어요"
        case .deleteFailed: "기록을 삭제하지 못했어요"
        }
    }

    var message: String {
        switch self {
        // 워치 워크아웃은 건강 앱에 이미 있어 다음 import 가 구간 1개짜리 레코드로 가져온다
        case .saveFailed: "다음 동기화 때 건강 앱에서 다시 가져와요. 근력·유산소 구분은 남지 않을 수 있어요."
        case .syncFailed: "목록을 당겨서 다시 시도해 주세요."
        case .deleteFailed: "잠시 후 다시 시도해 주세요."
        }
    }
}
```

- [x] **Step 2: 알림 센터를 만든다**

`Apps/HaruchiFit/iOSApp/AppAlertCenter.swift`:

```swift
import Combine
import Foundation

/// 실패를 한 곳에 모은다. 워치 저장·동기화·삭제가 각자 알림을 띄우면 겹쳐 뜬다.
@MainActor
final class AppAlertCenter: ObservableObject {
    @Published var current: AppAlert?

    /// **떠 있는 알림을 덮지 않는다** — 연달아 실패해도 한 장만 보인다.
    func report(_ alert: AppAlert) {
        guard current == nil else { return }
        current = alert
    }
}
```

- [x] **Step 3: 동기화 코디네이터가 실패를 알린다**

`WorkoutSyncCoordinator.swift` — 프로퍼티와 `init` 을 바꾼다:

```swift
    private let importer: HealthKitWorkoutImporter
    private let anchors: WorkoutQueryAnchorStore
    private let context: ModelContext
    private let alerts: AppAlertCenter

    init(importer: HealthKitWorkoutImporter = HealthKitWorkoutImporter(),
         anchors: WorkoutQueryAnchorStore = WorkoutQueryAnchorStore(),
         context: ModelContext,
         alerts: AppAlertCenter)
    {
        self.importer = importer
        self.anchors = anchors
        self.context = context
        self.alerts = alerts
    }
```

`sync()` 의 `catch` 를 바꾼다 (미뤄 둔 자리라는 주석을 지운다):

```swift
        } catch {
            print("[HaruchiFit] HealthKit 동기화 실패 — \(error)")
            alerts.report(.syncFailed)
        }
```

- [x] **Step 4: 앱 루트가 센터를 소유하고 저장 실패를 알린다**

`iOSApp.swift` — 프로퍼티에 추가:

```swift
    @StateObject private var alerts: AppAlertCenter
```

`init()` 의 `_sync` 줄을 바꾼다:

```swift
        let alerts = AppAlertCenter()
        _alerts = StateObject(wrappedValue: alerts)
        _sync = StateObject(wrappedValue: WorkoutSyncCoordinator(context: context, alerts: alerts))
```

`body` 의 `.environmentObject(sync)` 아래에 추가:

```swift
                .environmentObject(alerts)
```

`save(_:)` 의 `catch` 를 바꾼다 (미뤄 둔 자리라는 주석을 지운다):

```swift
        } catch {
            print("[HaruchiFit] 워크아웃 저장 실패 — \(error)")
            alerts.report(.saveFailed)
        }
```

- [x] **Step 5: `ContentView` 가 알림을 띄운다**

`ContentView.swift` 전체:

```swift
import SwiftData
import SwiftUI

/// 세 탭의 공통 셸. 각 화면이 자신의 내비게이션 상태를 소유한다.
/// 실패 알림은 어느 탭에서든 생길 수 있어 여기서 띄운다.
struct ContentView: View {
    @EnvironmentObject private var alerts: AppAlertCenter

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("홈", systemImage: "house.fill") }

            RecordsView()
                .tabItem { Label("기록", systemImage: "list.bullet.rectangle") }

            StatisticsView()
                .tabItem { Label("통계", systemImage: "chart.bar.fill") }
        }
        .tint(HaruchiPalette.accent)
        .toolbarBackground(HaruchiPalette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .alert(alerts.current?.title ?? "",
               isPresented: Binding(get: { alerts.current != nil },
                                    set: { if !$0 { alerts.current = nil } }),
               presenting: alerts.current)
        { _ in
            Button("확인", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}

#Preview {
    let container = ContentPreview.container
    let alerts = AppAlertCenter()
    ContentView()
        .modelContainer(container)
        .environmentObject(WorkoutSyncCoordinator(context: ModelContext(container), alerts: alerts))
        .environmentObject(alerts)
        .preferredColorScheme(.dark)
}

private enum ContentPreview {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: WorkoutRecord.self, Segment.self,
                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("미리보기 컨테이너를 만들지 못했다 — \(error)")
        }
    }()
}
```

- [x] **Step 6: iOS 빌드**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
```

Expected: `** BUILD SUCCEEDED **`. `WorkoutSyncCoordinator(` 를 부르는 곳이 `iOSApp.swift` 와 프리뷰 외에 더 있으면
컴파일 에러로 드러난다 — `grep -rn "WorkoutSyncCoordinator(" Apps/HaruchiFit` 로 둘뿐인지 확인한다.

- [x] **Step 7: 커밋**

```bash
git add Apps/HaruchiFit/iOSApp/AppAlert.swift Apps/HaruchiFit/iOSApp/AppAlertCenter.swift \
        Apps/HaruchiFit/iOSApp/Services/WorkoutSyncCoordinator.swift \
        Apps/HaruchiFit/iOSApp/iOSApp.swift Apps/HaruchiFit/iOSApp/ContentView.swift
git commit -m "✨ 하루치 워치 저장·동기화 실패를 알림으로 보여준다"
```

---

## Task 3: 기록 탭 목록과 스와이프 삭제

**Files:**
- Create: `Apps/HaruchiFit/iOSApp/Features/Records/RecordsViewModel.swift`
- Create: `Apps/HaruchiFit/iOSApp/Features/Records/Components/RecordRow.swift`
- Modify: `Apps/HaruchiFit/iOSApp/Features/Records/RecordsView.swift` (전체 교체)

**Interfaces:**
- Consumes: Task 1 의 `RecordListBuilder.sections(from:now:calendar:locale:)` · `RecordListSection` · `RecordListRow` · `RecordListRow.Chip`,
  Task 2 의 환경 객체 `AppAlertCenter.report(.deleteFailed)`, 기존 환경 객체 `WorkoutSyncCoordinator.sync()`
- Produces:
  - `@MainActor final class RecordsViewModel: ObservableObject { @Published private(set) var sections: [RecordListSection]; func rebuild(from: [WorkoutRecord]); func delete(_: WorkoutRecord, in: ModelContext) -> Bool }`
  - `struct RecordRow: View { let row: RecordListRow }` — #7 홈 최근 기록이 재사용한다

- [x] **Step 1: 뷰모델을 만든다**

`Apps/HaruchiFit/iOSApp/Features/Records/RecordsViewModel.swift`:

```swift
import Combine
import Foundation
import SwiftData

/// 기록 탭의 배선. **표시 규칙은 `RecordListBuilder` 에 있다** — 이 자리는 iOS 테스트 타깃이
/// 없어 유닛 테스트가 닿지 않는다 (`GrassViewModel` 과 같은 이유).
@MainActor
final class RecordsViewModel: ObservableObject {
    @Published private(set) var sections: [RecordListSection] = []

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// View 가 `@Query` 로 읽은 결과를 밀어넣는다. `이번 주` 는 부른 시각 기준이다.
    func rebuild(from records: [WorkoutRecord]) {
        sections = RecordListBuilder.sections(from: records, now: Date(), calendar: calendar)
    }

    /// 앱 저장소에서만 지운다 — 건강 앱의 워크아웃은 남는다 (플랜 "결정").
    /// 구간은 `deleteRule: .cascade` 로 함께 지워진다. 실패하면 되돌리고 false.
    func delete(_ record: WorkoutRecord, in context: ModelContext) -> Bool {
        context.delete(record)
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            print("[HaruchiFit] 기록 삭제 실패 — \(error)")
            return false
        }
    }
}
```

- [x] **Step 2: 행 컴포넌트를 만든다**

`Apps/HaruchiFit/iOSApp/Features/Records/Components/RecordRow.swift`:

```swift
import SwiftUI

/// 기록 목록의 한 행 — 날짜와 구간 칩, 우측 kcal. 문자열은 `RecordListRow` 가 다 만들어 온다.
struct RecordRow: View {
    let row: RecordListRow

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(row.dateTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HaruchiPalette.text)
                if !row.chips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(row.chips, id: \.self) { chip($0) }
                    }
                }
            }
            Spacer(minLength: 8)
            if let calories = row.caloriesText {
                Text(calories)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(HaruchiPalette.dim)
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ chip: RecordListRow.Chip) -> some View {
        let color = chip.kind == .strength ? HaruchiPalette.accent : HaruchiPalette.cardio
        return Text(chip.text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
    }
}
```

- [x] **Step 3: 기록 탭을 교체한다**

`Apps/HaruchiFit/iOSApp/Features/Records/RecordsView.swift` 전체:

```swift
import SwiftData
import SwiftUI

/// 기록 탭 — 주 단위 섹션의 최신순 목록 (제품 스펙 03b). 집계도 차트도 두지 않는다.
/// 행 탭 → 기록 상세는 Phase 3 #5 가 붙인다.
struct RecordsView: View {
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sync: WorkoutSyncCoordinator
    @EnvironmentObject private var alerts: AppAlertCenter
    @StateObject private var viewModel = RecordsViewModel()
    @State private var pendingDelete: WorkoutRecord?

    var body: some View {
        NavigationStack {
            content
                .background(HaruchiPalette.bg.ignoresSafeArea())
                .refreshable { await sync.sync() }
                .navigationTitle("기록")
                .toolbarBackground(HaruchiPalette.bg, for: .navigationBar)
                .confirmationDialog("이 기록을 삭제할까요?",
                                    isPresented: Binding(get: { pendingDelete != nil },
                                                         set: { if !$0 { pendingDelete = nil } }),
                                    titleVisibility: .visible)
                {
                    Button("삭제", role: .destructive) { confirmDelete() }
                    Button("취소", role: .cancel) { pendingDelete = nil }
                } message: {
                    Text("건강 앱의 운동 기록은 그대로 남아요.")
                }
                .onAppear { viewModel.rebuild(from: records) }
                .onChange(of: records) { _, updated in viewModel.rebuild(from: updated) }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.sections.isEmpty {
            // ScrollView 로 감싸야 빈 상태에서도 당겨서 새로고침이 걸린다
            ScrollView {
                ContentUnavailableView("아직 기록이 없어요",
                                       systemImage: "list.bullet.rectangle",
                                       description: Text("워치에서 운동을 저장하면 여기에 쌓여요."))
                    .foregroundStyle(HaruchiPalette.dim)
                    .containerRelativeFrame(.vertical)
            }
        } else {
            List {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            RecordRow(row: row)
                                .listRowBackground(HaruchiPalette.surface)
                                .swipeActions(edge: .trailing) {
                                    // role: .destructive 를 쓰지 않는다 — 확인 전에 행이 먼저 사라지는 애니메이션이 돈다
                                    Button("삭제") { pendingDelete = row.record }
                                        .tint(.red)
                                }
                        }
                    } header: {
                        Text(section.title)
                            .foregroundStyle(HaruchiPalette.dim)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func confirmDelete() {
        guard let record = pendingDelete else { return }
        pendingDelete = nil
        if !viewModel.delete(record, in: modelContext) {
            alerts.report(.deleteFailed)
        }
    }
}
```

- [x] **Step 4: iOS 빌드**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 5: lint · format**

```bash
make lint
make format
git diff --check
```

Expected: 새 경고·위반 0. `make format` 이 걸리면 `make fix` 로 고치고 diff 를 다시 본다.

- [x] **Step 6: 시뮬레이터 확인** — 데이터 상태 확인은 TODO 의 수동 확인 항목으로 옮겼다

시뮬레이터에 건강 앱 데이터가 없으므로 **데이터 확인은 두 갈래**로 한다.

1. 빈 상태 — 첫 실행에서 기록 탭에 빈 상태가 보이고, 당겨서 새로고침이 크래시 없이 끝나는지
2. 데이터 상태 — 시뮬레이터 건강 앱에서 근력 운동 1건(이번 주)·달리기 1건(3주 전)을 수동 추가한 뒤 앱을 포그라운드로 가져와 import 시킨다. 확인할 것:
   - 섹션 제목 `이번 주` 와 `M월 d일 – M월 d일`
   - 행 날짜의 요일, 칩 색(근력 오렌지 · 유산소 파랑), kcal 정렬
   - 스와이프 → `삭제` → 다이얼로그 `취소` 시 행이 그대로 있는지
   - `삭제` 확정 시 행이 사라지고, 섹션이 비면 섹션도 사라지는지, **홈 탭 잔디 칸도 비는지**
   - 앱을 종료했다 다시 켜도 지운 기록이 돌아오지 않는지

`deleteFailed`·`saveFailed`·`syncFailed` 알림은 시뮬레이터에서 실패를 재현할 방법이 없다. 코드 리뷰로 확인하고
실기기 확인 항목에도 넣지 않는다 (재현 수단이 없기는 같다).

- [x] **Step 7: 커밋**

```bash
git add Apps/HaruchiFit/iOSApp/Features/Records/
git commit -m "✨ 하루치 기록 탭에 주 단위 목록과 스와이프 삭제를 추가한다"
```

---

## Task 4: 문서 갱신 · PR

**Files:**
- Modify: `Apps/HaruchiFit/CLAUDE.md`
- Modify: `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md`
- Modify: `TODO.md`

- [x] **Step 1: 앱 `CLAUDE.md`**
  - Project overview 의 *"iOS는 홈·기록·통계 3탭 셸이 있으며"* 문장에 기록 탭이 주 단위 목록이라는 것을 더한다
  - Architecture 트리의 `Features/Records/ · Statistics/  후속 작업이 채울 탭 화면` 을
    `Features/Records/  주 단위 기록 목록 · 스와이프 삭제` 와 `Features/Statistics/  후속 작업이 채울 탭 화면` 두 줄로 나누고,
    `AppAlert.swift · AppAlertCenter.swift  앱 전역 실패 알림` 을 `iOSApp/` 아래에 더한다

- [x] **Step 2: 로드맵**
  - Phase 3 표의 #4 행을 취소선 + `**완료 — PR #N.**` 으로. 비고에 "부위 칩·행 탭은 #5 로 넘김" 을 적는다
  - 의존 관계 그림의 `03b 목록` 에 취소선
  - #5 비고 *"모델엔 필드가 이미 있다"* 를 *"메모 필드만 있다 — 부위 필드를 추가하고 목록 행에 부위 칩과 탭 진입도 붙인다"* 로 고친다

- [x] **Step 3: `TODO.md`** (루트 규약 — 같은 커밋에서)
  - 하루치 예정사항 표 #4 행을 취소선 + `**완료** ([PR #N](…))`
  - #5 행을 `**다음 코드 작업**` 으로
  - 본문 *"다음 코드는 Phase 3 #4 기록 목록이다"* 를 #5 기록 상세로 고친다
  - 하루치 "집 맥북에서 할 것" 의 **잔디 저장 실시간 갱신 확인** 항목 옆에 *"기록 탭 목록도 같은 경로"* 를 덧붙인다

- [ ] **Step 4: 사용자 검토 후 커밋 · PR**

```bash
git add Apps/HaruchiFit/CLAUDE.md \
        Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md \
        Apps/HaruchiFit/docs/plans/ios/2026/2026-09-28-records-list.md \
        TODO.md
git commit -m "📝 하루치 기록 목록 완료를 로드맵·TODO 에 반영한다"
git push -u origin feat/haruchi-records-list
gh pr create --title "✨ 하루치 기록 탭 — 주 단위 목록과 스와이프 삭제" --body "…"
```

PR 번호가 나오면 Step 2·3 의 `#N` 을 채워 한 번 더 커밋·푸시한다. CI 통과 후
`gh pr merge <n> --merge --delete-branch`, `main` 동기화, 워크트리 제거, `make dd-prune` → `make dd-prune-apply` 로
이 워크트리의 DerivedData 를 지운다.

## 완료 기준

- `RecordListBuilderTests` 8개 포함 워치 테스트 전체 통과
- iOS 빌드 · `make lint` · `make format` · `git diff --check` 통과
- 시뮬레이터에서 Task 3 Step 6 항목 전부 확인
- 스펙 03b 중 부위 칩·행 탭은 #5 로 넘어갔다는 것이 로드맵·TODO 에 적혀 있다
