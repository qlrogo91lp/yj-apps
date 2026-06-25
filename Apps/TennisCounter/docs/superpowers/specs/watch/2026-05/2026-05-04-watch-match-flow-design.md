# Watch 앱 매치 플로우 재설계 (Phase 1-B)

- **작성일**: 2026-05-04
- **대상**: watchOS Watch App 타겟
- **관련 Phase**: Phase 1-B (HealthKit + 매치 흐름 재구성)

---

## 1. 목적과 범위

### 목적

현재 Watch 앱은 Home → Quick Match → 2-page TabView (점수 / 운동 메트릭) 구조로, 매치와 워크아웃 세션이 1:1로 묶여 있다. 이를 다음 방향으로 재설계한다:

1. **워크아웃 세션과 매치를 분리.** 한 워크아웃 세션 동안 매치를 여러 번(One Set ↔ Best of 3 자유 전환) 진행할 수 있다.
2. **모드 선택 화면 도입.** Home에서 진입하면 모드(One Set / Best of 3) + 옵션(NO-AD / NO-TIE) 토글을 먼저 선택한다.
3. **표준 테니스 룰 지원.** 듀스/Advantage, 타이브레이크(6-6 자동 발동, 7점), Best of 3 매치.
4. **One Set 모드의 조기 무승부 종료(Draw).** 5게임 양쪽 도달 시점부터 우상단 새로고침 아이콘으로 종료 가능.
5. **Apple 기본 Workout 앱과 유사한 3-page TabView.** 좌측: 워크아웃 컨트롤(Pause/End), 가운데: 매치 흐름, 우측: 운동 메트릭.

### iOS와의 메뉴 일치 여부

iOS는 Phase 1-A에서 3-탭 구조(Summary / Match / History)로 발전 예정 (이번 스펙 범위 밖). Watch는 작은 화면 특성상 **Home + 매치 진행만**으로 단순화한다. 통계/히스토리 조회는 iPhone에서.

---

## 2. 화면 흐름

```
[Home]
  └─ "운동 시작" 탭
       │ (워크아웃 세션 시작 + workoutSessionId 생성)
       ▼
  [WorkoutFlowView — 3-page TabView]
  ◀ 좌측 Controls       │  중앙 Main           │  우측 Metrics ▶
  ─────────────────────  ─────────────────────  ─────────────────────
   • Pause / Resume      │  enum.phase 따라 swap  │  • 시간 (elapsed)
   • End Workout         │  ┌─ .modeSelection    │  • kcal
                         │  │   - One Set 카드   │  • BPM
                         │  │   - Best of 3 카드 │
                         │  │   - NO-AD 토글     │
                         │  │     (default ON)  │
                         │  │   - NO-TIE 토글    │
                         │  │     (default OFF) │
                         │  ├─ .playing(options) │
                         │  │   - 좌/우 점수 탭   │
                         │  │   - 세트 인디케이터 │
                         │  │   - Undo (조건부)  │
                         │  │   - 5:5+ 우상단    │
                         │  │     새로고침 아이콘 │
                         │  │     (One Set만)   │
                         │  └─ .finished(session)│
                         │     - Victory/Defeat/ │
                         │       Draw 헤더       │
                         │     - 세트 점수       │
                         │     - Save 버튼       │
                         │     - New Match 버튼  │
                         │       → .modeSelection│
                         │       으로 swap        │
       │ 좌측 "End Workout" 탭 (즉시 종료, 진행 중 매치 폐기)
       ▼
  [Home]
```

### 주요 결정 요약

