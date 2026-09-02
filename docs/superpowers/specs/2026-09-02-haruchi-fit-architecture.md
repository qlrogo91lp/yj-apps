# 하루치 핏 — 기술 설계

작성일: 2026-09-02
갱신일: 2026-09-03 — 미결 항목 M1~M7 **전부 결정**. 6절을 결정 사항으로 전환하고 관련 절에 반영
상태: **확정** — 구현 착수 가능. 남은 선행 작업은 `HKWorkoutActivity` 실기기 검증(2절)뿐
선행 문서: `2026-09-02-haruchi-fit-product-spec.md` (무엇을 만들지)

이 문서는 **어떻게 만들지**를 다룬다. 제품 결정은 선행 문서가 소유하므로 여기서 다시 논하지 않는다.

> **작성 원칙** — 코드로 확인한 사실과 검증이 필요한 가정을 구분해 적는다.
> 확인하지 않은 API 동작은 "검증 필요"로 표시한다. 결정 사항과 그 근거는 6절에 모은다.

---

## 1. 선행 조사 결과 — Notion 문서 정정

Notion「화면 구성」의 **"⚠️ ralli-kit 재사용 범위 정정 (2026-08-22)"** 절은 **더 이상 유효하지 않다.**
당시에는 "YJKit은 로직 전용이고 워치 세션 UI가 없다"가 맞았지만, 이후 승격이 완료됐다.

| Notion(08-22) 서술 | 현재 사실 | 근거 |
|---|---|---|
| 워치 세션 UI 없음 — 승격 작업 별도 필요 | **`WorkoutUI`에 존재** | `Sources/WorkoutUI/Watch/WorkoutMetricsView.swift`, `WorkoutControlsView.swift` (커밋 `caced15`) |
| ShareCore를 새로 만들어야 함 | **`WorkoutShareUI` 존재** — 카드 렌더러 + 인스타 스토리 딥링크 + 폴백 공유시트까지 | `Sources/WorkoutShareUI/` (커밋 `d5f24f4` 외 4건) |

따라서 **"승격할 것인가"는 더 이상 논점이 아니었다.** 실제 논점은
**"이미 있는 공유 뷰를 하루치 핏 요구에 맞게 어떻게 확장할 것인가"** 였고, 6절에서 결정했다.

### YJKit 현재 프로덕트

| Product | 역할 | 하루치 핏에서 |
|---|---|---|
| `WorkoutCore` | HKWorkoutSession·칼로리·심박 | **확장 필요** — 세그먼트 (2절) |
| `WorkoutUI` | 폰·워치 공유 워크아웃 화면 | **확장 필요** — 기본값 파라미터 (D-M1) |
| `ConnectivityCore` | 폰↔워치 전송 | 그대로 사용 |
| `PersistenceCore` | SwiftData + CloudKit | 그대로 사용 |
| `WorkoutShareUI` | 인스타 스토리 공유 (iOS 전용) | **그대로 사용** — 수정 없음 (D-M2) |

---

## 2. 가장 큰 기술적 공백 — 세그먼트

제품 스펙이 "세그먼트는 이 앱의 유일한 차별점이므로 어느 화면에서도 생략하지 않는다"고 못박았는데,
**현재 `WorkoutCore`에는 세그먼트 개념이 없다.**

### 확인된 사실 (코드 기준)

- `WorkoutSessionService.startWorkout()`은 `HKWorkoutSession` + `HKLiveWorkoutBuilder`를 만든다
- `HKWorkoutConfiguration.activityType`은 **세션 생성 시점에 고정**되며 도중에 바꿀 수 없다
- `stopWorkout()`은 `builder.statistics(for:)`로 **워크아웃 전체 구간**의 칼로리·심박·거리·걸음수만 집계한다
- `WorkoutResult`에 세그먼트를 담을 필드가 없다
- 세그먼트를 추가할 API(`addWorkoutActivity`)가 **서비스에 노출돼 있지 않다**

### 설계 방향

세션은 **하나의 activityType으로 시작**하고, 내부 구간을 `HKWorkoutActivity`로 나눈다.
근력↔유산소 전환은 "세션 재시작"이 아니라 "활동 구간 교체"다.

