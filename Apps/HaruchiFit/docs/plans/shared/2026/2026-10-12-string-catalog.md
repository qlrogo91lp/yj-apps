# String Catalog 전환 구현 계획 (한국어 + 영어)

> **For agentic workers:** `superpowers:executing-plans`로 단계별 실행한다. 별도 사용자 지시 없이 서브에이전트를 생성하지 않는다. 체크박스로 진행 상태를 기록한다.

**상태:** 플랜 작성 (2026-10-12). 사용자 검토 전 — 구현 미착수.

**Goal:** 하루치 iOS · 워치 · 컴플리케이션의 화면 문자열을 String Catalog 으로 옮겨 한국어와 영어로 낸다.
한국어 화면은 지금과 **한 글자도 달라지지 않는다.**

**Architecture:** 코드의 한국어 리터럴을 의미 키(`tab_home`)로 바꾸고, 키마다 ko · en 값을 카탈로그에 둔다.
카탈로그는 문자열을 쓰는 코드가 사는 폴더에 하나씩 둔다 (5개). 날짜와 시각은 번역하지 않고 로케일 템플릿에 맡긴다.
문자열을 만드는 `Shared/Models` 빌더의 한국어 기대값 테스트는 테스트 스킴의 언어를 한국어로 고정해 그대로 살린다.

**Tech Stack:** Xcode 26 String Catalog (`.xcstrings`), `String(localized:table:)`, SwiftUI `LocalizedStringKey`,
`DateFormatter.setLocalizedDateFormatFromTemplate`, Swift Testing.

**선례:** [Ralli String Catalog 전환](../../../../../TennisCounter/docs/plans/shared/2026/2026-09-07-string-catalog-migration.md).
Ralli 는 있던 `.strings` 를 옮기는 일이었고, 하루치는 번역이 처음이라 **호출부를 전부 고친다.**

---

## 왜 하는가

1.0 을 스토어와 앱 모두 한국어 + 영어로 내기로 했다 (2026-10-12). 지금은 카탈로그가 `InfoPlist.xcstrings`
(권한 문구) 뿐이라 기기 언어와 무관하게 한국어만 나온다. 온보딩(01)은 이 작업 뒤에 한다 — 새 문자열이
처음부터 카탈로그로 들어가게.

## 현재 상태 (2026-10-12 실측)

한국어가 든 코드 줄 수 (주석 제외):

| 폴더 | 줄 수 | 붙는 타깃 | 성격 |
|---|---|---|---|
| `iOSApp/` | 107 | iOS | 화면 문자열. `print` · `fatalError` 5줄 포함 |
| `Shared/` | 41 | iOS · 워치 | 빌더가 문자열을 직접 만든다. 날짜 패턴 · 단위 포함 |
| `WatchApp/` | 11 | 워치 | 화면 문자열. `#Preview` 이름 2줄 포함 |
| `ComplicationApp/` | 3 | 컴플리케이션 | 위젯 문자열 |
| `Common/` | 2 | 세 타깃 | `근력` · `유산소` |

- 프로젝트 개발 언어는 `en`, `knownRegions` 에 `ko` 가 없다 (Ralli 에는 있다)
- 홈 화면 표시 이름이 `HaruchiFit` 하나뿐이다 — 붙여 쓴 형태라 `Haruchi Fit` 으로 띄운다. **표시 이름은 한국어 기기에서도 영어다** (2026-10-12 결정)
- `watchosTests/Models` 의 단언 61개가 한국어 표시 문자열을 기대값으로 쓴다 (8개 파일)
- `Packages/YJKit` 의 `WorkoutUI` · `WorkoutShareUI` 는 이미 ko · en 이 있다. **이 작업은 Kit 을 건드리지 않는다**

---

## 결정 사항

### D1. 키는 의미 키, 개발 언어는 `en` 유지 (Ralli 와 같다)

`Text("홈")` → `Text("tab_home")`. 카탈로그에 `tab_home` = ko `홈` / en `Home`.

- **한국어와 영어가 아닌 기기는 영어로 뜬다.** 지원하지 않는 언어의 폴백은 개발 언어다. 한국어 리터럴을 키로
  남기려면 개발 언어를 `ko` 로 바꿔야 하고, 그러면 일본어 · 프랑스어 사용자가 한국어 화면을 본다
- 문구를 고쳐도 키가 안 바뀐다. 리터럴이 키면 한국어를 한 글자 고칠 때마다 영어 번역이 끊어진다
- Ralli 와 규칙이 같다

**치르는 값** — 코드에서 한국어 문구가 사라진다. 화면의 글자를 찾으려면 카탈로그에서 키를 먼저 찾아야 한다.