| 결정 항목 | 선택 |
|---------|------|
| iOS / Watch 메뉴 동일 여부 | Watch만 단순화 (Home + 매치) |
| 모드 선택 위치 | 별도 화면 (NavigationLink push) |
| 매치 진행 중 NavigationStack pop (좌상단 < / 좌측 가장자리 스와이프) | 컨펌 다이얼로그로 종료 확인 |
| 백그라운드 진입 / 손목 내림 | 워크아웃 + 매치 상태 유지 (HKWorkoutSession이 우선순위 보장) |
| 모드 선택 옵션 | NO-AD 토글 (default ON), NO-TIE 토글 (default OFF) |
| 타이브레이크 | 6-6 도달 시 자동 발동, 별도 토글 없음 |
| 결과 화면 진입 경로 | 자연 종료 + 5:5+ Draw 모두 동일 화면 |
| 결과 화면 Save 버튼 노출 조건 | 항상 노출 (저장 안 하고 싶으면 New Match만 누름) |
| 워크아웃 세션 시작 시점 | Home "운동 시작" 탭 시점 |
| 가운데 페이지 전환 방식 | enum 상태 swap (NavigationStack 미사용 — 좌우 스와이프 충돌 회피) |
| Pause 동작 | 워크아웃 측정만 멈춤, 매치 점수 입력은 그대로 |
| End Workout 동작 | 즉시 종료, 컨펌 없음, 진행 중 매치 폐기 |

---

## 3. 룰 로직

### 3.1 게임 승 조건

점수 표기: `0 → 15 → 30 → 40 → (게임 결정 점수)`

| 상황 | NO-AD OFF (표준 듀스) | NO-AD ON (default) |
|------|----------------------|--------------------|
| 한쪽 40, 다른쪽 ≤30 | 다음 점수 → 게임 승 | 다음 점수 → 게임 승 |
| 40-40 (듀스) | Advantage 부여 (`AD-IN`/`AD-OUT`) → 같은 쪽 또 따면 게임 승, 놓치면 다시 듀스 | 다음 1점 = 즉시 게임 승 (Sudden death) |

**UI 표시:**
- 듀스 시 점수 영역: `40` / `40` (그대로)
- Advantage: 점수 영역에 `AD` (해당 플레이어 쪽), 반대편은 `40`
- NO-AD 듀스(40-40): 헤더 캡슐 영역에 `DECIDING POINT` 표시 (워치 공간이 안 되면 생략 가능, 구현 시 결정)

### 3.2 세트 승 조건

| 상황 | NO-TIE OFF (default, 표준) | NO-TIE ON |
|------|----------------------------|-----------|
| 한쪽 6게임, 차이 ≥ 2 | 세트 종료 (6-0 ~ 6-4) | 세트 종료 (6-0 ~ 6-4) |
| 6-5 / 5-6 | 다음 게임 진행 | 6게임 도달 쪽 즉시 종료 (6-5 / 5-6) |
| 7-5 / 5-7 | 세트 종료 | (도달 불가 — NO-TIE에선 6게임 도달 = 종료) |
| 6-6 | 타이브레이크 진입 (7점, 2점 차) → 7-6으로 종료 | (도달 불가) |

### 3.3 매치 승 조건

| 모드 | 매치 종료 조건 |
|------|---------------|
| **One Set** | 한 세트 끝나면 매치 종료 |
| **Best of 3** | 한쪽이 2세트 선취 시 매치 종료 (1-1이면 3세트 진행) |

### 3.4 타이브레이크 UI

- 6-6 도달 시점에 `Score`가 타이브레이크 모드로 전환
- 점수 영역: 1, 2, 3, ... 카운트 (0/15/30/40 표기 안 씀)
- 헤더 캡슐: `n SET m` → `n TIE-BREAK m` 으로 변경
- 캡슐 공간 부족 시 (구현 시 41mm/40mm 시뮬에서 실측) `n TIE m`로 폴백, 모든 사이즈 통일

### 3.5 조기 종료 (One Set 모드 한정 Draw)

- **노출 조건**: 게임 카운트가 5-5 이상 도달한 시점부터 가운데 페이지 우상단에 새로고침 아이콘 (`arrow.clockwise`) 표시
- **탭 동작**: `confirmationDialog`("매치를 무승부로 종료할까요?") → 확인 시 `MatchResult.draw`로 phase 전환
- **결과 화면**: 헤더만 `Draw`로 표시, Save / New Match 버튼은 자연 종료와 동일하게 둘 다 노출
- **Best of 3 모드**: 새로고침 아이콘 노출 안 함