```
HKWorkoutSession  (전체 1:12:24)
├─ HKWorkoutActivity  .traditionalStrengthTraining  0:00–0:42
├─ HKWorkoutActivity  .running (또는 유산소 타입)    0:42–1:00
└─ HKWorkoutActivity  .traditionalStrengthTraining  1:00–1:12
```

**API 가용성은 SDK 헤더로 확인했다** (`WatchOS26.5.sdk/…/HealthKit.framework/Headers/`):

| 심볼 | 가용성 | 용도 |
|---|---|---|
| `HKWorkoutSession.beginNewActivity(configuration:date:metadata:)` | watchOS 9.0+ / iOS 17.0+ | 라이브 세션의 구간 시작 — **이걸 쓴다** |
| `HKWorkoutSession.endCurrentActivity(on:)` | watchOS 9.0+ / iOS 17.0+ | 현재 구간 종료 |
| `HKWorkout.workoutActivities` | watchOS 9.0+ | 저장된 워크아웃에서 구간 되읽기 |
| `HKWorkoutBuilder.addWorkoutActivity(_:completion:)` | watchOS 9.0+ | 수동 빌더용 — 라이브 세션에는 쓰지 않는다 |

배포 타깃이 watchOS 10.0이라 **가용성 문제는 없다.**

> ⚠️ **동작은 아직 검증되지 않았다.** API가 존재하는 것과 기대대로 동작하는 것은 다른 문제다.
> **구간이 실제로 저장되는지, 시각이 정확한지, 짧은 구간이 버려지지 않는지는 실기기로 확인해야 한다** —
> 시뮬레이터에서는 HealthKit 워크아웃을 신뢰할 수 없다.
> 검증 절차는 `plans/2026-09-03-haruchi-fit-target-scaffold.md`의 Task 6이며,
> 실패하면 아래 폴백으로 간다.

**폴백** — HealthKit에 구간을 남기지 못하면, 세그먼트를 **SwiftData 전용 데이터**로 취급한다.
HealthKit에는 단일 워크아웃만 남고 세그먼트는 앱 안에서만 보인다.
기능은 유지되지만 다른 앱·기기와의 이식성을 잃는다.

### WorkoutCore에 필요한 확장

- 세션 도중 활동 구간을 전환하는 API (`switchActivity(to:)` 형태)
- 구간 목록을 담은 결과 타입 — `WorkoutResult`에 세그먼트 배열 추가 (기존 소비자 2개가 깨지지 않도록 **기본값 있는 필드**로)
- **구간별 시간만 집계한다.** 구간별 칼로리·심박은 내지 않는다 (D-M3)

> ⚠️ `WorkoutCore`는 **GolfCounter와 Ralli가 함께 쓴다.** 시그니처를 바꾸면 두 앱이 영향받는다.
> 추가는 하되 **기존 API는 건드리지 않는** 방향으로 간다.

---

## 3. 데이터 모델

### 저장 위치 분리

HealthKit에 **자리가 없는 데이터**가 있다. 부위 태그와 메모다.

| 데이터 | HealthKit | SwiftData |
|---|---|---|
| 워크아웃 시각·시간·칼로리·심박 | ✅ 원본 | 캐시 |
| 세그먼트 | ⚠️ `HKWorkoutActivity` (검증 필요) | ✅ 원본 또는 미러 |
| **부위 태그** | ❌ 없음 | ✅ **원본** |
| **메모** | ❌ 없음 | ✅ **원본** |
| 잔디 일별 집계 | ❌ | 파생 (5절) |

> HealthKit 메타데이터에 부위를 욱여넣는 방식은 쓰지 않는다 — 조회·필터가 불편하고
> 다른 앱이 해석할 수 없어 이식성 이득이 없다.

### 엔티티 초안

```
WorkoutRecord            @Model
  healthKitUUID: UUID?   ← HealthKit 워크아웃과의 연결 키. 수동 기록은 nil
  startedAt / endedAt
  totalSeconds
  activeCalories / totalCalories / averageHeartRate
  segments: [Segment]    ← 순서 있는 구간
  bodyParts: [BodyPart]  ← 멀티 (D1)
  memo: String?
  source: .watch | .healthKitImport | .manual

Segment
  kind: .strength | .cardio
  startOffset / durationSeconds
```

**매칭 키는 `healthKitUUID`다.** HealthKit에서 워크아웃을 다시 읽어올 때 이 키로 기존 레코드를 찾아
부위·메모를 잃지 않고 갱신한다. `PersistenceService.upsert(_:replacing:)`가 predicate를 받으므로
그대로 쓸 수 있다.

