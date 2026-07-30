# Plan 3 이후 앱 개선 4건 — 설계

**작성일**: 2026-07-30
**전제**: `docs/superpowers/plans/2026-07-30-ralli-kit-persistence-core.md`(Plan 3) 완료 후 착수한다.
**범위**: ① 총 칼로리 구분 표시, ② 경기 전체 멀티 undo, ③ 피트니스 목록 대표 지표 조사 스파이크.

구현은 항목별 독립 브랜치 + 독립 구현 플랜으로 진행하며, 순서는 **② → ① → ③**이다 (②는 순수 로직이라 가장 안전, ③은 ①의 결과가 실험 변수라 마지막).

---

## ① 총 칼로리 (활동/총 구분)

### 배경

앱은 이미 `activeEnergyBurned`(활동칼로리)를 수집·표시하고 있다. 애플 운동 앱처럼 **활동 칼로리와 총 칼로리(활동+휴식)를 구분해 둘 다** 보여주는 것이 목표다. `HKLiveWorkoutDataSource`는 테니스 종목에서 `basalEnergyBurned`를 이미 자동 수집하므로(WWDC21 확인) 라이브 빌더 statistics로 basal 합계를 읽기만 하면 된다.

### 패키지 (ralli-kit WorkoutCore — 패키지 변경 수반)

- `WorkoutSessionService`에 `@Published public private(set) var currentBasalCalories: Double = 0` 추가.
- `workoutBuilder(_:didCollectDataOf:)`에서 `basalEnergyBurned` 통계의 `sumQuantity` 반영.
- `typesToRead`에 `HKQuantityType(.basalEnergyBurned)` 추가 (share는 라이브 빌더가 자동 저장하는 경로를 실기기에서 확인 후 필요 시에만 추가).
- `stopWorkout()`의 `WorkoutResult`에 `totalCaloriesBurned` 추가.
- ralli-kit 테스트 갱신 + README 갱신. 로컬 참조 상태라 즉시 소비 가능.

### 앱 레이어

- `Shared/Models/WorkoutMetrics.swift`: `totalCalories: Double` 필드 추가. **와이어 하위호환** — `toDictionary()`에 키 추가, `init?(from:)`은 키가 없으면 `calories`(활동)로 폴백.
- `Shared/Models/MatchSession.swift`: 경기 구간 분리를 위해 `basalKcalAtStart` 보관 (기존 `kcalAtStart` 패턴 동일).
- `Shared/Services/ConnectivityMessages.swift`의 `MatchEndMessage`: `totalCalories: Double?` 추가 (없으면 nil — 하위호환).
- `Shared/Persistence/Match.swift`: `totalCaloriesBurned: Double?` 추가 (CloudKit 규칙: optional, 라이트웨이트 마이그레이션).

### UI

- **Watch 메트릭 탭** (`WorkoutMetricsView`): 기존 kcal 줄 = 활동칼로리 유지, 총 칼로리 줄 추가.
- **iOS 워크아웃 탭** (`WorkoutMetricsGrid`): 항상 0인 "걸음" 카드(수집 자체를 안 함 — `broadcastMetrics`가 `steps: 0` 고정 전송)를 **총 칼로리 카드로 교체**해 2×2 그리드 유지. 걸음 관련 데드 코드(`WorkoutMetrics.steps` 등)는 이 작업에서 함께 정리할지 구현 플랜에서 판단.
- **History 상세** (`MatchDetailSheet`) + **Summary 워크아웃 통계** (`WorkoutStatsGrid`): 총 칼로리 표시. StatCard 규칙 준수 — 값에 단위 suffix 금지, 단위는 타이틀에.

### 피트니스 앱 반영

basal 샘플은 라이브 빌더가 이미 워크아웃에 붙이므로 피트니스 상세의 "총 킬로칼로리"는 자동 반영이 예상된다. **실기기 확인 항목**으로 남긴다 (③ 스파이크와 함께 확인).

### 테스트

- `WorkoutMetrics` 직렬화 왕복 + 구버전 딕셔너리(totalCalories 키 없음) 폴백.
- `WorkoutSessionViewModel`: 경기 종료 시 총 칼로리가 경기 구간(시작값 차감)으로 계산되는지.
- ralli-kit: basal 통계 반영 로직.

---

## ② 경기 전체 멀티 undo

### 배경

현재 `Score`는 스냅샷 1개만 보관해 직전 포인트만 되돌릴 수 있다. 실수 복구에 공백이 없으려면 undo가 게임·세트 경계를 넘어야 하므로, **경기 시작까지 전 구간 연속 undo**가 목표다. (초기에 "현재 게임 내"로 논의했으나, 스냅샷을 ViewModel 레벨로 올리면 세트 경계를 넘는 쪽이 오히려 코드가 단순하고 — 부분 스냅샷·클리어 규칙이 불필요 — 세트 마지막 포인트 실수라는 가장 치명적인 케이스를 커버하므로 경기 전체로 확정.)

