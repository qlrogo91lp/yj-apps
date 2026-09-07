# iOS 요약·기록·기록 상세 화면 개선

작성일: 2026-08-25
대상 타겟: `TennisCounter` (iOS)

## 배경

1.1.7 출시 이후 첫 화면 개선이다. 사용자 유입이 본격화되기 전에 요약·기록·기록 상세
세 화면의 정보 구성과 표현을 다시 잡는다.

현재 문제는 세 가지로 요약된다.

1. **위계가 없다.** 요약이 같은 색·같은 크기 카드 7개를 나열한다. 무엇이 중요한지
   드러나지 않고, 실제로 담긴 지표는 4종뿐인데 화면만 무겁다.
2. **같은 라벨이 화면마다 다른 값을 가리킨다.** "활동 kcal"이 요약에서는 워크아웃 누적,
   기록 상세에서는 경기 구간값이다. 두 화면을 오가면 숫자가 어긋나는데 이유를 알 수 없다.
3. **기록 화면이 세션 개념을 모른다.** 데이터 모델은 `workoutSessionId`로 한 워크아웃의
   경기들을 묶고 요약도 그 단위로 합산하는데, 기록 목록만 경기를 평평하게 나열한다.

## 목표

- 운동 리포트를 중심에 두고 전적은 보조로 둔다. 앱이 실제로 잘 쌓는 데이터가 운동 지표이고,
  전적은 상대 식별자가 없어 깊이가 없다.
- 화면마다 담당하는 값의 축을 하나로 고정해 라벨 충돌을 구조적으로 없앤다.
- 기록의 단위를 세션으로 바꿔 데이터 모델과 UI의 어긋남을 없앤다.

## 범위

**포함** — 요약·기록·기록 상세 화면의 정보 구성과 표현, 기록 삭제, 다크 모드 고정 정리.

**제외** — 아래는 이번 작업에서 다루지 않는다.

| 항목 | 이유 |
|---|---|
| 타이브레이크 점수 저장 | `SetRecord`가 게임 수만 갖는다. 워치·폰 저장 로직과 모델을 함께 고쳐야 해 범위가 크다 |
| 저장된 경기의 스코어 수정 | 편집 모드를 새로 만들어야 한다. 삭제만 먼저 넣는다 |
| 상대 이름 입력 UI | 반쪽만 태깅된 데이터는 없는 것보다 나쁘다. 온라인 대전이 열려 상대가 자동으로 붙을 때 시작한다 |
| 최대 심박·거리·심박 존 | 새 수집이 필요하다. 지금 지표만으로 재편한다 |
| 시간축(요일·월별) 차트 | 실제 사용자 플레이 빈도를 아직 모른다. 빈도 가정에 흔들리지 않는 세션축을 먼저 쓴다 |
| 차트 막대 탭 인터랙션 | 1차는 표시 전용 |

## 공통 원칙

### 1. 값의 축을 화면별로 고정한다

`Match`는 두 축의 값을 모두 갖는다. 어느 축을 쓰는지가 화면마다 고정되어야 한다.

| 축 | 필드 | 쓰는 곳 |
|---|---|---|
| 세션 누적 | `workoutElapsedSeconds`, `workoutCaloriesBurned`, `workoutTotalCaloriesBurned` | 요약, 기록 목록의 세션 헤더 |
| 경기 구간 | `durationSeconds`, `caloriesBurned`, `totalCaloriesBurned` | 기록 상세 |

세션 누적값은 같은 `workoutSessionId`를 가진 경기들이 하나의 누적 축을 공유하므로,
**그룹당 최댓값 하나만** 취한다. 이 규칙은 `SummaryViewModel.sumOfWorkoutMaxima`에 이미 있고
기록 화면도 같은 규칙을 쓴다.

기록 상세의 운동 섹션 헤더는 "이 경기"로 표기해 경기 구간값임을 명시한다.

### 2. 색은 의미에만 쓴다

| 역할 | 색 |
|---|---|
| 나 / 승 | 초록 |
| 상대 / 패 | 주황 |
| 액센트 (차트 막대, 선택된 날짜) | `Color.brand` (라임) |
| 통계 숫자 | 흰색 |
| 라벨·보조 정보 | 회색 |

