# MatchView 백 버튼으로 경기 제어

**Date:** 2026-05-07  
**Scope:** Watch App - MatchView 네비게이션 개선

## 개요

현재 MatchView에서 경기 중간에 나갈 방법이 제한적입니다 (EarlyEndButton은 특정 점수 조건에서만 표시). 이를 개선하기 위해 NavigationBackButton 스타일의 백 버튼을 MatchView 좌측 상단에 추가하여, 언제든 모드 선택 화면으로 돌아갈 수 있도록 합니다.

## 디자인

### 1. UI 변경

**추가:**
- MatchView 좌측 상단에 백 버튼 추가
- NavigationBackButton과 동일한 스타일 (`Image(systemName: "chevron.left")`)
- 항상 활성 상태로 표시

**제거:**
- EarlyEndButton 제거 (우측 상단)
- MatchViewModel의 `showEarlyEndButton` 속성 제거
- MatchViewModel의 `updateEarlyEndVisibility()` 메서드 제거

### 2. 동작 로직

**백 버튼 탭:**

```
if 경기 시작 전 (myGameScore == 0 && yourGameScore == 0):
  → 바로 모드 선택으로 이동 (다이얼로그 없음)
else (경기 중):
  → "경기를 종료하시겠습니까?" 확인 다이얼로그 표시
    - 취소: 다이얼로그 닫기, MatchView 유지
    - 종료: flowViewModel.finishMatch(.draw, completedSets) 호출
      → 모드 선택 화면으로 복귀
```

**운동 세션:**
- 백 버튼으로 매치만 종료 → 운동 세션은 계속 진행
- 모드 선택 화면에서 다시 경기 시작 가능

### 3. 코드 구현 범위

**MatchView 수정:**
- `@State private var showEndConfirm = false` 추가
- ZStack 최상단에 백 버튼 레이아웃 추가
- confirmationDialog 추가: 제목 "경기를 종료하시겠습니까?"
- 백 버튼 탭 시 로직:
  ```swift
  if myGameScore > 0 || yourGameScore > 0 {
      showEndConfirm = true
  } else {
      flowViewModel.finishMatch(.draw, completedSets)
  }
  ```

**MatchViewModel 수정:**
- `showEarlyEndButton: Bool` 속성 제거
- `updateEarlyEndVisibility()` 메서드 제거
- `triggerEarlyEnd()` 메서드는 유지 (확인 다이얼로그 후 호출)

**라벨 (ko.lproj/Localizable.strings):**
- "경기를 종료하시겠습니까?" 추가
- "취소" / "종료" 버튼 레이블 (기존 사용 가능하면 재사용)

## UX 이점

1. **일관성:** 하나의 백 버튼으로 모든 상황에서 모드 선택으로 복귀 가능
2. **명확성:** 네비게이션 백 버튼과 동일한 UI로 사용자 학습 곡선 감소
3. **유연성:** 경기 전/중 언제든 나갈 수 있지만, 경기 중에는 의도 확인 필요
4. **단순성:** EarlyEndButton의 조건부 표시 로직 제거로 코드 간결화

## 테스트 케이스

| 상황 | 액션 | 예상 결과 |
|------|------|----------|
| 모드 선택 후 경기 미시작 (0-0) | 백 버튼 탭 | 다이얼로그 없이 모드 선택으로 이동 |
| 경기 중 (점수 입력됨) | 백 버튼 탭 | "경기를 종료하시겠습니까?" 다이얼로그 표시 |
| 다이얼로그에서 취소 | 취소 버튼 탭 | MatchView 유지 |
| 다이얼로그에서 종료 | 종료 버튼 탭 | 모드 선택으로 복귀, 운동 세션 진행 중 |
| 경기 완료 (결과 화면) | 백 버튼 탭 | 모드 선택으로 복귀 |

## 파일 변경 목록

- `WatchApp/Features/Match/MatchView.swift` - 백 버튼 UI, 다이얼로그 로직 추가
- `WatchApp/Features/Match/MatchViewModel.swift` - showEarlyEndButton, updateEarlyEndVisibility() 제거
- `WatchApp/ko.lproj/Localizable.strings` - 다이얼로그 메시지 추가