### D2. 카탈로그는 폴더마다 하나 — 5개

폴더가 타깃 부착의 단위라(앱 `CLAUDE.md` "공유 폴더가 둘인 이유") 문자열도 그 단위를 따른다.

| 파일 | 테이블 이름 | 호출 |
|---|---|---|
| `iOSApp/Localizable.xcstrings` | (기본) | `Text("key")` · `String(localized: "key")` |
| `WatchApp/Localizable.xcstrings` | (기본) | 같다 |
| `ComplicationApp/Localizable.xcstrings` | (기본) | 같다 |
| `Shared/Shared.xcstrings` | `Shared` | `String(localized: "key", table: "Shared")` |
| `Common/Common.xcstrings` | `Common` | `String(localized: "key", table: "Common")` |

`Shared/` 와 `Common/` 의 파일 이름이 `Localizable` 이 아닌 이유 — iOS 앱에는 `iOSApp/` · `Shared/` · `Common/` 이
함께 붙는다. 같은 이름의 카탈로그가 한 타깃에 둘이면 리소스가 충돌한다.

### D3. 날짜와 시각은 번역하지 않는다 — 로케일 템플릿

`"M월 d일 (E)"` 같은 패턴을 카탈로그에 넣지 않고 `setLocalizedDateFormatFromTemplate` 로 바꾼다.
한국어 출력이 지금과 같은지 실측했다 (2026-08-22 19:12 기준):

| 지금 패턴 | 템플릿 | ko_KR | en_US | en_GB |
|---|---|---|---|---|
| `M월 d일 (E)` | `MMMdEEE` | 8월 22일 (토) | Sat, Aug 22 | Sat 22 Aug |
| `M월 d일` | `MMMd` | 8월 22일 | Aug 22 | 22 Aug |
| `yyyy년 M월 d일` | `yMMMd` | 2026년 8월 22일 | Aug 22, 2026 | 22 Aug 2026 |
| `yyyy년 M월 d일 (E)` | `yMMMdEEE` | 2026년 8월 22일 (토) | Sat, Aug 22, 2026 | Sat, 22 Aug 2026 |
| `yyyy년 M월` | `yMMMM` | 2026년 8월 | August 2026 | August 2026 |
| `a h:mm` | `jmm` | 오후 7:12 | 7:12 PM | 19:12 |

**템플릿으로 안 되는 두 곳은 한국어만 지금 패턴을 지킨다** — 제품 스펙이 표기를 못박았다.

| 곳 | 한국어 (그대로) | 그 밖의 언어 |
|---|---|---|
| 홈 상단 월 제목 | 패턴 `M월 yyyy` → `8월 2026` (스펙 02) | 템플릿 `yMMMM` → `August 2026` |
| 기록 상세 시간 범위 | 시간대 이름 `B` → `저녁 7:12 – 8:24` (스펙 04) | `DateIntervalFormatter` (시각 short) → `7:12 – 8:24 PM` |

영어의 `B` 는 `7:12 in the evening` 이 되어 헤더에 못 쓴다.

행의 날짜 + 시각(`8월 22일 (토) · 오후 7:12`)은 템플릿 하나(`MMMdEEEjmm`)로 만들면 한국어에서 가운뎃점이 빠지고
영어에 `at` 이 낀다. **날짜 템플릿과 시각 템플릿을 ` · ` 로 잇는다** — 한국어가 지금과 같다.

빌더의 `locale:` 기본값 `Locale(identifier: "ko_KR")` 과 뷰의 `ko_KR` 하드코딩 3곳은 `.current` 로 바꾼다.

### D4. 숫자 + 단위는 인자 있는 키

`"\(count)회"` → `String(localized: "count_workouts \(count)", table: "Shared")`. 카탈로그 키는 `count_workouts %lld`,
영어는 복수형 변형(`1 workout` / `2 workouts`)을 둔다.

- 소수는 **먼저 문자열로 만들어 넘긴다** — `String(format: "%.1f", …)` 결과를 `%@` 자리에. 키에 소수 지정자를 넣지 않는다
- **연도는 `String(year)` 로 넘긴다.** 정수 인자는 로케일 자릿수 구분이 붙어 `2,026` 이 된다
- 월 이름(`1월`…) · 요일 이름(`월`…)은 키로 두지 않고 로케일의 `shortMonthSymbols` · `shortWeekdaySymbols` 를 쓴다.
  요일은 지금처럼 월요일 시작 순서를 지킨다

### D5. 테스트는 언어를 한국어로 고정한다