### CloudKit 제약 (PersistenceCore README 기준)

- 모든 속성은 **optional 또는 기본값**
- `@Relationship`은 optional + `inverse` 명시
- **`.unique` 제약 금지** → `healthKitUUID`에 유니크 제약을 걸 수 없다. **중복 방지는 앱 코드 책임**이다

---

## 4. HealthKit 연동

### 4.1 동기화

워치에서 저장한 워크아웃과, **기본 운동 앱 등 다른 앱이 저장한 워크아웃**을 모두 가져와야 한다
(제품 스펙 흐름 C). 앵커드 쿼리(`HKAnchoredObjectQuery`)로 증분 동기화하고 앵커를 로컬에 보존한다.

- **앱 포그라운드 진입 시에만 동기화한다.** 백그라운드 배달(`enableBackgroundDelivery`)은 쓰지 않는다 (D-M4)

### 4.2 외부 워크아웃의 근력/유산소 분류

다른 앱이 저장한 워크아웃에는 하루치 핏의 세그먼트가 없다. `HKWorkoutActivityType` 하나만 있다.
이걸 근력/유산소 중 하나로 **분류하는 매핑 표가 필요**하다.

```
근력    .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining …
유산소  .running, .walking, .cycling, .elliptical, .rowing, .highIntensityIntervalTraining …
그 외   → 가져오지 않는다 (D-M5)
```

**매핑에 없는 타입은 아예 import하지 않는다.** 요가·수영·구기 종목 등이 여기 해당하며,
Ralli(테니스)·GolfCounter(골프)가 저장한 워크아웃도 잔디에 반영되지 않는다.

매핑 표의 최종 목록은 구현 시점에 `HKWorkoutActivityType` 전체를 훑어 확정한다 —
**한번 정하면 사용자의 과거 잔디가 달라지므로 이후 변경에 주의해야 한다.**

### 4.3 권한 거부

권한을 거부해도 앱은 **수동 기록 모드로 완결**된다 (제품 스펙 01b).
이 경우 HealthKit 읽기·쓰기를 모두 건너뛰고 SwiftData만 쓴다. 잔디 농도는 D4에 따라 최소 농도 fallback.

### 4.4 소비자 앱 체크리스트 (YJKit README에서)

- [ ] 타깃 Capability에 **HealthKit** 추가
- [ ] `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`
- [ ] `Info.plist`에 `LSApplicationQueriesSchemes` → `instagram-stories` (빠지면 **조용히** 공유시트로 폴백)
- [ ] Meta 개발자 대시보드에서 Facebook App ID 발급 → `instagramAppID`
- [ ] iCloud → CloudKit 컨테이너, Background Modes → Remote notifications
- [ ] watchOS 10.0 / iOS 17.0

---

## 5. 잔디 계산

### 일별 집계

- **하루 1칸, 여러 세션은 시간 합산** (D3)
- 농도 4단계, 기준은 시간(기본) ↔ 칼로리 전환 (D4)
- 수동 기록은 최소 농도

**시간 기준 컷은 30 / 60 / 90분이다** (D-M6). 칼로리 기준 컷은 구현 시점에 실제 데이터를 보고 정한다.

집계는 `WorkoutRecord`에서 파생하되, 홈 잔디(약 4개월 = 119칸)와 통계 잔디(1년 = 371칸)를
매번 전체 스캔하지 않도록 **일별 집계 캐시**를 두는 편이 낫다. 캐시 무효화 시점은
레코드 생성·수정·삭제 + 농도 기준 설정 변경이다.

### 통계 연도 아카이브

연도 세그먼트를 바꾸면 잔디·요약·차트가 전부 교체된다. 연 단위 쿼리가 반복되므로
**연도별 집계도 캐시 대상**이다. 과거 연도는 더 이상 변하지 않으므로 한 번 계산하면 고정이다.

---
## 6. 결정 사항 (2026-09-03)

미결로 두었던 M1~M7을 전부 결정했다. 각 항목에 **왜 그렇게 정했는지**를 남긴다.

### D-M1. `WorkoutUI` 워치 화면 — 패키지에 기본값 파라미터를 추가한다

목업이 요구하는 것과 현재 뷰의 차이:

