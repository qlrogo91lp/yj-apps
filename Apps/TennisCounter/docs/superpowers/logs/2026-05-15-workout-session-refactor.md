# WorkoutSession 리팩토링 로그

## 작업일: 2026-05-15

## 배경

iOS `MatchSessionView`와 Watch `WorkoutSessionView`의 네이밍 불일치 + `noAdRule`/`noTieRule`이 `ScoreView`에 전달되지 않는 버그 발견.

---

## 변경 내용

### 1. iOS MatchSession → WorkoutSession 이름 통일

Watch 앱과 네이밍을 맞추고 `MatchSession` 데이터 모델(`Shared/Models/MatchSession.swift`)과의 이름 충돌을 해소.

| 이전 | 이후 |
|---|---|
| `iOSApp/Features/Match/Session/MatchSessionView.swift` | `iOSApp/Features/Match/WorkoutSession/WorkoutSessionView.swift` |
| `iOSApp/Features/Match/Session/MatchSessionViewModel.swift` | `iOSApp/Features/Match/WorkoutSession/WorkoutSessionViewModel.swift` |
| `class MatchSessionViewModel` | `class WorkoutSessionViewModel` |
| `struct MatchSessionView` | `struct WorkoutSessionView` |

### 2. iOS ModeView 인라인 병합

Watch는 `WorkoutSessionView` 내부에서 `ModeView(viewModel:)`를 호출하는 구조인데, iOS는 `ModeView`가 별도 파일로 분리되어 있고 `ModeViewModel`도 독립적으로 존재했음. `MatchSessionView`에서만 사용되는 단순 화면이므로 인라인으로 병합.

**삭제된 파일:**
- `iOSApp/Features/Match/Mode/ModeView.swift`
- `iOSApp/Features/Match/Mode/ModeViewModel.swift`

**변경 내용:**
- `WorkoutSessionView.modeSelectionContent` 프로퍼티로 인라인
- `noAdRule`, `noTieRule` 상태를 `@State`로 `WorkoutSessionView`에서 관리
- `ModeListItem.swift` 컴포넌트는 유지 (인라인에서도 사용)

### 3. noAdRule/noTieRule 버그 수정

**버그:** `ModeView`에서 설정한 `noAdRule`/`noTieRule`이 `MatchOptions`에 담겼지만, `WorkoutSessionView`에서 `ScoreView`에 `format`만 전달 → 룰이 무시됨.

**수정 내용:**

`ScoreView` / `ScoreViewModel` 인터페이스 변경:
- `format: MatchFormat` → `options: MatchOptions`
- `ScoreViewModel.init`에서 `score.noAdRule = options.noAdRule` 적용

**추가 수정 (발견된 리팩토링 항목):**

| 항목 | 변경 내용 |
|---|---|
| `noTieRule` 미구현 | 6-6 도달 시 `score.setTieBreakMode()` 호출 연결 |
| `isTieBreak` 부정확 | `myGameScore == 6 && yourGameScore == 6` → `score.gameMode == .tieBreak` 기반으로 변경 (noTieRule 반영) |
| 타이브레이크 세트 종료 미처리 | `isSetComplete()`에 7-6 케이스 추가 |

---

## 수정된 파일 목록

| 파일 | 변경 종류 |
|---|---|
| `iOSApp/Features/Match/WorkoutSession/WorkoutSessionViewModel.swift` | 신규 (MatchSessionViewModel rename) |
| `iOSApp/Features/Match/WorkoutSession/WorkoutSessionView.swift` | 신규 (MatchSessionView rename + ModeView 인라인) |
| `iOSApp/Features/Match/Score/ScoreViewModel.swift` | 수정 |
| `iOSApp/Features/Match/Score/ScoreView.swift` | 수정 |
| `iOSApp/Features/Match/Result/MatchResultView.swift` | 수정 (타입명 변경) |
| `iOSApp/iOSApp.swift` | 수정 (참조 변경) |
| `iOSApp/Features/Match/Session/` (폴더) | 삭제 |
| `iOSApp/Features/Match/Mode/ModeView.swift` | 삭제 |
| `iOSApp/Features/Match/Mode/ModeViewModel.swift` | 삭제 |

