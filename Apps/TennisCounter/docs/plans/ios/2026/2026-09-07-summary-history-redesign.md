# iOS 요약·기록 리디자인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 요약·기록·기록 상세 세 화면의 정보 구성을 스펙대로 다시 잡는다. 요약은 3칸 통계 + 전적 한 줄 + 최근 추이 차트 + 최근 세션으로, 기록은 경기 나열에서 **세션 단위**로, 기록 상세는 가로 스코어보드로 바뀐다. 삭제 기능이 새로 들어간다.

**Architecture:** 데이터 모델은 건드리지 않는다. 새 축이 하나 생길 뿐이다 — `workoutSessionId` 로 경기를 묶는 `MatchSessionGroup` 이 요약·기록 목록·캘린더 하단 셋의 공용 표현 단위가 되고, 세 화면이 `SessionHeader`·`MatchRow` 두 조각을 공유한다 (조립은 카드와 `List` 두 가지 — §SessionCard 분해). 누적 지표는 그룹당 최댓값만 취하는 기존 `sumOfWorkoutMaxima` 규칙을 그대로 따른다. 삭제는 `PersistenceCore.PersistenceService.delete` 에 위임하며 `SetRecord` 는 `deleteRule: .cascade` 로 함께 지워진다.

**Tech Stack:** iOS 17+ / SwiftUI `List`+`Section` · Swift Charts · SwiftData / Swift Testing

**Spec:** [2026-08-25-summary-history-redesign-design.md](../../../specs/ios/2026/2026-08-25-summary-history-redesign-design.md) — 열린 질문 없음

**선행:** [String Catalog 전환 플랜](../../shared/2026/2026-09-07-string-catalog-migration.md). 이 플랜이 문자열 키 17개를 새로 넣으므로 카탈로그 전환을 먼저 끝내야 전환 커밋의 "키 개수 동일(iOS 71)" 검증 기준이 깨지지 않는다.

**후행:** [공유 버튼 플랜](2026-09-07-workout-share-button.md). 그 플랜은 `MatchDetailSheet` 의 `match_detail_section_info` 섹션 **뒤**에 버튼을 붙이는데, Task 7 이 이 파일의 섹션 구조를 바꾼다. 이 플랜을 먼저 끝내면 공유 버튼 플랜을 고칠 필요가 없다.

## 스펙 보정 (2026-09-08)

스펙 작성(08-25) 이후 확정된 것과, 스펙대로 만들면 막히는 것들. 스펙 본문보다 아래가 우선한다.

