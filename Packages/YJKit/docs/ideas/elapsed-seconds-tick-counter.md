# `elapsedSeconds` 가 벽시계가 아니라 틱 카운터다

상태: **탐색 — 아직 고치지 않았고, 결정도 안 났다**
계기: 하루치 핏 구간 시간이 실기기에서 "근력 0분" 으로 나온 문제 (2026-09-09)
관련: [하루치 작업 기록](../../../../Apps/HaruchiFit/docs/logs/2026/2026-09-09-segment-duration-tick-counter.md) · 루트 `TODO.md`

---

## 한 줄로

`WorkoutSessionService` 안에 **시계가 두 개** 있고 서로 다른 값을 낸다. 하나는 손목을 내리면
멈추고, 다른 하나는 정확하다. 어느 쪽을 쓰느냐가 앱마다 제각각이라 화면과 저장값이 어긋난다.

## 지금 무슨 일이 벌어지나

`elapsedSeconds` 는 벽시계가 아니라 **1초 `Timer` 가 올리는 틱 카운터**다.

```swift
// WorkoutSessionService.swift
private func startTimer() {
    elapsedSeconds = 0
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        DispatchQueue.main.async { self?.elapsedSeconds += 1 }
    }
}
```

실기기에서 손목을 내리거나 화면이 꺼지면 이 타이머가 멈추고, **다시 켜져도 밀린 만큼
따라잡지 않는다.** 하루치에서 40분 세션의 구간이 몇 초로 잡혔다 — 사용자가 실기기에서 확인했다.

시뮬레이터는 앱이 계속 앞에 떠 있어 틱이 벽시계와 거의 같게 쌓인다. **그래서 시뮬레이터로는
재현되지 않는다.**

## 핵심 — 이미 시계가 둘이고, 아무도 그걸 고르지 않았다

| 시계 | 어떻게 재나 | 일시정지 | 정확한가 |
|---|---|---|---|
| `elapsedSeconds` | 1초 `Timer` 틱 | **뺀다** (`pauseWorkout()` 이 타이머를 무효화) | ❌ 손목 내리면 안 쌓임 |
| `WorkoutResult.durationSeconds` | `Int(Date().timeIntervalSince(start))` | **포함한다** | ✅ |

**이 둘은 이미 서로 다른 것을 센다.** 정지 없이 짧게 운동하면 값이 비슷해서 지금까지 드러나지
않았을 뿐이다. 그래서 이 작업은 "버그 하나 고치기" 가 아니라 **"경과시간이 무엇을 뜻하는지
정하기"** 다.

## 앱별 영향

| 앱 | 진행 중 화면의 큰 시간 | 저장되는 값 |
|---|---|---|
| 하루치 핏 | `session.elapsedSeconds` → **영향 있음** | 총 시간 = `WorkoutResult` ✅ · 구간 = 2026-09-09 에 벽시계로 고침 ✅ |
| GolfCounter | `healthKit.elapsedSeconds` → **영향 있음** | `RoundMetrics(WorkoutResult)` ✅ |
| Ralli | `healthKit.elapsedSeconds` → **영향 있음** | `durationSeconds` · `workoutElapsedSeconds` 가 **틱 차이** ⚠️ |

**Ralli 가 가장 나쁘다.** 워치가 저장에 싣는 값이 틱 기반이다.

```swift
// 워치
elapsedAtStart: healthKit.elapsedSeconds
session.elapsedAtEnd = healthKit.elapsedSeconds
// 폰
match.durationSeconds = max(0, (elapsedAtEnd ?? elapsedAtStart) - elapsedAtStart)
match.workoutElapsedSeconds = session.elapsedAtEnd
```

`workoutElapsedSeconds` 는 **요약 3칸의 "운동시간" 과 기록 목록 세션 헤더가 보여주는 그 값**이다.
틱이 덜 쌓였다면 저장된 기록 자체가 실제보다 짧다. **1.1.7 에도 있는 문제라 기존 기록만 봐도
판단된다.**

또 하나 — 앱마다 정지 셈법이 이미 엇갈린다.

- 하루치: 화면·구간·총 시간이 **모두 정지 포함** (구간 고친 뒤로 일관됨)
- Ralli: 저장값이 **모두 정지 제외** (대신 둘 다 덜 셈)
- 골프: 화면은 **정지 제외**, 저장은 **정지 포함** — 한 앱 안에서 어긋난다

## 실기기에서 확인할 것

고치기 전에 정도를 재야 한다. **1번이 가장 빠르고 결정적이다.**

- [ ] **Ralli 저장 기록이 짧은가** — 기록 탭에서 예전 경기를 연다. "경기시간" 이 실제 친 시간과
      비슷한지. 새로 운동할 필요 없다
- [ ] **화면 표시가 뒤처지는가** — 아무 앱에서 워크아웃 중 손목을 30초 내렸다 올린다.
      30초 건너뛰어 있으면 정상 / **멈춰 있다가 이어서 세면 영향 있음**