`String(localized:)` 가 고르는 언어는 빌더에 넘긴 `locale` 이 아니라 **앱이 실행된 언어**다. CI 시뮬레이터는
영어라 그대로 두면 한국어 기대값 61개가 깨진다.

`HaruchiFitWatchTests` 스킴의 Test 액션에 언어 `ko` · 지역 `KR` 을 건다. 기대값은 그대로 살고, 한국어가 이 앱의
기준 표기라는 점과도 맞는다. 영어는 날짜 헬퍼의 로케일 단위 테스트(언어 고정과 무관)와 시뮬레이터 확인으로 본다.

### D6. 표시 문자열로 분기하지 않는다

`RecordsCalendarView` 가 `switch month.emptyMessage { case "아직 기록이 없어요": … }` 로 문자열을 비교한다.
번역하면 깨지는 구조라, 빌더가 **이유(enum)** 를 내고 뷰가 제목 · 설명 키를 고르도록 바꾼다.

### D7. 번역하지 않는 것

`print` 로그 · `fatalError` · `#Preview` 이름 · 주석 · 테스트 이름 · 브랜드 표기(`Haruchi Fit` 워치 홈 제목) · `kcal` · `h`.
브랜드 표기는 `Text(verbatim:)` 로 바꿔 카탈로그에 자동 추출되지 않게 한다.

---

## 용어

스토어 문구(`APPSTORE.md`)와 같은 말을 쓴다.

| 한국어 | 영어 | 메모 |
|---|---|---|
| 잔디 | grid | 스토어 · 권한 문구의 `activity grid` |
| 근력 / 유산소 | Strength / Cardio | |
| 운동 (횟수) | workout(s) | `12회` → `12 workouts` |
| 기록 | record · workout | 탭 이름은 `Records`, 빈 상태는 `No workouts yet` |
| 운동 구성 | Workout Mix | 근력 · 유산소 비율 |
| 부위 | Body Parts | |
| 메모 | Note | |
| 건강 앱 | Apple Health | |
| 워치 | Apple Watch | |
| 버리기 | Discard | |

## 문자열 표 — 영어 초안

**검토해 주실 부분이다.** 한국어 값은 지금 코드의 문자열 그대로다.

### `Common` 테이블 (2)

| 키 | ko | en |
|---|---|---|
| `segment_strength` | 근력 | Strength |
| `segment_cardio` | 유산소 | Cardio |

### `Shared` 테이블 (22)

| 키 | ko | en |
|---|---|---|
| `body_chest` | 가슴 | Chest |
| `body_back` | 등 | Back |
| `body_shoulders` | 어깨 | Shoulders |
| `body_arms` | 팔 | Arms |
| `body_legs` | 하체 | Legs |
| `body_core` | 코어 | Core |
| `count_workouts %lld` | %lld회 | 1: `%lld workout` · 그 외: `%lld workouts` |
| `duration_minutes %lld` | %lld분 | %lld min |
| `duration_hours %@` | %@시간 | %@ hr |
| `duration_under_minute` | 1분 미만 | Under 1 min |
| `chip_kind_minutes %@ %lld` | %1$@ %2$lld분 | %1$@ %2$lld min |
| `weekly_average %@` | 주 %@회 | %@ / week |
| `weekly_average_note_current` | 1월 1일부터 오늘까지의 기록을 주 단위로 환산해요. | Averaged per week from January 1 through today. |
| `weekly_average_note_past` | 선택한 연도 전체의 기록을 주 단위로 환산해요. | Averaged per week across the whole year. |
| `stats_empty_year %@` | %@년에는 아직 기록이 없어요 | No workouts in %@ yet |
| `stats_empty_all` | 아직 운동 기록이 없어요 | No workouts yet |
| `home_empty_week` | 이번 주는 아직 기록이 없어요 | No workouts this week yet |
| `home_milestone_first` | 워치에서 첫 운동을 기록해 보세요 | Record your first workout on Apple Watch |
| `home_milestone_progress %lld %lld` | %1$lld번째 운동을 기록하면 이번 주 구성이 보여요 · %2$lld회 남음 | Your weekly mix appears after %1$lld workouts · %2$lld to go |
| `list_this_week` | 이번 주 | This Week |
| `list_last_week` | 지난 주 | Last Week |
| `share_title_default` | 운동 | Workout |

달력 월 요약(`12회 · 9.2시간`)과 주 범위 제목(`9월 13일 – 9월 19일`)은 위 키와 날짜 템플릿을 코드에서 잇는다 — 키를 따로 두지 않는다.
시간 범위와 주 범위의 ` – ` 는 두 언어가 같아 코드에 그대로 둔다.

### iOS `Localizable` (88)

**공통**

