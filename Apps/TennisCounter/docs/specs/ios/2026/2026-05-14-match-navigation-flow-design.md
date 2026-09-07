# iOS 경기 네비게이션 플로우 & MatchResultView 재설계

**날짜:** 2026-05-14  
**대상:** iOSApp — Match 도메인 전체

---

## 1. 배경

현재 iOS 경기 화면의 네비게이션 플로우에 여러 버그가 존재한다. modeSelection 뒤로가기가 Workout 세션을 끊고 HomeView로 나가버리고, MatchResultView가 "종료" 시 운동도 함께 종료해버리며, ScoreView에 중복 역할의 "조기 종료" 버튼이 있다. Watch 앱과 패턴을 맞추면서 이를 수정한다.

---

## 2. 현황 분석 — 발견된 버그 및 이슈

### 네비게이션 버그

| 위치 | 현재 동작 | 문제 |
|---|---|---|
| modeSelection 뒤로가기 | `onExit()` → HomeView | Workout 세션이 종료됨 |
| playing 뒤로가기 | Tab 0 (WorkoutTab) 이동 | 경기가 묻히고 UX 불명확 |
| MatchResultView "종료" | `onExit()` → HomeView | Workout까지 끊김, 복수 경기 불가 |
| ScoreView 툴바 | "조기 종료" 버튼 | 뒤로가기와 역할 중복 |

### MatchResultView 구조 버그

- `didWin: Bool`, `completedSets: [(my, your)]` 원시 값 수신 → `MatchSession` 객체 없음
- SwiftData 저장 기능 없음 (SaveButton 미구현)
- 재경기(Rematch) 기능 없음
- Watch 패턴(`session: MatchSession`, `@ObservedObject viewModel`)과 불일치

### MatchViewModel 저장 버그

- `MatchViewModel.saveMatch()` 가 레거시 `Match` / `SetRecord` 모델로 자동 저장
- `MatchRecord` (현행 모델) 와 이중 저장 구조 → 충돌 위험
- `MatchResultView` 의 수동 저장 흐름과 책임 분리가 안 됨

### WatchConnectivity 이슈

| 방향 | 현황 | 판단 |
|---|---|---|
| iOS → Watch (ScoreUpdate) | `MatchViewModel.sendScoreUpdate()` ✅ | 정상 작동 |
| Watch → iOS (ScoreUpdate) | `receivedScoreUpdate` 발행되지만 구독자 없음 ❌ | 양방향 동기화 미구현 — Phase 1-A 별도 추적 |
| Watch → iOS (Metrics) | `MatchSessionViewModel` 에서 구독 ✅ | 정상 작동 |

---

## 3. 네비게이션 플로우 재설계

### 전체 플로우

```
HomeView
└── "운동 시작"
    └── MatchSessionView (Workout 자동 시작, TabView)
          ├── Tab 0: WorkoutTabView
          │     ├── [modeSelection] "종료" → 확인 다이얼로그 → endSession() + onExit()
          │     └── [playing]       "종료" → "경기 결과가 무효됩니다" 다이얼로그
          │                                  → endSession() + onExit()
          │
          └── Tab 1: scoreTabContent  (기본 탭)
                ├── [modeSelection] ModeView
                │     └── 뒤로가기(툴바) → selectedTab = 0  (WorkoutTab 이동)
                │
                ├── [playing] ScoreView
                │     ├── 툴바 "조기 종료" 버튼 → 제거
                │     └── 뒤로가기(툴바) → "경기를 종료하시겠습니까?" 다이얼로그
                │                           ├── 확인 → viewModel.startNewMatch() (ModeView)
                │                           └── 취소 → 경기 계속
                │
                └── [finished] MatchResultView
                      ├── [SaveButton] → MatchPersistenceService.save()
                      ├── [RematchButton] → viewModel.restartMatch()
                      └── 뒤로가기(툴바) → viewModel.startNewMatch() (ModeView)
```

### 핵심 원칙

- **Workout 종료** 는 WorkoutTab "종료" 버튼만 가능. 경기 화면에서는 절대 Workout을 끊지 않는다.
- **경기 종료** 는 자연 완료 또는 playing 뒤로가기 다이얼로그로만 발생.
- **MatchResultView** 는 자연 종료 시에만 표시. 조기 종료 시 바로 ModeView로 리셋.
- **복수 경기**: 하나의 Workout 세션 안에서 경기를 여러 번 할 수 있다.

### MatchSessionView 상태 변수 변경

```swift
// 추가
@State private var showEndMatchConfirm = false    // playing 뒤로가기 다이얼로그
@State private var showEndWorkoutConfirm = false  // WorkoutTab 종료 다이얼로그

// 제거
// showEndConfirm (기존 단일 상태 → 위 두 상태로 분리)
```

### 툴바 백 버튼 로직