- [ ] **하루치 구간이 고쳐졌는가** — 40분쯤 돌려 종목별 분이 맞는지 (PR #19 검증)

## 선택지

### A. YJKit 을 안 건드리고 앱마다 벽시계를 잰다

하루치가 이미 이렇게 했다 (`SegmentTracker`).

- 좋은 점 — 공유 패키지를 안 건드려 다른 앱이 안 흔들린다
- 나쁜 점 — **같은 실수가 앱마다 반복된다.** 이미 세 앱이 같은 함정을 밟았다. 화면 표시는
  여전히 틀린 채로 남는다

### B. `elapsedSeconds` 를 벽시계로 바꾼다

`Date().timeIntervalSince(startDate)` 로 계산한다.

- 좋은 점 — 한 곳만 고치면 세 앱의 화면과 Ralli 저장값이 함께 맞는다. 변경이 작다
- 나쁜 점 — **정지 중에도 늘어난다.** 지금 정지 중 화면이 멈추는 동작이 사라진다.
  Ralli 저장값의 의미도 "정지 제외" → "정지 포함" 으로 바뀐다

### C. 정지 누적을 빼는 벽시계

정지 구간 길이를 더해 두고 벽시계에서 뺀다.

- 좋은 점 — 가장 정확하고, 정지 중 멈추는 동작도 지킨다
- 나쁜 점 — `WorkoutResult.durationSeconds` 도 같이 바꿔야 일관된다. 그러면 **세 앱의 저장값
  의미가 한꺼번에 달라진다.** 기존 기록과 새 기록을 나란히 놓고 비교할 수 있는가?

### D. HealthKit 이 낸 값을 쓴다 ← **확인해볼 가치가 있다**

`stopWorkout()` 은 이미 `builder.finishWorkout()` 이 돌려준 `HKWorkout` 을 들고 있는데
**`uuid` 만 쓰고 버린다.**

```swift
let saved = try? await builder.finishWorkout()
// ...
healthKitUUID: saved?.uuid      // duration 은 안 쓴다
```

`HKWorkout.duration` 을 쓰면 종료 시각의 총 시간은 HealthKit 이 낸 값이 된다 — 건강 앱에
보이는 숫자와 앱이 보여주는 숫자가 같아진다는 뜻이라 그 자체로 값어치가 있다.

- 확인할 것 — 이 값이 **정지 시간을 빼는지**. 뺀다면 C 를 직접 구현하지 않고도 C 를 얻는다
- 한계 — **진행 중에는 못 쓴다.** 종료 후에만 나오는 값이라 화면 표시는 여전히 B 나 C 가 필요하다

## 추천

**D 를 먼저 확인하고, 화면은 C 로 간다.**

- 저장값(종료 후) — `HKWorkout.duration` 이 정지를 빼면 그걸 쓴다. 건강 앱과 숫자가 맞는 게
  사용자에게 가장 덜 헷갈린다
- 화면 표시(진행 중) — 정지 누적을 빼는 벽시계. 정지 중 멈추는 동작을 지키면서 손목을 내려도
  안 밀린다

A 는 임시방편으로만 쓴다. B 는 정지 동작을 잃는 대가가 커 보인다.

## 정해야 할 것

1. **경과시간은 정지를 포함하는가, 빼는가?** — 이게 갈리면 나머지가 다 갈린다.
   지금은 앱마다 다르다
2. **기존 기록을 어떻게 하나?** — 이미 저장된 Ralli 기록은 덜 세어진 값이다. 그대로 두면
   새 기록과 나란히 놓았을 때 옛 기록이 짧아 보인다. 보정할 방법도 마땅치 않다
   (HealthKit 워크아웃과 `healthKitUUID` 로 이어 다시 계산하는 길은 있다)
3. **어디까지를 이번 범위로 잡나?** — Ralli 저장 경로만 급히 고치고 화면은 나중에 갈지,
   한 번에 갈지

## 검증을 어떻게 할 것인가

**이 버그의 진짜 원인은 테스트가 없다는 것이다.** `WorkoutSessionService` 가 HealthKit 을 직접
만들어 쓰기 때문에 테스트에서 돌릴 수 없고, 그래서 시간 계산이 통째로 검증 밖에 있다.

무엇을 고르든 **시계를 주입 가능하게** 만들어야 한다. 하루치 `SegmentTracker` 가 그 모양이다 —
`() -> Date` 를 받아 테스트가 시간을 직접 돌린다. 같은 방식을 `WorkoutSessionService` 에
적용하면 정지·재개를 섞은 시나리오를 HealthKit 없이 검증할 수 있다.

## 주의

- `Packages/YJKit` 변경은 **CI 가 3개 앱을 전부 빌드**한다
- 기존 시그니처를 바꾸지 않는다 (루트 `CLAUDE.md`)
- **컴플리케이션은 별개다** — 하루치 `WorkoutSnapshot` 은 정지를 빼려고 **일부러** 틱을 쓴다.
  벽시계를 그냥 꽂으면 의도가 깨진다. 경과시간을 그리는 것은 `.accessoryRectangular`
  패밀리뿐이라 눈에 띄는 정도도 작다