지금 통계 카드가 전부 `.green`이라 초록이 "나/승"과 "통계 강조" 두 뜻을 겸한다. 통계 숫자에서
색을 걷어내고 크기·굵기로 위계를 만든다. 초록이 한 뜻만 갖게 되면 스코어보드가 선명해진다.

`Color.brand`는 현재 런치스크린과 워크아웃 인디케이터 2곳에만 쓰인다. 차트 막대와 캘린더
선택 상태에 쓰면서 본문에 존재감을 만든다.

### 3. 다크 모드를 앱 전체에 고정한다

`MainTabView`가 `.colorScheme(.dark)`를 쓰는데 이는 SwiftUI 하위 트리에만 적용되고 윈도우의
인터페이스 스타일은 바꾸지 않는다. `Info.plist`에도 `UIUserInterfaceStyle`이 없다. 그래서
라이트 모드 사용자에게는 시스템이 그리는 요소(시트 그래버, 알림창, 키보드, 컨텍스트 메뉴)가
밝게 뜬다. 이번에 삭제 확인 다이얼로그를 추가하므로 바로 드러난다.

- `Info.plist`에 `UIUserInterfaceStyle = Dark` 추가
- `.colorScheme(.dark)` → `.preferredColorScheme(.dark)`

### 4. 누적 시간 포맷을 새로 둔다

`WorkoutMetrics.formatSeconds`는 스톱워치 포맷(`시:분:초`)이다. 경기 중 타이머용으로는 맞지만
누적 통계에 쓰면 `03:12:40`처럼 불필요한 초가 붙고, 전체 누적에서는 `470:00:00`이 되어 카드에서
넘친다. 누적 전용 포맷을 새로 만들고 `formatSeconds`는 타이머용으로 그대로 둔다.

| 범위 | 한국어 | 영어 |
|---|---|---|
| 1시간 미만 | `42분` | `42m` |
| 1~99시간 | `18시간 42분` | `18h 42m` |
| 100시간 이상 | `470시간` | `470h` |

칼로리는 천단위 콤마를 넣는다 (`234,320`). `StatCard`에 `minimumScaleFactor(0.6)`이 이미 걸려
있어 자릿수가 더 늘어도 깨지지 않는다.

## 화면 설계

### 요약 (Summary)

```
[ 이번 주 | 이번 달 | 전체 ]

┌────────┐ ┌────────┐ ┌────────┐
│ 경기 수 │ │ 운동시간 │ │ 활동 kcal│
│   12   │ │18시간42분│ │  6,240  │
└────────┘ └────────┘ └────────┘

8승 4패 · 67%

최근 추이
▁▃▅▂▆▄▇▅▃▆   (최근 10회 세션 운동시간)

최근 세션
[ 세션 카드 ]
```

**기간 필터** — `오늘`을 빼고 `전체`를 넣는다. `오늘`은 어떤 플레이 빈도에서도 대부분 0이고,
오늘 친 경기는 하단 최근 세션이 이미 답한다. 반대로 전체 누적("총 42회, 68시간")은 지금
어디서도 볼 수 없는 숫자이며 저빈도 운동일수록 동기부여가 크다.

`SummaryPeriod`를 `.week` / `.month` / `.all`로 바꾼다. `.all`은 `startDate`가 `nil`이라
필터 없이 전체를 반환한다. 기본값은 `.week`를 유지한다. `summary_period_all` 문자열은 이미
정의되어 있으나 쓰이지 않고 있다.

**통계 3칸** — 경기 수 / 운동시간 / 활동 kcal.

- 승·승률 카드 2개를 제거한다. 경기 수에서 파생되는 값이라 카드 3칸을 쓸 이유가 없다.
- 총 kcal를 제거한다. 활동 kcal와 나란히 두면 차이를 알 방법이 없다. 기록 상세에만 남긴다.
- 평균 심박을 제거한다. 여러 경기 평균의 평균은 경기 길이 가중이 없어 의미가 흐려진다.
  심박은 경기 단위로 봐야 쓸모 있으므로 기록 상세에 둔다.

**전적 한 줄** — `8승 4패 · 67%`. 온라인 대전이 열리면 이 자리를 헤드투헤드·랭킹으로 확장하거나
독립 화면으로 들어낼 수 있도록 블록 하나로 유지한다.

**최근 추이 차트** — 최근 10개 세션의 누적 운동시간을 막대로 그린다 (Swift Charts, iOS 17 타겟).