---

## 4. 파일/컴포넌트 구조

```
WatchApp/Features/Workout/                  ★ 신규 폴더 (기존 Match/ 대체)
├── WorkoutFlowView.swift                   3-page TabView 컨테이너
├── WorkoutFlowViewModel.swift              워크아웃 세션 + phase 관리
├── WorkoutControlsView.swift               좌측 페이지
├── WorkoutMetricsView.swift                우측 페이지
│
├── Components/
│   ├── WorkoutPauseButton.swift            Pause/Resume 토글
│   └── WorkoutEndButton.swift              End Workout (즉시 종료)
│
├── ModeSelection/
│   ├── ModeSelectionView.swift             One Set / Best of 3 카드 + 토글들
│   └── ModeSelectionViewModel.swift        토글 상태 관리
│
├── Match/
│   ├── MatchView.swift                     메인 — 자식 조립
│   ├── MatchViewModel.swift                룰 로직
│   ├── ScorePadView.swift                  좌/우 점수 입력 영역
│   ├── SetIndicatorView.swift              헤더 캡슐 (SET / TIE-BREAK)
│   └── Components/
│       ├── UndoButton.swift
│       └── EarlyEndButton.swift            5:5+ 새로고침 아이콘
│
└── Result/
    └── MatchResultView.swift               Victory / Defeat / Draw + Save / New Match

Shared/
├── Models/
│   ├── Score.swift                         (대폭 수정: AD/Deuce/NO-AD/TieBreak 분기)
│   ├── MatchOptions.swift                  ★ struct: mode, noAdRule, noTieRule
│   ├── MatchPhase.swift                    ★ enum: .modeSelection / .playing(MatchOptions) / .finished(MatchSession)
│   ├── MatchResult.swift                   ★ enum: .win / .loss / .draw
│   ├── MatchMode.swift                     ★ enum: .oneSet / .bestOfThree
│   ├── SetScore.swift                      ★ struct: my, your (Codable)
│   ├── MatchSession.swift                  ★ in-memory 매치 진행 상태
│   └── MatchRecord.swift                   ★ SwiftData @Model (저장용)
│
└── Services/
    ├── HealthKitService.swift              (소폭 수정: 매치 구간 평균 BPM 조회 메서드 추가)
    ├── WatchConnectivityService.swift      (변경 없음)
    └── MatchPersistenceService.swift       ★ SwiftData CRUD 래퍼
```

### 폴더 컨벤션 규칙

- **`...View.swift` (화면 영역/섹션)** → 평평하게
- **버튼/배지/아이콘 같은 작은 위젯** → `Components/` 안에
- **단일 파일 화면**(`WorkoutControlsView`, `WorkoutMetricsView`, `MatchResultView`) → 폴더 안 만들고 평평하게
- **ViewModel 또는 Components가 있는 화면** → 폴더로 묶음

### 기존 코드 정리

- `WatchApp/Features/Home/HomeView.swift` → 라벨 `Quick Match` → `운동 시작`, `NavigationLink` 대상 `MatchView` → `WorkoutFlowView`로 변경
- `WatchApp/Features/Match/MatchView.swift` → `WatchApp/Features/Workout/Match/MatchView.swift`로 이동 + 대폭 수정 (룰 매트릭스, MatchOptions 주입, 5:5+ Draw 트리거)
- `WatchApp/Features/Match/MatchViewModel.swift` → `WatchApp/Features/Workout/Match/MatchViewModel.swift`로 이동 + 대폭 수정 (1세트 종료 = 매치 종료 로직 제거, 모드별 분기, NO-AD/NO-TIE 분기, 타이브레이크, 매치 종료 시 finishMatch 콜백 호출)
- `WatchApp/Features/Match/ExerciseView.swift` (현재 미커밋) → `WatchApp/Features/Workout/WorkoutMetricsView.swift`로 이동/리네임
- `WatchApp/Features/Match/` 폴더 자체 삭제

