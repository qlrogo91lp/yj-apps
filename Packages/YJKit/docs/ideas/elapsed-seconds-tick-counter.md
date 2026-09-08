# `elapsedSeconds` 가 벽시계가 아니라 틱 카운터다

상태: **확인 필요 — 아직 고치지 않았다**
계기: 하루치 핏 구간 시간이 실기기에서 "근력 0분" 으로 나온 문제
([작업 기록](../../../../Apps/HaruchiFit/docs/logs/2026/2026-09-09-segment-duration-tick-counter.md))

## 무엇이 문제인가

`WorkoutSessionService.elapsedSeconds` 는 벽시계가 아니라 **1초 `Timer` 가 올리는 틱 카운터**다.

```swift
// Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift
private func startTimer() {
    elapsedSeconds = 0
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        DispatchQueue.main.async { self?.elapsedSeconds += 1 }
    }
}
```

실기기에서 손목을 내리거나 화면이 꺼지면 이 타이머가 멈추고, **다시 켜져도 밀린 만큼
따라잡지 않는다.** 하루치에서는 40분 세션의 구간이 몇 초로 잡혔다 (사용자 확인).

시뮬레이터는 앱이 계속 앞에 떠 있어 틱이 벽시계와 거의 같게 쌓인다 — 그래서 시뮬레이터로는
재현되지 않는다.

## 어디에 퍼져 있나

**같은 서비스 안에도 벽시계 경로가 따로 있다.** `stopWorkout()` 이 돌려주는
`WorkoutResult.durationSeconds` 는 `Int(Date().timeIntervalSince(start))` 라 정확하다.
그래서 "총 시간은 맞는데 구간만 0분" 같은 어긋남이 생긴다.

| 앱 | 진행 중 화면의 경과시간 | 저장되는 값 |
|---|---|---|
| 하루치 핏 | `session.elapsedSeconds` → **영향 있음** | 총 시간 = `WorkoutResult` (벽시계) ✅ · 구간 = **2026-09-09 에 벽시계로 고침** ✅ |
| GolfCounter | `healthKit.elapsedSeconds` → **영향 있음** | `RoundMetrics(WorkoutResult)` (벽시계) ✅ |
| Ralli | `healthKit.elapsedSeconds` → **영향 있음** | `durationSeconds` · `workoutElapsedSeconds` 가 **틱 카운터 차이** ⚠️ |

**Ralli 가 가장 걱정된다.** 워치가 저장에 싣는 값이 틱 기반이다.

```swift
// Apps/TennisCounter/WatchApp/.../WorkoutSessionViewModel.swift
elapsedAtStart: healthKit.elapsedSeconds     // 경기 시작 시점
session.elapsedAtEnd = healthKit.elapsedSeconds  // 경기 종료 시점

// Apps/TennisCounter/iOSApp/.../WorkoutSessionViewModel.swift
match.durationSeconds = max(0, (elapsedAtEnd ?? elapsedAtStart) - elapsedAtStart)
match.workoutElapsedSeconds = session.elapsedAtEnd
```

`workoutElapsedSeconds` 는 **요약 3칸의 "운동시간" 과 기록 목록 세션 헤더가 보여주는 바로 그
값**이다. 틱이 덜 쌓였다면 저장된 기록 자체가 실제보다 짧다.

## 실기기에서 확인할 것

고치기 전에 **정말 어긋나는지부터** 본다. 아래 셋이면 충분하다.

- [ ] **화면 표시가 뒤처지나** — 아무 앱에서 워크아웃을 시작하고, 손목을 30초쯤 내렸다 올린다.
      경과시간이 30초 건너뛰어 있으면 정상, **멈춰 있다가 이어서 세면 영향 있음**
- [ ] **Ralli 저장 기록이 짧나** — 앱의 기록 탭에서 최근 경기를 연다. "경기시간" 과 세션 헤더의
      누적 시간이 실제 친 시간과 비슷한지 본다. 지금 출시된 1.1.7 에도 있는 문제라
      **기존 기록만 봐도 판단할 수 있다**
- [ ] **하루치 구간이 고쳐졌나** — 40분쯤 돌리고 종목별 분이 맞는지 (PR #19 검증)

## 고친다면 — 갈림길은 일시정지다

`elapsedSeconds` 가 틱인 것에는 **의도된 쓸모가 하나 있다: 일시정지 중에는 안 늘어난다.**
(`pauseWorkout()` 이 타이머를 무효화한다.) 벽시계로 바꾸면 그 성질이 사라진다.

| 안 | 방법 | 대가 |
|---|---|---|
| **A. 그대로 둔다** | 각 앱이 필요한 곳에서 벽시계를 따로 잰다 (하루치가 지금 이렇게 했다) | 같은 실수가 앱마다 반복된다 |
| **B. 벽시계로 바꾼다** | `Date().timeIntervalSince(startDate)` | 일시정지한 시간이 경과시간에 섞인다. `stopWorkout()` 의 총 시간과는 **일치하게 된다** (그쪽도 정지를 포함하므로) |
| **C. 정지 누적을 빼는 벽시계** | 정지 구간 길이를 더해 두고 벽시계에서 뺀다 | 가장 정확하지만 `stopWorkout()` 의 총 시간도 함께 바꿔야 일관된다 |

C 가 옳아 보이지만 **`WorkoutResult.durationSeconds` 까지 건드리는 변경**이라 3개 앱의 저장값
의미가 한꺼번에 바뀐다. 기존 기록과의 비교 가능성을 어떻게 할지 함께 정해야 한다.

## 주의

- `Packages/YJKit` 변경은 **CI 가 3개 앱을 전부 빌드**한다
- 기존 시그니처를 바꾸지 않는다 (루트 `CLAUDE.md`)
- 컴플리케이션 쪽은 별개다 — 하루치 `WorkoutSnapshot` 은 **일시정지를 빼려고 일부러** 틱을 쓴다.
  거기에 벽시계를 꽂으면 의도가 깨진다