- x축은 시간이 아니라 **세션 회차**다. 주 3회면 최근 10회가 약 3주치, 주 1회면 10주치로,
  플레이 빈도와 무관하게 항상 채워진다. 요일·월별 막대는 저빈도 사용자와 신규 사용자에게
  빈 칸만 보여준다.
- 빈도 정보는 이미 통계 3칸의 경기 수와 기록 탭 캘린더가 담당한다. 차트는 "얼마나 오래 쳤나"를
  맡아 역할이 겹치지 않는다.
- x축 라벨은 세션 날짜(`8/24`), 막대 색은 `Color.brand`.
- 세션이 3개 미만이면 차트 대신 안내 문구를 띄운다.
- 기간 필터와 무관하게 항상 최근 10개를 본다. 섹션 제목에 "최근 10회"를 명시해 독립 블록으로
  읽히게 한다.

**최근 세션** — 기록 목록과 같은 `SessionCard`로 가장 최근 세션 하나를 표시한다. 현재의
"최근 경기 2개"를 대체한다. 카드 스타일이 두 벌 생기지 않도록 컴포넌트를 공유하며,
래퍼(`RecentMatchList`) 없이 `SummaryView`가 직접 쓴다.

**빈 상태** — 선택한 기간에 경기가 없으면 통계·차트·최근 세션을 숨기고 `summary_no_matches`를
띄운다. 현재 이 문자열은 정의되어 있으나 쓰이지 않아 0과 `–`만 남은 화면이 나온다.

### 기록 (History)

기록의 단위를 경기에서 **세션**으로 바꾼다.

```
8월 24일 (일)              1시간 52분 · 840 kcal
  승   6-4  4-6  6-3
  패   3-6  4-6
  승   6-2

8월 21일 (목)                    48분 · 310 kcal
  승   6-3
```

**세션 그룹핑**

- `workoutSessionId`가 같은 경기를 한 세션으로 묶는다.
- `workoutSessionId`가 `nil`인 기록(누적값 도입 이전)은 각자 단독 세션으로 둔다.
- 세션 정렬은 세션 내 최신 `startedAt` 기준 내림차순, 세션 안의 경기는 `startedAt` 오름차순.

**세션 헤더** — 날짜(요일) + 누적 운동시간 + 누적 활동 kcal.

전적과 경기 수는 넣지 않는다. 아래 경기 행을 세면 나오는 값이라 헤더는 아래에 없는 정보만
갖는 편이 역할이 선명하다. 목록은 스캔하는 화면이므로 심박·시작 시각처럼 궁금해진 다음에
보는 값은 상세로 미룬다.

세션은 항상 펼쳐둔다. 세션당 경기가 보통 1~4개라 접어서 아낄 공간이 적고 탭만 늘어난다.
경기가 하나뿐인 세션도 예외 없이 헤더 + 경기 행으로 그려 목록의 리듬을 유지한다.

**경기 행** — 승/패 + 세트별 게임 스코어.

- 세트합계(`2-1`)는 넣지 않는다. 게임 스코어에서 세면 나오는 파생값이고, 1세트 경기에서는
  항상 `1-0`/`0-1`이라 아무 말도 하지 않는다. 현재 `MatchCard`가 1세트일 때 세트합계를 숨기는
  예외를 두고 있는 것 자체가 이 값이 약하다는 신호다.
- 승/패 텍스트에만 색을 쓴다. 게임 스코어는 기본색으로 두고 **내가 이긴 세트의 숫자만 굵게**
  한다. 색을 더 쓰면 목록이 시끄러워지지만 굵기는 조용히 읽힌다.
- 5세트까지 한 줄에 들어간다 (`6-4 4-6 6-3 7-5 6-2`).

**페이지네이션**

현재 `HistoryViewModel`은 경기 20개 단위로 페이징한다. 세션 단위로 그리면 페이지 경계에서
한 세션이 두 페이지로 쪼개져 헤더가 중복 출력된다. 경기 단위 페칭은 유지하되, **직전 페이지의
마지막 세션과 새 페이지의 첫 세션이 같은 `workoutSessionId`면 병합**한다.

**삭제**

- 목록에서 **경기 행 스와이프 삭제**. 세션 헤더 단위 삭제는 넣지 않는다. 한 번에 3~4경기가
  날아가면 실수 비용이 너무 크다. 세션의 마지막 경기를 지우면 헤더는 자동으로 사라진다.