| | 현재 `WorkoutUI` | 목업 요구 |
|---|---|---|
| `WorkoutMetricsView` | 경과·활동kcal·총kcal·BPM 4개 고정 | 상단 모드 라벨(`진행 중 · 근력`) 추가 |
| `WorkoutControlsView` | 일시정지 + 종료 2버튼 | 위에 근력/유산소 전환 행 추가 |

두 뷰에 **기본값이 있는 optional 파라미터**를 넣는다. 기본값을 주면 GolfCounter·Ralli는
호출부를 고치지 않아도 지금과 똑같이 동작하고, 하루치 핏만 값을 넘겨 확장된 화면을 얻는다.

컴포지션(앱이 위아래에 자기 뷰를 얹는 방식)은 레이아웃이 어긋나기 쉽고 **색 불일치를 해결하지 못해서**,
자체 구현은 같은 화면의 세 번째 중복이 생겨서 각각 기각했다.

**대가** — 3개 앱이 공유하는 API가 커진다. 패키지를 고치므로 **CI가 세 앱을 전부 빌드해 회귀를 확인**해야 한다.

> **색 처리는 별도 결정이 남아 있다.** 현재 `WorkoutMetricsView`는 경과시간을 `.yellow`로 그리는데
> 하루치 핏 목업은 오렌지 계열이다. 틴트를 파라미터로 뺄지, 시리즈 공통으로 노랑을 유지할지는
> 구현 착수 시점에 실제 화면을 보고 정한다. **기능 결정이 아니라 시각 결정이므로 문서로 미리 정하지 않는다.**

### D-M2. 공유 — 기존 `WorkoutShareUI`를 그대로 쓴다. 목업 06은 채택하지 않는다

패키지를 수정하지 않고, `WorkoutShareButton(result:style:instagramAppID:)`을 그대로 붙인다.

이에 따라 **목업 06의 잔디 공유 카드는 v1에서 빠진다.** 함께 빠지는 것:
잔디 그리드 카드, `8월, 12번째 운동` 문구, 톤 3종(다크/라이트/오렌지), `이미지 저장` 버튼,
홈 잔디 길게 누르기 진입.

공유 카드 내용은 패키지가 소유하는 **시간 · kcal · 평균 심박 3행**이 되고,
배경은 브랜드 오렌지에서 파생된 그라디언트 하나로 고정된다.

**부수 효과 — 이 결정이 패키지의 첫 실사용 검증이 된다.**
`WorkoutShareUI`는 현재 **어느 앱에서도 쓰이지 않는다**(`Apps/` 안에 참조 0건).
하루치 핏이 첫 소비자다.

검증 상태:

- ✅ 렌더링 — `make kit-test` 통과 (26 tests / 5 suites). `WorkoutShareRendererTests` 4건이
  스티커 크기·투명도·행 수에 따른 높이 변화를 검증한다
- ❌ **인스타그램 딥링크가 실기기에서 실제로 열리는지는 미검증.** 시뮬레이터로 확인할 수 없다.
  `LSApplicationQueriesSchemes`에 `instagram-stories`가 빠지면 **크래시가 아니라 조용히 공유 시트로 폴백**되므로,
  실기기에서 딥링크가 열리는 것을 눈으로 확인해야 한다

### D-M3. 세그먼트별 지표 — 시간만 낸다

세그먼트별 값을 쓰는 화면은 W2 요약(`근력 54분` / `유산소 18분`)과 기록 상세 둘뿐이고,
**둘 다 시간만 표시한다.** 칼로리·심박은 세션 전체 값으로 나간다.

구간별 통계를 내려면 구간마다 `HKStatisticsQuery`를 돌려야 하는데, 그 값을 쓰는 화면이 없다.

### D-M4. HealthKit 백그라운드 배달 — 쓰지 않는다

컴플리케이션은 **진행 중인 워크아웃 세션 상태만** 표시한다 — GolfCounter·Ralli와 같은 방식이다.
누적 횟수나 오늘 운동 여부 같은 집계 값을 넣지 않으므로, **앱을 안 열어도 HealthKit이 갱신될 필요가 없다.**

기존 두 앱의 컴플리케이션 구현이 이미 이 형태다 (`Apps/GolfCounter/ComplicationApp/`):