### 컴포넌트 책임

| 컴포넌트 | 책임 | 주요 의존성 |
|---------|------|------------|
| `WorkoutFlowViewModel` | 워크아웃 세션 ID 발급, phase 전환, 매치 시작/종료 콜백 | `HealthKitService`, `MatchPersistenceService` |
| `MatchViewModel` | 한 매치 내 점수/게임/세트/타이브레이크 룰, 5:5+ Draw 트리거 | `Score`, `MatchOptions` |
| `Score` | 한 게임 내 점수 상태 (Normal / Deuce / Advantage / TieBreak 모드) | 없음 |
| `MatchPersistenceService` | SwiftData 저장/조회 (Phase 1-A에서 iOS와 공유 예정) | SwiftData |
| `HealthKitService` | 워크아웃 세션 관리 + 실시간 메트릭 publish + 구간 평균 BPM 조회 | HealthKit |

---

## 5. 데이터 모델

### 5.1 in-memory 모델

```swift
struct MatchOptions {
    let mode: MatchMode               // .oneSet / .bestOfThree
    let noAdRule: Bool                // default true
    let noTieRule: Bool               // default false
}

enum MatchMode: Codable { case oneSet, bestOfThree }
enum MatchResult: Codable { case win, loss, draw }

struct SetScore: Codable {
    let my: Int
    let your: Int
}

enum MatchPhase {
    case modeSelection
    case playing(MatchOptions)
    case finished(MatchSession)
}

class MatchSession {
    let id: UUID
    let workoutSessionId: UUID
    let options: MatchOptions
    let startedAt: Date
    var endedAt: Date?
    var result: MatchResult?

    var mySetScore: Int = 0
    var yourSetScore: Int = 0
    var completedSets: [SetScore] = []

    let kcalAtStart: Double
    var kcalAtEnd: Double?
    var averageHeartRate: Double?
}
```

### 5.2 영속화 모델

```swift
@Model
final class MatchRecord {
    var id: UUID
    var mode: MatchMode
    var noAdRule: Bool
    var startedAt: Date
    var endedAt: Date
    var result: MatchResult

    var mySetScore: Int
    var yourSetScore: Int
    var completedSets: [SetScore]    // 7-6은 자연스럽게 타이브레이크 의미

    var durationSeconds: Int         // endedAt - startedAt
    var caloriesBurned: Double       // 매치 구간 누적
    var averageHeartRate: Double?    // 매치 구간 평균

    var workoutSessionId: UUID?      // 같은 워크아웃 안의 매치들 묶기
}
```

**설계 메모:**
- `wasTieBreak: Bool` 같은 별도 플래그는 두지 않음. `completedSets`에 `7-6`이 있으면 자동으로 타이브레이크였다는 의미.
- `workoutSessionId`는 옵셔널이지만 처음부터 채워서 저장 (나중에 추가하면 과거 데이터는 영원히 비어있게 되므로 처음부터 둠).
- 워크아웃 세션 자체를 별도 `@Model`로 두지 않음. 통계 시 `GROUP BY workoutSessionId`로 처리.

---

## 6. 데이터 흐름

### 6.1 Home → 워크아웃 시작
```
HomeView "운동 시작" 탭
  ↓
WorkoutFlowViewModel 초기화
  - workoutSessionId = UUID()
  - HealthKitService.startWorkout()  → HKWorkoutSession 시작
  - phase = .modeSelection
  ↓
WorkoutFlowView 진입 (NavigationLink push)
  - 3-page TabView 표시
```