- 확인 다이얼로그를 띄운다. CloudKit 동기화라 **삭제가 다른 기기로 전파되고 되돌릴 수 없다.**
- 되돌리기(undo)는 넣지 않는다. 드문 동작이라 확인으로 충분하고, CloudKit 전파와 엮이면
  복잡해진다.
- `MatchPersistenceService`에 `delete(_:)`를 추가한다. `PersistenceCore.PersistenceService`에
  `delete`가 이미 있으므로 위임만 하면 된다. `SetRecord`는 `deleteRule: .cascade`라 함께 지워진다.

스와이프를 쓰려면 `MatchList`를 `ScrollView` + `LazyVStack`에서 `List`로 바꿔야 한다. 세션을
`Section`으로 표현하면 구조가 오히려 맞아떨어진다. 다크 배경을 유지하도록 `listStyle`과
`listRowBackground`를 조정한다.

**캘린더**

```
┌─────────────────────────┐
│  ◀   2026년 8월    ▶     │
│  일 월 화 수 목 금 토      │
│  ...      [24]          │
│            ●●●          │
├─────────────────────────┤
│ 8월 24일 (일)  1:52·840 │
│   승  6-4 4-6 6-3       │
│   패  3-6 4-6           │
│   승  6-2               │
└─────────────────────────┘
```

- **날짜 셀의 점을 경기 수만큼** 찍고 각 점을 승/패 색으로 칠한다. 현재는 점 하나이고
  `hasWin`이 `contains { 이김 }`이라 1승 5패도 초록으로 뜬다. 셀 폭이 40pt라 5pt 점 4개와
  간격이 들어간다. 4경기를 넘으면 마지막 점을 회색으로 칠해 "더 있음"을 표시한다.
- **날짜를 선택하면 캘린더 아래에 그날의 세션 목록**을 띄운다. 현재는 그날 마지막 경기 하나만
  시트로 열려([CalendarGrid.swift:19](../../../../iOSApp/Features/History/Calendar/Components/CalendarGrid.swift))
  나머지 경기는 캘린더에서 접근할 방법이 없다.
- 하단 목록은 목록 뷰와 **같은 세션 카드 컴포넌트를 재사용**한다. 스와이프 삭제도 그대로
  따라오므로 캘린더에서도 삭제할 수 있다. 캘린더 → 세션 시트 → 상세 시트로 시트가 겹치는
  것도 피할 수 있다.
- 캘린더는 고정하고 하단 목록만 스크롤한다.
- 셀 상태가 셋(평소 / 오늘 / 선택)이 된다. **선택은 채워진 원, 오늘은 테두리 원**으로 구분해
  두 상태가 겹쳐도 읽히게 한다.
- 진입하면 오늘을 선택한다. 월을 넘기면 **그 달에서 경기가 있는 가장 최근 날짜를 자동 선택**한다.
  월을 넘기는 행동 자체가 "이 달엔 뭐 했지"라는 질문이므로 자동으로 답하면 탭이 하나 줄고 빈
  화면도 나오지 않는다. 그 달에 경기가 없으면 빈 상태 문구를 띄운다.

### 기록 상세 (MatchDetailSheet)

```
              S1   S2   S3
  나     승     6    4    6
  상대          4    6    3

─────────── 이 경기
[활동 kcal] [총 kcal]
[경기시간 ] [평균 bpm]

─────────── 정보
포맷      3세트
시간      14:30 ~ 15:22
```

**스코어보드** — 현재의 승/패 큰 텍스트 + 세로 세트 나열을 가로 스코어보드로 바꾼다.

- 행 2개(나 / 상대), 열은 세트. 이긴 행을 굵게 하고 승/패 표기는 행 안에 흡수시킨다.
- 지금은 "승"이 28pt인데 최종 스코어가 22pt라 위계가 뒤집혀 있다. 승패는 색만으로도 전달되므로
  그 자리를 스코어에 넘긴다.
- 세로 비교 형태라 어느 세트를 내줬는지 한눈에 들어온다. `Set 1 / Set 2 / Set 3` 세로 나열은
  같은 정보를 눈이 세 번 움직여야 읽힌다.
