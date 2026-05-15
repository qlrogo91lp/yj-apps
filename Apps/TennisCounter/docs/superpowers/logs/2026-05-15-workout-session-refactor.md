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