| 키 | ko | en |
|---|---|---|
| `tab_home` | 홈 | Home |
| `tab_records` | 기록 | Records |
| `tab_statistics` | 통계 | Stats |
| `btn_ok` | 확인 | OK |
| `btn_cancel` | 취소 | Cancel |
| `btn_delete` | 삭제 | Delete |
| `btn_edit` | 편집 | Edit |
| `btn_save` | 저장 | Save |
| `btn_done` | 완료 | Done |

**실패 알림** (`AppAlert`)

| 키 | ko | en |
|---|---|---|
| `alert_save_failed_title` | 워치 기록을 저장하지 못했어요 | Couldn't save your watch workout |
| `alert_save_failed_message` | 다음 동기화 때 건강 앱에서 다시 가져와요. 근력·유산소 구분은 남지 않을 수 있어요. | It will be imported from Apple Health on the next sync. The strength and cardio split may be lost. |
| `alert_sync_failed_title` | 건강 앱 기록을 가져오지 못했어요 | Couldn't import from Apple Health |
| `alert_sync_failed_message` | 목록을 당겨서 다시 시도해 주세요. | Pull down on the list to try again. |
| `alert_delete_failed_title` | 기록을 삭제하지 못했어요 | Couldn't delete the record |
| `alert_edit_failed_title` | 변경 내용을 저장하지 못했어요 | Couldn't save your changes |
| `alert_retry_later` | 잠시 후 다시 시도해 주세요. | Please try again in a moment. |

**홈**

| 키 | ko | en |
|---|---|---|
| `home_add_manual` | 수동 기록 추가 | Add Workout Manually |
| `home_this_week` | 이번 주 | This Week |
| `home_stat_month` | 이번 달 | This Month |
| `home_stat_total` | 전체 누적 | All Time |
| `home_recent` | 최근 기록 | Recent |
| `home_show_all` | 전체 보기 › | See All › |
| `home_recent_empty` | 아직 기록이 없어요 | No workouts yet |

**기록 탭 · 달력**

| 키 | ko | en |
|---|---|---|
| `records_mode_picker` | 보기 | View |
| `records_mode_calendar` | 달력 | Calendar |
| `records_mode_list` | 목록 | List |
| `records_delete_confirm` | 이 기록을 삭제할까요? | Delete this record? |
| `records_delete_note_manual` | 삭제한 수동 기록은 복구할 수 없어요. | A manually added record can't be recovered once deleted. |
| `records_delete_note_health` | 건강 앱의 운동 기록은 그대로 남아요. | The workout stays in Apple Health. |
| `records_empty_title` | 아직 기록이 없어요 | No workouts yet |
| `records_empty_message` | 워치에서 운동하거나 홈의 + 버튼으로 기록해 보세요. | Work out with your Apple Watch, or tap + on Home to add one. |
| `calendar_empty_month_title` | 이 달에는 기록이 없어요 | No workouts this month |
| `calendar_empty_month_message` | 다른 달을 선택해 보세요. | Try another month. |
| `calendar_empty_day_title` | 이 날에는 기록이 없어요 | No workouts on this day |
| `calendar_empty_day_message` | 다른 날짜를 선택해 보세요. | Try another day. |
| `calendar_prev_month` | 이전 달 | Previous month |
| `calendar_next_month` | 다음 달 | Next month |
| `calendar_day_a11y_none` | 운동 기록 없음 | No workouts |
| `calendar_day_a11y_workouts %lld %lld` | 운동 %1$lld회, %2$lld분 | 1: `%1$lld workout, %2$lld min` · 그 외: `%1$lld workouts, %2$lld min` |
| `calendar_day_a11y_today` | 오늘 | Today |
| `calendar_day_a11y_selected` | 선택됨 | Selected |

**기록 상세**

| 키 | ko | en |
|---|---|---|
| `detail_total_time` | 총 시간 | Total Time |
| `detail_avg_heart_rate` | 평균 심박 | Avg Heart Rate |
| `detail_composition` | 운동 구성 | Workout Mix |
| `detail_body_parts` | 부위 | Body Parts |
| `detail_memo` | 메모 | Note |
| `detail_memo_placeholder` | 메모 추가하기… | Add a note… |

**수동 기록**

