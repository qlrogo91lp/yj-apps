# W2 요약 화면 — 구현 플랜

작성일: 2026-09-07
상태: **검토 대기**
선행 문서: `specs/2026-09-02-haruchi-fit-product-spec.md` W2절 · `specs/2026-09-02-haruchi-fit-architecture.md`
선행 작업: PR #9 (세그먼트 SwiftData 저장) — `868d172`

---

## 목표

세션 종료 후 요약을 보여주고 **저장할지 버릴지 사용자가 정한다.**

PR #9 는 종료 즉시 자동 저장이라 쓰레기 세션을 걸러낼 방법이 없다. 그 임시 상태를 닫는다.
동시에 **세그먼트 바**로 이 앱의 유일한 기능적 차별점을 처음 화면에 드러낸다.

---

## 1. 먼저 해결해야 할 충돌 — HealthKit 은 이미 저장돼 있다

제품 스펙 W2 는 이렇게 못박았다.

> **버리기 탭 시 확인 1단계 필수** (되돌릴 수 없음). **폐기하면 HealthKit에도 저장하지 않는다.**

그런데 현재 구조로는 **지킬 수 없다.** `WorkoutSessionService.stopWorkout()` 이
`builder.finishWorkout()` 을 무조건 호출하므로, W2 화면이 뜨는 시점에 HKWorkout 은 **이미
HealthKit 에 저장돼 있다.**

### 검토한 안

| 안 | 평가 |
|---|---|
| **A. 저장 후 삭제** — 버리기 시 `healthKitUUID` 로 찾아 `HKHealthStore.delete` | ✅ 채택. 패키지 무수정, 앱 안에서 끝난다 |
| B. `WorkoutCore` 에 "종료하되 저장은 보류" API 추가 | 기각 — 3개 앱 공유 API 를 키우고, `HKLiveWorkoutBuilder` 는 보류를 지원하지 않아 세션을 직접 다뤄야 한다 |
| C. 스펙을 고쳐 "HealthKit 에는 남는다"로 | 기각 — 사용자가 버린 기록이 건강 앱에 남는 건 명백한 배신이다 |

**A 의 한계를 문서에 남긴다** — 삭제까지 짧은 순간 HealthKit 에 존재한다. 그 사이 다른 앱이
읽어갈 수 있으나, 워치에서 요약을 보고 버튼을 누르는 수 초 안의 일이고 되돌릴 수단이 그것뿐이다.
삭제가 실패해도(권한 회수 등) 앱 저장소에는 안 남으므로 **잔디·기록에는 영향이 없다.**

---

## 2. 세션 상태를 3단계로 바꾼다

지금은 `isActive` 불리언 하나라 요약 화면이 낄 자리가 없다.

```
.idle  ──start()──▶  .active  ──end()──▶  .summary  ──save()/discard()──▶  .idle
```

`isActive` 는 제거하고 `phase` 로 대체한다. `HomeView` 의 분기도 3갈래가 된다.

---

## Task 1 — 세그먼트 바

**Files:**
- Create: `Apps/HaruchiFit/Shared/SegmentBar.swift`

`Shared/` 에 두는 이유는 **iOS 기록 상세가 같은 바를 쓰기 때문이다** (제품 스펙 04a).
두 타깃에 이미 붙어 있어 추가 비용이 없다.

```swift
struct SegmentBar: View {
    let segments: [WorkoutRecordMessage.SegmentPayload]
    var height: CGFloat = 8
}
```

- 구간 길이 **비율대로** 가로를 나눈다. `GeometryReader` 없이 `HStack` + `layoutPriority` 가 아니라
  **비율 계산 후 `frame(width:)`** — 워치에서 반올림 오차로 칸이 어긋나는 것을 막는다
- 색은 근력 `.brandOrange` · 유산소 `.blue` (W1b 전환 행과 같은 대응)
- 구간이 비면 **바를 그리지 않는다** (1분 미만 세션)
- `#Preview` 2종 — 구간 3개 / 빈 배열

> `Color.brandOrange` 는 지금 `HomeView.swift` 에 있다. `Shared/` 에서도 써야 하므로
> **`Shared/BrandColor.swift` 로 옮긴다.** 정의 위치만 바뀌고 값은 그대로다.

---

## Task 2 — 뷰모델: 상태 분리와 저장/버리기

**Files:**
- Modify: `Apps/HaruchiFit/WatchApp/WorkoutViewModel.swift`

### 상태

```swift
enum SessionPhase { case idle, active, summary }
@Published private(set) var phase: SessionPhase = .idle
```

`isActive` 제거. 요약 화면이 읽을 값을 함께 보관한다 — `pendingRecord: WorkoutRecordMessage?`.
**전송 페이로드를 그대로 들고 있는다.** 요약 화면 표시용 타입을 따로 만들면 같은 값이 두 벌이 된다.

### `end()` — 전송하지 않는다

지금 `end()` 안의 `connectivity.send(...)` 를 **`save()` 로 옮긴다.**
`end()` 는 세션을 멈추고 `pendingRecord` 를 채운 뒤 `phase = .summary` 로만 간다.

