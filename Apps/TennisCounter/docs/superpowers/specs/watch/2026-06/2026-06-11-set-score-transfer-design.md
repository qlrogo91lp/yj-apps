# Set Score Transfer — Design Spec

## 개요

Watch 앱 ScoreView에서 세트 스코어가 잘못 기록됐을 때, 알약(Capsule) 모양의 SetScores 영역을 롱프레스해 세트 귀속을 이전할 수 있는 기능.

**핵심 의도**: "추가/삭제"가 아닌 "방금 잘못 기록된 세트를 올바른 쪽으로 이전"하는 수정 플로우.

---

## 진입 조건

- `SetScores` 컴포넌트가 표시 중일 때만 (세트 스코어가 1 이상인 상태)
- 롱프레스 최소 지속 시간: **0.5초**
- 진입 시 햅틱 피드백 1회 (`.impactOccurred()`)

---

## 편집 모드 외형

```
평상시:      1 SET 0
편집 모드: ‹  1 SET 0  ›
```

- `scaleEffect(1.12)` 애니메이션으로 알약이 약간 커짐
- SF Symbols `chevron.left` / `chevron.right` 버튼이 알약 좌우에 나타남 (간격 6pt, 흰색)
- 테두리 색 변화 없음 — scale 변화만으로 편집 중임을 표시

---

## 이전 로직

총 완료된 세트 수는 고정, 귀속만 변경.

| 버튼 | 결과 |
|---|---|
| `‹` (chevron.left) | 상대 세트 -1, 내 세트 +1 |
| `›` (chevron.right) | 내 세트 -1, 상대 세트 +1 |

### 비활성화 조건

이전할 세트가 없으면 해당 chevron을 `.opacity(0.2)`로 dim 처리.

- 내 세트가 0이면 `›` 비활성
- 상대 세트가 0이면 `‹` 비활성

### completedSets 처리

`completedSets` 배열(세트별 게임 스코어 기록)은 수정하지 않음. `mySetScore` / `yourSetScore` 카운트만 조정.

---

## 편집 모드 종료

편집 모드 진입 시 전체 화면을 덮는 투명 레이어를 삽입해 `PlayerPointButton` 탭을 차단.

| 방법 | 동작 |
|---|---|
| 탭 아웃 | 알약 외 영역(투명 레이어) 탭 시 즉시 종료. 포인트 추가 없음. |
| 자동 타임아웃 | 마지막 chevron 탭 후 2.5초 무조작 시 자동 종료 |

종료 시 `scaleEffect`, chevron 버튼, 투명 레이어 모두 `.easeInOut(duration: 0.2)` 애니메이션으로 복귀.

---

## 영향 파일

| 파일 | 변경 내용 |
|---|---|
| `WatchApp/Features/Match/Score/Components/SetScores.swift` | 롱프레스 제스처, 편집 상태 UI (chevron 버튼, scaleEffect) 추가 |
| `WatchApp/Features/Match/Score/ScoreViewModel.swift` | `transferSet(to: PlayerSide)` 메서드 추가 |
| `WatchApp/Features/Match/Score/ScoreView.swift` | `onSetTransfer` 콜백 연결 |

---

## 비고

- watchOS 편집 UI는 터치 타깃 최소 44pt 준수
- WatchConnectivity 동기화: 이전 후 즉시 `sendScoreState()` 호출하여 iPhone에 반영