| 스펙 표기 | 실제 | 이유 |
|---|---|---|
| `Info.plist` | **`TennisCounter-Info.plist`** (현재 `<dict/>` 빈 파일) | iOS 타깃의 plist 는 이것 하나. `GENERATE_INFOPLIST_FILE = YES` 와 병행하므로 빈 dict 를 열어 키를 넣는다 |
| `{en,ko}.lproj/Localizable.strings` 에 키 추가 | **`iOSApp/Localizable.xcstrings`** | String Catalog 전환(#5)을 먼저 하므로 `.lproj` 가 이미 없다 |
| 변경 파일에 `HistoryView.swift` 없음 | **수정 대상** | 삭제 확인 다이얼로그·선택 날짜·`SessionList` 호출이 여기 붙는다 |
| `SessionCard.swift` 하나 | **`SessionHeader` + `MatchRow` + `RecentSessionCard` + `SessionList` 넷** | 아래 §SessionCard 분해 |
| `DaySessionList.swift` 신규 | **만들지 않는다** | `SessionList` 를 `CalendarView` 가 그대로 쓴다. 래퍼가 하는 일이 빈 상태 분기뿐이라 파일을 늘릴 이유가 없다 |
| `DayCellDotsTests` 대상 파일 없음 | **`DayCell.swift` 안의 `enum DayCellDots`** | 파일을 새로 만들 분량이 아니다 |
| 죽는 키 3개 | **7개** — `match_detail_section_sets` + #5 가 넣은 3개 | Task 7 이 세트 섹션을 지우면 `match_detail_section_sets` 의 참조가 사라진다. 나머지 3개는 아래 §#5 와의 겹침 |
| 신규 문자열 키 (개수 없음) | **17개** (스펙 16 + `btn_delete`), 최종 iOS 키 **76 + 17 − 7 = 86** | 스와이프 삭제 버튼 문구가 저장소에 없다. 기준이 71 이 아니라 76 인 것은 #5 가 키 5개를 더했기 때문 |

### #5(String Catalog 전환)와의 겹침

이 플랜은 2026-09-07 에 쓰였고, 그때 `MatchDetailSheet` 에는 `"Format"`·`"Date"`·`"No set data"`
가 하드코딩돼 있었다. #5 가 그 셋을 키로 올리면서(`history_field_*` · `history_no_set_data`)
이 플랜이 만들려던 키와 **자리가 겹친다.**

| #5 가 넣은 키 | 이 플랜 | 처리 |
|---|---|---|
| `history_field_format` | `match_detail_format` | 플랜 이름을 쓴다 — 형제 키가 전부 `match_detail_*` |
| `history_field_date` | `match_detail_time` | 플랜 이름. `Date` 가 **시간 범위**로 의미까지 바뀐다 |
| `history_no_set_data` | `match_detail_no_sets` | 플랜 이름 |
| `summary_period_label` | — | 이 플랜이 안 건드린다. 그대로 산다 |
| `score_point_zone_hint` | — | 점수 화면. 이 플랜 범위 밖 |

ko 번역은 #5 가 정한 값을 그대로 옮긴다 — `경기 방식` · `세트 기록이 없습니다`.

### SessionCard 분해

스펙은 "요약·기록 목록·캘린더 하단이 `SessionCard` 를 공유한다"고 쓰는데, **세 화면이 쓰는 모양이 다르다.**

- 요약 — 최근 세션 **하나**를 패딩·배경·라운드가 붙은 카드로
- 기록 목록·캘린더 하단 — `List` 의 `Section`. 헤더와 행을 **따로** 넘겨야 하고 행에 `.swipeActions` 가 붙는다

`Section(header:)` 에 카드 한 덩어리를 넣을 수 없으므로 **조각을 먼저 만들고 두 가지로 조립**한다.

```
Components/SessionHeader.swift   날짜(요일) + 누적 시간 + 누적 kcal      ← 두 조립 모두 사용
Components/MatchRow.swift        승/패 + 세트별 게임 스코어              ← 두 조립 모두 사용
        ↑                                    ↑
Features/Summary/Components/            Features/History/Components/
  RecentSessionCard.swift                 SessionList.swift
  (카드 래퍼, 요약 전용)                    (List+Section+스와이프, 기록·캘린더 공용)
```

`SessionHeader`·`MatchRow` 는 요약과 기록 **두 Feature 가 공유**하므로 앱 루트 `Components/` (루트 CLAUDE.md §계층화된 컴포넌트 구조). 조립 둘은 각자의 Feature 아래.

`SessionList` 는 `MatchList.swift` 를 rename 해서 만든다 — 기록 목록과 캘린더 하단이 같은 것이므로 파일을 늘리지 않는다. 무한 스크롤은 `onLoadMore: (() -> Void)?` 로 두어 캘린더 쪽은 `nil` 을 넘긴다.

## Global Constraints

- **모델을 바꾸지 않는다.** `Match`·`SetRecord` 에 필드를 추가하지 않는다 — CloudKit 스키마 마이그레이션이 붙는 순간 이 작업의 성격이 달라진다.
- **누적값(`workout*`) 은 요약·세션 헤더에서만, 경기 구간값(`durationSeconds`·`caloriesBurned`·`totalCaloriesBurned`) 은 기록 상세에서만** 쓴다. 이 규칙이 이번 작업의 핵심이므로 어느 화면에서든 축을 섞지 않는다.
- ViewModel 은 SwiftUI 를 import 하지 않는다 (루트 CLAUDE.md §역할 분리). 그룹핑·정렬·페이징은 전부 ViewModel 또는 `Shared/Models/` 의 순수 로직에 둔다.
- 옛 기록 호환 — `workoutSessionId == nil` 은 단독 세션, 누적값이 `nil` 이면 `–` 로 표기한다. 크래시나 0 표기로 흘리지 않는다.
- 브랜치 **`feat/summary-history-redesign`** (메인 체크아웃). `feat/ralli` 는 PR #11 로 이미 머지되어 더 쓰지 않는다.
- 커밋은 **Task 단위로 8개**, PR 하나로 머지 (`gh pr merge --merge --delete-branch`).
- 새 문자열 **17개**는 코드에 `String(localized:)` 로 쓰면 빌드 때 카탈로그에 추출된다. 추출되지 않으면 Xcode 에서 카탈로그에 직접 키를 추가한다. **영어(en)는 소스 문자열 그대로, 한국어(ko)만 채운다.**

**빌드 명령** (루트에서)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test -only-testing:iosTests
make lint && make format
```

## File Structure

**신규**

| 파일 | 책임 |
|---|---|
| `iOSApp/Extensions/Duration+Cumulative.swift` | 누적 시간 포맷 (`42분` / `18시간 42분` / `470시간`) |
| `Shared/Models/MatchSessionGroup.swift` | 세션 그룹 struct + 그룹핑·정렬 순수 로직 |
| `iOSApp/Components/SessionHeader.swift` | 세션 헤더 (요약·기록 공유) |
| `iOSApp/Components/MatchRow.swift` | 경기 행 (요약·기록 공유) |
| `iOSApp/Features/Summary/Components/RecentSessionCard.swift` | 요약의 카드 조립 |
| `iOSApp/Features/Summary/Components/RecentTrendChart.swift` | 최근 10회 세션 막대 차트 |
| `iOSApp/Features/History/Components/Scoreboard.swift` | 가로 스코어보드 (기록 상세 전용) |
| `iosTests/Extensions/DurationFormatTests.swift` | 포맷 4케이스 |
| `iosTests/Shared/MatchSessionGroupTests.swift` | 그룹핑·정렬·누적 최댓값 |
| `iosTests/History/DayCellDotsTests.swift` | 점 개수·색 |

**수정**

| 파일 | 내용 |
|---|---|
| `TennisCounter-Info.plist` | `UIUserInterfaceStyle = Dark` (빈 `<dict/>` 를 연다) |
| `iOSApp/iOSApp.swift:59` | `.colorScheme(.dark)` → `.preferredColorScheme(.dark)` |
| `iOSApp/Components/StatCard.swift` | `color` 파라미터 제거, 값은 흰색 고정 (호출부 11곳) |
| `iOSApp/Features/Summary/SummaryViewModel.swift` | `SummaryPeriod` 재정의, `SummaryStats` 축소, 세션·추이 반환 |
| `iOSApp/Features/Summary/SummaryView.swift` | 3칸 + 전적 줄 + 차트 + 최근 세션 + 빈 상태 |
| `…/Summary/Components/MatchStatsGrid.swift` → `SummaryStatsGrid.swift` | rename + 3칸 재구성 + `#Preview` 인자 갱신 |
| `iOSApp/Features/History/HistoryViewModel.swift` | 세션 그룹, **offset 방식 교체**, 선택 날짜, 삭제 |
| `iOSApp/Features/History/HistoryView.swift` | 삭제 다이얼로그, 선택 날짜, `SessionList` 호출, 캘린더 `ScrollView` 제거 |
| `…/History/Components/MatchList.swift` → `SessionList.swift` | rename + `List`+`Section`+스와이프 |
| `…/History/Components/MatchDetailSheet.swift` | 스코어보드, "이 경기" 섹션, 시간 범위, 하드코딩 문자열 제거 |
| `…/History/Calendar/CalendarView.swift` | 하단에 `SessionList` + 빈 상태 |
| `…/History/Calendar/Components/CalendarGrid.swift` | `selectedMatch` → `selectedDate` 바인딩 |
| `…/History/Calendar/Components/DayCell.swift` | 다중 점, 선택/오늘 상태, `DayCellDots` |
| `iOSApp/Services/MatchPersistenceService.swift` | `delete(_:)` |
| `iOSApp/Localizable.xcstrings` | 신규 17 / 삭제 4 |
| `iosTests/Summary/SummaryViewModelTests.swift` | 기간·통계·추이 |
| `iosTests/History/HistoryViewModelTests.swift` | 그룹핑·페이징·삭제·날짜 선택 |
| `iosTests/Services/MatchPersistenceServiceTests.swift` | 삭제 2케이스 |

**삭제**

| 파일 | 이유 |
|---|---|
| `iOSApp/Components/MatchCard.swift` | `MatchRow` 가 대체. 사용처는 `MatchList`·`RecentMatchList` 둘뿐 |
| `iOSApp/Features/Summary/Components/WorkoutStatsGrid.swift` | 3칸에 통합 |
| `iOSApp/Features/Summary/Components/RecentMatchList.swift` | `RecentSessionCard` 가 대체 |

**신규 문자열 키 17개** — 형식이 있는 것만 값을 못박는다.

| 키 | ko | en |
|---|---|---|
| `duration_minutes` | `%d분` | `%dm` |
| `duration_hours_minutes` | `%1$d시간 %2$d분` | `%1$dh %2$dm` |
| `duration_hours` | `%d시간` | `%dh` |
| `summary_record_line` | `%1$d승 %2$d패 · %3$d%%` | `%1$dW %2$dL · %3$d%%` |
| `summary_section_trend` · `summary_trend_insufficient` · `summary_recent_session` | 문구 | |
| `history_delete_confirm_title` · `history_delete_confirm_message` · `history_day_empty` | 문구 | |
| `match_detail_section_this_match` · `match_detail_format` · `match_detail_time` · `match_detail_no_sets` · `match_detail_me` · `match_detail_opponent` | 문구 | |
| `btn_delete` | `삭제` | `Delete` |

`%%` 는 리터럴 `%` 다. 위치 지정자(`%1$d`)를 쓰는 건 한국어·영어 어순이 갈릴 때 번역자가 순서를 바꿀 수 있게 하기 위해서다.

**죽는 키 7개** — `summary_period_today` · `summary_recent_matches` · `summary_section_workout` ·
`match_detail_section_sets` · `history_field_format` · `history_field_date` · `history_no_set_data`

전환 후 iOS 키 개수: **76 + 17 − 7 = 86**

---

### Task 1: 기반 — 다크 모드 고정 · 누적 시간 포맷 · StatCard 색 제거

**Files:**
- Modify: `Apps/TennisCounter/TennisCounter-Info.plist`
- Modify: `Apps/TennisCounter/iOSApp/iOSApp.swift`
- Create: `Apps/TennisCounter/iOSApp/Extensions/Duration+Cumulative.swift`
- Create: `Apps/TennisCounter/iosTests/Extensions/DurationFormatTests.swift`
- Modify: `Apps/TennisCounter/iOSApp/Components/StatCard.swift`

- [ ] **Step 1: plist 에 다크 모드 고정**

`TennisCounter-Info.plist` 에 `UIUserInterfaceStyle = Dark` (String) 을 추가한다.

> `INFOPLIST_KEY_UIUserInterfaceStyle` 빌드 세팅이 아니라 **plist 파일**에 넣는다. 배열이 아니라 문자열이라 빌드 세팅으로도 되지만, 같은 파일에 `LSApplicationQueriesSchemes`(공유 버튼 플랜)가 들어올 예정이라 한곳에 모은다 — 루트 `docs/specs/2026/2026-09-03-xcode-target-conventions.md` §`INFOPLIST_KEY_*` 참고.

- [ ] **Step 2: `iOSApp.swift:59` 모디파이어 교체**

```swift
            .preferredColorScheme(.dark)   // .colorScheme 은 SwiftUI 하위 트리만 바꾸고
                                           // 시트 그래버·알림창·키보드는 시스템 스타일을 따라간다
```

- [ ] **Step 3: 누적 시간 포맷**

`Duration+Cumulative.swift` — `WorkoutMetrics.formatSeconds`(스톱워치용)는 건드리지 않는다.

```swift
import Foundation

/// 누적 통계용 시간 표기. 경기 중 타이머는 WorkoutMetrics.formatSeconds 를 계속 쓴다 —
/// 그쪽은 시:분:초라 누적에 쓰면 470:00:00 처럼 카드에서 넘친다.
enum CumulativeDuration {
    static func format(_ seconds: Int) -> String {
        let totalMinutes = max(0, seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return String(format: String(localized: "duration_minutes"), minutes)
        }
        if hours >= 100 {
            return String(format: String(localized: "duration_hours"), hours)
        }
        return String(format: String(localized: "duration_hours_minutes"), hours, minutes)
    }
}
```

문자열 (ko / en):

| 키 | ko | en |
|---|---|---|
| `duration_minutes` | `%d분` | `%dm` |
| `duration_hours_minutes` | `%d시간 %d분` | `%dh %dm` |
| `duration_hours` | `%d시간` | `%dh` |

- [ ] **Step 4: 포맷 테스트**

`iosTests/Extensions/DurationFormatTests.swift` — `formatsMinutesOnlyBelowOneHour`(2520 → `42분`) · `formatsHoursAndMinutes`(67320 → `18시간 42분`) · `formatsHoursOnlyAboveHundred`(1692000 → `470시간`) · `formatsZero`(0 → `0분`).

> 테스트는 ko 로케일 문자열을 직접 비교하지 말고 `String(format: String(localized:), ...)` 로 기대값을 만든다. 시뮬레이터 로케일에 따라 깨지지 않게 한다.

- [ ] **Step 5: `StatCard` 색 제거**

`color: Color` 프로퍼티를 지우고 값 `Text` 의 `.foregroundColor(color)` 를 `.foregroundColor(.white)` 로 바꾼다. 호출부 3곳(`MatchStatsGrid` 3개, `WorkoutStatsGrid` 4개, `MatchDetailSheet` 4개)에서 `color:` 인자를 지운다. 이 파일들은 뒤 Task 에서 다시 손대므로 여기서는 컴파일만 통과시킨다.

- [ ] **Step 6: 빌드·테스트·커밋**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test -only-testing:iosTests
git commit -m "🎨 다크 모드를 앱 전체에 고정하고 누적 시간 포맷을 분리한다"
```

---

### Task 2: 세션 그룹핑 모델

**Files:**
- Create: `Apps/TennisCounter/Shared/Models/MatchSessionGroup.swift`
- Create: `Apps/TennisCounter/iosTests/Shared/MatchSessionGroupTests.swift`

- [ ] **Step 1: 그룹 struct + 그룹핑 로직**

```swift
import Foundation

/// 한 워크아웃(`workoutSessionId`)에 속한 경기들. 요약·기록 목록·캘린더 하단이 공유하는 표현 단위다.
/// 진행 중 경기 상태인 `MatchSession` 과 이름이 겹치지 않게 `~Group` 을 붙였다.
struct MatchSessionGroup: Identifiable {
    /// `workoutSessionId`. nil 기록은 각자 단독 세션이므로 경기의 `id` 를 쓴다.
    let id: UUID
    /// `startedAt` 오름차순.
    let matches: [Match]

    /// 세션 정렬 기준. 세션 안에서 가장 늦게 시작한 경기.
    var latestStartedAt: Date { matches.last?.startedAt ?? .distantPast }
    var date: Date { matches.first?.startedAt ?? .distantPast }

    /// 누적 지표는 그룹당 최댓값 하나. 같은 워크아웃의 경기들이 하나의 누적 축을 공유하므로
    /// 합산하면 같은 값을 여러 번 세게 된다.
    var elapsedSeconds: Int? { matches.compactMap(\.workoutElapsedSeconds).max() }
    var activeCalories: Double? { matches.compactMap(\.workoutCaloriesBurned).max() }

    static func group(_ matches: [Match]) -> [MatchSessionGroup] {
        var bySession: [UUID: [Match]] = [:]
        var solo: [MatchSessionGroup] = []

        for match in matches {
            if let sid = match.workoutSessionId {
                bySession[sid, default: []].append(match)
            } else {
                // 누적값 도입 이전 기록. 서로 묶을 근거가 없어 각자 한 세션으로 둔다.
                solo.append(MatchSessionGroup(id: match.id, matches: [match]))
            }
        }

        let grouped = bySession.map { sid, list in
            MatchSessionGroup(id: sid, matches: list.sorted { $0.startedAt < $1.startedAt })
        }
        return (grouped + solo).sorted { $0.latestStartedAt > $1.latestStartedAt }
    }
}
```

- [ ] **Step 2: 그룹핑 테스트**

`matchesGroupIntoSessions` · `nilSessionIdBecomesOwnSession` · `sessionsSortedByLatestMatch` (세션 내림차순 + 세션 안 경기 오름차순) · `cumulativeTakesMaximumPerGroup` (같은 세션 경기 3개의 누적값이 합산이 아니라 최댓값).

- [ ] **Step 3: 커밋** — `✨ 경기를 워크아웃 세션 단위로 묶는 MatchSessionGroup 을 추가한다`

---

### Task 3: 세션 조각 — `SessionHeader` · `MatchRow`

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Components/SessionHeader.swift`
- Create: `Apps/TennisCounter/iOSApp/Components/MatchRow.swift`

두 조각이 요약과 기록 양쪽 조립에 쓰인다. **어느 쪽도 패딩·배경·라운드를 스스로 붙이지 않는다** —
카드가 될지 `List` 행이 될지는 조립하는 쪽이 정한다. 여기서 배경을 칠하면 `List` 안에서 이중 배경이 된다.

- [ ] **Step 1: `SessionHeader` 시그니처**

```swift
struct SessionHeader: View {
    let session: MatchSessionGroup
    // 표기: 날짜(요일) · 누적 운동시간 · 누적 활동 kcal
    // 전적·경기 수는 넣지 않는다 — 아래 행을 세면 나오는 값이다.
    // 누적값이 nil 인 옛 기록은 "–".
}
```

시간은 `CumulativeDuration.format`, 칼로리는 천단위 콤마.

> **누적값 폴백을 두지 않는다.** `MatchSessionGroup.elapsedSeconds` 는 `workoutElapsedSeconds` 만 본다
> (`durationSeconds` 로 대체하지 않는다). 요약 3칸은 기존 `sumOfWorkoutMaxima` 의 폴백을 그대로 쓰므로,
> **옛 기록만 있는 세션은 헤더가 `–` 인데 요약 숫자에는 잡힌다.** 스펙이 헤더는 `–` 로 정했으므로 그대로 두되,
> 이 차이를 알고 둔다 — 헤더는 "이 워크아웃의 누적", 요약은 "기간 합계"로 축이 다르다.

- [ ] **Step 2: `MatchRow` 시그니처**

```swift
struct MatchRow: View {
    let match: Match
    // 표기: 승/패 + 세트별 게임 스코어 ("6-4 4-6 6-3")
}
```

- 승/패 텍스트에만 색 (초록/주황). 게임 스코어는 기본색
- **내가 이긴 세트의 숫자만 `.bold`** — 색을 더 쓰면 목록이 시끄러워진다
- 세트합계(`2-1`)는 넣지 않는다
- 5세트가 한 줄에 들어가야 한다
- 세트는 `(match.sets ?? []).sorted { $0.setNumber < $1.setNumber }`
- **탭·스와이프를 스스로 처리하지 않는다.** 조립하는 쪽이 `.onTapGesture` / `.swipeActions` 를 붙인다

- [ ] **Step 3: `#Preview`** — 3세트 승 / 1세트 패 / 세트 없음(`sets` 가 `nil`) 셋

- [ ] **Step 4: 커밋** — `✨ 세션 헤더와 경기 행 컴포넌트를 추가한다`

### Task 4: 요약 화면 재편

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/Summary/SummaryViewModel.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/Summary/SummaryView.swift`
- Rename+Modify: `…/Summary/Components/MatchStatsGrid.swift` → `SummaryStatsGrid.swift`
- Create: `…/Summary/Components/RecentSessionCard.swift`
- Create: `…/Summary/Components/RecentTrendChart.swift`
- Delete: `…/Summary/Components/WorkoutStatsGrid.swift`, `…/Summary/Components/RecentMatchList.swift`
- Modify: `Apps/TennisCounter/iosTests/Summary/SummaryViewModelTests.swift`

- [ ] **Step 1: `SummaryPeriod` 교체**

`case today, week, month` → `case week, month, all`. `.all` 의 `startDate` 는 `nil` (기존 `filteredMatches` 가 이미 `nil` 이면 전체를 반환한다). 기본값 `.week` 유지. `summary_period_all` 키는 이미 정의되어 있다.

- [ ] **Step 2: `SummaryStats` 축소**

남기는 것 — `totalMatches` · `wins` · `winRate` · `totalCalories`(활동) · `totalDuration`.
지우는 것 — `totalEnergy` · `avgHeartRate` 와 그 `formatted*`.

`formattedDuration` 은 `WorkoutMetrics.formatSeconds` → `CumulativeDuration.format` 으로 바꾼다. `formattedCalories` 는 천단위 콤마를 넣는다 (`NumberFormatter` 또는 `.formatted(.number)`).

`sumOfWorkoutMaxima` 는 그대로 둔다.

- [ ] **Step 3: 세션·추이 반환**

`recentMatches(from:)`(경기 2개) 를 지우고 아래 둘로 바꾼다.

```swift
    /// 최근 세션 하나. 기간 필터를 탄다.
    func recentSession(from matches: [Match]) -> MatchSessionGroup? {
        MatchSessionGroup.group(filteredMatches(from: matches)).first
    }

    /// 최근 10회 세션, 오래된 것부터. 기간 필터와 무관하게 항상 전체에서 뽑는다 —
    /// 차트는 "얼마나 오래 쳤나"만 맡는 독립 블록이다.
    /// 3개 미만이면 빈 배열을 돌려 뷰가 안내 문구를 띄우게 한다.
    func trendSessions(from matches: [Match]) -> [MatchSessionGroup] {
        let groups = MatchSessionGroup.group(matches)
        guard groups.count >= 3 else { return [] }
        return Array(groups.prefix(10)).reversed()
    }
```

- [ ] **Step 4: `SummaryStatsGrid`** — Xcode 네비게이터에서 `MatchStatsGrid.swift` 를 `SummaryStatsGrid.swift` 로 rename 하고 타입명도 바꾼다. 3칸을 `경기 수` / `운동시간` / `활동 kcal` 로 교체한다 (승·승률 카드 제거). **`#Preview` 가 `SummaryStats(...)` 를 7개 인자로 만들고 있으므로 Step 2 의 새 이니셜라이저에 맞춰 고친다** — 안 고치면 이 파일에서 컴파일이 깨진다.

- [ ] **Step 5: `RecentSessionCard`**

```swift
struct RecentSessionCard: View {
    let session: MatchSessionGroup
    let onSelect: (Match) -> Void
    // VStack { SessionHeader; ForEach(session.matches) { MatchRow.onTapGesture } }
    // 패딩·배경(Color.white.opacity(0.2))·라운드 16 은 여기서 붙인다 — 조각은 배경을 모른다.
}
```

- [ ] **Step 6: `RecentTrendChart`**

`import Charts` (iOS 배포 타깃 17.0 이라 사용 가능).

```swift
struct RecentTrendChart: View {
    /// 오래된 것부터. 비어 있으면 안내 문구를 대신 띄운다.
    let sessions: [MatchSessionGroup]
}
```

- `BarMark(x: .value(라벨, 세션 날짜 문자열), y: .value(라벨, 분))`, y 는 `elapsedSeconds / 60`
- x축 라벨은 `8/24` — `DateFormatter` 에 `setLocalizedDateFormatFromTemplate("Md")`
- 막대 색 `Color.brand` (`iOSApp/BrandColor.swift`)
- `sessions.isEmpty` 면 차트 대신 `summary_trend_insufficient`
- 누적값이 `nil` 인 세션은 막대 0 이 아니라 **건너뛴다** — 0 막대는 "그날 안 뛰었다"로 읽힌다

- [ ] **Step 7: `SummaryView` 재구성**

순서 — 기간 `Picker` → `SummaryStatsGrid` → 전적 한 줄 → `summary_section_trend`("최근 10회 추이") + `RecentTrendChart` → `summary_recent_session` + `RecentSessionCard`.

전적 줄:

```swift
Text(String(format: String(localized: "summary_record_line"),
            stats.wins, stats.totalMatches - stats.wins, Int(stats.winRate * 100)))
```

**빈 상태** — `viewModel.filteredMatches(from: matches)` 가 비면 `Picker` 만 남기고 `summary_no_matches` 를 띄운다. 키는 이미 정의되어 있고 지금 쓰이지 않아, 경기가 없으면 0 과 `–` 만 남은 화면이 나온다.

**상세 시트** — 최근 세션의 경기 행을 탭하면 `MatchDetailSheet` 를 연다. 지금 시트는 기록 탭에만 있으므로 `SummaryView` 에도 `@State private var selectedMatch: Match?` 와 `.sheet(item: $selectedMatch)` 를 새로 둔다.

- [ ] **Step 8: `WorkoutStatsGrid.swift`·`RecentMatchList.swift` 삭제**

- [ ] **Step 9: 테스트**

`allPeriodIncludesEveryMatch` · `weekPeriodExcludesOlderMatches`(기존 유지) · `statsExcludeRemovedMetrics` · `trendReturnsAtMostTenSessions` · `trendGroupsBySession` · `trendHiddenBelowThreeSessions`.

- [ ] **Step 10: 빌드·테스트·커밋** — `✨ 요약 화면을 3칸 통계·전적 줄·추이 차트·최근 세션으로 재편한다`

---

### Task 5: 기록 목록 세션화 + 삭제

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Services/MatchPersistenceService.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/History/HistoryViewModel.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/History/HistoryView.swift`
- Rename+Modify: `…/History/Components/MatchList.swift` → `SessionList.swift`
- Delete: `Apps/TennisCounter/iOSApp/Components/MatchCard.swift`
- Modify: `iosTests/History/HistoryViewModelTests.swift`, `iosTests/Services/MatchPersistenceServiceTests.swift`

- [ ] **Step 1: `delete(_:)`**

```swift
    /// SetRecord 는 deleteRule: .cascade 라 함께 지워진다.
    /// CloudKit 동기화라 다른 기기로 전파되고 되돌릴 수 없다 — 호출부가 확인을 받는다.
    func delete(_ match: Match) throws {
        guard let store else { throw PersistenceError.notConfigured }
        do {
            try store.delete(match)
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }
```

- [ ] **Step 2: offset 방식을 바꾼다 — 삭제와 충돌한다**

지금은 페이지 번호로 offset 을 만든다.

```swift
descriptor.fetchOffset = currentPage * pageSize   // HistoryViewModel.swift:43
currentPage += 1
```

여기에 삭제가 들어오면 **저장소 레코드가 하나 줄어 다음 페이지가 한 칸 밀린다.** 20번째 경계에 있던
경기가 영영 안 나온다. `currentPage` 를 버리고 **이미 들고 있는 개수**를 offset 으로 쓴다.

```swift
        // 페이지 번호가 아니라 보유 개수로 offset 을 잡는다 — 삭제로 저장소와 배열이 함께 하나 줄면
        // offset 도 같이 줄어 경계가 어긋나지 않는다. 화면에 없는 레코드는 지울 수 없으므로 항상 일치한다.
        descriptor.fetchOffset = listMatches.count
```

`loadInitial()` 의 `currentPage = 0` 도 함께 지운다 (`listMatches = []` 가 그 역할을 한다).

- [ ] **Step 3: 세션 그룹 파생**

`listMatches`(경기 단위 페칭)는 그대로 두고, 뷰가 쓰는 것을 파생시킨다.

```swift
    @Published private(set) var listSessions: [MatchSessionGroup] = []

    // 누적 배열 전체를 다시 그룹핑한다. 페이지 경계에서 한 세션이 둘로 갈리는 문제가
    // 여기서 자연히 사라진다 — 경계를 따로 병합할 필요가 없다.
    private func rebuildSessions() {
        listSessions = MatchSessionGroup.group(listMatches)
    }
```

`loadNextPage()` 끝과 `delete(_:)` 끝에서 부른다.

- [ ] **Step 4: `delete(_:)` on ViewModel**

```swift
    func delete(_ match: Match) {
        try? MatchPersistenceService.shared.delete(match)
        listMatches.removeAll { $0.id == match.id }
        calendarMatches.removeAll { $0.id == match.id }
        rebuildSessions()
    }
```

> **컨텍스트가 둘이다.** `iOSApp.swift:14` 가 서비스에 `ModelContext(container)` 를 따로 만들어 주고,
> `HistoryViewModel` 은 `@Environment(\.modelContext)` 를 받는다. 같은 컨테이너라 저장소에는 반영되지만
> **VM 의 배열은 자동으로 갱신되지 않으므로 위처럼 직접 지운다.**

- [ ] **Step 5: `MatchList` → `SessionList`**

Xcode 네비게이터에서 rename. 시그니처가 바뀐다.

```swift
struct SessionList: View {
    let sessions: [MatchSessionGroup]
    let isLoadingMore: Bool
    /// 캘린더 하단은 페이징하지 않으므로 nil.
    let onLoadMore: (() -> Void)?
    let onSelect: (Match) -> Void
    let onDelete: (Match) -> Void
}
```

`ScrollView`+`LazyVStack` → `List`. 세션 하나가 `Section(header: SessionHeader(session:))`, 행이 `MatchRow`.

**다크 배경은 모디파이어 셋을 다 걸어야 유지된다** — 하나라도 빠지면 흰 배경이 비친다.

```swift
        .listStyle(.plain)
        .scrollContentBackground(.hidden)     // List 자체 배경
        // 각 행에:
        .listRowBackground(Color.clear)
```

스와이프 삭제는 행에 붙인다.

```swift
                    .swipeActions(edge: .trailing) {
                        Button(String(localized: "btn_delete"), role: .destructive) { onDelete(match) }
                    }
```

무한 스크롤 — `onLoadMore` 가 `nil` 이 아닐 때만, **세션이 아니라 경기 기준으로** 끝 5개 전에서 부른다.

- [ ] **Step 6: `HistoryView`**

- `MatchList(matches: viewModel.listMatches, …)` → `SessionList(sessions: viewModel.listSessions, …)`
- 빈 상태 조건 `viewModel.listMatches.isEmpty` → `viewModel.listSessions.isEmpty`
- `@State private var pendingDelete: Match?` + `.confirmationDialog`. `onDelete:` 는 곧바로 지우지 말고 `pendingDelete` 에 담는다
- 다이얼로그 문구 `history_delete_confirm_title` / `history_delete_confirm_message` — 메시지에 **다른 기기로 전파되고 되돌릴 수 없다**는 점을 적는다

- [ ] **Step 7: `MatchCard.swift` 삭제**

```bash
grep -rn "MatchCard" Apps/TennisCounter/ --include='*.swift'   # 결과가 없어야 한다
```

- [ ] **Step 8: 테스트**

`HistoryViewModelTests` — `matchesGroupIntoSessions` · `nilSessionIdBecomesOwnSession` · `sessionsSortedByLatestMatch` · `pageBoundaryMergesSameSession` · **`deleteDoesNotSkipNextPage`**(20개 경계에서 하나 지우고 `loadNextPage` → 건너뛴 경기가 없어야 한다) · `deleteRemovesMatchFromSession` · `deletingLastMatchRemovesSession`.

> 삭제 테스트는 VM 과 서비스가 **같은 컨테이너**를 봐야 한다. 기존 `makeContext()` 는 컨테이너를 안 돌려주므로
> 컨테이너를 만들어 `vm.configure(modelContext: ModelContext(container))` 와
> `MatchPersistenceService.shared.configure(with: ModelContext(container))` 에 각각 넘기는 헬퍼를 추가한다.
> 서비스가 싱글턴이라 **`@Suite(.serialized)` 가 필요하다** — `MatchPersistenceServiceTests` 가 같은 이유로 이미 쓰고 있다.

`MatchPersistenceServiceTests` — `deleteRemovesMatch` · `deleteCascadesSetRecords`.

- [ ] **Step 9: 빌드·테스트·커밋** — `✨ 기록 목록을 세션 단위로 바꾸고 경기 삭제를 넣는다`

### Task 6: 캘린더 — 다중 점 · 날짜 선택 · 하단 세션 목록

**Files:**
- Modify: `…/History/Calendar/Components/DayCell.swift`, `CalendarGrid.swift`, `…/Calendar/CalendarView.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/History/HistoryViewModel.swift`, `HistoryView.swift`
- Create: `Apps/TennisCounter/iosTests/History/DayCellDotsTests.swift`

- [ ] **Step 1: `DayCellDots` 순수 함수**

`DayCell.swift` 안에 둔다.

```swift
/// 점 계산을 뷰에서 떼어 테스트한다.
enum DayCellDots {
    enum Dot: Equatable { case win, loss, more }

    /// 셀 폭이 40pt라 5pt 점 4개 + 간격이 한계다. 넘으면 마지막을 회색 `.more` 로.
    static func dots(for matches: [Match], limit: Int = 4) -> [Dot] {
        let sorted = matches.sorted { $0.startedAt < $1.startedAt }
        if sorted.count <= limit {
            return sorted.map { $0.myTotalSets > $0.yourTotalSets ? .win : .loss }
        }
        return sorted.prefix(limit - 1).map { $0.myTotalSets > $0.yourTotalSets ? .win : .loss } + [.more]
    }
}
```

- [ ] **Step 2: `DayCell` 상태 셋**

`isToday ? .blue` 단일 상태를 셋으로 늘린다 — 평소 / **오늘 = 테두리 원** / **선택 = 채워진 원**(`Color.brand`).
겹칠 수 있으므로 채움과 테두리로 나눈다. `hasWin`(`contains { 이김 }`) 단일 점은 `dots(for:)` 로 교체한다.

```swift
struct DayCell: View {
    let date: Date
    let matches: [Match]
    let isSelected: Bool          // 추가
    let onTap: () -> Void
}
```

- [ ] **Step 3: `CalendarGrid` 바인딩 교체**

```swift
    @Binding var selectedDate: Date?   // was: @Binding var selectedMatch: Match?
```

`DayCell` 의 `onTap` 은 `selectedDate = date` 만 한다. **캘린더가 상세 시트를 직접 열지 않는다** —
지금은 `CalendarGrid.swift:19` 가 그날 마지막 경기 하나만 시트로 띄워 나머지는 접근할 방법이 없다.
상세는 하단 목록의 경기 행에서 연다.

- [ ] **Step 4: `CalendarView` 하단 목록**

```swift
struct CalendarView: View {
    let matches: [Match]
    let currentMonth: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    @Binding var selectedDate: Date?
    let onSelect: (Match) -> Void
    let onDelete: (Match) -> Void
}
```

`VStack` — 위는 `MonthHeader`+`WeekdayLabels`+`CalendarGrid`(고정), 아래는 선택 날짜의 세션.

```
선택 날짜의 경기 = matches.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: selectedDate) }
비어 있으면 → Text(history_day_empty)
아니면      → SessionList(sessions: group(그 경기들), isLoadingMore: false,
                          onLoadMore: nil, onSelect: onSelect, onDelete: onDelete)