### `save()`

`pendingRecord` 를 `.reliable` 로 전송 → `phase = .idle`. 햅틱 `.success`.

### `discard()`

전송하지 않는다. `healthKitUUID` 가 있으면 **HealthKit 에서 삭제**한다 (1절 A안).
`phase = .idle`. 햅틱 `.failure`.

삭제는 `HKHealthStore` 를 직접 쓴다 — `WorkoutCore` 에는 삭제 API 가 없고,
이 한 곳을 위해 공유 패키지를 키우지 않는다. 실패는 삼키되 로그를 남긴다.

### 햅틱 — 스펙 5절 표를 마저 채운다

현재 `.directionUp`/`.directionDown` 둘만 구현돼 있다. 세션 흐름에 필요한 나머지를 넣는다.

| 동작 | 햅틱 | 위치 |
|---|---|---|
| 세션 시작 | `.start` | `start()` |
| 일시정지 / 재개 | `.click` | `togglePause()` |
| 운동 종료 | `.stop` | `end()` |
| 저장 완료 | `.success` | `save()` |
| 버리기 확정 | `.failure` | `discard()` |

> W0 유형 토글 `.click` 은 W0 화면이 없으므로 이번 범위 밖이다.

---

## Task 3 — 요약 화면

**Files:**
- Create: `Apps/HaruchiFit/WatchApp/SummaryView.swift`
- Modify: `Apps/HaruchiFit/WatchApp/HomeView.swift`

### 레이아웃 (제품 스펙 W2)

```
      운동 완료          ← 오렌지, 상단 중앙
      1:12:24            ← 큰 시간. 1시간 미만은 54:12
  ███████▒▒▒███          ← 세그먼트 바
  근력 54분   유산소 18분
  ♥ 128      🔥 412
  [ 버리기 ] [ 저장 ]
```

- 2×2 는 **배경 카드 없이 텍스트만** — 기존 UI 밀도 유지
- 버튼 배치·크기는 **GolfCounter `SummaryView` 를 따른다** (`.bordered` + `.borderedProminent`,
  `minHeight: 38`, 가로 2등분). 시리즈 일관성이 목적이다. 틴트만 그린 → 오렌지
- **버리기는 `confirmationDialog` 로 확인 1단계** — 골프와 같은 패턴
- 세그먼트가 비면 바와 2×2 첫 줄을 건너뛴다

### `HomeView`

`phase` 3갈래 분기로 바꾸고 `.summary` 에서 `SummaryView` 를 띄운다.
`Color.brandOrange` 정의는 Task 1 에서 `Shared/` 로 옮겼으므로 여기선 참조만 한다.

---

## Task 4 — 문서 갱신

**Files:**
- Modify: `Apps/HaruchiFit/docs/superpowers/specs/2026-09-02-haruchi-fit-architecture.md`

- **10절** — W2 항목 완료 처리, "당분간 자동 저장" 단서 제거
- **새 절 또는 2절 말미** — 1절에서 정한 **HealthKit 사후 삭제 방식과 그 한계**를 기록한다.
  스펙이 요구한 "폐기 시 HealthKit 에 남기지 않는다"를 어떻게 지켰는지가 남아야 한다

---

## 검증

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')

xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit Watch App" -destination "id=$WATCH" build
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
make lint && make format
```

`WorkoutCore` 를 건드리지 않으므로 **GolfCounter · Ralli 회귀 빌드는 불필요**하다
(CI 경로 필터가 알아서 스킵한다).

### 실기기 (필수)

햅틱은 시뮬레이터에서 재현되지 않는다 (제품 스펙 5절 경고).

- [ ] 근력 → 유산소 → 근력 전환 후 종료 → **요약 화면**에 구간 3개 바와 시간이 맞게 뜬다
- [ ] `저장` → `.success` 햅틱 → 폰 리스트에 기록이 뜬다
- [ ] `버리기` → 확인 다이얼로그 → 확정 시 `.failure` 햅틱 → **폰에 안 뜨고 건강 앱에서도 사라진다**
- [ ] 종료 `.stop` · 시작 `.start` · 일시정지 `.click` 햅틱

---

## 스코프 밖

W0 유형 토글 · 부위 태그/메모 UI · HealthKit import(4.1) · 잔디(5절) · 컴플리케이션 모드 표시.

---

## 커밋 · PR

브랜치 `feat/w2-summary`. 문서(Task 4)는 코드와 같은 PR 에 묶는다 —
HealthKit 삭제 방식의 근거가 코드와 함께 리뷰돼야 한다.

```
✨ 종료 후 요약 화면에서 저장할지 버릴지 정한다 (W2)

세션 종료가 곧 저장이던 것을 요약 단계로 끊는다. 세그먼트 바로 구간을
보여주고, 버리기는 확인을 한 번 받는다.

버리면 HealthKit 에서도 지운다. stopWorkout() 이 finishWorkout() 을 무조건
부르므로 요약 시점엔 이미 저장돼 있어, 사후 삭제로 스펙을 지킨다.
```
