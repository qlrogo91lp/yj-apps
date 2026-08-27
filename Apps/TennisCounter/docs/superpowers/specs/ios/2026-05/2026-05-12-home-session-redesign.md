# iOS Home View & Match Session 구조 재설계

## 배경

현재 iOS 앱은 Match 탭에 진입하면 바로 `ModeView`(포맷 선택)가 표시된다. 워크아웃 시작 트리거가 없고, `MatchTabView`와 `MatchContainerView`가 같은 역할로 중복 존재한다. Watch 앱의 `HomeView → WorkoutSessionView` 패턴과 대칭 구조로 정리한다.

---

## 목표

1. iOS Match 탭에 `HomeView` 추가 — Watch처럼 "운동 시작" 버튼으로 세션 진입
2. 세션 화면을 `[Workout | Score]` 2탭 구조로 구성
3. `MatchTabView` / `MatchContainerView` 중복 제거 및 `MatchSessionView`로 통합
4. 로컬 타이머로 운동 시간 측정 (Watch 연결 시 HealthKit 메트릭 자동 수신)
5. `.playing` phase에서 커스텀 BackButton으로 Workout 탭 이동, 종료 시 확인 dialog

---

## 화면 흐름

```
MainTabView
├── SummaryView (탭)
├── HomeView (Match 탭)          ← NEW
│   └── NavigationLink →
│       MatchSessionView          ← 메인 탭바 숨김, [Workout | Score] 탭
│       ├── [Workout 탭] WorkoutTabView
│       │     타이머 / 칼로리 / 심박수 + 일시정지·종료 버튼
│       └── [Score 탭] phase 기반 전환
│             .modeSelection → ModeView  (back → HomeView 복귀, dialog 없음)
│             .playing(MatchOptions) → ScoreView  (back → Workout 탭 이동)
│             .finished(MatchSession) → MatchResultView  (새 경기 or 저장 후 종료)
└── HistoryView (탭)
```

---

## ViewModel 구조

### `MatchSessionViewModel` (신규)

Watch `WorkoutSessionViewModel`과 대칭.

```swift
@MainActor
class MatchSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var elapsedSeconds: Int = 0
    @Published var metrics: WorkoutMetrics = .init()
    @Published var watchConnected: Bool = false
    @Published var isPaused: Bool = false

    func startSession()                              // Date() 기록, 타이머 시작
    func pauseSession() / resumeSession()
    func startMatch(format: MatchFormat)             // MatchOptions 생성 후 phase → .playing(options)
    func finishMatch(result:, completedSets:)        // MatchSession 완성 후 phase → .finished(session)
    func endSession()                                // 타이머 정지, dismiss
}
```

> **참고**: `MatchFormat`(iOS UI용, localizedTitle 등 포함)과 `MatchMode`(Shared 모델)가 동일한 케이스를 가진 별도 enum으로 중복 존재함. `startMatch`에서 `MatchFormat → MatchOptions` 변환 처리.

**타이머**: `startSession()` 시 `startedAt = Date()` 기록, `Timer`로 1초마다 `elapsedSeconds` 업데이트.

**메트릭**: Watch 연결 시 `WatchConnectivityService.$receivedMetrics`의 칼로리·심박수를 수신해 `metrics`에 반영. `elapsedSeconds`는 항상 로컬 타이머 우선.

### 삭제

- `MatchTabViewModel` → `MatchSessionViewModel`로 통합
- `MatchContainerViewModel` → `MatchSessionViewModel`로 통합

---

## 파일 구조

### 삭제

```
iOSApp/Features/Match/Tab/MatchTabView.swift
iOSApp/Features/Match/Tab/MatchTabViewModel.swift
iOSApp/Features/Match/Session/MatchContainerView.swift
iOSApp/Features/Match/Session/MatchContainerViewModel.swift
iOSApp/Features/Match/Session/Score/ScoreTabView.swift
```

### 신규

```
iOSApp/Components/BackButton.swift              ← Watch BackButton과 대칭

iOSApp/Features/Match/Home/
└── HomeView.swift                              ← 로고 + "운동 시작" 버튼

iOSApp/Features/Match/Session/
├── MatchSessionView.swift                      ← [Workout | Score] 2탭 컨테이너
└── MatchSessionViewModel.swift
```

### 유지

```
iOSApp/Features/Match/Mode/                     ← ModeView, ModeListItem
iOSApp/Features/Match/Score/                    ← ScoreView, MatchViewModel, Components
iOSApp/Features/Match/Result/                   ← MatchResultView
iOSApp/Features/Match/Workout/                  ← WorkoutTabView
```

### 변경

`iOSApp/iOSApp.swift` — `MainTabView`의 Match 탭을 `ModeView()` → `NavigationStack { HomeView() }`로 교체

---

## 종료 확인 Dialog

| phase | back/종료 동작 |
|-------|--------------|
| `.modeSelection` | 기본 back 버튼 → HomeView 복귀 (dialog 없음) |
| `.playing(MatchOptions)` | 커스텀 `BackButton` → Workout 탭 이동 (`selectedTab = 0`) |
| `.playing(MatchOptions)` 종료 버튼 | `confirmationDialog` → [종료(destructive) / 취소] |
| `.finished(MatchSession)` | 뒤로가기 없음, "새 경기" or "저장 후 종료" 버튼 |

**종료 진입점 두 곳:**
1. Workout 탭 "종료" 버튼
2. Score 탭 조기 종료 버튼 (`.playing` phase)

두 곳 모두 동일한 `confirmationDialog` 사용.

---

## Watch 대칭 구조

| Watch | iOS |
|-------|-----|
| `HomeView` | `HomeView` |
| `WorkoutSessionView` | `MatchSessionView` |
| `WorkoutSessionViewModel` | `MatchSessionViewModel` |
| `[Controls \| Match \| Metrics]` 3탭 | `[Workout \| Score]` 2탭 |
| `WatchApp/Components/BackButton` | `iOSApp/Components/BackButton` |
| `MatchPhase` (Shared) | 동일 사용 |

---

## 비고

- HealthKit은 Watch 전담. iOS는 `WatchConnectivityService`로 메트릭만 수신.
- iOS 자체 HealthKit 연동은 Phase 1-B 이후 검토.
- `BackButton`은 `iOSApp/Components/`에 배치 (두 Feature 이상에서 공유 가능성).
