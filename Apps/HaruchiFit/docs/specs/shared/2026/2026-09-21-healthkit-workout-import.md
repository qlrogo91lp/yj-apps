# HealthKit 워크아웃 import

작성일: 2026-09-21
상태: **확정 설계 — 구현 대기**
로드맵 위치: Phase 2 #2
선행 문서: [아키텍처](2026-09-02-haruchi-fit-architecture.md) (3절·4.1·4.2·4.3·D-M4·D-M5) ·
[제품 스펙](2026-09-02-haruchi-fit-product-spec.md) (흐름 C) ·
[잔디 일별 집계](2026-09-09-grass-daily-aggregate.md) (**4.5·5절·6절이 이 문서의 입력이다**) ·
[로드맵](2026-09-07-haruchi-fit-roadmap.md)

---

## 한 줄로

**다른 앱이 건강 앱에 저장한 워크아웃을 데려온다.** 매핑 표에 있는 타입만 들어오고,
우리가 이미 가진 기록은 건드리지 않는다.

## 왜 지금인가

매핑 표를 한번 정하면 **사용자의 과거 잔디가 달라진다** (아키텍처 4.2). 잔디를 쓰는 화면
셋(02 홈 · 03a 달력 · 05 통계)이 Phase 4 에 한꺼번에 나오므로, 그 전에 확정해 두어야
"어제까지 3단계였던 칸이 오늘 2단계가 되는" 일을 사용자가 겪지 않는다.