- 진행 중 여부를 로컬 스냅샷 스토어로 판단한다 — **HealthKit을 참조하지 않는다**
- 비활성 시 타임라인 정책은 `.never`. 시간 기반 갱신을 하지 않고, 상태가 바뀌면
  워치 앱이 `reloadAllTimelines()`를 호출한다

따라서 HealthKit 동기화는 **앱 진입 시 포그라운드 동기화만** 한다.
`enableBackgroundDelivery`와 Background Modes 설정은 필요 없다.

> iOS 위젯(홈 화면 잔디)을 나중에 도입하면 이 결정을 재검토해야 한다. 위젯은 집계 값을 보여주므로
> 백그라운드 갱신이 실제로 필요하다.

### D-M5. 잔디 반영 범위 — 근력·유산소로 분류되는 워크아웃만

4.2의 매핑 표에 있는 `HKWorkoutActivityType`만 가져온다. 매핑에 없는 타입(요가·수영·구기 종목 등)은
**아예 가져오지 않는다.**

데이터가 깔끔하게 유지되고, 비율 차트와 부위 통계의 분모가 정확해진다.

**대가** — 하루치 시리즈의 다른 앱(Ralli 테니스, GolfCounter 골프)이 저장한 워크아웃은
**잔디에 반영되지 않는다.** 시리즈 통합 관점의 아쉬움은 v1.1 이후 검토 대상으로 남긴다.

### D-M6. 잔디 농도 컷 — 30 / 60 / 90분

하루 합산 시간 기준 4단계:

| 단계 | 범위 |
|---|---|
| 1 | ~30분 |
| 2 | 30~60분 |
| 3 | 60~90분 |
| 4 | 90분 초과 |

대상 사용자의 한 세션이 보통 60~90분이라 **2~3단계가 기본값**이 된다.
문턱을 더 낮추면(20/45/75) 상위 단계가 금방 포화되고, 더 높이면(40/70/100)
가벼운 운동이 계속 1단계로 보여 "해도 표가 안 난다"는 인상을 준다.

칼로리 기준 컷은 실제 데이터를 보고 구현 시점에 정한다.

### D-M7. 타깃 구성 — iOS + Watch App + 컴플리케이션

위젯은 v1 스코프 밖이다. 컴플리케이션의 역할은 D-M4에 적은 대로
**세션 상태 표시 + 앱 실행 진입점**이며, 집계 값을 넣지 않는다.

컴플리케이션 설계는 기존 두 앱을 그대로 따른다:

- 패밀리 3종 — `accessoryCircular` · `accessoryCorner` · `accessoryRectangular`
- 진행 중 여부를 판단할 **로컬 스냅샷 스토어**가 필요하다 (골프의 `RoundSnapshotStore` 대응)
- **표시 로직을 `Shared/`로 내려 워치 테스트 타깃에서 검증한다** —
  위젯 타깃에는 테스트 타깃을 붙일 수 없기 때문이다 (골프의 `ComplicationState` 패턴)

## 7. 타깃 구조

```
Apps/HaruchiFit/
├─ HaruchiFit.xcodeproj
├─ HaruchiFit/              iOS 앱
├─ HaruchiFit Watch App/    watchOS 앱
├─ ComplicationApp/         컴플리케이션 익스텐션
├─ Shared/                  워치 앱 ↔ 컴플리케이션 공유 (스냅샷·표시 상태)
└─ .swiftlint.yml           parent_config로 루트 상속
```

프로덕트 연결 (기존 두 앱의 패턴을 따름):