- 목록의 인라인 표기(`6-4 4-6 6-3`)와 **형태가 달라 중복으로 읽히지 않는다.** 같은 데이터를
  다른 해상도로 보여준다.
- 나중에 타이브레이크를 넣으면 `7` 아래 작은 `(5)`를 붙이는 식으로 확장할 수 있다.
- `opponentName`이 `nil`이면 "상대"로 표기하고, 값이 있으면 그것을 쓴다. 입력 UI는 만들지 않지만
  코드 경로는 열어둔다.

**이 경기 섹션** — 활동 kcal / 총 kcal / 경기시간 / 평균 bpm 4칸. 모두 경기 구간값이다.
섹션 제목을 "운동"에서 "이 경기"로 바꿔 세션 누적과 구분한다. 총 kcal는 요약에서 뺐지만
여기서는 활동 kcal와 나란히 놓여 비교 맥락이 생기므로 의미가 살아난다.

**정보 섹션** — 포맷 + 시간 범위(`14:30 ~ 15:22`). 현재는 시작 시각 하나뿐이다.
`endedAt`이 `nil`인 기록은 시작 시각만 표기한다.

**세트 섹션 삭제** — 스코어보드가 대신한다. 섹션이 넷에서 셋으로 준다.

**하드코딩 문자열** — `"Format"`, `"Date"`, `"No set data"`가 영어로 노출된다.
`Localizable.strings`로 옮긴다.

## 데이터 · 모델 영향

**모델 변경 없음.** 새 필드를 추가하지 않으므로 CloudKit 스키마와 마이그레이션 영향이 없다.
기존 기록은 그대로 읽힌다.

- 누적값이 없는 옛 기록(`workoutElapsedSeconds` 등이 `nil`)은 세션 헤더에서 `–`로 표기한다.
- `workoutSessionId`가 `nil`인 옛 기록은 각자 단독 세션이 된다.

서비스 변경은 `MatchPersistenceService.delete(_:)` 추가 하나다.

## 변경 파일

**신규**

| 파일 | 내용 |
|---|---|
| `iOSApp/Components/SessionCard.swift` | 세션 헤더 + 경기 행. 요약·기록 목록·캘린더 하단이 공유 |
| `iOSApp/Features/Summary/Components/RecentTrendChart.swift` | 최근 10회 세션 막대 차트 |
| `iOSApp/Features/History/Components/DaySessionList.swift` | 캘린더 하단 세션 목록 |
| `Shared/Models/MatchSessionGroup.swift` | 세션 그룹핑 결과 struct + 그룹핑 로직 |
| `iOSApp/Features/History/Components/Scoreboard.swift` | 가로 스코어보드 (기록 상세 전용) |
| `iOSApp/Extensions/Duration+Cumulative.swift` | 누적 시간 포맷 |

> 요약과 기록이 함께 쓰므로 특정 Feature 아래가 아니라 `Shared/Models/`에 둔다
> (`Shared/Persistence/Match.swift`가 iOS에서만 쓰이면서도 `Shared/`에 있는 것과 같은 이유).
> 진행 중 경기 상태인 `Shared/Models/MatchSession.swift`와 이름이 겹치므로 `MatchSessionGroup`으로 둔다.

**수정**

| 파일 | 내용 |
|---|---|
| `iOSApp/iOSApp.swift` | `.colorScheme` → `.preferredColorScheme` |
| `Info.plist` | `UIUserInterfaceStyle = Dark` |
| `iOSApp/Components/StatCard.swift` | 값 색을 흰색으로, 색 파라미터 제거 |
| `iOSApp/Components/MatchCard.swift` | `SessionCard`로 대체 후 삭제 |
| `iOSApp/Features/Summary/SummaryView.swift` | 3칸 그리드 + 전적 줄 + 차트 + 최근 세션 + 빈 상태 |
| `iOSApp/Features/Summary/SummaryViewModel.swift` | `SummaryPeriod` 변경, 세션 그룹 반환 |
| `iOSApp/Features/Summary/Components/MatchStatsGrid.swift` | `SummaryStatsGrid.swift`로 개명 + 3칸 재구성. 경기·운동 지표를 함께 담으므로 `Match~`는 더 이상 맞지 않는다 |
| `iOSApp/Features/Summary/Components/WorkoutStatsGrid.swift` | 삭제 (3칸에 통합) |
| `iOSApp/Features/Summary/Components/RecentMatchList.swift` | 삭제. `SummaryView`가 `SessionCard`를 직접 쓴다 |
| `iOSApp/Features/History/HistoryViewModel.swift` | 세션 그룹핑, 경계 병합 페이징, 선택 날짜, 삭제 |
| `iOSApp/Features/History/Components/MatchList.swift` | `List` + `Section` + 스와이프 삭제 |
| `iOSApp/Features/History/Components/MatchDetailSheet.swift` | 스코어보드, "이 경기" 섹션, 시간 범위, 문자열 |
| `iOSApp/Features/History/Calendar/CalendarView.swift` | 하단 세션 목록 추가 |
| `iOSApp/Features/History/Calendar/Components/CalendarGrid.swift` | 날짜 선택 바인딩 |
| `iOSApp/Features/History/Calendar/Components/DayCell.swift` | 다중 점, 선택 상태 |
| `iOSApp/Services/MatchPersistenceService.swift` | `delete(_:)` |
| `iOSApp/{en,ko}.lproj/Localizable.strings` | 신규 키 |