| 키 | ko | en |
|---|---|---|
| `manual_title_add` | 수동 기록 추가 | Add Workout |
| `manual_title_edit` | 기록 편집 | Edit Workout |
| `manual_when` | 언제 | When |
| `manual_how_long` | 얼마나 | Duration |
| `manual_minutes_unit` | 분 | min |
| `manual_start_hint` | 운동을 시작한 날짜와 시각을 입력해 주세요. | Enter the date and time you started. |
| `manual_kind` | 유형 | Type |
| `manual_body_parts_optional` | 부위 · 선택 | Body Parts · Optional |
| `manual_memo_optional` | 메모 · 선택 | Note · Optional |
| `manual_error_title` | 저장할 수 없어요 | Can't Save |
| `manual_error_duration` | 운동 시간은 1분부터 24시간까지 입력해 주세요. | Enter a duration between 1 minute and 24 hours. |
| `manual_error_future` | 운동이 끝난 시각이 현재보다 늦어요. | The workout can't end in the future. |
| `manual_error_save` | 변경 내용을 저장하지 못했어요. 잠시 후 다시 시도해 주세요. | Couldn't save your changes. Please try again in a moment. |

**통계**

| 키 | ko | en |
|---|---|---|
| `stats_empty_message` | 워치에서 운동을 기록하면 한 해의 흐름을 볼 수 있어요. | Record workouts on your Apple Watch to see your year take shape. |
| `stats_grass` | 연간 잔디 | Year Grid |
| `stats_count_current` | 올해 운동 | Workouts This Year |
| `stats_count_past` | 연간 운동 | Workouts |
| `stats_duration_current` | 올해 누적 | Time This Year |
| `stats_duration_past` | 연간 누적 | Total Time |
| `stats_weekly_average` | 주 평균 | Weekly Average |
| `stats_monthly` | 월별 운동 | By Month |
| `stats_weekday` | 요일 패턴 | By Weekday |
| `stats_composition` | 운동 구성 | Workout Mix |
| `stats_composition_empty` | 구성 시간이 있는 기록이 없어요 | No workouts with a strength or cardio split |
| `stats_body_parts` | 운동 부위 | Body Parts |
| `stats_body_parts_note` | 부위를 태그한 운동 횟수예요. 한 운동은 여러 부위에 포함될 수 있어요. | Number of workouts tagged with each body part. One workout can count toward several. |
| `stats_milestones` | 연간 마일스톤 | Yearly Milestones |
| `stats_milestone_remaining %lld` | %lld회 남음 | %lld to go |
| `stats_milestone_achieved_a11y %lld` | %lld회 달성 | 1: `%lld workout reached` · 그 외: `%lld workouts reached` |
| `stats_milestone_remaining_a11y %lld %lld` | %1$lld회, %2$lld회 남음 | %1$lld workouts, %2$lld to go |
| `chart_item` | 항목 | Item |
| `chart_count` | 횟수 | Count |
| `chart_body_part` | 부위 | Body Part |
| `grass_legend_less` | 적음 | Less |
| `grass_legend_more` | 많음 | More |
| `grass_legend_a11y` | 운동량 적음에서 많음까지 네 단계 | Four levels, from less to more activity |
| `grass_level_none` | 운동 없음 | No workout |
| `grass_level_light` | 운동량 적음 | Light activity |
| `grass_level_medium` | 운동량 보통 | Moderate activity |
| `grass_level_heavy` | 운동량 많음 | High activity |
| `grass_level_peak` | 운동량 매우 많음 | Very high activity |

키를 두지 않고 코드에서 잇는 것 — 구성 범례(`근력 75.5h (64%)` 는 `SegmentKind.title` + 값), 마일스톤 목표와 차트 막대
접근성 라벨의 횟수(`Shared` 의 `count_workouts`), 달력 날짜 머리줄(`8월 22일 (토) · 2회`), 잔디 칸 접근성 라벨의 날짜.

### 워치 `Localizable` (7)

| 키 | ko | en |
|---|---|---|
| `start_workout` | 운동 시작 | Start Workout |
| `start_kind_label` | 시작 운동 | Start With |
| `summary_title` | 운동 완료 | Workout Complete |
| `summary_discard_confirm` | 이 기록을 버릴까요? | Discard this workout? |
| `btn_discard` | 버리기 | Discard |
| `btn_cancel` | 취소 | Cancel |
| `btn_save` | 저장 | Save |

요약의 구간 문구(`근력 54분`)는 `Shared` 의 `chip_kind_minutes` 를 쓴다 — iOS 행의 칩과 같은 키다.

### 컴플리케이션 `Localizable` (3)

| 키 | ko | en |
|---|---|---|
| `complication_start` | 운동 시작 | Start Workout |
| `complication_name` | Haruchi Fit | Haruchi Fit |
| `complication_description` | 진행 중인 운동을 보여줍니다. | Shows your workout in progress. |

### `InfoPlist.xcstrings` — 표시 이름 (iOS · 워치)

| 키 | ko | en |
|---|---|---|
| `CFBundleDisplayName` | Haruchi Fit | Haruchi Fit (지금은 `HaruchiFit`) |