```swift
// modeSelection → WorkoutTab
// playing       → 경기 종료 다이얼로그
// finished      → startNewMatch() (ModeView)
ToolbarItem(placement: .topBarLeading) {
    switch viewModel.phase {
    case .modeSelection:
        BackButton { selectedTab = 0 }
    case .playing:
        BackButton { showEndMatchConfirm = true }
    case .finished:
        BackButton { viewModel.startNewMatch() }
    }
}
```

---

## 4. MatchResultView 재설계 (Watch 패턴 적용)

### 인터페이스 변경

```swift
// 변경 전
struct MatchResultView(
    didWin: Bool,
    completedSets: [(my: Int, your: Int)],
    onNewMatch: () -> Void,
    onExit: () -> Void
)

// 변경 후 (Watch 패턴)
struct MatchResultView(
    session: MatchSession,
    viewModel: MatchSessionViewModel   // @ObservedObject
)
```

### UI 구성

```
[결과 텍스트: 승리 / 패배]          ← resultColor (green/orange)
[세트 스코어: 2 : 1]
[세트별 상세: 6:4 | 3:6 | 6:3]     ← bestOfThree 포맷만 표시

[SaveButton]  [RematchButton]       ← HStack

← BackButton (툴바 leading)         ← startNewMatch() → ModeView
```

### 신규 컴포넌트 위치

```
iOSApp/Features/Match/Result/Components/
├── SaveButton.swift      ← @State saved: Bool, 저장 완료 시 체크마크
└── RematchButton.swift   ← 원형 회전 아이콘 버튼
```

---

## 5. MatchSessionViewModel 변경사항

```swift
// 추가할 필드
private var _currentSession: MatchSession?

// 추가할 메서드
func saveCurrentMatch() throws {
    guard let session = _currentSession else { return }
    let record = MatchRecord(from: session)
    try MatchPersistenceService.shared.save(record)
}

func restartMatch() {
    guard let options = _currentSession?.options else { return }
    startMatch(format: MatchFormat(rawValue: options.mode.rawValue) ?? .oneSet)
}

// finishMatch() 수정
func finishMatch(didWin: Bool, completedSets: [(my: Int, your: Int)]) {
    // ... 기존 session 생성 로직 ...
    _currentSession = session   // ← 추가
    phase = .finished(session)
}

// startNewMatch() 수정
func startNewMatch() {
    _currentSession = nil       // ← 추가
    currentOptions = nil
    phase = .modeSelection
}
```

### MatchViewModel 저장 책임 제거

`MatchViewModel.saveMatch()` 를 삭제하고 관련 `modelContext` 의존성 제거 (`SwiftData`, `SwiftUI` import 제거).  
저장은 `MatchResultView` 의 SaveButton → `MatchSessionViewModel.saveCurrentMatch()` 로 일원화.

`ScoreView` 에서도 `@Environment(\.modelContext)` 와 `viewModel.injectContext()` 호출을 제거한다.

---

## 6. WatchConnectivity 점검 결과

### 이번 범위 포함 (수정)

- `MatchViewModel.saveMatch()` 레거시 `Match`/`SetRecord` 자동 저장 → 삭제
- `MatchViewModel` 의 `modelContext` 의존성 제거 (SwiftData import 제거)

### 별도 추적 (Phase 1-A)

- **Watch → iOS ScoreUpdate 미구독**: `WatchConnectivityService.receivedScoreUpdate` 가 발행되지만 iOS MatchViewModel이 구독하지 않음. 양방향 실시간 동기화는 Phase 1-A에서 구현.

---

## 7. 테스트 계획

### 7-A. 단위 테스트 — MatchSessionViewModel

| 테스트 케이스 | 검증 내용 |
|---|---|
| `startMatch(format:)` | phase → `.playing`, `_currentSession` 초기화 |
| `finishMatch(didWin:completedSets:)` | phase → `.finished`, `_currentSession` 저장, session 필드 정확성 |
| `startNewMatch()` | phase → `.modeSelection`, `_currentSession` = nil |
| `restartMatch()` | 동일 포맷으로 `.playing` 재진입, 기존 `_currentSession` 덮어씀 |
| `saveCurrentMatch()` | MatchPersistenceService.save 호출됨 (mock) |
| `saveCurrentMatch()` - session 없음 | throw 없이 조용히 반환 |
| `endSession()` | phase → `.modeSelection`, 타이머 정지, metrics 리셋 |

### 7-B. 단위 테스트 — MatchViewModel

| 테스트 케이스 | 검증 내용 |
|---|---|
| `addPoint(.me)` | myGameScore 증가, sendScoreUpdate 호출 |
| `addPoint(.opponent)` | yourGameScore 증가 |
| `addPoint()` 세트 완료 조건 | 6게임 & 2게임 차 달성 시 completedSets 추가, mySetScore 증가 |
| `addPoint()` — 타이브레이크 없음 | 6:6 이후 7:5 필요 (noTieRule = true 기본값) |
| `addPoint()` — 경기 완료 | setsToWin 충족 시 isMatchOver = true, didWin 정확 |
| `addPoint()` — isMatchOver 후 | 추가 점수 무시 |
| `undo()` | score.lastAction 되돌림 |
| `saveMatch()` 메서드 | 삭제됨 — 존재하지 않아야 함 |