**신규 문자열 키**

`summary_section_trend`, `summary_trend_insufficient`, `summary_recent_session`,
`summary_record_line`, `match_detail_section_this_match`, `match_detail_format`,
`match_detail_time`, `match_detail_no_sets`, `match_detail_me`, `match_detail_opponent`,
`history_delete_confirm_title`, `history_delete_confirm_message`, `history_day_empty`,
`duration_hours_minutes`, `duration_hours`, `duration_minutes`

## 테스트

`iosTests/` 아래 기존 구조를 따른다. ViewModel과 순수 로직만 검증하고 View는 다루지 않는다.

**`iosTests/Summary/SummaryViewModelTests.swift`**

- `allPeriodIncludesEveryMatch` — `.all`이 기간 필터 없이 전체를 반환
- `weekPeriodExcludesOlderMatches` — 기존 케이스 유지
- `statsExcludeRemovedMetrics` — 총 kcal·평균 심박이 `SummaryStats`에서 제거됐는지
- `trendReturnsAtMostTenSessions` — 세션이 12개면 10개만
- `trendGroupsBySession` — 한 세션의 경기 3개가 막대 1개로
- `trendHiddenBelowThreeSessions` — 2개 이하면 빈 배열

**`iosTests/History/HistoryViewModelTests.swift`**

- `matchesGroupIntoSessions` — 같은 `workoutSessionId` 경기 3개가 세션 1개로
- `nilSessionIdBecomesOwnSession` — `workoutSessionId`가 `nil`인 기록 2개가 세션 2개로
- `sessionsSortedByLatestMatch` — 세션 정렬 내림차순, 세션 내 경기 오름차순
- `pageBoundaryMergesSameSession` — 페이지 경계에서 같은 세션이 헤더 중복 없이 병합
- `deleteRemovesMatchFromSession` — 삭제 후 해당 경기가 사라짐
- `deletingLastMatchRemovesSession` — 세션의 마지막 경기를 지우면 세션도 사라짐
- `selectsMostRecentMatchDayOnMonthChange` — 월 이동 시 경기 있는 최근 날짜 선택
- `selectsNothingWhenMonthHasNoMatches` — 경기 없는 달이면 선택 없음

**`iosTests/Extensions/DurationFormatTests.swift`**

- `formatsMinutesOnlyBelowOneHour` — 2520초 → `42분`
- `formatsHoursAndMinutes` — 67320초 → `18시간 42분`
- `formatsHoursOnlyAboveHundred` — 1692000초 → `470시간`
- `formatsZero` — 0초 → `0분`

**`iosTests/History/DayCellDotsTests.swift`**

점 계산을 View에서 분리한 순수 함수로 검증한다.

- `dotsMatchMatchCount` — 경기 3개면 점 3개
- `dotsCapAtFour` — 경기 6개면 점 4개, 마지막은 회색
- `dotColorsFollowEachResult` — 승·패·승이면 초록·주황·초록

**`iosTests/Services/MatchPersistenceServiceTests.swift`**

- `deleteRemovesMatch` — 삭제 후 `fetchAll`에서 사라짐
- `deleteCascadesSetRecords` — 연결된 `SetRecord`도 삭제됨

## 열린 질문

없음. 모든 결정이 확정되었다.