**표시 이름은 한국어 기기에서도 영어다.** 한국어 값을 따로 번역하지 않고 두 언어를 같은 값으로 둔다 —
홈 화면 아이콘, 워치 앱 목록, 컴플리케이션 이름(`complication_name`)이 모두 `Haruchi Fit` 이다.
스토어 이름의 한국어 표기(`하루치 핏 — 운동 잔디 기록`)와는 별개다.
`CFBundleName` 과 권한 문구는 그대로 둔다.

---

## Global Constraints

- **한국어 화면과 한국어 기대값 테스트는 바뀌지 않는다.** 한국어 값을 다듬지 않는다 — 다듬을 것이 보이면 기록만 한다
- `Packages/YJKit` 을 건드리지 않는다
- ViewModel 과 `Shared/` · `Common/` 은 SwiftUI 를 import 하지 않는다 — `String(localized:)` 는 Foundation 이다
- 카탈로그의 모든 키는 `ko` · `en` 둘 다 `translated` 상태여야 한다. 한쪽만 있는 키를 남기지 않는다
- 모든 빌드/테스트는 워크스페이스 기준, 시뮬레이터는 UDID 를 지정한다
- 브랜치 · 커밋 · PR 은 사용자 승인 범위 안에서만 한다

## Review Focus

1. **같은 키가 두 카탈로그에 필요한데 한쪽에만 있다** — `btn_cancel` · `btn_save` 는 iOS 와 워치 양쪽 카탈로그에 따로 있어야 한다.
   없으면 키 이름이 화면에 그대로 뜬다 (빌드는 통과한다). Task 5 의 검사 스크립트가 잡는다
2. **테이블 이름을 빠뜨린 호출** — `Shared/` 코드가 `table: "Shared"` 없이 부르면 기본 테이블에서 찾다가 키가 그대로 뜬다
3. **정수 인자의 자릿수 구분** — 연도가 `2,026` 으로 나오지 않는지 (D4)
4. **컴플리케이션 타깃 링크** — `Common.xcstrings` 가 컴플리케이션 번들에도 들어가는지. `Shared/` 의 것을 `Common/` 코드가 부르면 위젯에서만 깨진다
5. **영어에서 넘치는 곳** — Task 5 수동 확인 목록

## 실행 전 준비와 Git 범위

- [ ] 최신 `main` 에서 브랜치 `feat/haruchi-string-catalog` 를 만든다. 메인 체크아웃 하나로 순차 진행한다 (워크트리 불필요)
- [ ] 커밋은 Task 단위. PR 하나로 올리고 머지는 사용자 확인 뒤에 한다

---

## Task 1 — 카탈로그 5개와 프로젝트 설정

**Files**

- Create: `iOSApp/Localizable.xcstrings` · `WatchApp/Localizable.xcstrings` · `ComplicationApp/Localizable.xcstrings`
  · `Shared/Shared.xcstrings` · `Common/Common.xcstrings`
- Modify: `iOSApp/InfoPlist.xcstrings` · `WatchApp/InfoPlist.xcstrings` — `CFBundleDisplayName` 의 ko · en
- Modify: `HaruchiFit.xcodeproj/project.pbxproj` — `knownRegions` 에 `ko` 한 줄 (Ralli 와 같은 상태로)

**할 일**

- [ ] 위 "문자열 표" 를 그대로 카탈로그 JSON 으로 쓴다. `sourceLanguage` 는 `en`, 모든 항목 `extractionState: manual`,
      ko · en 둘 다 `state: translated`. 복수형은 `variations.plural` 의 `one` / `other`
- [ ] 이 시점에는 코드가 키를 부르지 않는다 — 빌드가 통과하고 화면은 그대로 한국어다
- [ ] 세 스킴 빌드 후 **빌드 산출물에 `ko.lproj` · `en.lproj` 가 둘 다 있는지** 본다 (iOS 앱 · 워치 앱 · 컴플리케이션)
- [ ] `ComplicationApp/` 는 `Info.plist` 가 들어 있는 폴더다 — 카탈로그가 리소스로 잡히는지 산출물에서 확인한다

## Task 2 — `Common` · `Shared` 의 문자열과 날짜

**Files**

- Create: `Shared/Models/DisplayDateFormat.swift` — 날짜 · 시각 표기 한 곳 (D3). 템플릿 종류별 포매터, 홈 월 제목, 시간 범위
- Create: `Shared/Models/RecordCalendarEmptyState.swift` — `noRecords` · `emptyMonth` · `emptyDay` (D6)
- Modify: `Common/SegmentKind.swift` — `title` 이 `Common` 테이블을 읽는다
- Modify: `Shared/Models/BodyPart.swift` — `title`
- Modify: `Shared/Models/RecordListBuilder.swift` — 날짜 템플릿, `이번 주` · `지난 주`, `locale` 기본값. 기존 `formatter(_:calendar:locale:)` 는
  호출부가 다 옮겨 가면 지운다
