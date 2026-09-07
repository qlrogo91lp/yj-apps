# Summary & History 개선 디자인

**날짜**: 2026-05-26  
**대상**: iOS 앱 — Summary 탭, History 탭(MatchDetailSheet, CalendarHistoryView)

---

## 목표

1. Summary 화면에 피트니스 데이터(kcal, 운동시간, bpm) 추가 및 섹션 분리
2. MatchDetailSheet에 Workout 섹션 추가 (카드 그리드 형태)
3. CalendarHistoryView 탭 동작 수정 (가장 최근 경기 오픈)

---

## 1. Summary 화면

### 1-1. 경기 통계 섹션

기존 4카드(경기수, 승률, 연속플레이, 승수)에서 **연속플레이(streak) 제거**, 3카드로 재편.

| 카드 | 값 | 색상 |
|------|-----|------|
| 경기수 | 선택 기간 내 총 경기 수 | blue |
| 승률 | 승/총경기 (50% 이상 green, 미만 orange) | 동적 |
| 승수 | 선택 기간 내 승리 수 | green |

레이아웃: `LazyVGrid` 3열 (기존 2열 → 3열로 변경)

### 1-2. 피트니스 섹션 (신규)

경기 통계 섹션 아래에 별도 섹션 헤더("피트니스")와 함께 3카드 배치.

| 카드 | 집계 방식 | 단위 | 데이터 없을 때 |
|------|----------|------|--------------|
| 총 kcal | 선택 기간 내 합산 | kcal | – |
| 운동시간 | 선택 기간 내 합산 | MM:SS / H:MM:SS | – |
| 평균 bpm | 선택 기간 내 평균 | BPM | – |

- `caloriesBurned` 또는 `averageHeartRate` 가 있는 경기만 집계에 포함
- 해당 기간 내 워크아웃 데이터가 전혀 없으면 세 카드 모두 "–" 표시
- 섹션 헤더는 기존 `recentMatchesSection`의 `.headline` 스타일 동일 적용

### 1-3. 데이터 모델 변경

`SummaryStats` struct에 필드 추가:

```swift
struct SummaryStats {
    let totalMatches: Int
    let wins: Int
    let winRate: Double
    // streak 제거
    let totalCalories: Double?   // nil = 데이터 없음
    let totalDuration: Int?      // 초 단위, nil = 데이터 없음
    let avgHeartRate: Double?    // nil = 데이터 없음
}
```

`SummaryViewModel.stats(from:)` 에서 집계:
- `totalCalories`: `filtered.compactMap(\.caloriesBurned).reduce(0, +)`, 빈 배열이면 nil
- `totalDuration`: `durationSeconds` 우선, 없으면 `endedAt - startedAt` (초 단위) 합산, 빈 배열이면 nil
- `avgHeartRate`: `filtered.compactMap(\.averageHeartRate)` 평균, 빈 배열이면 nil

### 1-4. 운동시간 포맷

`WorkoutMetrics.formattedElapsed` 와 동일한 로직을 `SummaryViewModel` 또는 별도 helper로 추출:

```
1시간 미만 → MM:SS
1시간 이상 → H:MM:SS
```

---

## 2. MatchDetailSheet

### 2-1. Workout 섹션 추가

기존 섹션 순서: 결과 → Sets → Info  
변경 후 순서: **결과 → Workout → Sets → Info**

Workout 섹션 레이아웃: `LazyVGrid` 3열, 각 셀은 아이콘 + 값 + 단위 구조.

| 셀 | 아이콘 | 값 | 단위 | 소스 |
|----|--------|-----|------|------|
| 칼로리 | flame.fill | caloriesBurned 또는 – | kcal | `match.caloriesBurned` |
| 운동시간 | timer | durationSeconds 또는 endedAt 기반 또는 – | MM:SS / H:MM:SS | `match.durationSeconds` → `match.endedAt - match.startedAt` fallback |
| 심박수 | heart.fill | averageHeartRate 또는 – | BPM | `match.averageHeartRate` |

- 데이터가 nil 이면 값 자리에 "–" 표시 (단위는 표시하지 않음)
- 아이콘 색상: flame → orange, timer → blue, heart → red

### 2-2. Info 섹션 변경

기존 Info 섹션에서 **Calories, Avg. Heart Rate, Duration 행 제거** (Workout 섹션으로 이동).

변경 후 Info 섹션 항목:
- Format
- Date

### 2-3. 컴포넌트 분리

`MatchDetailSheet` 내부 private helper로 `WorkoutStatCell` 정의:

```swift
// icon: SF Symbol name, value: 표시값 또는 nil, unit: "kcal" 등
private struct WorkoutStatCell: View { ... }
```

---

## 3. CalendarHistoryView — 탭 동작 수정

### 현재

```swift
selectedMatch = dayMatches.first
```

`matches`가 `order: .reverse`로 정렬되어 있어 이론상 최신 경기가 `.first`이나, `matchesForDate` 필터 후 순서 보장을 명시적으로 처리하지 않음.

### 변경 후

```swift
selectedMatch = dayMatches.max(by: { $0.startedAt < $1.startedAt })
```

같은 날 여러 경기가 있을 때 `startedAt` 기준 가장 최근 경기를 명시적으로 선택.

---

## 변경 파일 목록

| 파일 | 변경 내용 |
|------|---------|
| `iOSApp/Features/Summary/SummaryViewModel.swift` | `SummaryStats` 필드 추가(streak 제거, 피트니스 3종), `stats(from:)` 집계 로직, 시간 포맷 helper |
| `iOSApp/Features/Summary/SummaryView.swift` | 경기 통계 3열 그리드, 피트니스 섹션 추가 |
| `iOSApp/Components/MatchDetailSheet.swift` | Workout 섹션 추가, Info에서 중복 항목 제거 |
| `iOSApp/Features/History/Components/CalendarHistoryView.swift` | 탭 동작 `max(by:)` 수정 |

---

## 테스트

| 대상 | 시나리오 |
|------|---------|
| `SummaryViewModel` | 워크아웃 데이터 없는 경기만 있을 때 피트니스 stats이 nil 반환 |
| `SummaryViewModel` | 혼합(워크아웃 있/없) 경기 기간에서 올바른 합산/평균 계산 |
| `SummaryViewModel` | streak 관련 계산 완전 제거 확인 |
| `CalendarHistoryView` | 같은 날 여러 경기 중 최신 경기 선택 확인 |