### 6.2 매치 시작
```
ModeSelectionView 카드 탭 (예: Best of 3)
  ↓
WorkoutFlowViewModel.startMatch(MatchOptions(...))
  - currentMatch = MatchSession(
      id, workoutSessionId, options, startedAt: Date(),
      kcalAtStart: HealthKitService.currentCalories
    )
  - phase = .playing(options)
  ↓
가운데 페이지가 MatchView로 swap
  - MatchViewModel(options) 초기화
```

### 6.3 점수 입력
```
ScorePadView 좌/우 탭
  ↓
MatchViewModel.addPoint(.me)
  ↓
Score.addPoint(.me, mode: currentScoreMode)
  - 일반: 0 → 15 → 30 → 40 → 게임승
  - 듀스: 40-40 → AD-IN/OUT → 게임승 또는 다시 듀스
  - NO-AD: 40-40 → 다음 1점 즉시 게임승
  - 타이브레이크: 1-2-3... 카운트 (2점 차)
  ↓
MatchViewModel.checkGameUpdate()
  - 게임 승 → gameCount +1, Score 리셋
  - 세트 승 조건 체크 (NO-TIE 분기)
  - 6-6 도달 → Score 모드 = .tieBreak
  - 매치 승 조건 체크 (모드별)
  ↓
sendScoreUpdate() → WatchConnectivityService (Phase 1-A에서 활용)
```

### 6.4 매치 종료 (자연 종료)
```
MatchViewModel.checkSetUpdate() → 매치 승부 결정
  ↓
WorkoutFlowViewModel.finishMatch(result: .win | .loss)
  - currentMatch.endedAt = Date()
  - currentMatch.kcalAtEnd = HealthKitService.currentCalories
  - currentMatch.averageHeartRate = await HealthKitService.averageHeartRate(from:to:)
  - currentMatch.completedSets = MatchViewModel.completedSets
  - currentMatch.result = .win | .loss
  - phase = .finished(currentMatch)
  ↓
MatchResultView 표시 (Save / New Match 버튼)
```

### 6.5 매치 종료 (조기 Draw — One Set 5:5+)
```
EarlyEndButton 탭 (가운데 우상단 새로고침 아이콘)
  ↓
ConfirmationDialog "매치를 무승부로 종료할까요?"
  ↓ 확인
WorkoutFlowViewModel.finishMatch(result: .draw)
  - 6.4와 동일 흐름, result = .draw
  ↓
MatchResultView (헤더만 "Draw", Save / New Match 둘 다 노출)
```

### 6.6 저장
```
MatchResultView "Save" 탭
  ↓
MatchPersistenceService.save(MatchRecord(
    ...currentMatch에서 매핑...
))
  ↓
Save 버튼 비활성화 + "Saved" 시각 피드백
```

> Save 안 누르고 New Match로 가면 currentMatch가 메모리에서만 사라짐 (저장 안 됨).

### 6.7 New Match
```
MatchResultView "New Match" 탭
  ↓
WorkoutFlowViewModel.startNewMatch()
  - currentMatch = nil
  - phase = .modeSelection
  ↓
가운데 페이지가 ModeSelectionView로 swap
  - 워크아웃 세션 + workoutSessionId 그대로 유지
```

### 6.8 End Workout
```
WorkoutControlsView "End Workout" 탭
  ↓
(즉시 종료, 컨펌 없음)
WorkoutFlowViewModel.endWorkout()
  - phase가 .playing이면 currentMatch 폐기 (저장 안 함)
  - HealthKitService.stopWorkout() (async)
  ↓
NavigationStack pop → Home
```

### 6.9 Pause / Resume
```
WorkoutControlsView "Pause" 탭
  ↓
HealthKitService.pauseWorkout()
  - HKWorkoutSession.pause()  → kcal/시간 카운트 멈춤
  ↓
명시적으로 "Resume" 탭해야 측정 재개
  ↓
HealthKitService.resumeWorkout()

※ 매치 점수 입력은 Pause 영향 없음
※ Paused 동안 우측 페이지 elapsed 텍스트는 회색 (시각 피드백)
```

---

## 7. UI 디자인 노트