- Modify: `Shared/Models/RecordListRow.swift` — 칩 문구
- Modify: `Shared/Models/RecordDetailBuilder.swift` — 날짜, 시간 범위, `1분 미만` · `N분`
- Modify: `Shared/Models/HomeDashboardBuilder.swift` — 월 제목, 횟수 · 시간, 마일스톤, 빈 주 문구
- Modify: `Shared/Models/RecordCalendarBuilder.swift` — 월 제목, 월 요약, `RecordCalendarMonth.emptyMessage: String?` → `emptyState: RecordCalendarEmptyState?`
  (`RecordCalendarMonth` 도 이 파일에 정의돼 있다)
- Modify: `Shared/Models/StatisticsBuilder.swift` — 횟수 · 시간 · 주 평균 · 설명 · 빈 문구, 월 · 요일 이름을 로케일 심볼로
- Modify: `Shared/Models/RecordShareBuilder.swift` — 기본 제목
- Modify: `HaruchiFit.xcodeproj/xcshareddata/xcschemes/HaruchiFitWatchTests.xcscheme` — Test 액션 언어 `ko` · 지역 `KR` (D5)
- Modify: `watchosTests/Models/RecordCalendarBuilderTests.swift` — 빈 상태 단언을 enum 으로
- Create: `watchosTests/Models/DisplayDateFormatTests.swift`

**순서 (TDD)**

- [ ] **스킴 언어 고정을 먼저 한다.** Xcode ▸ Edit Scheme ▸ Test ▸ Options 의 App Language / Region 을 바꾸고 생긴 diff 를 커밋한다.
      고정한 뒤 코드를 안 바꾼 채로 테스트가 그대로 통과하는지 본다
- [ ] `DisplayDateFormatTests` 를 먼저 쓴다 — D3 표의 ko_KR · en_US 출력, 홈 월 제목 두 언어, 시간 범위(ko 는 같은 시간대면 끝 시각에 이름 생략,
      en 은 `7:12 – 8:24 PM`), 날짜 + 시각 잇기. 로케일을 인자로 넘기므로 실행 언어와 무관하다
- [ ] `DisplayDateFormat` 구현 → 빌더의 날짜 패턴을 하나씩 교체. **교체할 때마다 기존 한국어 기대값 테스트가 그대로 통과해야 한다**
- [ ] 단위 · 문구를 키로 교체 (D4). 연도는 `String(year)`
- [ ] 달력 빈 상태를 enum 으로 (D6). 이 Task 에서는 iOS 뷰가 깨지므로 뷰의 `switch` 를 enum 에 맞춰 최소로 고친다 — 문구 키 교체는 Task 3
- [ ] `HaruchiFitWatchTests` 전체 통과. **시뮬레이터 언어가 영어인 상태에서도 통과하는지** 확인한다 (CI 조건)

## Task 3 — iOS 화면

**Files** (전부 Modify)

- `iOSApp/ContentView.swift` — 탭 3개, 알림 확인 버튼
- `iOSApp/AppAlert.swift` — 제목 · 본문
- `iOSApp/Features/Home/HomeView.swift` · `Components/WeekCompositionBar.swift` · `Components/AccumulationStats.swift` · `Components/RecentRecordsSection.swift`
- `iOSApp/Features/Records/RecordsView.swift` · `RecordsViewModel.swift`
- `iOSApp/Features/Records/Calendar/RecordsCalendarView.swift` · `Components/RecordMonthHeader.swift` · `Components/RecordDayCell.swift`
- `iOSApp/Features/Records/Detail/RecordDetailView.swift`
- `iOSApp/Features/Records/Manual/ManualRecordView.swift`
- `iOSApp/Features/Statistics/StatisticsView.swift` · `Components/AnnualComposition.swift` · `AnnualMilestones.swift` · `StatisticsFrequencyChart.swift`
  · `BodyPartFrequencyChart.swift` · `AnnualSummary.swift` · `AnnualGrass.swift`

**할 일**