```

> **`HistoryView` 의 `ScrollView` 를 없앤다.** 지금 `HistoryView:24` 가 `CalendarView` 를 `ScrollView` 로
> 감싸는데, 안에 `List`(`SessionList`)가 들어오면 스크롤이 중첩돼 높이가 무너진다. 캘린더는 고정,
> 스크롤은 `SessionList` 가 갖는다.

- [ ] **Step 5: 날짜 자동 선택**

`HistoryViewModel` 에 `@Published var selectedDate: Date?`.

- `loadInitial()` — 오늘
- `changeMonth(by:)` — **`loadCalendarMatches()` 를 먼저 부른 뒤** 그 달에서 경기가 있는 가장 최근 날짜를 고른다. 없으면 `nil`. 순서를 뒤집으면 이전 달 데이터로 고르게 된다

- [ ] **Step 6: 상세 시트 경로**

`HistoryView` 의 `.sheet(item: $selectedMatch)` 는 그대로 두고, 캘린더 쪽 `onSelect: { selectedMatch = $0 }` 로
연결한다. 목록 모드와 같은 시트를 공유한다. 삭제도 `onDelete: { pendingDelete = $0 }` 로 같은 다이얼로그를 탄다.

- [ ] **Step 7: 테스트**

`DayCellDotsTests` — `dotsMatchMatchCount` · `dotsCapAtFour` · `dotColorsFollowEachResult`.
`HistoryViewModelTests` 추가 — `selectsMostRecentMatchDayOnMonthChange` · `selectsNothingWhenMonthHasNoMatches`.

- [ ] **Step 8: 빌드·테스트·커밋** — `✨ 캘린더에 다중 점과 날짜별 세션 목록을 넣는다`

### Task 7: 기록 상세 — 스코어보드 · "이 경기" 섹션

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Features/History/Components/Scoreboard.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/History/Components/MatchDetailSheet.swift`