| 타깃 | 링크할 프로덕트 |
|---|---|
| `HaruchiFit` | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI, **WorkoutShareUI** |
| `HaruchiFit Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |
| `HaruchiComplicationExtension` | (없음 — 로컬 스냅샷만 읽는다) |

- 워크스페이스 `YJApps.xcworkspace`에 프로젝트 추가 + **스킴 공유** (CI가 스킴 이름으로 빌드함).
  기존 공유 스킴 7개에 하루치 핏 3개가 더해져 **10개**가 된다
- `Packages/YJKit`는 `XCLocalSwiftPackageReference "../../Packages/YJKit"`로 참조
- 프로젝트는 **`PBXFileSystemSynchronizedRootGroup`** 방식 — 파일 추가/삭제에 pbxproj 편집 불필요
- CI 경로 필터에 `Apps/HaruchiFit/**` 추가 필요 (`.github/workflows`)

> **`Shared/`가 필요한 이유** — 위젯 타깃에는 테스트 타깃을 붙일 수 없다. 컴플리케이션의 표시 로직을
> `Shared/`에 두고 워치 테스트 타깃에서 검증한다. GolfCounter의 `Shared/Models/ComplicationState.swift` +
> `watchosTests/Shared/ComplicationStateTests.swift` 구조를 그대로 따른다.

---

## 8. 폰↔워치 계약

`CLAUDE.md`의 **워크아웃 동작 계약 3조**를 그대로 지킨다. 세 앱이 같은 규칙을 지켜야 숫자 의미가 갈리지 않는다.

- [ ] 화면에 넘기는 칼로리는 **워크아웃 누적값**. 구간 값이 필요하면 저장 시점에 `종료값 - 시작값`
- [ ] 경과시간은 **워치가 단일 소스**. 폰은 `WorkoutAnchor.interpolatedElapsed(...)`로 보간하고 자체 타이머를 돌리지 않는다
- [ ] pause는 **폰→워치 명령**. `WorkoutPauseMessage`를 `.reliable`로 보내고 `isPaused`는 워치 앵커로만 갱신 (낙관적 토글 금지). 워치 미연결이면 `isPauseAvailable: false`
- [ ] `WorkoutMetricsMessage`는 반드시 **`.realtimeOnly`** — 앵커 보간이 "방금 보냄" 전제 위에 있다
- [ ] `ConnectivityService`는 **프로세스당 하나**, `onReceive` 등록은 생성한 main-queue turn 안에서 완료

### 하루치 핏이 추가하는 메시지

세그먼트 전환을 폰이 실시간으로 알아야 하는가? 세션 중 폰 화면에 세그먼트를 표시할 계획이 제품 스펙에 없으므로,
**전환 이벤트는 저장 시점에 결과와 함께 한 번만 보내면 충분하다.** 별도 실시간 메시지는 두지 않는다.

---

## 9. 리스크

| 리스크 | 영향 | 완화 |
|---|---|---|
| `HKWorkoutActivity` 실시간 구간 기록이 기대대로 동작하지 않음 | 세그먼트 이식성 상실 | 2절 폴백 — SwiftData 전용 세그먼트. 기능은 유지 |
| `WorkoutCore` 확장이 GolfCounter·Ralli를 깨뜨림 | 기존 앱 회귀 | 기존 시그니처 무변경 + 기본값 파라미터. CI가 3개 앱 전부 빌드 |
| 햅틱을 시뮬레이터에서 검증 불가 | 운동 중 유일한 확인 수단이 동작 안 함 | **실기기 테스트를 완료 조건에 포함** |
| CloudKit이 `.unique`를 막아 워크아웃 중복 저장 | 잔디가 부풀려짐 | `healthKitUUID` 중복 검사를 앱 코드로. 동기화 경로 단일화 |
| 인스타 딥링크가 조용히 폴백 | 공유 경험 저하를 인지 못 함 | `LSApplicationQueriesSchemes` 확인 + 실기기에서 딥링크 실제 오픈 검증 |

---

## 10. 다음 단계

미결 항목은 전부 결정됐다 (6절). 남은 것은 검증과 구현이다.

1. **`HKWorkoutActivity` 실기기 검증** (2절) ← 여기가 다음 시작점.
   실패하면 폴백(SwiftData 전용 세그먼트)으로 확정하고 3절 표를 고친다
2. `Apps/HaruchiFit/` 타깃 3개 생성 + 워크스페이스 스킴 공유 + CI 경로 필터 등록
3. `WorkoutCore` 세그먼트 확장 — 기존 두 앱 회귀 검증 포함
4. `WorkoutUI` 기본값 파라미터 추가 (D-M1) — 색 처리는 실제 화면 보고 결정
5. 구현 플랜 작성 → `docs/superpowers/plans/`

### 검증이 남은 항목

| 항목 | 왜 시뮬레이터로 안 되는가 | 관련 |
|---|---|---|
| `HKWorkoutActivity` 실시간 구간 기록·되읽기 | HealthKit 워크아웃 동작이 실기기와 다름 | 2절 |
| 햅틱 8종 | 시뮬레이터에 햅틱 엔진이 없음 | 제품 스펙 5절 |
| 인스타그램 스토리 딥링크 | 인스타그램 앱이 설치돼 있어야 함 | D-M2 |