### 설계 (`ScoreViewModel` — iOS·Watch 양쪽 동일 적용)

- 스냅샷을 `Score` 내부가 아니라 **`ScoreViewModel` 레벨의 전체 상태 스냅샷 스택**으로 구현:
  - 스냅샷 내용: `Score` 상태(포인트·게임 모드·타이브레이크 점수) + `myGameScore`/`yourGameScore` + `mySetScore`/`yourSetScore` + `completedSets` + `tieBreakInProgress`.
  - `Score`는 내부 상태를 담은 스냅샷 타입과 `makeSnapshot()`/`restore(_:)`를 노출 (기존 private `SnapShot` 승격).
- `addPoint(_:)` 진입 시 push, `undo()`는 pop 후 전체 복원. 포인트당 작은 struct 하나라 경기 전체를 쌓아도 메모리 부담 없음.
- **스택 클리어 시점**:
  - `resetAll(options:)` — 새 경기 시작
  - `applyRemoteState(...)` — 원격 상태 수신 (mirror 쪽 undo 불가 유지, 기존 동작 동일)
  - ScoreEditSheet 수동 수정 시 (iOS `onChange` 경로) — 수동 수정은 새 기준점이며, 수정 이전 과거로 undo되는 혼란을 방지한다.
- 경기 종료 포인트는 `onMatchFinished` → 결과 화면 전환이므로 undo 대상이 아니다 (기존 동작 유지 — 결과 화면에는 재경기 버튼이 있다).
- `var canUndo: Bool { !snapshots.isEmpty }`를 ViewModel에 추가. 양 플랫폼 `UndoButton` 표시 조건을 `score.lastAction` 기반 → `canUndo`로 교체 (undo 후에도 스택이 남으면 버튼 유지). `Score.lastAction`은 남은 용처가 없으면 제거.

### 동기화

기존 메커니즘 그대로 — undo → `onStateChanged` → 전체 `ScoreState` 브로드캐스트 (게임·세트 스코어와 `completedSets`가 이미 포함돼 있어 세트 경계를 넘는 undo도 그대로 동기화). 스택은 driver 로컬에만 존재하고 와이어 포맷 변경 없음.

### 테스트 (iOS·Watch `ScoreViewModelTests`)

- 포인트 N개 입력 후 연속 undo → 게임 포인트 0:0 복귀.
- 게임 경계 넘는 undo: 게임 획득 직후 undo → 게임 스코어 원복 + 직전 포인트 상태(예: 40:30) 복원.
- 세트 경계 넘는 undo: 세트 완료 직후 undo → `completedSets`·세트 스코어 원복.
- 경기 시작까지 전부 undo → 모든 스코어 0, `canUndo == false`.
- 타이브레이크 진입 경계 undo (진입 직전 상태 복원, `tieBreakInProgress` 원복).
- `applyRemoteState` 후 `canUndo == false`.
- 수동 수정(클리어 경로) 후 `canUndo == false`.

---

## ③ 피트니스 목록 대표 지표 조사 스파이크

### 배경

피트니스 앱 운동 목록에서 Ralli 기록이 kcal 대신 **시간**으로 표시된다. 상세 화면에는 kcal이 정상이므로 데이터 누락이 아니라 목록의 대표 지표 선택 로직 문제다. Apple 개발자 포럼에서도 미해결(공식 API·메타데이터 키 없음, 일부 서드파티만 kcal 표시 성공 사례 보고 — thread 679835). 따라서 구현이 아닌 **타임박스 조사**로 정의한다.

### 절차

1. 실기기에서 Apple 운동 앱 테니스 1건 + Ralli 1건 기록.
2. 디버그용 덤프 코드(iOS, DEBUG 전용)로 두 `HKWorkout`의 `metadata`·전체 `statistics`·`sourceRevision`·`device`·`workoutEvents`를 전수 비교.
3. ①(basal 포함) 반영 빌드로 재실험 — 목록 지표가 kcal로 바뀌는지 관찰.
4. 결론을 `docs/superpowers/logs/`에 기록.

### 종료 조건

- 차이점에서 해결 단서 발견 → 별도 소형 플랜으로 수정.
- 시스템 동작(서드파티 기본값)이라는 결론 → 수용하고 문서화로 종료. 실험 2회(±덤프 분석)로 타임박스.

---

## 결정 기록

| 결정 | 내용 |
|---|---|
| 총 칼로리 수집 | WorkoutCore 확장 (앱 직접 쿼리 대신) |
| 걸음 카드 | 총 칼로리 카드로 교체 (걸음은 수집한 적 없어 항상 0) |
| undo 범위 | 경기 전체 — 게임·세트 경계를 넘어 경기 시작까지 (ViewModel 레벨 스냅샷이라 세트 내 제한보다 오히려 단순) |
| 수동 수정 vs undo | ScoreEditSheet 수정 시 undo 스택 클리어 |
| 피트니스 목록 지표 | 조사 스파이크 (공식 해결책 부재) |