### 7-C. 시나리오 테스트 — 네비게이션 플로우

#### SC-1. 기본 경기 완주

```
HomeView → "운동 시작" 탭
→ MatchSessionView (Tab 1: ModeView)
→ "1세트" 선택 → ScoreView
→ 게임 반복 → 6게임 달성 → MatchResultView 자동 표시
→ BackButton → ModeView (Workout 유지)
```
**검증:** MatchResultView 표시, Workout 타이머 지속 동작

#### SC-2. modeSelection 뒤로가기

```
MatchSessionView (Tab 1: ModeView)
→ 뒤로가기 탭
```
**검증:** Tab 0 (WorkoutTab) 으로 전환, HomeView 이동 없음

#### SC-3. playing 중 뒤로가기 — 취소

```
ScoreView (경기 중)
→ 뒤로가기 탭
→ "경기를 종료하시겠습니까?" 다이얼로그 표시
→ "취소" 탭
```
**검증:** ScoreView 유지, 점수 변화 없음

#### SC-4. playing 중 뒤로가기 — 확인

```
ScoreView (경기 중)
→ 뒤로가기 탭 → 다이얼로그 확인
```
**검증:** ModeView 표시, 이전 점수 초기화, Workout 타이머 유지

#### SC-5. WorkoutTab 종료 — modeSelection

```
Tab 0 WorkoutTab (modeSelection 단계)
→ "종료" 탭 → 확인 다이얼로그 → 확인
```
**검증:** HomeView 이동, Workout 세션 종료

#### SC-6. WorkoutTab 종료 — playing 중

```
Tab 0 WorkoutTab (경기 진행 중)
→ "종료" 탭
```
**검증:** "경기 결과가 무효됩니다" 메시지 포함 다이얼로그 표시

#### SC-7. WorkoutTab 종료 — playing 중 확인

```
SC-6 에서 확인 탭
```
**검증:** HomeView 이동, Workout 세션 종료

#### SC-8. SaveButton 동작

```
MatchResultView 표시 (자연 종료)
→ SaveButton 탭
```
**검증:** 버튼이 체크마크로 변경 & 비활성화, MatchRecord가 SwiftData에 저장됨

#### SC-9. SaveButton 중복 탭 방지

```
SC-8 직후 SaveButton 재탭
```
**검증:** 두 번째 저장 시도 없음 (disabled 상태)

#### SC-10. RematchButton 동작

```
MatchResultView 표시
→ RematchButton 탭
```
**검증:** 동일 포맷으로 ScoreView 재진입, 점수 초기화

#### SC-11. 복수 경기 연속 플레이

```
경기 1 완료 → MatchResultView → BackButton → ModeView
→ 경기 2 시작 → 완료 → MatchResultView
```
**검증:** Workout 타이머 연속, 경기 2 결과 정상 표시

#### SC-12. ScoreView 툴바 검증

```
ScoreView 진입
```
**검증:** "조기 종료" 버튼 없음 (뒤로가기 버튼만 존재)

### 7-D. WatchConnectivity 테스트

| 테스트 케이스 | 검증 내용 |
|---|---|
| 점수 추가 시 sendScoreUpdate 호출 | `WCSession` mock으로 메시지 전송 확인 |
| Watch 미연결 상태 | `isReachable = false` → applicationContext fallback 동작 |
| Watch 앱 미설치 | `isWatchAppInstalled = false` → sendScoreUpdate 조용히 스킵 |
| receivedMetrics 수신 | Watch가 Metrics 전송 시 WorkoutTabView 수치 업데이트 (통합) |

---

## 8. 변경 파일 목록

| 파일 | 변경 종류 |
|---|---|
| `iOSApp/Features/Match/Session/MatchSessionView.swift` | 네비게이션 로직 전면 수정 |
| `iOSApp/Features/Match/Session/MatchSessionViewModel.swift` | `_currentSession`, `saveCurrentMatch()`, `restartMatch()` 추가 |
| `iOSApp/Features/Match/Result/MatchResultView.swift` | Watch 패턴으로 재설계 |
| `iOSApp/Features/Match/Result/Components/SaveButton.swift` | 신규 생성 |
| `iOSApp/Features/Match/Result/Components/RematchButton.swift` | 신규 생성 |
| `iOSApp/Features/Match/Score/ScoreView.swift` | `onEnd` 파라미터 & 툴바 버튼 제거 |
| `iOSApp/Features/Match/Score/MatchViewModel.swift` | `saveMatch()` 제거, `modelContext` 의존성 제거 |