- 좌측 컨트롤 페이지 / 우측 메트릭 페이지: **Apple 기본 Workout 앱 스타일** 참고 (큰 컬러 버튼, 큰 숫자 + 라벨)
- 가운데 매치 페이지: 기존 색상 컨벤션 유지 (`me = green`, `opp = orange`)
- 평균 BPM 매치 종료 시 못 가져온 동안: `--` 표시 (실시간 BPM과 동일 패턴)
- 결과 화면 로딩 스피너: 불필요 (BPM 조회 보통 100ms 이내)

---

## 8. 엣지 케이스

| 상황 | 동작 |
|------|------|
| HealthKit 권한 거부 | 첫 진입 시 권한 요청 → 거부 시에도 매치 진행 가능, 우측 메트릭 페이지에 "권한 필요" 배너. kcal/BPM `--`. 매치 저장 시 메트릭은 0/null |
| 워크아웃 시작 실패 (`HKWorkoutSession` 생성 에러) | Home에 alert 후 진입 차단, 사용자 재시도 |
| 점수 Undo (일반) | 1점 단위 Undo |
| 듀스 중 Undo | AD 상태 → 40-40로 복귀 가능 (Score의 lastAction 확장 필요) |
| 타이브레이크 중 Undo | 1점 단위 Undo |
| 매치 종료 후 Undo | 결과 화면 진입 후엔 Undo 불가 (phase = .finished) |
| 백그라운드 진입 / 손목 내림 | 워크아웃 + 매치 상태 유지 |
| Watch ↔ iPhone 연결 끊김 | 매치는 워치 단독 진행, 동기화는 Phase 1-A에서 베스트에포트 |
| Pause 중 매치 종료 | Pause 상태 그대로 phase = .finished, kcal/시간은 Pause 시점까지만 측정 |
| 5-5 도달 후 새로고침 안 누르고 계속 진행 | 정상 — 6-5/7-5/6-6/7-6까지 룰대로 진행 |

---

## 9. Out of Scope (Phase 1-B 1차 구현 제외)

- ❌ 앱 강제 종료 / 워치 재부팅 시 진행 중 매치 복구 (Score 상태 휘발 OK)
- ❌ 세트/게임 단위 Undo (점수 1단계 Undo만)
- ❌ Best of 5 모드
- ❌ End Workout 컨펌 다이얼로그 (추후 요청 시 추가)
- ❌ Home 설정 화면 — NO-AD/NO-TIE default 변경 (UserDefaults 저장)
- ❌ 매치 사이 휴식 타이머
- ❌ Live Activity / Complication 동기화 (Phase 1-B 별도 작업)
- ❌ iOS 앱 동기화 (`WatchConnectivity` 매치 모델 송신 — Phase 1-A 별도 작업)
- ❌ 저장된 매치 편집/삭제 (워치에서 직접 수정 안 함, iPhone에서)

---

## 10. 테스트 전략

### 단위 테스트 (`Score`, `MatchViewModel`)

- 일반 게임 (0→15→30→40→승)
- 듀스 → AD → 게임 승
- 듀스 → AD → 다시 듀스
- NO-AD 듀스 → 1점 즉시 게임 승
- NO-TIE OFF: 6-5 → 7-5 / 6-5 → 6-6 → TB 7-6
- NO-TIE ON: 6-5에서 즉시 종료
- Best of 3: 1세트씩 진행, 2세트 선취 시 매치 종료
- 5:5+ Draw: One Set 모드에서만 트리거 가능, Best of 3에선 노출 안 됨
- Undo: 점수 / 듀스 / 타이브레이크 각 케이스

### 통합 테스트

- HealthKit: 시뮬레이터 + 수동 검증 (권한 거부, 평균 BPM 구간 조회)
- SwiftData 저장/조회: `MatchPersistenceService` 단위 테스트

### UI 테스트

- 일단 미작성 (워치 UI 테스트는 비용 대비 효과 낮음, 핵심 로직 단위 테스트로 커버)