잔디 집계(#1)는 이미 끝났고 **임시 그리드가 확인 수단으로 서 있다** — 유입 결과를 그 화면으로 본다.

---

## 1. 범위

**한다**

- `HKAnchoredObjectQuery` 증분 동기화 + 앵커 영속화
- `HKWorkoutActivityType` → `SegmentKind` **매핑 표 확정** (2절)
- 중복 방지 — 이미 `healthKitUUID` 를 가진 레코드는 건드리지 않는다 (3절)
- iOS 읽기 권한 요청 경로 (7절) — **지금 iOS 앱에는 권한을 요청하는 코드가 한 줄도 없다**
- 임시 `ContentView` 에 `.refreshable` — 잔디 스펙 5절이 이 작업에 예약해 둔 항목

**안 한다**

- **삭제 반영** — 건강 앱에서 지워진 워크아웃을 따라 지우는 일은 **YJKit 범위로 옮겼다** (4절)
- **백그라운드 배달** (`enableBackgroundDelivery`) — D-M4. 포그라운드 진입 시에만 돈다
- **HealthKit 쓰기** — iOS 앱은 읽기만 한다. 저장은 워치 몫이고, 08 수동 기록은 Phase 5 다
- **import 기록의 부위 태깅·메모 채우기** — HealthKit 에 그 자리가 없다 (아키텍처 3절).
  사용자가 04 상세에서 나중에 붙인다
- **01 온보딩 화면** — Phase 5 #12. 여기서는 권한 요청 **경로만** 만들고 화면은 안 만든다
- **다른 하루치 시리즈 앱(Ralli·GolfCounter)의 워크아웃 수용** — D-M5 의 대가로 확정된 사항

---

## 2. 매핑 표 (확정)

아키텍처 4.2 의 예시를 **그대로 확정한다.** 여기 없는 타입은 `nil` 을 돌려주고, `nil` 은
**import 자체를 안 한다** (D-M5).

### 근력

| `HKWorkoutActivityType` | 건강 앱 표기 |
|---|---|
| `.traditionalStrengthTraining` | 근력 운동 |
| `.functionalStrengthTraining` | 기능적 근력 운동 |
| `.coreTraining` | 코어 트레이닝 |

### 유산소

| `HKWorkoutActivityType` | 건강 앱 표기 |
|---|---|
| `.running` | 달리기 (실내·실외 모두 이 타입) |
| `.walking` | 걷기 |
| `.cycling` | 사이클링 (실내 자전거 포함) |
| `.elliptical` | 일립티컬 |
| `.rowing` | 로잉 |
| `.stairClimbing` | 계단 오르기 |
| `.stepTraining` | 스텝 운동 |
| `.highIntensityIntervalTraining` | 고강도 인터벌 트레이닝 |

### 그 외 — 가져오지 않는다

요가 · 필라테스 · 수영 · 구기 종목 · 댄스 · 등산 · 스키 · `.crossTraining` ·
`.mixedCardio` · `.other` · 나머지 전부.

### 왜 이 경계인가

**`.other` · `.mixedCardio` · `.crossTraining` 을 뺀 것이 이 표의 핵심 판단이다.**
셋 다 실제로 흔하게 쓰이지만, 사용자가 그 안에 무엇을 넣었는지 앱이 알 수 없다.
근력·유산소 어느 쪽으로 넣어도 절반은 틀린 분류가 되고, 그 오분류가 **Phase 4 비율 차트의
분모**로 그대로 들어간다. 잔디 한 칸이 비는 손해보다 통계가 거짓말을 하는 손해가 크다.

**넓히는 건 쉽고 좁히는 건 어렵다.** 나중에 `.hiking` 을 더하면 과거 잔디에 칸이 *생기는*
것이라 사용자에게 "예전 기록이 이제 보인다" 로 읽힌다. 반대로 지금 넣은 타입을 나중에
빼면 **있던 칸이 사라진다** — 같은 변경이 아니다.

**변경 시 지켜야 할 것** — 이 표를 고치면 앵커를 버리고 전체를 다시 읽어야 과거가 반영된다.
앵커만 유지한 채 표를 넓히면 *앞으로 들어올 워크아웃*만 새 규칙을 따르고 과거는 옛 규칙에
남아, 같은 종목이 날짜에 따라 다르게 보인다. **표를 고치는 PR 은 앵커 초기화를 함께 한다.**

---

## 3. 중복 — 이미 가진 기록은 건드리지 않는다

**`healthKitUUID` 가 이미 있는 레코드는 import 가 통과시킨다.** 잔디 스펙 6절의 불변조건을
그대로 따른다.

건드리면 이렇게 된다 — 워치로 저장한 기록의 `totalSeconds` 는 **앱이 잰 값(정지 제외,
PR #26)** 인데 같은 워크아웃의 `HKWorkout.duration` 은 HealthKit 이 잰 값이다. 덮어쓰면
과거 잔디 농도가 소급해서 바뀌고, 세그먼트·부위·메모까지 날아간다.

```
들어온 워크아웃 UUID ∈ 기존 레코드의 healthKitUUID 집합  →  건너뛴다 (갱신도 안 한다)
그 외                                                  →  새 레코드로 삽입
```

### 경합 — 워치 메시지가 늦게 도착하는 경우

`transferUserInfo` 는 폰이 꺼져 있으면 큐잉된다. 그 사이 사용자가 폰을 열면 **워치 기록이
import 경로로 먼저 들어올 수 있다** (우리 워치 세션은 `.traditionalStrengthTraining` 이라
매핑 표에 걸린다).

이때는 나중에 도착한 워치 메시지가 이긴다 — `iOSApp.save(_:)` 가
`upsert(replacing: healthKitUUID == uuid)` 로 갈아끼우기 때문이다. **이미 그렇게 짜여 있고
고칠 것이 없다.** 최종 상태는 세그먼트를 가진 워치 레코드다.

> 소스 필터(`HKSource`)로 우리 앱이 쓴 워크아웃을 애초에 거르는 방법도 있지만, 워치 앱과
> 폰 앱의 소스가 묶이는 방식이 기기·계정 구성에 따라 달라 UUID 비교보다 약한 보장이다.
> UUID 는 확실하다.

---

## 4. 삭제는 다루지 않는다 — YJKit 범위로 옮겼다

앵커드 쿼리는 삭제된 객체를 `HKDeletedObject` 로 같이 준다. **이 작업은 그것을 읽지 않고
버린다.**

건강 앱 ↔ 앱 저장소의 삭제 동기화는 하루치 핏만의 문제가 아니다 — Ralli·GolfCounter 도
같은 상황(HealthKit 워크아웃과 SwiftData 레코드가 UUID 로 묶여 있음)이고, 같은 판단을
세 번 따로 내리면 세 앱의 동작이 갈린다. **YJKit 에서 한 번 정해 셋이 나눠 쓴다.**

> 거기서 정해야 할 것 — `source` 를 가려 삭제할지(부위·메모를 가진 레코드는 살린다) 전부
> 지울지, 삭제 앵커를 import 앵커와 같이 둘지 따로 둘지.

### 그동안 생기는 어긋남

**건강 앱에서 지운 워크아웃이 잔디에 남는다.** import 로 들어온 칸이든 워치로 저장한
칸이든 앱에서는 사라지지 않는다.

지금 감수할 만한 이유는 두 가지다.

- 지우는 쪽이 **훨씬 드문 행동**이다. 잘못 시작한 세션은 W2 요약에서 "버리기" 로 끝나고,
  그 경로는 HealthKit 에서도 사후 삭제한다 (아키텍처 2절) — 건강 앱까지 가서 지우는
  경우만 남는다
- **되돌릴 수 있는 방향의 공백이다.** 나중에 삭제를 붙이면 남아 있던 칸이 *사라지는* 것이라
  사용자에겐 "이제 맞게 나온다" 로 읽힌다. 반대 방향(잘못 지운 걸 되살리기)과 달리 복구할
  데이터를 잃지 않는다

그래서 이 공백은 **기능이 아니라 일정의 문제**다. `TODO.md` 에서 YJKit 항목으로 추적한다.

---

## 5. 가져오는 값

### 필드 매핑

| `WorkoutRecord` | 출처 | 비고 |
|---|---|---|
| `healthKitUUID` | `workout.uuid` | 중복 방지의 키 (3절) |
| `startedAt` / `endedAt` | `workout.startDate` / `.endDate` | |
| `totalSeconds` | `Int(workout.duration.rounded())` | **`duration` 은 일시정지를 뺀 값**이라 워치 기록(PR #26)과 의미가 같다 |
| `activeCalories` | `statistics(for: .activeEnergyBurned)?.sumQuantity()` | 없으면 nil |
| `totalCalories` | **`activeCalories` 와 같은 값** | 아래 참고 |
| `averageHeartRate` | `statistics(for: .heartRate)?.averageQuantity()` | 없으면 nil — **추가 쿼리를 돌리지 않는다** |
| `source` | `.healthKitImport` 고정 | |
| `memo` · 부위 | 채우지 않는다 | HealthKit 에 자리가 없다 |

**`totalCalories` 를 active 와 같게 두는 이유** — 우리 모델의 `totalCalories` 는 "활동 + 휴식"
이고 휴식분은 워치 세션이 `HKLiveWorkoutBuilder` 로 모을 때만 나온다. 다른 앱 워크아웃에는
basal 샘플이 붙어 있지 않은 경우가 대부분이라, 별도 쿼리를 돌려도 대개 0 이거나 nil 이다.
active 를 그대로 쓰면 **`nil` 보다 나은 값**이 되고 카드·요약이 빈칸을 피한다.

**평균 심박에 추가 쿼리를 안 도는 이유** — `workout.statistics(for:)` 가 nil 인 워크아웃마다
`HKStatisticsQuery` 를 하나씩 돌리면 첫 동기화에서 쿼리가 수백 개가 된다. 심박이 나오는
자리는 기록 행·요약·공유 카드의 **참고 표시값**이고, 없으면 `–` 로 그리면 된다 (D5 —
강도형 지표를 쓰지 않기로 이미 정했다).

### 세그먼트 — 전체 길이 1개

import 기록은 **매핑된 kind 로 워크아웃 전체를 덮는 세그먼트 하나**를 갖는다.

```swift
Segment(kind: 매핑결과, startOffset: 0, durationSeconds: totalSeconds)
```

`GrassAggregator` 는 `strengthSeconds` / `cardioSeconds` 를 세그먼트에서 뽑는다. 세그먼트를
안 만들면 **잔디 농도는 채워지는데 비율 차트에서만 빠지는** 절름발이 레코드가 되고, 집계기가
"세그먼트가 없으면 다른 필드를 본다" 는 분기를 갖게 된다 — 집계 경로가 둘로 갈린다.

의미도 사실과 맞는다. 외부 워크아웃은 **전환이 0 회인 세션**이다. `WorkoutRecord` 에 분류
필드를 따로 더하는 안은 CloudKit 스키마를 늘리면서 얻는 게 없어 버렸다.

---

## 6. 동기화 시점과 앵커

### 언제 도나

| 시점 | 근거 |
|---|---|
| 앱이 포그라운드로 들어올 때 (`scenePhase == .active`) | D-M4 — 백그라운드 배달을 안 쓴다 |
| 사용자가 홈을 당겨 새로고침할 때 (`.refreshable`) | 잔디 스펙 5절이 이 작업에 예약 |

**동시에 두 번 돌지 않는다.** 진행 중이면 두 번째 호출은 그냥 돌아간다 — 앵커가 경합하면
같은 워크아웃이 두 배치에 나뉘어 들어올 수 있다.

### 앵커

`HKQueryAnchor` 를 `NSKeyedArchiver` 로 인코딩해 `UserDefaults` 에 둔다.

- 앵커가 없으면 **전체 히스토리를 읽는다.** 기간을 자르지 않는다 — 05 통계가 연도 아카이브라
  과거 연도를 자르면 그 화면이 빈 채로 나온다
- 첫 동기화 비용은 한 번뿐이고, 매핑 표가 대부분의 타입을 거르므로 실제 삽입량은 쿼리
  결과보다 훨씬 적다
- 앵커 디코딩이 실패하면 **nil 로 취급해 전체를 다시 읽는다.** 중복은 3절이 막으므로
  안전한 폴백이다

### 저장은 한 번에

플래너가 고른 삽입을 `ModelContext` 에 모아 넣고 **`save()` 를 한 번만** 부른다.
`PersistenceService.upsert` 는 건당 `save()` 라 첫 동기화 수백 건에는 맞지 않는다 —
읽기(`fetch`)에만 쓰고 쓰기는 컨텍스트를 직접 만진다.

---

## 7. 권한

### 읽기 권한은 상태를 알 수 없다

HealthKit 은 **읽기 권한의 허용 여부를 앱에 알려주지 않는다.** `authorizationStatus(for:)`
는 쓰기 권한에만 의미가 있다. 거부된 상태에서 쿼리를 돌리면 에러가 아니라 **빈 결과**가 온다.

따라서 앱은 "거부" 를 감지하려 하지 않는다. 동기화는 항상 같은 코드 경로를 타고, 결과가
0 건이면 0 건으로 끝낸다. **이 사실을 모르면 "왜 실패 처리가 없나" 를 나중에 다시 묻게 된다.**

### 요청 시점

`requestAuthorization` 을 **첫 동기화 직전에 한 번** 부른다. 이미 결정된 사용자에게는
시스템이 시트를 띄우지 않으므로 매번 불러도 무해하다.

읽기 타입 4종 — `HKObjectType.workoutType()` · `.activeEnergyBurned` · `.basalEnergyBurned` ·
`.heartRate`. **쓰기(`toShare`)는 빈 집합이다** — iOS 앱은 HealthKit 에 쓰지 않는다.

> `WorkoutCore.WorkoutSessionService.requestAuthorization()` 을 재사용하지 않는다. 그쪽은
> `WorkoutConfiguration` 을 요구하고 **쓰기 권한까지 함께 요청**한다. 워치 세션을 위한
> 시그니처이지 폰의 읽기 전용 경로가 아니다. 패키지는 한 줄도 고치지 않는다.

### 거부해도 앱은 완결된다

아키텍처 4.3 그대로다. 워치로 저장한 기록은 WatchConnectivity 로 들어오므로 HealthKit
권한과 무관하고, 08 수동 기록(Phase 5)이 폰 단독 경로를 연다.

---

## 8. 산출물

| 파일 | 무엇 | 테스트 |
|---|---|---|
| `Shared/Services/WorkoutTypeMapping.swift` | 매핑 표. `HKWorkoutActivityType → SegmentKind?` | ✅ |
| `Shared/Services/ImportedWorkout.swift` | HealthKit 을 떠난 순수 값 타입 | — |
| `Shared/Services/WorkoutImportPlanner.swift` | 무엇을 새로 넣을지 고른다. **3절 불변조건이 여기 산다** | ✅ |
| `Shared/Persistence/WorkoutRecord+Import.swift` | `ImportedWorkout → WorkoutRecord` (세그먼트 1개 포함) | ✅ |
| `iOSApp/Services/WorkoutQueryAnchorStore.swift` | 앵커 영속화 | — |
| `iOSApp/Services/HealthKitWorkoutImporter.swift` | 앵커드 쿼리 실행 + 권한 요청 + 값 추출 | — |
| `iOSApp/Services/WorkoutSyncCoordinator.swift` | 배선. `@Published isSyncing` | — |
| `iOSApp/iOSApp.swift` (수정) | 코디네이터 주입 · `scenePhase` 트리거 | — |
| `iOSApp/ContentView.swift` (수정) | `.refreshable` | — |

**순수 규칙은 전부 `Shared/` 에 있다.** `Shared/` 가 iOS·워치 양쪽 타깃에 붙어 있어
`HaruchiFitWatchTests` 가 그대로 본다 — `iOSApp/` 에 둔 것은 **iOS 테스트 타깃이 없어
아무도 검증하지 못한다.** 잔디(#1)가 같은 이유로 같은 선을 그었다.

---

## 9. 검증

### 유닛 테스트 (`HaruchiFitWatchTests`)

- 매핑 표 — 근력 3종 · 유산소 8종이 각각 맞는 kind 로 나온다
- 매핑 표 — `.other` · `.mixedCardio` · `.crossTraining` · `.yoga` · `.swimming` · `.hiking` 이 nil 이다
- 플래너 — 기존 UUID 를 가진 워크아웃은 삽입 목록에 없다
- 플래너 — 같은 배치에 같은 UUID 가 두 번 오면 한 번만 삽입한다
- 변환 — 세그먼트가 정확히 1 개이고 `startOffset == 0` · `durationSeconds == totalSeconds`
- 변환 — `source == .healthKitImport` · `totalCalories == activeCalories`
- 집계 연동 — import 레코드 1 건이 `GrassAggregator` 에서 올바른 `cardioSeconds` 로 접힌다

### 실기기 확인 (유닛 테스트가 못 닿는 것)

HealthKit 앵커드 쿼리·권한 시트·실제 데이터는 시뮬레이터로 판단할 수 없다.
`TODO.md` 의 "집 맥북에서 할 것" 에 넣는다.

- 건강 앱에 다른 앱 기록(달리기·걷기)이 있는 상태에서 앱을 열면 잔디에 칸이 생긴다
- **요가·수영을 건강 앱에 넣어도 칸이 생기지 않는다** (D-M5)
- 앱을 껐다 켜도 같은 워크아웃이 두 번 들어오지 않는다 (앵커가 산다)
- **워치로 저장한 기록의 시간이 import 로 덮이지 않는다** (3절 — 정지 제외 값이 살아 있는지)
- 당겨서 새로고침이 실제로 새 기록을 데려온다
- 권한을 거부한 상태에서도 앱이 크래시 없이 열리고 워치 기록은 그대로 보인다

---

## 10. 열린 채로 두는 것

| 항목 | 언제 |
|---|---|
| **건강 앱 삭제 반영** | **YJKit 범위** — 3개 앱이 같은 문제를 갖는다 (4절) |
| 매핑 표 확장 (`.hiking` · `.crossTraining` …) | 실사용 데이터를 보고. **앵커 초기화를 함께** (2절) |
| 소스 필터로 우리 앱 워크아웃 사전 제외 | UUID 비교로 충분하다고 판단. 성능 문제가 실제로 보이면 |
| 평균 심박 보강 쿼리 | 실기기에서 `statistics(for:)` 가 자주 nil 이면 |
| 동기화 실패 알림 UI | 03b 기록 목록(Phase 3 #4). 지금은 로그만 — `iOSApp.save(_:)` 와 같은 자리다 |
| 백그라운드 배달 | iOS 홈 화면 위젯을 도입하면 (D-M4 각주) |
| import 기록의 부위 태깅 | 04 상세(Phase 3 #5)에서 사용자가 손으로 |

---

## 11. 다른 문서에 반영할 것

- **아키텍처 4.2** — "매핑 표의 최종 목록은 구현 시점에 확정한다" 를 **이 문서 2절로 가는
  링크**로 바꾼다. 표를 두 곳에 두지 않는다
- **아키텍처 4.1** — 앵커 영속화 위치(UserDefaults)와 "첫 동기화는 전체 히스토리" 를 한 줄 추가
- **로드맵 Phase 2** — #2 행을 완료로
- **잔디 스펙 9절** — `.refreshable` 행을 완료로
- **`TODO.md`** — 하루치 표의 #2 행과 실기기 확인 항목. **`## YJKit` 표에 "건강 앱 삭제
  반영" 을 새 행으로 추가한다** (4절) — 3개 앱에 걸리는 항목이라 하루치 표가 아니라 그쪽이다
