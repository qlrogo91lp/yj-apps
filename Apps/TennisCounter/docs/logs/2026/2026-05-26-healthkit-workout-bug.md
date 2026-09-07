# HealthKit 워크아웃 세션 버그 (피트니스 앱 0:05 표시)

## 작업일: 2026-05-26

## 증상

Apple 피트니스 앱 세션 목록에서 테니스 운동 duration이 실제(약 4분)와 전혀 다른 0:05로 표시됨.

---

## 원인 분석

### 버그 1: `stopWorkout()` 참조 미정리 — ghost 워크아웃 생성

`HealthKitService.stopWorkout()`이 완료된 후 `workoutSession`, `liveWorkoutBuilder`, `startDate`를 `nil`로 초기화하지 않는다.

`WorkoutSessionViewModel.endWorkout()`은 두 경로에서 호출될 수 있다:
- Watch에서 직접 종료 → `endWorkout()` 호출
- iOS 원격 신호(`receivedWorkoutEnd`) 수신 → `endWorkout()` 재호출

두 번째 호출 시 `healthKit.stopWorkout()`이 이미 종료된 세션 객체로 재진입하고, HealthKit에 짧은 ghost 워크아웃이 저장될 수 있다.

**코드 위치**: `HealthKitService.swift:109-128`, `WorkoutSessionViewModel.swift:136-142`

### 버그 2: `startWorkout()` 중복 가드 없음

`HealthKitService.startWorkout()`에 기존 세션 존재 여부 체크가 없다. 중복 호출 시 이전 `workoutSession` 참조를 덮어써서 이전 세션이 HealthKit에서 고아(orphan) 상태로 남고 짧은 duration으로 자동 종료된다.

**코드 위치**: `HealthKitService.swift:57-86`

### 버그 3: `endCollection` 전에 칼로리 수집

`stopWorkout()`에서 `session.end()` 직후 `collectCalories()`를 호출한다. 이 시점에는 세션 종료 직후라 아직 커밋되지 않은 데이터가 있을 수 있어 불완전한 값을 반환할 수 있다.

**코드 위치**: `HealthKitService.swift:118-120`

---

## 수정 내용

### `HealthKitService.swift`

| 버그 | 수정 |
|------|------|
| 중복 세션 생성 | `startWorkout()` 시작부에 `guard workoutSession == nil else { return }` 추가 |
| ghost 워크아웃 | `stopWorkout()` 완료 후 `workoutSession`, `liveWorkoutBuilder`, `startDate` = `nil` 초기화 |
| 칼로리 순서 | `collectCalories()` / `collectAverageHeartRate()` 호출을 `endCollection` 완료 후로 이동 |

---

## 테스트

- `WorkoutSessionViewModelTests`: `endWorkout()` 중복 호출 idempotent 검증
- HealthKit 실제 세션은 시뮬레이터 단위 테스트로 직접 검증 불가 (시스템 API 제약). 워크아웃 세션 생명주기는 실기기 수동 확인 필요.
