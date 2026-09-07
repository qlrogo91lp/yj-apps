# 뒤로 가기 확인 다이얼로그 리팩토링

## 작업일: 2026-05-18

## 배경

Watch `ScoreView`의 뒤로 가기 확인 로직에 두 가지 문제가 있었음:

1. **변수명 어색함**: `showEarlyEndConfirm`은 "무승부 조기 종료"를 암시하지만, 실제 의도는 단순 "경기 중단 후 모드 선택 복귀"
2. **조건 불완전**: 게임스코어만 체크해서 세트 1개 완료 후 새 게임 0-0이면 확인 없이 이탈 가능
3. **동작 오류**: 확인 시 `triggerEarlyEnd()` → 무승부 결과 화면으로 이동. 원하는 동작은 결과 없이 모드 선택으로 복귀

---

## 변경 내용

### Watch `ScoreView.swift`

| 항목 | 이전 | 이후 |
|---|---|---|
| 상태 변수 | `showEarlyEndConfirm` | `showExitConfirm` |
| 진행 중 조건 | `myGameScore == 0 && yourGameScore == 0` | `mySetScore == 0 && yourSetScore == 0 && myGameScore == 0 && yourGameScore == 0` |
| 확인 후 동작 | `viewModel.triggerEarlyEnd()` (무승부 결과화면) | `flowViewModel.startNewMatch()` (모드 선택으로 바로 이동) |

### Watch `ScoreViewModel.swift`

- `triggerEarlyEnd()` 함수 제거 (사용처 없음)

### 로컬라이제이션 (Watch + iOS 공통 변경)

| 키 | 이전 (ko) | 이후 (ko) |
|---|---|---|
| `early_end_confirm_title` | 경기 종료 / 경기를 종료할까요? | 경기 중단 / 경기를 중단할까요? |
| `early_end_confirm_message` | 매치를 무승부로 종료할까요? | 경기를 중단할까요? 점수는 저장되지 않습니다. |
| `early_end_confirm_yes` | 무승부 / 종료 | 확인 |

| 키 | 이전 (en) | 이후 (en) |
|---|---|---|
| `early_end_confirm_title` | End Match / End Match? | Quit Match / Quit Match? |
| `early_end_confirm_message` | End as a draw? / The match result will not be saved. | Quit the match? Your score won't be saved. / Your score won't be saved. |
| `early_end_confirm_yes` | Draw / End Match | Confirm |

---

## 영향 범위

- **iOS**: `WorkoutSessionView`의 alert 동작 자체는 이미 `startNewMatch()` 호출로 올바른 상태. `hasProgress`도 세트스코어 포함 조건이었음. 로컬라이제이션 문자열만 업데이트.
- **Watch**: 조건 + 동작 + 변수명 + 로컬라이제이션 모두 변경.