---

## 빌드 결과

```
** BUILD SUCCEEDED **
```

---

## iOS ↔ Watch Feature 폴더 대칭화 (2026-05-15 추가)

### 배경

iOS와 Watch의 `Features/` 폴더 구조 비교 중 5개 비대칭 항목 발견. 구조 일관성 확보를 위해 정리.

### 변경 내용

#### 1. iOS Home 위치 통일

Watch와 동일하게 `Features/Home/`으로 이동.

| 이전 | 이후 |
|---|---|
| `iOSApp/Features/Match/Home/HomeView.swift` | `iOSApp/Features/Home/HomeView.swift` |

#### 2. iOS Mode 화면 분리

기존에 `WorkoutSessionView.modeSelectionContent` @ViewBuilder로 인라인 구현되어 있던 Mode 선택 UI를 독립 파일로 추출. `ModeListItem`도 잘못된 `Workout/Components/`에서 `Mode/Components/`로 이동.

**신규 파일:**
- `iOSApp/Features/Match/Mode/ModeView.swift` — Watch의 `ModeView`와 동일 구조 (`@ObservedObject viewModel`, `@StateObject selectionVM`)
- `iOSApp/Features/Match/Mode/ModeViewModel.swift` — Watch의 `ModeViewModel`과 동일 (`selectedMode`, `noAdRule`, `noTieRule`, `options`)
- `iOSApp/Features/Match/Mode/Components/ModeListItem.swift` — `Workout/Components/`에서 이동

**변경 파일:**
- `WorkoutSessionView.swift` — `@State noAdRule/noTieRule` 제거, `modeSelectionContent` 제거, `.modeSelection` case에서 `ModeView(viewModel: viewModel)` 호출로 교체

#### 3. Watch ScoreView 이름 통일

`Score/` 폴더에 있음에도 `MatchView`라는 이름을 사용하던 Watch 뷰를 `ScoreView`로 통일.

| 이전 | 이후 |
|---|---|
| `WatchApp/Features/Match/Score/MatchView.swift` (`struct MatchView`) | `ScoreView.swift` (`struct ScoreView`) |
| `WatchApp/Features/Match/Score/MatchViewModel.swift` (`class MatchViewModel`) | `ScoreViewModel.swift` (`class ScoreViewModel`) |

**참조 변경:**
- `WorkoutSessionView.swift` (Watch) — `.playing` case에서 `MatchView` → `ScoreView`

#### 4. iOS Workout 독립 Feature화

Watch처럼 `Workout`을 `Match` 하위가 아닌 독립 Feature로 분리.

| 이전 | 이후 |
|---|---|
| `iOSApp/Features/Match/Workout/WorkoutTabView.swift` | `iOSApp/Features/Workout/WorkoutTabView.swift` |
| `iOSApp/Features/Match/Workout/Components/WorkoutControls.swift` | `iOSApp/Features/Workout/Components/WorkoutControls.swift` |

#### 5. iOS WorkoutSession 독립 Feature화

Watch의 `Features/WorkoutSession/`과 동일한 위치로 이동.

| 이전 | 이후 |
|---|---|
| `iOSApp/Features/Match/WorkoutSession/WorkoutSessionView.swift` | `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` |
| `iOSApp/Features/Match/WorkoutSession/WorkoutSessionViewModel.swift` | `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` |

### 대칭화 후 구조

```
WatchApp/Features/               iOSApp/Features/
─────────────────                ─────────────────
Home/                            Home/               ✅
Match/                           Match/
  Mode/                            Mode/             ✅
  Score/                           Score/            ✅
  Result/                          Result/           ✅
Workout/                         Workout/            ✅
WorkoutSession/                  WorkoutSession/     ✅
```

### 빌드 결과

```
iOS:   ** BUILD SUCCEEDED **
Watch: ** BUILD SUCCEEDED **
```