- [ ] SwiftUI 리터럴 자리(`Text` · `Label` · `Button` · `Section` · `navigationTitle` · `confirmationDialog` · `alert` · `Picker` · `TextField` 자리 표시)는 키 리터럴로
- [ ] `String` 을 받는 자리(헬퍼 함수 인자, `accessibilityLabel` 에 보간하는 곳, ViewModel)는 `String(localized:)` 로
- [ ] `stat("이번 달", month)` 같은 **헬퍼가 `String` 을 받아 `Text(문자열)` 로 그리는 곳**은 키가 번역되지 않고 그대로 뜬다.
      헬퍼 인자를 `LocalizedStringKey` 로 바꾸거나 호출부에서 `String(localized:)` 로 넘긴다 — 파일마다 확인한다
- [ ] `ko_KR` 하드코딩 3곳(`AnnualGrass` · `RecordDayCell` · `RecordsCalendarView`)을 `DisplayDateFormat` 으로
- [ ] `AnnualGrass` 의 월 눈금(`1 · 4 · 7 · 10 · 12월`)을 로케일 짧은 월 이름으로
- [ ] `HaruchiFit` 스킴 빌드

## Task 4 — 워치와 컴플리케이션

**Files** (전부 Modify)

- `WatchApp/Features/Workout/Start/StartView.swift` — `운동 시작` · `시작 운동`, `Haruchi Fit` 은 `Text(verbatim:)`
- `WatchApp/Features/Workout/Summary/SummaryView.swift` — 제목, 버리기 확인, 버튼, 구간 문구(`Shared` 의 `chip_kind_minutes`)
- `ComplicationApp/HaruchiComplicationExtension.swift` — `운동 시작`, 표시 이름, 설명

**할 일**

- [ ] 키 교체. 세션 화면의 일시정지 · 종료는 YJKit `WorkoutUI` 가 그린다 — 건드리지 않는다
- [ ] `HaruchiFitWatchTests` 테스트, `HaruchiComplicationExtension` 빌드

## Task 5 — 검증과 문서

**Files**

- Modify: `Apps/HaruchiFit/CLAUDE.md` — "문자열" 절: 의미 키, 카탈로그 5개와 테이블 이름, 날짜는 `DisplayDateFormat`, 테스트 언어 고정
- Modify: `TODO.md` · 이 플랜의 상태 줄

**자동 검사**

- [ ] **남은 한국어 리터럴** — `grep` 으로 다섯 폴더를 훑어 남은 줄이 D7 의 예외(`print` · `fatalError` · `#Preview`)뿐인지
- [ ] **카탈로그 완결성** — 스크립트(일회용, 스크래치패드)로 ① 모든 키에 ko · en 이 있는지 ② 코드가 부르는 키가 그 타깃에 붙는 카탈로그에 있는지
      ③ 카탈로그에만 있고 아무도 안 부르는 키가 없는지
- [ ] `make lint` · `make format`, 세 스킴 빌드, `HaruchiFitWatchTests` 테스트

**시뮬레이터 수동 확인 (사용자)** — 기기 언어를 바꿔 가며 본다

- [ ] **한국어** — 모든 탭이 전환 전과 같다. 특히 홈 월 제목 `8월 2026`, 상세 시간 범위 `저녁 7:12 – 8:24`, 행 날짜 `8월 22일 (토)`
- [ ] **영어** — 키 이름(`tab_home` 같은 밑줄 글자)이 화면에 보이는 곳이 없다
- [ ] **영어에서 넘치기 쉬운 곳** — 통계 요약 3칸(`Workouts This Year`), 월별 차트 축(`Jan`…`Dec` 12개), 홈 마일스톤 한 줄,
      수동 기록 섹션 제목, 워치 `Start Workout` 캡슐과 `Workout Complete`, 사각 컴플리케이션의 `Start Workout`
- [ ] **일본어 등 미지원 언어** — 영어로 뜨고 날짜도 영어 표기로 나온다 (D1 · D3)
- [ ] 홈 화면 아이콘 이름이 한국어 기기와 영어 기기 모두 `Haruchi Fit`
- [ ] 공유 카드 제목이 영어 기기에서 `Strength · Cardio`

## 완료 조건

- 한국어 기기의 화면과 `HaruchiFitWatchTests` 의 기존 한국어 기대값이 전환 전과 같다
- 영어 기기에서 모든 화면이 영어로 나오고 키 이름이 노출되는 곳이 없다
- 다섯 폴더에 번역 대상 한국어 리터럴이 남아 있지 않다
- 새 화면 문자열을 어디에 어떻게 넣는지가 앱 `CLAUDE.md` 에 적혀 있다

## 범위 밖

- 한국어 문구 다듬기, 영어 외 언어 추가
- YJKit 의 문자열
- 워치 워크아웃 권한 문구 · 건강 앱 권한 문구 (이미 ko · en 이 있다)
- 온보딩 문자열 — 01 온보딩 플랜이 이 카탈로그에 더한다
