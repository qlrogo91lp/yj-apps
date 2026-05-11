# MatchResultView 리팩토링 디자인

**날짜:** 2026-05-11
**대상 파일:** `WatchApp/Features/Match/Result/MatchResultView.swift`

## 목표

- ScrollView 제거 → 한 화면에 모든 내용 표시
- 버튼을 별도 컴포넌트로 분리
- 툴바에 백 버튼 추가 (모드 선택으로 이동)
- "새 게임" 버튼을 "재경기"로 변경 (같은 옵션으로 즉시 재시작)
- One Set 모드에서 세트 점수(1-0) 숨기기

## 레이아웃

```
[툴바] ← BackButton

WIN / LOSE / DRAW         (size: 20, bold, resultColor)
─────────────────
세트 점수  2 - 1          (size: 22, bold) — Best of 3만 표시
세트 상세  6-4 · 3-6      (size: 12, opacity: 0.7)
─────────────────
[저장 버튼]
[재경기 버튼]
```

## 크기/간격 변경

| 요소 | 현재 | 변경 후 |
|------|------|---------|
| 결과 타이틀 | size 26 | size 20 |
| 세트 점수 | size 30 | size 22 |
| VStack spacing | 10 | 8 |
| vertical padding | 10 | 6 |

## 컴포넌트 구조

`Result/Components/` 폴더 신설. 세 컴포넌트 모두 이 폴더에 배치.

### `BackButton.swift`
- 툴바 `topBarLeading`에 배치
- 탭 시 `flowViewModel.startNewMatch()` 호출 → 모드 선택 화면으로 이동
- confirmation dialog 없음 (결과 화면이므로 즉시 이동)
- `EarlyEndButton`과 동일한 스타일 패턴 참고

### `SaveButton.swift`
- `saved: Bool`, `action: () -> Void` 를 props로 받음
- saved 상태에 따라 아이콘/색상 분기 (현재 로직 동일)
- saved이면 disabled

### `RematchButton.swift`
- `action: () -> Void` 를 prop으로 받음
- 로컬라이제이션: `watch_rematch` 키 사용 (기존 `watch_new_match` 키 값 수정 또는 새 키 추가)

## WorkoutSessionViewModel 변경

`restartMatch()` 함수 추가:

```swift
func restartMatch() {
    guard let options = _currentSession?.options else { return }
    startMatch(options: options)
}
```

- 현재 세션의 options를 재사용해 새 세션 시작
- `_currentSession` 교체는 `startMatch(options:)` 내부에서 처리됨

## 모드별 세트 점수 조건부 표시

```swift
if session.options.mode == .bestOfThree {
    // 세트 점수 (mySetScore - yourSetScore) 표시
}
// completedSets는 항상 표시
```

One Set 모드에서 `1-0` 은 의미 없는 노이즈이므로 숨김. `completedSets` 상세(예: `6-4`)는 모드 무관하게 항상 표시.

## 로컬라이제이션

`watch_new_match` 키는 `MatchResultView`에서만 사용되며 의미가 완전히 바뀌므로 키 이름도 교체:

| 파일 | 변경 |
|------|------|
| `WatchApp/ko.lproj/Localizable.strings` | `watch_new_match` 삭제 → `watch_rematch` = "재경기" 추가 |
| `WatchApp/en.lproj/Localizable.strings` | `watch_new_match` 삭제 → `watch_rematch` = "Rematch" 추가 |

`result_save`, `result_saved` 키는 그대로 유지.

## 변경 파일 목록

| 파일 | 변경 종류 |
|------|----------|
| `WatchApp/Features/Match/Result/MatchResultView.swift` | 수정 |
| `WatchApp/Features/Match/Result/Components/BackButton.swift` | 신규 |
| `WatchApp/Features/Match/Result/Components/SaveButton.swift` | 신규 |
| `WatchApp/Features/Match/Result/Components/RematchButton.swift` | 신규 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 수정 |
| `WatchApp/ko.lproj/Localizable.strings` | 수정 |
| `WatchApp/en.lproj/Localizable.strings` | 수정 |
