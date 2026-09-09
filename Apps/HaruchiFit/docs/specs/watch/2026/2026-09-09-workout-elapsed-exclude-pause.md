# 워치 경과시간에서 일시정지를 뺀다

작성일: 2026-09-09
상태: **확정 설계 — 구현 대기**
선행 문서: [YJKit 탐색 — elapsedSeconds 틱 카운터](../../../../../../Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md) ·
[구간 시간 작업 기록](../../../logs/2026/2026-09-09-segment-duration-tick-counter.md) ·
[아키텍처](../../shared/2026/2026-09-02-haruchi-fit-architecture.md)
후속 문서: [잔디 일별 집계](../../shared/2026/2026-09-09-grass-daily-aggregate.md) — 이 작업이 그쪽의 선행이다

---

## 한 줄로

하루치가 저장하고 보여주는 시간이 **일시정지한 시간을 포함**한다. 세트 사이에 정지를 누르는
사용자는 45분 운동이 70분으로 기록된다. 잔디 농도가 통째로 한 단계 밀린다.

## 왜 지금 고치나

잔디 집계(Phase 2 #1)의 입력이 이 값이다. 부풀려진 시간 위에 농도를 얹으면
**화면의 목적 자체가 깨진다** — 잔디는 "얼마나 했나"를 보여주는 화면이다.

그리고 **지금이 가장 싼 시점이다.** 하루치는 미출시고 저장된 기록이 실기기 검증 몇 건뿐이라
보정할 과거 데이터가 없다. Ralli 는 이미 출시돼 그 문제를 안고 있다.

## 현재 무슨 일이 벌어지나

워치 안에 시계가 두 개 있고 서로 다른 것을 센다.

| 시계 | 재는 법 | 일시정지 | 손목 내리면 |
|---|---|---|---|
| `WorkoutSessionService.elapsedSeconds` | 1초 `Timer` 틱 | **뺀다** | ❌ 멈추고 안 따라잡는다 |
| `WorkoutResult.durationSeconds` | `Date().timeIntervalSince(start)` | **포함한다** | ✅ 정확 |
| `SegmentTracker.elapsedSeconds` | `Date().timeIntervalSince(startedAt)` | **포함한다** | ✅ 정확 |

지금 하루치는 이렇게 쓴다.

| 쓰는 곳 | 소스 | 결과 |
|---|---|---|
| W1 진행 중 화면의 큰 시간 | `session.elapsedSeconds` | 정지 제외 · **손목 내리면 밀린다** |
| 컴플리케이션 경과시간 | `session.elapsedSeconds` | 위와 같음 |
| 구간(세그먼트) 길이 | `SegmentTracker` | 정지 **포함** · 정확 |
| 저장되는 총 시간 | `WorkoutResult.durationSeconds` | 정지 **포함** · 정확 |

**네 값이 두 갈래로 갈려 있다.** 정지 없이 짧게 운동하면 비슷해서 지금까지 드러나지 않았다.

## 결정

### 1. 경과시간은 일시정지를 **뺀다**

"운동한 시간"이 사용자가 기대하는 의미다. 잔디·요약·구간 바가 전부 그 뜻으로 읽힌다.

### 2. 시계는 앱 레이어(`SegmentTracker`)가 소유한다. YJKit 은 건드리지 않는다

**세그먼트 때문이다.** HealthKit 은 근력↔유산소 구간 전환을 모른다 (아키텍처 2절, 실기기로 확정).
그러니 **구간별 시간에서 정지를 빼는 일은 어차피 앱이 할 수밖에 없다.** 탐색 문서의 D안
(`HKWorkout.duration` 사용)이 총 시간을 해결해줘도 구간은 못 해결하고, 그러면
`구간 합계 == 총 시간` 불변조건이 다시 깨진다 — PR #19 에서 맞춰놓은 그 조건이다.

하루치는 이미 *"시간의 진실은 앱이 소유한다"* 를 `SegmentTracker` 로 결정했다.
정지 제외는 그 소유권의 연장이지 새 원칙이 아니다.

**YJKit 통합은 이 문서의 범위가 아니다.** 3개 앱의 저장값 의미가 한꺼번에 바뀌고, Ralli 는
기존 기록 보정 문제가 딸려오며, 판단 근거가 될 실기기 확인 3항목이 아직 안 됐다.
탐색 문서에 그대로 열어둔다.

### 3. `SegmentTracker` 를 워치의 **단일 시계**로 만든다

저장값만 고치면 워치 화면엔 32분, 요약엔 45분이 뜬다. 지금보다 나을 게 없다.
화면·컴플리케이션·구간·총시간이 **모두 같은 값**을 쓴다.

## 설계

### `SegmentTracker` 확장

```
SegmentTracker
  pause()                  ← 정지 시각을 붙든다
  resume()                 ← 정지 길이를 누적에 더한다
  elapsedSeconds: Int      ← 벽시계 − 정지 누적 (정지 중이면 정지 시작 시점에 멈춰 있다)
  closeOpenSegment(kind:)  ← 변경 없음. elapsedSeconds 를 쓰므로 자동으로 정지가 빠진다
```

`now: () -> Date` 주입은 이미 있다. 정지·재개를 섞은 시나리오를 HealthKit 없이 테스트한다.

### `WorkoutViewModel` 배선

- `session.$isPaused` 구독에서 `segments.pause()` / `segments.resume()` 를 부른다.
  **정지 상태의 단일 소스는 지금처럼 `WorkoutSessionService` 다** — 낙관적 토글을 만들지 않는다
  (루트 `CLAUDE.md` 워크아웃 계약)
- `snapshot(of:)` 의 `elapsedSeconds` 를 `segments.elapsedSeconds` 로 교체
- `publishSnapshot` 의 `elapsedSeconds` 를 `segments.elapsedSeconds` 로 교체
- `record(from:)` 의 `totalSeconds` 를 `result.durationSeconds` 대신 `segments.elapsedSeconds` 로 교체

### 지켜야 할 불변조건

- `구간 길이의 합 == totalSeconds` (반올림 오차 이내)
- `totalSeconds <= endedAt − startedAt` — 정지가 있으면 작다. **둘이 같아야 한다는 가정을 코드
  어디에도 두지 않는다**
- 정지 중에는 화면·컴플리케이션의 경과시간이 **멈춰 있다** (지금 동작 유지)

### 건드리지 않는 것

- `Packages/YJKit` 전체. `WorkoutSessionService.elapsedSeconds` 는 그대로 둔다 (다른 두 앱이 쓴다)
- `WorkoutRecordMessage` 의 **형태**. 필드를 더하지 않는다 — `totalSeconds` 의 의미만 바뀐다
- iOS 타깃. 폰은 받은 값을 그대로 저장한다
- 일시정지 시간 자체의 저장. 보여주는 화면이 없다

## 타깃과 파일

| 파일 | 타깃 |
|---|---|
| `WatchApp/Features/Workout/SegmentTracker.swift` | `HaruchiFit Watch App` |
| `WatchApp/Features/Workout/WorkoutViewModel.swift` | `HaruchiFit Watch App` |
| `watchosTests/Workout/SegmentTrackerTests.swift` (확장) | `HaruchiFitWatchTests` |

CI 가 3개 앱을 전부 빌드하는 일은 없다 — 패키지를 안 건드린다.

## 검증

### 유닛 테스트 (`HaruchiFitWatchTests`)

- 정지 없이 40분 → `elapsedSeconds == 2400`
- 20분 운동 → 10분 정지 → 20분 운동 → `elapsedSeconds == 2400` (정지 10분 제외)
- 정지 중에는 `elapsedSeconds` 가 늘지 않는다
- 정지를 사이에 낀 구간 전환 → 구간 길이에도 정지가 빠진다
- 구간 합계 == `totalSeconds`
- 정지 상태로 세션을 끝내도 값이 어긋나지 않는다
- `reset()` 이 정지 누적까지 지운다

### 실기기

- [ ] 20분쯤 돌리다 5분 정지 후 재개 → 요약의 총 시간이 **정지를 뺀 값**인지
- [ ] 구간 종목별 분의 합이 총 시간과 맞는지
- [ ] **WC 재검증 2항목** — 컴플리케이션 경과시간, 일시정지 시 멈춤.
      **이 작업이 스냅샷 소스를 바꾸므로 이미 끝낸 검증을 다시 연다**
- [ ] 워크아웃 중 손목을 30초 내렸다 올렸을 때 화면 시간이 **건너뛰어 있는지**
      (틱이었을 땐 멈춰 있었다)

## 탐색 문서에 남길 것

`Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md` 에 한 절을 더한다.

> 하루치는 앱 레이어(`SegmentTracker`)에서 정지 제외로 갔다. 문서의 A안이지만
> **임시방편이 아니라 의도된 선택**이다 — HealthKit 이 세그먼트를 모르므로 구간에서
> 정지를 빼는 일은 앱이 할 수밖에 없고, 그 시계를 두 개 둘 이유가 없다.
> YJKit 통합을 결정할 때 이걸 선례로 본다.

## 열린 채로 두는 것

- **YJKit `elapsedSeconds` 통합** — 탐색 문서의 미결 3가지 그대로. Ralli 저장값이 짧은지
  실기기 확인이 선행이다
- **골프의 화면/저장 불일치** — 같은 미결에 속한다