- [ ] **Step 1: `Scoreboard`**

행 2개(나 / 상대) × 열 = 세트. 이긴 행을 굵게 하고 승/패 표기를 행 안에 흡수한다. 현재는 "승" 28pt · 최종 스코어 22pt 로 위계가 뒤집혀 있다 — 그 자리를 스코어에 넘긴다.

`opponentName` 이 `nil` 이면 `match_detail_opponent`("상대"), 값이 있으면 그것을 쓴다. 입력 UI 는 만들지 않지만 코드 경로는 열어 둔다. 내 행 라벨은 `match_detail_me`.

세트가 없으면 `match_detail_no_sets` (#5 가 넣은 `history_no_set_data` 를 대체한다).

- [ ] **Step 2: `MatchDetailSheet` 섹션 재구성**

```
스코어보드 (Section, listRowBackground(.clear))
─ match_detail_section_this_match : 활동 kcal / 총 kcal / 경기시간 / 평균 bpm  (2×2)
─ match_detail_section_info       : 포맷 / 시간 범위
```

- **세트 섹션 삭제** — 스코어보드가 대신한다. 섹션이 넷에서 셋으로 준다.
- 4칸은 전부 **경기 구간값**(`caloriesBurned`·`totalCaloriesBurned`·`durationSeconds`·`averageHeartRate`). 누적값을 쓰지 않는다. 경기시간은 스톱워치 포맷(`WorkoutMetrics.formatSeconds`)을 그대로 둔다 — 여기는 누적이 아니다.
- 시간 범위 `14:30 ~ 15:22`. `endedAt` 이 `nil` 이면 시작 시각만.
- `history_field_format` · `history_field_date` → `match_detail_format` · `match_detail_time`.
  #5 가 하드코딩 `"Format"`·`"Date"` 를 이미 키로 올렸다. 형제 키가 전부 `match_detail_*` 라
  이름을 맞추고, `Date` 는 이번에 **시간 범위**로 의미가 바뀌므로 `match_detail_time` 이 맞다.
- 섹션 제목을 `summary_section_workout`("운동") 에서 `match_detail_section_this_match`("이 경기") 로 바꿔 세션 누적과 구분한다.
- **이 Step 이 키 5개를 죽인다** — `summary_section_workout`(다른 사용처였던 `WorkoutStatsGrid` 는 Task 4 에서 삭제됨), `match_detail_section_sets`(세트 섹션의 유일한 사용처), 그리고 #5 가 넣은 `history_field_format`·`history_field_date`·`history_no_set_data`. Task 8 에서 정리한다.

- [ ] **Step 3: 빌드·커밋** — `✨ 기록 상세를 가로 스코어보드와 '이 경기' 섹션으로 바꾼다`

---

### Task 8: 마무리 — 죽은 키 정리 · 전체 검증

- [ ] **Step 1: 죽은 키 7개 삭제**

`summary_period_today` · `summary_recent_matches` · `summary_section_workout` ·
`match_detail_section_sets` · `history_field_format` · `history_field_date` · `history_no_set_data`
**7개**를 `iOSApp/Localizable.xcstrings` 에서 지운다. 지우기 전에 참조가 없는지 확인한다.

```bash
grep -rnE 'summary_period_today|summary_recent_matches|summary_section_workout|match_detail_section_sets|history_field_format|history_field_date|history_no_set_data' Apps/TennisCounter/ --include='*.swift'
```

- [ ] **Step 2: 키 개수 확인** — iOS 카탈로그가 **86개**여야 한다 (76 + 17 − 7).

- [ ] **Step 3: 전체 검증**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test -only-testing:iosTests
make lint && make format
```

- [ ] **Step 4: 시뮬레이터 확인 (사람이 한다)**

- [ ] 기록이 하나도 없는 상태 — 요약 빈 상태 / 기록 빈 상태가 뜬다
- [ ] 세션 1개(경기 1개)·세션 여러 개(경기 3~4개) 둘 다 카드가 같은 리듬으로 그려진다
- [ ] 세션이 2개 이하일 때 차트 대신 안내 문구
- [ ] 경기 20개를 넘겨 스크롤 — **페이지 경계에서 세션 헤더가 두 번 나오지 않는다**
- [ ] **20번째 경계 부근의 경기를 지운 뒤 계속 스크롤 — 건너뛴 경기가 없다** (Task 5 Step 2 검증)
- [ ] 캘린더 모드에서 하단 목록이 스크롤되고 캘린더는 고정된다 (중첩 스크롤 아님)
- [ ] 캘린더 하단에서 경기 행을 탭하면 상세 시트, 스와이프하면 삭제 다이얼로그
- [ ] 스와이프 삭제 → 확인 다이얼로그 → 삭제. 세션의 마지막 경기를 지우면 헤더도 사라진다
- [ ] 캘린더에서 4경기 넘는 날 — 점 4개, 마지막이 회색
- [ ] 월을 넘기면 경기 있는 최근 날짜가 자동 선택된다. 경기 없는 달이면 빈 문구
- [ ] **라이트 모드 기기에서** 시트 그래버·삭제 다이얼로그·키보드가 어둡게 뜬다 (Task 1 검증)
- [ ] 옛 기록(`workoutSessionId == nil`, 누적값 `nil`)이 크래시 없이 단독 세션 + `–` 로 뜬다
- [ ] ko / en 두 로케일에서 문자열이 다 뜬다

- [ ] **Step 5: 커밋 + PR** — `🎨 죽은 문자열 키를 정리한다` 후 `gh pr create`

## 후속 (이번 PR 에 넣지 않는다)

- 타이브레이크 점수 저장 — `SetRecord` 가 게임 수만 갖는다. 워치·폰 저장 로직과 모델을 함께 고쳐야 한다
- 저장된 경기의 스코어 수정 — 편집 모드가 필요하다. 삭제만 먼저 넣는다
- 상대 이름 입력 UI — 반쪽만 태깅된 데이터는 없는 것보다 나쁘다. `Scoreboard` 의 코드 경로만 열어 둔다
- 최대 심박·거리·심박 존 — 새 수집이 필요하다
- 시간축(요일·월별) 차트, 차트 막대 탭 인터랙션
- 삭제 되돌리기(undo) — CloudKit 전파와 엮이면 복잡해진다. 확인 다이얼로그로 충분하다

## Self-Review

- 스펙의 공통 원칙 4개 → 값의 축(Global Constraints + Task 4·7), 색(Task 1 Step 5 + Task 3), 다크 모드(Task 1 Step 1·2), 누적 포맷(Task 1 Step 3) ✅
- 스펙의 변경 파일 → File Structure 에 반영. 스펙과 갈린 곳 8건은 §스펙 보정에 근거와 함께 ✅
- 스펙의 테스트 목록 22개 → Task 1·2·4·5·6 에 분배, `DayCellDots` 대상 파일 확정 ✅
- 선행·후행 — #5 String Catalog(선행), #1 공유 버튼(후행) ✅
- 모델 무변경 · CloudKit 마이그레이션 없음 ✅

**2026-09-08 구현 가능성 점검에서 고친 것**

| 결함 | 고친 곳 |
|---|---|
| `SessionCard` 하나로는 `Section(header:)` 를 못 만든다 — Task 3 과 Task 5 가 서로 다른 것을 요구했다 | §SessionCard 분해, Task 3·4·5 |
| 삭제하면 offset 페이징이 레코드를 건너뛴다 | Task 5 Step 2 |
| `CalendarGrid` 바인딩을 바꾼 뒤 상세 시트를 여는 경로가 끊긴다 | Task 6 Step 3·6 |
| `SessionList`(=`List`) 를 `ScrollView` 안에 넣으면 스크롤이 중첩된다 | Task 6 Step 4 |
| 죽는 키가 3개가 아니라 4개 (`match_detail_section_sets` 누락) | §스펙 보정, Task 7·8 |
| 스와이프 삭제 버튼 문구 `btn_delete` 가 저장소에 없다 — 신규 키 16 → 17 | §신규 문자열 키 |
| `SummaryStatsGrid` 의 `#Preview` 가 옛 `SummaryStats` 7인자로 컴파일 실패 | Task 4 Step 4 |
| 삭제 테스트에서 VM 과 싱글턴 서비스가 다른 컨테이너를 보면 통과하지 않는다 | Task 5 Step 8 |
| `SessionList` 시그니처·`CalendarView` 시그니처·`DayCell` 시그니처 미지정 | Task 5 Step 5, Task 6 Step 2·4 |
| 전적 줄·누적 시간 포맷 문자열의 위치 지정자 미지정 | §신규 문자열 키 |
