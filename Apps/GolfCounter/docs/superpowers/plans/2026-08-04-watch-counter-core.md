# ③ watch: 워치 카운터 코어 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워치 앱에 라운드의 전 과정(홈 → 파 선택 → 카운터 → 세션 컨트롤·메트릭)을 구현하고, 상태 변경마다 `RoundSnapshot`을 App Group에 기록해 컴플리케이션 갱신과 크래시 복구를 동작시킨다.

**Architecture:** 라운드 상태·카운터 불변식은 UI 프레임워크를 모르는 `RoundViewModel`(`@MainActor ObservableObject`)에 전부 넣고 `watchosTests`에서 검증한다. 스냅샷 저장과 `WidgetCenter` 갱신은 `RoundSnapshotPublishing` 프로토콜 뒤로 숨겨 ViewModel이 테스트 더블을 주입받게 한다. HealthKit 워크아웃은 ralli-kit `WorkoutSessionService`를 그대로 쓰되, 골프에 필요한 거리·걸음수 수집만 패키지에 **추가 전용(additive)** 으로 확장한다. 화면은 tennis_counter와 동일하게 3페이지 `TabView`(컨트롤 / 카운터 / 메트릭)로 구성한다.

**Tech Stack:** SwiftUI / WatchKit / HealthKit (WorkoutCore) / WidgetKit / Swift Testing

**참조 spec:** `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` (§3 카운터 규칙·RoundSnapshot, §4 워치 화면 흐름, §8 HealthKit, §11 테스트, §12 에러 처리)

**선행 상태 (plan ①·② 완료분, 이미 저장소에 있음):**
- `Shared/Models/RoundSnapshot.swift` — `startedAt`, `courseName`, `currentHoleIndex`(0-based), `holeScores`, `holePars`, `puttCounts` / 계산 프로퍼티 `currentHoleNumber`, `totalStrokes`, `relativeToPar`
- `Shared/Services/RoundSnapshotStore.swift` — `save(_:to:) -> Bool`, `load(from:) -> RoundSnapshot?`, `clear(from:)` (기본 인자는 App Group suite)
- `Shared/Models/ComplicationState.swift` — `relativeToParText`("+3"/"E"/"-2") 포맷 보유. **Task 3에서 공통 포맷터로 추출한다.**
- `GolfCounter Watch App.entitlements`에 `com.apple.developer.healthkit`와 App Group `group.com.yj.GolfCounter`가 이미 설정되어 있다
- pbxproj에 `INFOPLIST_KEY_NSHealthShareUsageDescription`·`NSHealthUpdateUsageDescription`이 이미 있다 → **Info.plist 작업 없음**
- 워치 타깃에 `WorkoutCore`·`ConnectivityCore`가 이미 링크되어 있다 → **패키지 링크 작업 없음**
- `WatchApp/`은 `PBXFileSystemSynchronizedRootGroup`이다 → **pbxproj를 손댈 일이 없다.** 파일 추가는 파일시스템 조작만으로 빌드에 반영된다

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0**
- App Group: `group.com.yj.GolfCounter`
- **카운터 불변식 (spec §3, 절대 어기지 말 것)**
  - 스윙 모드 `+`: 타수 +1
  - 스윙 모드 `−`: 타수 −1, 단 **타수 ≥ 퍼팅** 유지
  - 퍼팅 모드 `+`: 타수 +1 **및** 퍼팅 +1
  - 퍼팅 모드 `−`: 타수 −1 **및** 퍼팅 −1, 0 미만 불가
  - 하한 0, **상한 클램프 없음**
  - 홀 이동 시 입력 모드는 **스윙으로 리셋**
- 파 선택 화면 등장 조건은 "홀 이동 방향"이 아니라 **"해당 홀에 파가 설정되어 있는가"** 하나다 (미설정 = `holePars[i] == 0`)
- 사용자 노출 문자열은 이 단계에서도 **한국어 하드코딩**한다. `.xcstrings` 로컬라이즈는 plan ⑦ 범위
- ViewModel은 UI 프레임워크(SwiftUI/WatchKit/WidgetKit) import 금지 — `Foundation`·`Combine`만
- 워치는 완료 라운드를 **로컬 저장하지 않는다** (spec §14). 저장·전송은 plan ④
- 한 파일 = 한 타입 (파일 내 `private` helper struct는 예외)
- 커밋 메시지는 gitmoji prefix, `main` 직접 커밋 금지 (golf-counter·ralli-kit 양쪽 모두)
- 빌드/테스트 시뮬레이터: 워치는 `Apple Watch Series 11 (46mm)`, iPhone은 `iPhone 17 Pro`

## 이 plan에서 내린 설계 결정 (spec 대비 차이)

1. **거리·걸음수는 ralli-kit `WorkoutCore`를 확장해 얻는다.** `WorkoutSessionService`는 `HKLiveWorkoutBuilder`를 private으로 갖고 있어 외부에서 거리·걸음수 통계를 꺼낼 수 없다. 권한 요청 타입 세트도 하드코딩 상수라, 여기에 타입을 그냥 더하면 tennis_counter 사용자에게도 권한 시트 항목이 늘어난다. 따라서 **`WorkoutConfiguration`에 `additionalReadTypes`를 주입받는 형태로 확장**해, 지정하지 않는 소비자(tennis_counter)는 완전히 무영향이 되게 한다 (Task 1·2).
2. **크래시 복구는 스냅샷만 복구하고 `HKWorkoutSession`은 새로 시작한다.** `HKHealthStore.recoverActiveWorkoutSession()` 경로는 만들지 않는다. 스코어 데이터(핵심 자산)는 온전히 살아나며, 대가로 크래시 이전 구간의 심박·칼로리가 별도 워크아웃으로 분리 기록된다.
3. **홈 화면의 "최근 라운드 요약 한 줄"(spec §4)은 구현하지 않는다.** spec §14가 워치에 완료 기록을 보관하지 않는다고 못박고 있어 워치가 참조할 데이터원이 없다 — 두 조항이 충돌한다. 홈은 "라운드 시작" 버튼 하나로 두고, 요약이 필요하면 iOS→워치 역방향 데이터가 생기는 시점에 재검토한다.
4. **"라운드 종료" 버튼은 워크아웃을 끝내고 스냅샷을 지운 뒤 곧바로 홈으로 복귀한다.** 종료 요약 화면과 `.reliable` 전송은 plan ④ 범위다. 이 plan 시점에는 라운드 결과가 어디에도 저장되지 않는다 — 의도된 중간 상태다.

---

## 구현 결과 (2026-08-04 완료)

Task 0~11 전체 완료. superpowers:subagent-driven-development로 태스크별 구현 → 리뷰 → (필요시) 수정 루프를 거치고, 마지막에 브랜치 전체 리뷰를 별도로 진행했다. 이 절에는 진행 중 실제로 있었던 결정·변경 사항만 남긴다 — 각 태스크의 세부 스텝이 계획대로 됐는지는 위 체크리스트와 git 커밋 이력이 원본이다.

- ralli-kit PR: [ralli-kit#2](https://github.com/qlrogo91lp/ralli-kit/pull/2) — `main` 머지 완료
- golf-counter PR: [golf_counter#7](https://github.com/qlrogo91lp/golf_counter/pull/7) — 리뷰 대기

### 플랜 문서 자체의 오류

- Task 7 `RoundViewModelSnapshotTests`: 코드 블록에 실제로 작성된 `@Test`는 10개인데, 요약 문구는 "11"로 잘못 표기되어 있었다 (→ Task 11 Step 5, 완료 기준의 "watchosTests 45건"도 같은 이유로 실제와 다름). 코드가 맞고 요약 숫자가 틀렸던 것 — 구현은 코드 블록 그대로 따랐다.
- Task 11 Step 3 기대치(iosTests 2건, watchosTests 45건)도 위와 같은 이유, 그리고 이 브랜치가 건드리지 않은 기존 baseline 파일(`RoundSnapshotTests`가 4건이 아니라 6건, `GolfRoundTests`가 2건이 아니라 3건)까지 겹쳐 실제로는 iosTests 3건·watchosTests 46건(태스크별 리뷰 시점 기준, 최종 리뷰의 fix wave로 3건 더 늘어 49건)이 정상이다. 회귀는 아니고 플랜의 최초 집계 실수다.

### 태스크별 리뷰에서 나온 plan-mandated 발견 — 사용자가 판단

각 태스크 리뷰에서 "플랜 브리프 코드 자체가 문제"라고 표시된 발견은 규칙상 임의로 처리하지 않고 사람에게 판단을 맡겼다. 결과:

| 태스크 | 발견 | 판단 |
|---|---|---|
| Task 2 | `stopWorkout()`에서 거리·걸음수가 calories/heartRate와 달리 종료 시점 fresh query가 아니라 마지막 라이브 콜백 시점의 캐시값을 씀 — undercounting 가능 | **지금 고침** → `collectDistance(builder:)`/`collectSteps(builder:)` 헬퍼 추가, `stopWorkout()`에서 사용 |
| Task 4 | `RoundSnapshotPublisher.swift` 한 파일에 `protocol RoundSnapshotPublishing`과 `struct RoundSnapshotPublisher` 두 타입 — "한 파일 = 한 타입" 규칙과 문자 그대로는 어긋남 | **플랜대로 유지** — protocol+유일한 구현체를 한 파일에 두는 건 Swift에서 흔한 저위험 패턴이라는 판단 |
| Task 8 | `ParOptionButton`/`CounterView`/`Scorecard`의 "Par"/"H" 영문 하드코딩 — "한국어 하드코딩" 규칙과 어긋남 | **플랜대로 유지** — 골프 용어로 관용적으로 쓰이는 표기라는 판단 |

### 태스크별 리뷰에서 나온 실질적 버그 — 그 자리에서 수정

- **Task 2 (ralli-kit):** 위 표의 fresh-query 수정.
- **Task 9 (golf-counter):** `RoundSessionView.startRound()`가 `Task { await requestAuthorization(); startWorkout() }`를 발사하는데, 그 인증 대기 중에 사용자가 "라운드 종료"를 누르면 `endRound()`의 `stopWorkout()`은 아직 세션이 없어 no-op이 되고 뷰는 dismiss된다. 뒤늦게 깨어난 start Task가 `startWorkout()`을 호출해 아무도 멈추지 못하는 워크아웃 세션이 남는 레이스였다. `startTask`를 보관해 `endRound()`에서 취소하고, 인증 완료 후 `Task.isCancelled`를 확인한 뒤에만 `startWorkout()`을 호출하도록 수정.

### 최종 브랜치 전체 리뷰에서 새로 나온 발견 (태스크 단위 리뷰로는 못 잡음) — 전부 수정

Task 11 자동 검증(린트·3스킴 빌드·전체 테스트) 통과 후, 두 브랜치 각각에 대해 opus 모델로 별도의 브랜치 전체 리뷰를 추가로 돌렸다. plan-mandated 충돌이 아니라 순수 리뷰 발견이라 바로 수정 라운드를 거쳤다.

- **ralli-kit:** `additionalReadTypes`가 `typesToRead`만 넓히고 `typesToShare`는 그대로였다. `HKLiveWorkoutDataSource.enableCollection`으로 수집한 샘플을 워크아웃에 실제로 저장하려면 share 권한이 필요한데, 이게 빠져 있어 골프 워크아웃의 거리·걸음수가 Health에 조용히 저장 안 될 수 있는 위험이었다. `typesToShare`도 `typesToRead`와 같은 패턴으로 `additionalReadTypes`를 반영하도록 수정, 대응 테스트 추가.
- **golf-counter — 파 선택 화면 유령 홀 버그:** `ParSelectionView`에 이전 홀로 돌아가는 버튼이 없었다. 카운터 화면에서 실수로 "다음"을 눌러 새 홀(par 미설정)에 진입하면 되돌아갈 방법이 없고, 빠져나가려고 아무 파나 고르면 `score 0 · 그 파 · putts 0`인 유령 홀이 영구히 남아 전체 오버파 표시가 그 파만큼 틀어지는(스코어카드·헤더·컴플리케이션 전부) 문제였다. `ParSelectionView`에 `ParBackButton` 추가, `RoundViewModel.cancelToPreviousHole()`/`isPristinePhantomHole`을 추가해 "손대지 않은 말단 홀"에서 되돌아갈 때만 그 홀을 배열에서 완전히 제거하고, `beginParEditing()`으로 재편집 중인 진짜 홀은 절대 건드리지 않도록 구분.
- **golf-counter — 비정상 종료 시 워크아웃 고아 문제:** `endRound()`를 거치지 않고 뷰가 사라지면(예: 엣지 스와이프가 완전히 막히지 않는 경우) 스냅샷이 남아 홈 진입 시 자동 복구가 새 `WorkoutSessionService`로 워크아웃을 다시 시작해, 먼저 시작된 세션이 고아로 남을 수 있었다. `RoundSessionView`에 `didFinish` 플래그와 `.onDisappear` 가드를 추가해 `endRound()`를 거치지 않은 종료 시 워크아웃을 정리하도록 함 (스냅샷/App Group 상태는 건드리지 않아 크래시 복구는 그대로 동작).
- **golf-counter — 사소한 정정:** `endRound()`의 `Task { await healthKit.stopWorkout() }`가 `dismiss()` 이후 `@StateObject`를 읽을 수 있는 위험 → `Task` 생성 전에 로컬 `let service = healthKit`로 캡처하도록 수정.

### 최종 리뷰에서 나왔지만 병합을 막지 않는다고 판단해 보류한 것 (deferred minor)

- `WorkoutConfiguration+Golf.swift`가 `Features/Round/`에 있음 — 비-UI HealthKit 설정이라 `Shared/Services/`가 더 맞다는 지적
- `RoundSnapshotPublisherTests`의 임시 `UserDefaults` suite가 `removePersistentDomain`을 호출하지 않음 (UUID라 실질적 위험 없음)
- `Scorecard`가 퍼트를 영문 약어 "p"로 표기, 요약 줄은 "퍼트"로 표기 — 표기 불일치
- `MetricsView`의 단위 문자열 "bpm"/"kcal"/"km"이 영문 — Par/H와 같은 범주의 관용 표기로 판단해 보류
- `startRound()`가 `requestAuthorization()`의 `Bool` 결과를 버림 — HealthKit 권한 거부 시 UI 피드백 없음
- (fix wave가 새로 만든 것) `cancelToPreviousHole()` 테스트가 배열 길이 축소를 직접 단언하지 않아 회귀 방지력이 약함
- (fix wave가 새로 만든 것) `ParSelectionView`에 `ScrollView`가 없어 40/41mm 워치 화면에서 새 버튼이 잘릴 가능성 — 이 프로젝트의 대상 기기는 46mm라 우선순위 낮음
- ralli-kit `additionalReadTypes`라는 이름이 read 권한뿐 아니라 실제로는 live-collection 활성화까지 겸한다는 걸 이름만으로 알기 어려움
- ralli-kit: 소비자가 `additionalReadTypes`에 `.distanceWalkingRunning`/`.stepCount` 외의 타입을 넣으면 수집·권한은 되지만 published 프로퍼티나 `WorkoutResult` 필드로 노출되지 않고 버려짐 (골프·테니스 조합에서는 문제 없음)
- ralli-kit: watchOS 전용 경로(`enableCollection`, `didCollectDataOf` 콜백 등)는 `swift test`가 macOS에서 도는 한 유닛테스트로 검증되지 않음 — golf-counter 워치 타깃 빌드 성공과 실기기/시뮬레이터 확인이 사실상의 커버리지

### 남은 일

- Task 11 Step 4 (워치 시뮬레이터 육안 확인 12항목, `ParSelectionView`에 새로 추가된 "이전" 버튼 포함) — 사용자가 Xcode에서 직접 확인 예정
- golf-counter [PR #7](https://github.com/qlrogo91lp/golf_counter/pull/7) 리뷰·머지

---

### Task 0: 작업 브랜치 준비 (두 저장소)

golf-counter와 ralli-kit 양쪽에 브랜치를 만든다. golf-counter는 로컬 경로로 ralli-kit을 참조하므로, ralli-kit 브랜치의 변경이 곧바로 워치 빌드에 반영된다.

**Files:** 없음 (git만)

- [ ] **Step 1: plan ②의 PR이 머지되었는지 확인**

```bash
cd /Users/yj/Workspace/Projects/golf-counter
gh pr list --state open
```

PR #6(`feat/complication`)이 아직 열려 있으면 먼저 머지한다.

```bash
gh pr merge 6 --merge --delete-branch
```

- [ ] **Step 2: golf-counter 브랜치 생성**

```bash
cd /Users/yj/Workspace/Projects/golf-counter
git checkout main && git pull
git checkout -b feat/watch-counter-core
```

- [ ] **Step 3: ralli-kit 브랜치 생성**

```bash
cd /Users/yj/Workspace/Projects/ralli-kit
git checkout main && git pull
git checkout -b feat/workout-distance-steps
```

---

### Task 1: ralli-kit — `WorkoutConfiguration.additionalReadTypes` (TDD)

권한 요청 타입을 소비자가 주입할 수 있게 한다. 기본값이 빈 집합이라 기존 소비자(tennis_counter)의 권한 시트는 그대로다.

**Files:**
- Modify: `../ralli-kit/Sources/WorkoutCore/WorkoutConfiguration.swift`
- Test: `../ralli-kit/Tests/WorkoutCoreTests/WorkoutConfigurationTests.swift`

**Interfaces:**
- Produces: `WorkoutConfiguration.additionalReadTypes: Set<HKQuantityTypeIdentifier>`, `init(activityType:locationType:additionalReadTypes:)` — Task 2의 `typesToRead`와 Task 4의 `WorkoutConfiguration.golf`가 이 시그니처에 의존한다

- [ ] **Step 1: 실패하는 테스트 추가** — `Tests/WorkoutCoreTests/WorkoutConfigurationTests.swift`의 `WorkoutConfigurationTests` struct 안, `equalWhenAllFieldsMatch()` 아래에 이어 붙인다

```swift
    @Test func additionalReadTypesDefaultToEmpty() {
        let config = WorkoutConfiguration(activityType: .tennis)
        #expect(config.additionalReadTypes.isEmpty)
    }

    @Test func additionalReadTypesAreStored() {
        let config = WorkoutConfiguration(
            activityType: .golf,
            locationType: .indoor,
            additionalReadTypes: [.distanceWalkingRunning, .stepCount]
        )
        #expect(config.additionalReadTypes == [.distanceWalkingRunning, .stepCount])
    }

    @Test func equalityAccountsForAdditionalReadTypes() {
        let a = WorkoutConfiguration(activityType: .golf, locationType: .indoor, additionalReadTypes: [.stepCount])
        let b = WorkoutConfiguration(activityType: .golf, locationType: .indoor)
        #expect(a != b)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/yj/Workspace/Projects/ralli-kit
swift test --filter WorkoutConfigurationTests
```

Expected: FAIL — `extra argument 'additionalReadTypes' in call` 컴파일 에러.

- [ ] **Step 3: 구현** — `Sources/WorkoutCore/WorkoutConfiguration.swift` 전체를 아래로 교체

```swift
import HealthKit

/// 앱별 워크아웃 종목 설정. 소비자 앱이 자기 종목으로 만들어 서비스에 주입한다.
public struct WorkoutConfiguration: Equatable, Sendable {
    public let activityType: HKWorkoutActivityType
    public let locationType: HKWorkoutSessionLocationType
    /// 기본 세트(활동/휴식 에너지·심박·워크아웃) 외에 추가로 읽고 수집할 수량 타입.
    /// 종목마다 필요한 지표가 달라 소비자가 지정한다 — 비워 두면 권한 요청 항목이 늘지 않는다.
    public let additionalReadTypes: Set<HKQuantityTypeIdentifier>

    public init(activityType: HKWorkoutActivityType,
                locationType: HKWorkoutSessionLocationType = .outdoor,
                additionalReadTypes: Set<HKQuantityTypeIdentifier> = [])
    {
        self.activityType = activityType
        self.locationType = locationType
        self.additionalReadTypes = additionalReadTypes
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd /Users/yj/Workspace/Projects/ralli-kit
swift test --filter WorkoutCoreTests
```

Expected: PASS 18건 (기존 15건 + 신규 3건).

- [ ] **Step 5: 커밋**

```bash
cd /Users/yj/Workspace/Projects/ralli-kit
git add Sources/WorkoutCore/WorkoutConfiguration.swift Tests/WorkoutCoreTests/WorkoutConfigurationTests.swift
git commit -m "✨ WorkoutConfiguration에 additionalReadTypes 주입 추가"
```

---

### Task 2: ralli-kit — 거리·걸음수 수집 (TDD)

`additionalReadTypes`에 지정된 타입을 권한 요청과 `HKLiveWorkoutDataSource` 수집 대상에 넣고, 거리·걸음수를 실시간 published 값과 `WorkoutResult`로 노출한다.

**Files:**
- Modify: `../ralli-kit/Sources/WorkoutCore/WorkoutResult.swift`
- Modify: `../ralli-kit/Sources/WorkoutCore/WorkoutSessionService.swift`
- Test: `../ralli-kit/Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift`

**Interfaces:**
- Consumes: `WorkoutConfiguration.additionalReadTypes` (Task 1)
- Produces:
  - `WorkoutResult.init(durationSeconds:caloriesBurned:averageHeartRate:totalCaloriesBurned:distanceMeters:steps:)` — 새 인자 둘은 기본값 0이라 기존 호출부는 그대로 컴파일된다
  - `WorkoutResult.distanceMeters: Double`, `WorkoutResult.steps: Int`
  - `WorkoutSessionService.currentDistanceMeters: Double`, `WorkoutSessionService.currentSteps: Int` (둘 다 `@Published private(set)`) — Task 10의 `MetricsView`가 의존
  - `WorkoutSessionService.typesToRead: Set<HKObjectType>` — `private let`에서 **internal computed var**로 승격(테스트 접근용)
  - `setLiveMetricsForTesting(heartRate:calories:basalCalories:elapsedSeconds:distanceMeters:steps:)` (DEBUG 전용)

- [ ] **Step 1: 실패하는 테스트 추가** — `Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift`의 struct 안 마지막에 이어 붙인다

`typesToReadOmitsAdditionalTypesByDefault`가 **tennis_counter 무영향 보증 테스트**다. 기본 4종에서 늘어나면 실패한다.

```swift
    @Test @MainActor func typesToReadOmitsAdditionalTypesByDefault() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .tennis))
        #expect(service.typesToRead.count == 4)
        #expect(!service.typesToRead.contains(HKQuantityType(.stepCount)))
        #expect(!service.typesToRead.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func typesToReadIncludesAdditionalTypes() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(
            activityType: .golf,
            locationType: .indoor,
            additionalReadTypes: [.distanceWalkingRunning, .stepCount]
        ))
        #expect(service.typesToRead.count == 6)
        #expect(service.typesToRead.contains(HKQuantityType(.stepCount)))
        #expect(service.typesToRead.contains(HKQuantityType(.distanceWalkingRunning)))
    }

    @Test @MainActor func distanceAndStepsStartAtZero() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .golf))
        #expect(service.currentDistanceMeters == 0)
        #expect(service.currentSteps == 0)
    }

    @Test @MainActor func setLiveMetricsInjectsDistanceAndSteps() {
        let service = WorkoutSessionService(configuration: WorkoutConfiguration(activityType: .golf))
        service.setLiveMetricsForTesting(distanceMeters: 4820.5, steps: 7100)
        #expect(service.currentDistanceMeters == 4820.5)
        #expect(service.currentSteps == 7100)
    }

    @Test func resultDistanceAndStepsDefaultToZero() {
        let result = WorkoutResult(durationSeconds: 60, caloriesBurned: 100, averageHeartRate: 120)
        #expect(result.distanceMeters == 0)
        #expect(result.steps == 0)
    }

    @Test func resultCarriesDistanceAndSteps() {
        let result = WorkoutResult(durationSeconds: 60,
                                   caloriesBurned: 100,
                                   averageHeartRate: 120,
                                   totalCaloriesBurned: 145,
                                   distanceMeters: 4820.5,
                                   steps: 7100)
        #expect(result.distanceMeters == 4820.5)
        #expect(result.steps == 7100)
    }
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/yj/Workspace/Projects/ralli-kit
swift test --filter WorkoutSessionServiceTests
```

Expected: FAIL — `value of type 'WorkoutSessionService' has no member 'currentDistanceMeters'` 등 컴파일 에러.

- [ ] **Step 3: `WorkoutResult` 확장** — `Sources/WorkoutCore/WorkoutResult.swift` 전체를 아래로 교체

```swift
import Foundation

public struct WorkoutResult: Equatable, Sendable {
    public let durationSeconds: Int
    /// 활동 에너지(activeEnergyBurned)만.
    public let caloriesBurned: Double
    /// 활동 + 휴식(basalEnergyBurned). 소비자가 값을 주지 않으면 0.
    public let totalCaloriesBurned: Double
    public let averageHeartRate: Double?
    /// 워크아웃 구간의 이동 거리(미터). 종목이 distanceWalkingRunning을 수집하지 않으면 0.
    public let distanceMeters: Double
    /// 워크아웃 구간의 걸음수. 종목이 stepCount를 수집하지 않으면 0.
    public let steps: Int

    public init(durationSeconds: Int,
                caloriesBurned: Double,
                averageHeartRate: Double?,
                totalCaloriesBurned: Double = 0,
                distanceMeters: Double = 0,
                steps: Int = 0)
    {
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.totalCaloriesBurned = totalCaloriesBurned
        self.distanceMeters = distanceMeters
        self.steps = steps
    }
}
```

- [ ] **Step 4: `typesToRead`를 computed로 바꾸고 published 값 추가** — `Sources/WorkoutCore/WorkoutSessionService.swift`

4-a. published 프로퍼티 추가 — `@Published public private(set) var elapsedSeconds: Int = 0` 바로 아래에 삽입

```swift
    @Published public private(set) var currentDistanceMeters: Double = 0
    @Published public private(set) var currentSteps: Int = 0
```

4-b. `typesToRead` 상수를 computed var로 교체 — 기존 블록

```swift
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]
```

을 아래로 교체한다 (`private` 제거 — 테스트가 읽는다).

```swift
    /// 기본 4종 + configuration이 지정한 추가 타입. 지정이 없으면 기존 소비자와 완전히 동일하다.
    var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.heartRate),
            HKObjectType.workoutType(),
        ]
        for identifier in configuration.additionalReadTypes {
            types.insert(HKQuantityType(identifier))
        }
        return types
    }
```

- [ ] **Step 5: 수집 활성화와 통계 반영** — 같은 파일

5-a. `startWorkout()` 안의 기존 한 줄

```swift
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
```

을 아래 5줄로 교체한다. `HKLiveWorkoutDataSource`는 activityType에 맞는 기본 타입만 자동 수집하므로, `.golf`+`.indoor`에서 거리·걸음수가 빠질 수 있다. 명시적으로 켠다.

```swift
                let dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
                for identifier in configuration.additionalReadTypes {
                    dataSource.enableCollection(for: HKQuantityType(identifier), predicate: nil)
                }
                builder.dataSource = dataSource
```

5-b. `workoutBuilder(_:didCollectDataOf:)` 안, `currentBasalCalories` 갱신 블록 **아래**에 삽입

```swift
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.distanceWalkingRunning)) {
                    self.currentDistanceMeters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? self.currentDistanceMeters
                }
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.stepCount)) {
                    let value = stats.sumQuantity()?.doubleValue(for: .count())
                    self.currentSteps = value.map { Int($0) } ?? self.currentSteps
                }
```

5-c. `stopWorkout()`의 `return WorkoutResult(...)` 를 아래로 교체

```swift
            return WorkoutResult(durationSeconds: elapsed,
                                 caloriesBurned: calories,
                                 averageHeartRate: heartRate,
                                 totalCaloriesBurned: calories + basal,
                                 distanceMeters: currentDistanceMeters,
                                 steps: currentSteps)
```

5-d. 새 세션 시작 시 이전 라운드 값이 남지 않도록 초기화한다. `startWorkout()` 안의 `startTimer()` 호출 **바로 위**에 삽입한다.

`elapsedSeconds`는 `startTimer()`가 0으로 되돌리지만 거리·걸음수는 그런 지점이 없다. 골프는 샘플 갱신 간격이 길어, 초기화하지 않으면 두 번째 라운드 시작 직후 한동안 **이전 라운드의 거리가 그대로 보인다.**

```swift
                currentDistanceMeters = 0
                currentSteps = 0
```

- [ ] **Step 6: DEBUG 주입 헬퍼 확장** — 파일 맨 아래 `setLiveMetricsForTesting` 전체를 아래로 교체

```swift
        /// 테스트·프리뷰 전용: HealthKit 세션 없이 표시 값을 주입한다. 릴리즈 빌드에는 포함되지 않는다.
        func setLiveMetricsForTesting(heartRate: Double? = nil,
                                      calories: Double? = nil,
                                      basalCalories: Double? = nil,
                                      elapsedSeconds: Int? = nil,
                                      distanceMeters: Double? = nil,
                                      steps: Int? = nil)
        {
            if let heartRate { currentHeartRate = heartRate }
            if let calories { currentCalories = calories }
            if let basalCalories { currentBasalCalories = basalCalories }
            if let elapsedSeconds { self.elapsedSeconds = elapsedSeconds }
            if let distanceMeters { currentDistanceMeters = distanceMeters }
            if let steps { currentSteps = steps }
        }
```

- [ ] **Step 7: 테스트 통과 확인**

```bash
cd /Users/yj/Workspace/Projects/ralli-kit
swift test --filter WorkoutCoreTests
```

Expected: PASS 24건 (Task 1 이후 18건 + 신규 6건).

- [ ] **Step 8: tennis_counter 회귀 빌드**

추가 전용 변경이라 컴파일이 깨질 이유는 없지만, 공유 패키지를 건드렸으므로 실제로 확인한다.

```bash
cd /Users/yj/Workspace/Projects/tennis-counter
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`. 스킴명이 다르면 `xcodebuild -project TennisCounter.xcodeproj -list`로 확인한다. tennis-counter가 ralli-kit을 로컬 경로가 아닌 원격으로 참조한다면 이 단계는 건너뛰고, 그 사실을 PR 본문에 적는다.

- [ ] **Step 9: 커밋 + ralli-kit PR 생성**

```bash
cd /Users/yj/Workspace/Projects/ralli-kit
git add Sources/WorkoutCore Tests/WorkoutCoreTests
git commit -m "✨ WorkoutCore에 거리·걸음수 수집 추가"
git push -u origin feat/workout-distance-steps
gh pr create --title "✨ WorkoutCore: 거리·걸음수 수집 (golf-counter plan ③)" --body "$(cat <<'EOF'
## 요약
- `WorkoutConfiguration.additionalReadTypes`로 권한·수집 타입을 소비자가 주입
- `WorkoutSessionService`에 `currentDistanceMeters`·`currentSteps` published 추가, `HKLiveWorkoutDataSource.enableCollection`으로 명시 수집
- `WorkoutResult`에 `distanceMeters`·`steps` 추가 (기본값 0)

## 기존 소비자 영향
추가 전용 변경이다. `additionalReadTypes`를 지정하지 않으면 권한 요청 타입은 기존 4종 그대로이며, `typesToReadOmitsAdditionalTypesByDefault` 테스트가 이를 보증한다. TennisCounter 워치 타깃 BUILD SUCCEEDED 확인.

## 테스트
`swift test --filter WorkoutCoreTests` 24건 PASS
EOF
)"
```

---

### Task 3: 파 대비 스코어 포맷 공통화 (TDD)

`ComplicationState.relativeToParText`의 "E/+n/-n" 규칙을 카운터 화면도 그대로 써야 한다. 두 곳에 같은 로직을 두지 않도록 공통 포맷터로 추출한다.

**Files:**
- Create: `Shared/Models/ScoreFormat.swift`
- Modify: `Shared/Models/ComplicationState.swift`
- Test: `watchosTests/Shared/ScoreFormatTests.swift`

**Interfaces:**
- Produces: `ScoreFormat.relativeToPar(_ value: Int) -> String` — Task 8의 `CounterView`·`Scorecard`와 기존 `ComplicationState`가 의존

- [ ] **Step 1: 실패하는 테스트 작성** — `watchosTests/Shared/ScoreFormatTests.swift`

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct ScoreFormatTests {
    @Test func 이븐파는_E로_표시한다() {
        #expect(ScoreFormat.relativeToPar(0) == "E")
    }

    @Test func 오버파는_플러스부호를_붙인다() {
        #expect(ScoreFormat.relativeToPar(3) == "+3")
    }

    @Test func 언더파는_음수부호를_유지한다() {
        #expect(ScoreFormat.relativeToPar(-2) == "-2")
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/yj/Workspace/Projects/golf-counter
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/ScoreFormatTests
```

Expected: FAIL — `cannot find 'ScoreFormat' in scope`.

- [ ] **Step 3: 구현** — `Shared/Models/ScoreFormat.swift`

```swift
import Foundation

/// 골프 표기 관례에 맞춘 표시 문자열 포맷. 컴플리케이션과 워치 카운터가 같은 규칙을 쓴다.
enum ScoreFormat {
    /// 이븐파는 0이 아니라 E, 오버파는 명시적으로 + 부호를 붙인다.
    static func relativeToPar(_ value: Int) -> String {
        if value == 0 {
            return "E"
        }
        if value > 0 {
            return "+\(value)"
        }
        return "\(value)"
    }
}
```

- [ ] **Step 4: `ComplicationState`가 공통 포맷터를 쓰도록 수정** — `Shared/Models/ComplicationState.swift`의 `relativeToParText` 블록을 아래로 교체

```swift
    var relativeToParText: String {
        ScoreFormat.relativeToPar(relativeToPar)
    }
```

(바로 위의 `/// 골프 표기 관례: ...` 주석 줄도 함께 지운다 — 설명은 `ScoreFormat`으로 옮겨갔다.)

- [ ] **Step 5: 테스트 통과 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/ScoreFormatTests -only-testing:watchosTests/ComplicationStateTests
```

Expected: PASS 8건 (신규 3건 + 기존 `ComplicationStateTests` 5건). 기존 테스트가 그대로 통과하는 것이 리팩터링이 안전했다는 증거다.

- [ ] **Step 6: 커밋**

```bash
git add Shared/Models/ScoreFormat.swift Shared/Models/ComplicationState.swift watchosTests/Shared/ScoreFormatTests.swift
git commit -m "♻️ refactor: 파 대비 스코어 포맷을 ScoreFormat으로 공통화"
```

---

### Task 4: 스냅샷 발행 서비스 + 골프 워크아웃 설정 (TDD)

스냅샷 저장과 컴플리케이션 갱신을 한 지점에 묶는다. ViewModel이 `WidgetCenter`를 직접 부르지 않게 하는 것이 목적이다 (테스트 가능성 + ViewModel의 UI 프레임워크 무의존).

**Files:**
- Create: `Shared/Services/RoundSnapshotPublisher.swift`
- Create: `WatchApp/Features/Round/WorkoutConfiguration+Golf.swift`
- Test: `watchosTests/Shared/RoundSnapshotPublisherTests.swift`

**Interfaces:**
- Consumes: `RoundSnapshotStore.save(_:to:)`, `.load(from:)`, `.clear(from:)` (plan ①), `WorkoutConfiguration.additionalReadTypes` (Task 1)
- Produces:
  - `protocol RoundSnapshotPublishing { func publish(_ snapshot: RoundSnapshot); func clear(); func loadCurrent() -> RoundSnapshot? }` — Task 5~7의 `RoundViewModel`이 이 프로토콜을 주입받는다
  - `struct RoundSnapshotPublisher: RoundSnapshotPublishing`, `init(defaults: UserDefaults?)`
  - `WorkoutConfiguration.golf` — Task 9의 `RoundSessionView`가 의존

- [ ] **Step 1: 실패하는 테스트 작성** — `watchosTests/Shared/RoundSnapshotPublisherTests.swift`

App Group이 아닌 임시 suite를 주입해 테스트 간 격리를 지킨다.

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct RoundSnapshotPublisherTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func makeSnapshot() -> RoundSnapshot {
        RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: "테스트CC",
                      currentHoleIndex: 1,
                      holeScores: [4, 3],
                      holePars: [4, 3],
                      puttCounts: [2, 1])
    }

    @Test func publish한_스냅샷을_다시_읽을_수_있다() {
        let defaults = makeDefaults()
        let publisher = RoundSnapshotPublisher(defaults: defaults)

        publisher.publish(makeSnapshot())

        #expect(publisher.loadCurrent() == makeSnapshot())
    }

    @Test func clear하면_스냅샷이_사라진다() {
        let defaults = makeDefaults()
        let publisher = RoundSnapshotPublisher(defaults: defaults)
        publisher.publish(makeSnapshot())

        publisher.clear()

        #expect(publisher.loadCurrent() == nil)
    }

    @Test func 저장된적_없으면_nil이다() {
        let publisher = RoundSnapshotPublisher(defaults: makeDefaults())

        #expect(publisher.loadCurrent() == nil)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/RoundSnapshotPublisherTests
```

Expected: FAIL — `cannot find 'RoundSnapshotPublisher' in scope`.

- [ ] **Step 3: 구현** — `Shared/Services/RoundSnapshotPublisher.swift`

```swift
import Foundation
import WidgetKit

/// 스냅샷 저장/삭제와 컴플리케이션 타임라인 갱신을 한 동작으로 묶는다 (spec §7).
/// ViewModel은 이 프로토콜에만 의존해, 테스트에서 WidgetKit 부작용 없이 호출 여부를 검증한다.
protocol RoundSnapshotPublishing {
    func publish(_ snapshot: RoundSnapshot)
    func clear()
    func loadCurrent() -> RoundSnapshot?
}

struct RoundSnapshotPublisher: RoundSnapshotPublishing {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = RoundSnapshotStore.appGroupDefaults) {
        self.defaults = defaults
    }

    func publish(_ snapshot: RoundSnapshot) {
        RoundSnapshotStore.save(snapshot, to: defaults)
        reloadComplication()
    }

    func clear() {
        RoundSnapshotStore.clear(from: defaults)
        reloadComplication()
    }

    func loadCurrent() -> RoundSnapshot? {
        RoundSnapshotStore.load(from: defaults)
    }

    /// 컴플리케이션 타임라인 정책이 `.never`라, 이 호출이 갱신의 유일한 트리거다 (plan ②).
    private func reloadComplication() {
        #if os(watchOS)
            WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
```

- [ ] **Step 4: 골프 워크아웃 설정 작성** — `WatchApp/Features/Round/WorkoutConfiguration+Golf.swift`

```swift
import HealthKit
import WorkoutCore

extension WorkoutConfiguration {
    /// spec §8 — GPS를 쓰지 않아(.indoor) 배터리를 아끼고, 거리·걸음수는 가속도계 기반 값을 읽는다.
    static let golf = WorkoutConfiguration(activityType: .golf,
                                           locationType: .indoor,
                                           additionalReadTypes: [.distanceWalkingRunning, .stepCount])
}
```

- [ ] **Step 5: 테스트 통과 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/RoundSnapshotPublisherTests
```

Expected: PASS 3건. 컴파일 에러로 `.golf`를 찾을 수 없다면 ralli-kit 브랜치(Task 1·2)가 체크아웃되어 있는지 확인한다.

- [ ] **Step 6: 커밋**

```bash
git add Shared/Services/RoundSnapshotPublisher.swift "WatchApp/Features/Round/WorkoutConfiguration+Golf.swift" watchosTests/Shared/RoundSnapshotPublisherTests.swift
git commit -m "✨ feat: 스냅샷 발행 서비스와 골프 워크아웃 설정 추가"
```

---

### Task 5: `RoundViewModel` — 카운터 불변식 (TDD)

라운드 상태의 뼈대와 spec §3 카운터 규칙을 구현한다. 이 태스크에서는 홀이 1개(인덱스 0)인 상태만 다룬다 — 홀 이동은 Task 6, 스냅샷 발행은 Task 7이다.

**Files:**
- Create: `Shared/Models/StrokeInputMode.swift`
- Create: `WatchApp/Features/Round/RoundViewModel.swift`
- Create: `watchosTests/Support/RoundSnapshotPublisherSpy.swift`
- Test: `watchosTests/Round/RoundViewModelTests.swift`

**Interfaces:**
- Consumes: `RoundSnapshotPublishing` (Task 4), `RoundSnapshot` (plan ①)
- Produces:
  - `enum StrokeInputMode { case swing, putt }` — `Shared/Models/`에 둔다. Task 8의 `ModeToggle`이 이 타입을 바인딩으로 받는데, 컴포넌트가 상위 폴더의 ViewModel을 참조하면 CLAUDE.md의 import 규칙 위반이라 Shared로 내린다
  - `RoundViewModel.Phase` (`.parSelection` / `.counting`) — ViewModel 내부 상태 표현이라 중첩 유지 (참조처는 같은 폴더의 `RoundSessionView` 하나)
  - `init(startedAt:courseName:publisher:)`
  - `@Published private(set) var holeScores/holePars/puttCounts: [Int]`, `currentHoleIndex: Int`, `@Published var inputMode: StrokeInputMode`
  - `func incrementStroke()`, `func decrementStroke()`
  - 표시용 계산 프로퍼티 `currentScore`, `currentPutts`, `currentPar`, `currentHoleNumber`, `totalStrokes`, `relativeToPar`, `snapshot`
  - Task 6이 `selectPar(_:)`·`goToNextHole()`·`goToPreviousHole()`·`beginParEditing()`·`phase`를, Task 7이 `finish()`·`init(resuming:publisher:)`를 같은 파일에 덧붙인다

- [ ] **Step 1: 테스트 더블 작성** — `watchosTests/Support/RoundSnapshotPublisherSpy.swift`

Task 7에서 발행 호출을 검증할 때 쓴다. 이 태스크에서는 부작용 차단용으로만 쓴다.

```swift
import Foundation
@testable import GolfCounter_Watch_App

/// 스냅샷 발행 호출을 기록만 하는 테스트 더블. WidgetKit·App Group을 건드리지 않는다.
final class RoundSnapshotPublisherSpy: RoundSnapshotPublishing {
    private(set) var published: [RoundSnapshot] = []
    private(set) var clearCallCount = 0
    var stored: RoundSnapshot?

    func publish(_ snapshot: RoundSnapshot) {
        published.append(snapshot)
        stored = snapshot
    }

    func clear() {
        clearCallCount += 1
        stored = nil
    }

    func loadCurrent() -> RoundSnapshot? {
        stored
    }
}
```

- [ ] **Step 2: 실패하는 테스트 작성** — `watchosTests/Round/RoundViewModelTests.swift`

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelTests {
    private func makeViewModel() -> RoundViewModel {
        RoundViewModel(startedAt: Date(timeIntervalSince1970: 1000),
                       publisher: RoundSnapshotPublisherSpy())
    }

    @Test func 시작하면_첫홀의_값이_모두_0이다() {
        let viewModel = makeViewModel()

        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.inputMode == .swing)
    }

    @Test func 스윙모드_증가는_타수만_올린다() {
        let viewModel = makeViewModel()

        viewModel.incrementStroke()
        viewModel.incrementStroke()

        #expect(viewModel.currentScore == 2)
        #expect(viewModel.currentPutts == 0)
    }

    @Test func 퍼팅모드_증가는_타수와_퍼팅을_함께_올린다() {
        let viewModel = makeViewModel()
        viewModel.inputMode = .putt

        viewModel.incrementStroke()

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 1)
    }

    @Test func 스윙모드_감소는_타수를_내린다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke()
        viewModel.incrementStroke()

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 1)
    }

    @Test func 스윙모드_감소는_퍼팅수_아래로_내려가지_않는다() {
        let viewModel = makeViewModel()
        viewModel.inputMode = .putt
        viewModel.incrementStroke()
        viewModel.incrementStroke()
        viewModel.inputMode = .swing

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 2)
        #expect(viewModel.currentPutts == 2)
    }

    @Test func 스윙모드_감소는_0아래로_내려가지_않는다() {
        let viewModel = makeViewModel()

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 0)
    }

    @Test func 퍼팅모드_감소는_타수와_퍼팅을_함께_내린다() {
        let viewModel = makeViewModel()
        viewModel.inputMode = .putt
        viewModel.incrementStroke()
        viewModel.inputMode = .swing
        viewModel.incrementStroke()
        viewModel.inputMode = .putt

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 0)
    }

    @Test func 퍼팅이_0이면_퍼팅모드_감소는_아무것도_바꾸지_않는다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke()
        viewModel.inputMode = .putt

        viewModel.decrementStroke()

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 0)
    }

    @Test func 타수에_상한이_없다() {
        let viewModel = makeViewModel()

        for _ in 0 ..< 15 { viewModel.incrementStroke() }

        #expect(viewModel.currentScore == 15)
    }
}
```

- [ ] **Step 3: 실패 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/RoundViewModelTests
```

Expected: FAIL — `cannot find 'RoundViewModel' in scope`.

- [ ] **Step 4: 입력 모드 타입 작성** — `Shared/Models/StrokeInputMode.swift`

```swift
import Foundation

/// 카운터 입력 모드. 스윙은 타수만, 퍼팅은 타수와 퍼팅을 함께 센다 (spec §3).
enum StrokeInputMode: Equatable {
    case swing
    case putt
}
```

- [ ] **Step 5: 구현** — `WatchApp/Features/Round/RoundViewModel.swift`

```swift
import Combine
import Foundation

/// 라운드 진행 상태와 카운터 불변식(spec §3)을 담는다.
/// UI 프레임워크를 import하지 않으며, 스냅샷 발행은 주입된 publisher에 위임한다.
@MainActor
final class RoundViewModel: ObservableObject {
    enum Phase: Equatable {
        case parSelection
        case counting
    }

    @Published private(set) var holeScores: [Int]
    @Published private(set) var holePars: [Int]
    @Published private(set) var puttCounts: [Int]
    @Published private(set) var currentHoleIndex: Int
    @Published var inputMode: StrokeInputMode = .swing

    let startedAt: Date
    var courseName: String?

    private let publisher: RoundSnapshotPublishing

    init(startedAt: Date = Date(),
         courseName: String? = nil,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        self.startedAt = startedAt
        self.courseName = courseName
        self.publisher = publisher
        holeScores = [0]
        holePars = [0]
        puttCounts = [0]
        currentHoleIndex = 0
    }

    // MARK: - 표시값

    var currentHoleNumber: Int { currentHoleIndex + 1 }
    var currentScore: Int { holeScores[currentHoleIndex] }
    var currentPutts: Int { puttCounts[currentHoleIndex] }
    /// 0은 "아직 파가 설정되지 않음"을 뜻한다.
    var currentPar: Int { holePars[currentHoleIndex] }
    var totalStrokes: Int { snapshot.totalStrokes }
    var relativeToPar: Int { snapshot.relativeToPar }

    var snapshot: RoundSnapshot {
        RoundSnapshot(startedAt: startedAt,
                      courseName: courseName,
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: puttCounts)
    }

    // MARK: - 카운터

    func incrementStroke() {
        switch inputMode {
        case .swing:
            holeScores[currentHoleIndex] += 1
        case .putt:
            holeScores[currentHoleIndex] += 1
            puttCounts[currentHoleIndex] += 1
        }
    }

    func decrementStroke() {
        switch inputMode {
        case .swing:
            // 퍼팅은 타수에 포함되는 개념이라, 타수가 퍼팅 수 아래로 내려갈 수 없다.
            // puttCounts는 항상 0 이상이므로 하한 0도 이 식이 함께 보장한다.
            holeScores[currentHoleIndex] = max(holeScores[currentHoleIndex] - 1, puttCounts[currentHoleIndex])
        case .putt:
            guard puttCounts[currentHoleIndex] > 0 else { return }
            holeScores[currentHoleIndex] -= 1
            puttCounts[currentHoleIndex] -= 1
        }
    }
}
```

- [ ] **Step 6: 테스트 통과 확인**

Step 3과 같은 명령. Expected: PASS 9건.

- [ ] **Step 7: 커밋**

```bash
git add Shared/Models/StrokeInputMode.swift WatchApp/Features/Round/RoundViewModel.swift watchosTests/Round/RoundViewModelTests.swift watchosTests/Support/RoundSnapshotPublisherSpy.swift
git commit -m "✨ feat: RoundViewModel 카운터 불변식 구현"
```

---

### Task 6: `RoundViewModel` — 파 선택과 홀 이동 (TDD)

파 미설정 여부로 화면을 가르는 `phase`, 홀 이동 시 배열 확장과 모드 리셋을 구현한다.

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`
- Test: `watchosTests/Round/RoundViewModelTests.swift` (파일 말미에 새 struct 추가)

**Interfaces:**
- Consumes: Task 5의 `RoundViewModel` 전체
- Produces:
  - `var phase: Phase` — 파 미설정이거나 파 편집 중이면 `.parSelection`
  - `func selectPar(_ par: Int)`, `func beginParEditing()`
  - `func goToNextHole()`, `func goToPreviousHole()`
  - `var canGoToPreviousHole: Bool` — Task 8의 `HoleNavigation`이 의존

- [ ] **Step 1: 실패하는 테스트 작성** — `watchosTests/Round/RoundViewModelTests.swift` 파일 맨 아래에 새 struct로 추가

```swift
@MainActor
struct RoundViewModelHoleFlowTests {
    private func makeViewModel() -> RoundViewModel {
        RoundViewModel(startedAt: Date(timeIntervalSince1970: 1000),
                       publisher: RoundSnapshotPublisherSpy())
    }

    @Test func 파가_없으면_파선택_단계다() {
        let viewModel = makeViewModel()

        #expect(viewModel.phase == .parSelection)
    }

    @Test func 파를_고르면_카운팅_단계로_넘어간다() {
        let viewModel = makeViewModel()

        viewModel.selectPar(4)

        #expect(viewModel.currentPar == 4)
        #expect(viewModel.phase == .counting)
    }

    @Test func 파편집을_시작하면_파선택_단계로_되돌아간다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)

        viewModel.beginParEditing()

        #expect(viewModel.phase == .parSelection)
    }

    @Test func 파를_다시_고르면_편집이_끝난다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.beginParEditing()

        viewModel.selectPar(5)

        #expect(viewModel.currentPar == 5)
        #expect(viewModel.phase == .counting)
    }

    @Test func 다음홀로_가면_새_홀은_값이_0이고_파선택_단계다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.goToNextHole()

        #expect(viewModel.currentHoleNumber == 2)
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.phase == .parSelection)
    }

    @Test func 홀_이동은_입력모드를_스윙으로_되돌린다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.inputMode = .putt

        viewModel.goToNextHole()

        #expect(viewModel.inputMode == .swing)
    }

    @Test func 파가_이미_있는_홀로_돌아가면_바로_카운팅_단계다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()
        viewModel.goToNextHole()
        viewModel.selectPar(3)

        viewModel.goToPreviousHole()

        #expect(viewModel.currentHoleNumber == 1)
        #expect(viewModel.currentPar == 4)
        #expect(viewModel.currentScore == 1)
        #expect(viewModel.phase == .counting)
    }

    @Test func 첫홀에서는_이전홀로_갈_수_없다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)

        #expect(viewModel.canGoToPreviousHole == false)
        viewModel.goToPreviousHole()
        #expect(viewModel.currentHoleNumber == 1)
    }

    @Test func 이전홀로_이동_중이던_파편집은_취소된다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.beginParEditing()

        viewModel.goToPreviousHole()

        #expect(viewModel.phase == .counting)
    }

    @Test func 누적_타수와_오버파를_홀에_걸쳐_합산한다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        for _ in 0 ..< 5 { viewModel.incrementStroke() }
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        for _ in 0 ..< 3 { viewModel.incrementStroke() }

        #expect(viewModel.totalStrokes == 8)
        #expect(viewModel.relativeToPar == 1)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/RoundViewModelHoleFlowTests
```

Expected: FAIL — `value of type 'RoundViewModel' has no member 'phase'`.

- [ ] **Step 3: 편집 플래그 프로퍼티 추가** — `RoundViewModel.swift`의 `@Published var inputMode: StrokeInputMode = .swing` 바로 아래에 삽입

```swift
    /// 파가 이미 설정된 홀에서 [Par] 버튼으로 파 선택 화면을 다시 띄운 상태.
    @Published private(set) var isEditingPar = false
```

- [ ] **Step 4: `phase`와 `canGoToPreviousHole` 추가** — `var currentPar: Int { ... }` 바로 아래에 삽입

```swift
    /// 화면 분기 조건은 "홀 이동 방향"이 아니라 "이 홀에 파가 있는가" 하나다 (spec §4).
    var phase: Phase {
        if isEditingPar { return .parSelection }
        return currentPar == 0 ? .parSelection : .counting
    }

    var canGoToPreviousHole: Bool { currentHoleIndex > 0 }
```

- [ ] **Step 5: 파 선택·홀 이동 메서드 추가** — `decrementStroke()` 아래, 클래스 닫는 괄호 앞에 삽입

```swift
    // MARK: - 파 선택

    func selectPar(_ par: Int) {
        holePars[currentHoleIndex] = par
        isEditingPar = false
    }

    func beginParEditing() {
        isEditingPar = true
    }

    // MARK: - 홀 이동

    func goToNextHole() {
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
        resetHoleLocalState()
    }

    func goToPreviousHole() {
        guard canGoToPreviousHole else { return }
        currentHoleIndex -= 1
        resetHoleLocalState()
    }

    /// 홀 배열 세 개의 길이를 현재 홀까지 맞춘다. 세 배열은 항상 같은 길이를 유지한다.
    private func ensureCapacityForCurrentHole() {
        let needed = currentHoleIndex + 1
        while holeScores.count < needed { holeScores.append(0) }
        while holePars.count < needed { holePars.append(0) }
        while puttCounts.count < needed { puttCounts.append(0) }
    }

    /// 홀을 옮기면 입력 모드는 스윙으로 리셋되고(spec §3), 진행 중이던 파 편집은 취소된다.
    private func resetHoleLocalState() {
        inputMode = .swing
        isEditingPar = false
    }
```

- [ ] **Step 6: 테스트 통과 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/RoundViewModelTests -only-testing:watchosTests/RoundViewModelHoleFlowTests
```

Expected: PASS 19건 (Task 5의 9건 + 신규 10건).

- [ ] **Step 7: 커밋**

```bash
git add WatchApp/Features/Round/RoundViewModel.swift watchosTests/Round/RoundViewModelTests.swift
git commit -m "✨ feat: RoundViewModel 파 선택과 홀 이동 구현"
```

---

### Task 7: `RoundViewModel` — 스냅샷 발행과 복구 (TDD)

상태가 바뀔 때마다 스냅샷을 발행하고, 진행 중 스냅샷으로 라운드를 되살린다.

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`
- Test: `watchosTests/Round/RoundViewModelSnapshotTests.swift`

**Interfaces:**
- Consumes: Task 5·6의 `RoundViewModel`, `RoundSnapshotPublishing` (Task 4)
- Produces:
  - `init(resuming snapshot: RoundSnapshot, publisher:)` — Task 11의 `HomeView`가 의존
  - `func start()` — 라운드 진입 시 최초 스냅샷 발행. Task 9의 `RoundSessionView.onAppear`가 호출
  - `func finish()` — 스냅샷 제거. Task 9의 "라운드 종료"가 호출

- [ ] **Step 1: 실패하는 테스트 작성** — `watchosTests/Round/RoundViewModelSnapshotTests.swift`

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelSnapshotTests {
    private let startedAt = Date(timeIntervalSince1970: 1000)

    private func makeViewModel(spy: RoundSnapshotPublisherSpy) -> RoundViewModel {
        RoundViewModel(startedAt: startedAt, courseName: "테스트CC", publisher: spy)
    }

    @Test func start하면_최초_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)

        viewModel.start()

        #expect(spy.published.count == 1)
        #expect(spy.published.last?.startedAt == startedAt)
        #expect(spy.published.last?.courseName == "테스트CC")
    }

    @Test func 타수를_올리면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.selectPar(4)

        viewModel.incrementStroke()

        #expect(spy.published.last?.holeScores == [1])
    }

    @Test func 타수를_내리면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.decrementStroke()

        #expect(spy.published.last?.holeScores == [0])
    }

    @Test func 파를_고르면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)

        viewModel.selectPar(3)

        #expect(spy.published.last?.holePars == [3])
    }

    @Test func 홀을_옮기면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.selectPar(4)

        viewModel.goToNextHole()

        #expect(spy.published.last?.currentHoleIndex == 1)
        #expect(spy.published.last?.holeScores == [0, 0])
    }

    @Test func 이동할_수_없는_이전홀은_스냅샷을_발행하지_않는다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.start()
        let countAfterStart = spy.published.count

        viewModel.goToPreviousHole()

        #expect(spy.published.count == countAfterStart)
    }

    @Test func finish하면_스냅샷을_지운다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.start()

        viewModel.finish()

        #expect(spy.clearCallCount == 1)
        #expect(spy.loadCurrent() == nil)
    }

    @Test func 스냅샷으로_라운드를_복구한다() {
        let snapshot = RoundSnapshot(startedAt: startedAt,
                                     courseName: "복구CC",
                                     currentHoleIndex: 2,
                                     holeScores: [4, 3, 2],
                                     holePars: [4, 3, 5],
                                     puttCounts: [2, 1, 1])

        let viewModel = RoundViewModel(resuming: snapshot, publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.startedAt == startedAt)
        #expect(viewModel.courseName == "복구CC")
        #expect(viewModel.currentHoleNumber == 3)
        #expect(viewModel.currentScore == 2)
        #expect(viewModel.currentPar == 5)
        #expect(viewModel.currentPutts == 1)
        #expect(viewModel.totalStrokes == 9)
        #expect(viewModel.phase == .counting)
        #expect(viewModel.inputMode == .swing)
    }

    @Test func 복구한_라운드에서_이어서_카운트할_수_있다() {
        let snapshot = RoundSnapshot(startedAt: startedAt,
                                     courseName: nil,
                                     currentHoleIndex: 1,
                                     holeScores: [4, 3],
                                     holePars: [4, 3],
                                     puttCounts: [2, 1])
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = RoundViewModel(resuming: snapshot, publisher: spy)

        viewModel.incrementStroke()

        #expect(viewModel.currentScore == 4)
        #expect(spy.published.last?.holeScores == [4, 4])
    }

    /// 배열 길이가 어긋난 스냅샷(외부 저장소에서 온 값)이 인덱스 크래시를 내지 않아야 한다.
    @Test func 길이가_어긋난_스냅샷도_안전하게_복구한다() {
        let snapshot = RoundSnapshot(startedAt: startedAt,
                                     courseName: nil,
                                     currentHoleIndex: 3,
                                     holeScores: [4],
                                     holePars: [],
                                     puttCounts: [])

        let viewModel = RoundViewModel(resuming: snapshot, publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.currentHoleNumber == 4)
        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPar == 0)
        #expect(viewModel.currentPutts == 0)
        #expect(viewModel.phase == .parSelection)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/RoundViewModelSnapshotTests
```

Expected: FAIL — `value of type 'RoundViewModel' has no member 'start'`.

- [ ] **Step 3: 복구 이니셜라이저 추가** — `RoundViewModel.swift`의 기존 `init` 아래에 삽입

```swift
    /// App Group 스냅샷으로 라운드를 되살린다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 새로 시작하므로, 여기서는 스코어 상태만 복원한다.
    init(resuming snapshot: RoundSnapshot,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        startedAt = snapshot.startedAt
        courseName = snapshot.courseName
        self.publisher = publisher
        holeScores = snapshot.holeScores
        holePars = snapshot.holePars
        puttCounts = snapshot.puttCounts
        currentHoleIndex = max(snapshot.currentHoleIndex, 0)
        ensureCapacityForCurrentHole()
    }
```

- [ ] **Step 4: 발행 지점 연결** — 같은 파일

4-a. `// MARK: - 카운터` 위에 라이프사이클 메서드를 추가한다.

```swift
    // MARK: - 라이프사이클

    /// 라운드 화면 진입 시 1회. 컴플리케이션이 곧바로 "라운드 중"으로 바뀌게 한다.
    func start() {
        publishSnapshot()
    }

    /// 라운드 종료. 스냅샷을 지워 컴플리케이션을 평상시로 되돌린다.
    /// 완료 라운드의 저장·전송은 plan ④ 범위다.
    func finish() {
        publisher.clear()
    }

    private func publishSnapshot() {
        publisher.publish(snapshot)
    }
```

4-b. 상태를 바꾸는 메서드 끝에 `publishSnapshot()`을 추가한다. `incrementStroke()`·`selectPar(_:)`·`goToNextHole()`은 본문 마지막 줄로, `decrementStroke()`는 두 case 각각의 마지막에 넣는다 (조기 return 경로에서는 발행하지 않는다).

```swift
    func incrementStroke() {
        switch inputMode {
        case .swing:
            holeScores[currentHoleIndex] += 1
        case .putt:
            holeScores[currentHoleIndex] += 1
            puttCounts[currentHoleIndex] += 1
        }
        publishSnapshot()
    }

    func decrementStroke() {
        switch inputMode {
        case .swing:
            // 퍼팅은 타수에 포함되는 개념이라, 타수가 퍼팅 수 아래로 내려갈 수 없다.
            // puttCounts는 항상 0 이상이므로 하한 0도 이 식이 함께 보장한다.
            holeScores[currentHoleIndex] = max(holeScores[currentHoleIndex] - 1, puttCounts[currentHoleIndex])
        case .putt:
            guard puttCounts[currentHoleIndex] > 0 else { return }
            holeScores[currentHoleIndex] -= 1
            puttCounts[currentHoleIndex] -= 1
        }
        publishSnapshot()
    }

    func selectPar(_ par: Int) {
        holePars[currentHoleIndex] = par
        isEditingPar = false
        publishSnapshot()
    }

    func goToNextHole() {
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
        resetHoleLocalState()
        publishSnapshot()
    }

    func goToPreviousHole() {
        guard canGoToPreviousHole else { return }
        currentHoleIndex -= 1
        resetHoleLocalState()
        publishSnapshot()
    }
```

`beginParEditing()`은 표시 상태만 바꾸므로 발행하지 않는다.

- [ ] **Step 5: 테스트 통과 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/RoundViewModelTests -only-testing:watchosTests/RoundViewModelHoleFlowTests -only-testing:watchosTests/RoundViewModelSnapshotTests
```

Expected: PASS 30건 (9 + 10 + 11).

- [ ] **Step 6: 커밋**

```bash
git add WatchApp/Features/Round/RoundViewModel.swift watchosTests/Round/RoundViewModelSnapshotTests.swift
git commit -m "✨ feat: RoundViewModel 스냅샷 발행과 라운드 복구 구현"
```

---

### Task 8: 파 선택 화면과 카운터 화면

ViewModel이 다 갖춰졌으니 화면을 붙인다. 컴포넌트는 CLAUDE.md 계층 규칙에 따라 화면별 `Components/`에 둔다.

**Files:**
- Create: `WatchApp/Features/Round/ParSelection/ParSelectionView.swift`
- Create: `WatchApp/Features/Round/ParSelection/Components/ParOptionButton.swift`
- Create: `WatchApp/Features/Round/Counter/CounterView.swift`
- Create: `WatchApp/Features/Round/Counter/Components/StrokeButton.swift`
- Create: `WatchApp/Features/Round/Counter/Components/ModeToggle.swift`
- Create: `WatchApp/Features/Round/Counter/Components/HoleNavigation.swift`
- Create: `WatchApp/Features/Round/Counter/Components/Scorecard.swift`

**Interfaces:**
- Consumes: `RoundViewModel`(Task 5~7)의 `currentHoleNumber`, `currentPar`, `currentScore`, `currentPutts`, `relativeToPar`, `inputMode`, `canGoToPreviousHole`, `snapshot`, `incrementStroke()`, `decrementStroke()`, `selectPar(_:)`, `beginParEditing()`, `goToNextHole()`, `goToPreviousHole()`; `StrokeInputMode`(Task 5); `ScoreFormat.relativeToPar(_:)`(Task 3); `RoundSnapshot`(plan ①)
- Produces: `ParSelectionView(viewModel:)`, `CounterView(viewModel:)` — Task 9의 `RoundSessionView`가 `phase`로 분기해 띄운다

- [ ] **Step 1: 파 선택 버튼** — `WatchApp/Features/Round/ParSelection/Components/ParOptionButton.swift`

```swift
import SwiftUI

struct ParOptionButton: View {
    let par: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Par \(par)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.green.opacity(0.85) : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
    }
}
```

- [ ] **Step 2: 파 선택 화면** — `WatchApp/Features/Round/ParSelection/ParSelectionView.swift`

세로로 길게 배치해 원탭 즉시 선택한다 (spec §4 — Confirm 2단계 없음).

```swift
import SwiftUI

struct ParSelectionView: View {
    @ObservedObject var viewModel: RoundViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text("H\(viewModel.currentHoleNumber)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach([3, 4, 5], id: \.self) { par in
                ParOptionButton(par: par, isSelected: viewModel.currentPar == par) {
                    viewModel.selectPar(par)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    ParSelectionView(viewModel: RoundViewModel())
}
```

- [ ] **Step 3: 타수 버튼** — `WatchApp/Features/Round/Counter/Components/StrokeButton.swift`

```swift
import SwiftUI

struct StrokeButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 26, weight: .bold))
                .frame(width: 62, height: 62)
        }
        .buttonStyle(.plain)
        .background(tint.opacity(0.85), in: Circle())
        .foregroundStyle(.white)
    }
}
```

- [ ] **Step 4: 스윙/퍼팅 토글** — `WatchApp/Features/Round/Counter/Components/ModeToggle.swift`

watchOS에는 `.segmented` picker 스타일이 없어 캡슐 버튼 두 개로 직접 만든다.

```swift
import SwiftUI

struct ModeToggle: View {
    @Binding var mode: StrokeInputMode

    var body: some View {
        HStack(spacing: 4) {
            segment(title: "스윙", value: .swing)
            segment(title: "퍼팅", value: .putt)
        }
    }

    private func segment(title: String, value: StrokeInputMode) -> some View {
        Button {
            mode = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.plain)
        .background(mode == value ? Color.green.opacity(0.8) : Color.gray.opacity(0.25), in: Capsule())
        .foregroundStyle(.white)
    }
}
```

- [ ] **Step 5: 홀 이동** — `WatchApp/Features/Round/Counter/Components/HoleNavigation.swift`

```swift
import SwiftUI

struct HoleNavigation: View {
    let canGoToPrevious: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            navButton(title: "이전", systemName: "chevron.left", action: onPrevious)
                .disabled(!canGoToPrevious)
                .opacity(canGoToPrevious ? 1 : 0.35)
            navButton(title: "다음", systemName: "chevron.right", action: onNext)
        }
    }

    private func navButton(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.25), in: Capsule())
    }
}
```

- [ ] **Step 6: 스코어카드** — `WatchApp/Features/Round/Counter/Components/Scorecard.swift`

crown으로 아래로 스크롤하면 나타나는 전체 스코어카드다 (모달 아님 — `CounterView`의 `ScrollView` 안에 이어 붙는다).

```swift
import SwiftUI

struct Scorecard: View {
    let snapshot: RoundSnapshot

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows, id: \.holeNumber) { row in
                HStack(spacing: 4) {
                    Text("H\(row.holeNumber)")
                        .frame(width: 26, alignment: .leading)
                    Text(row.par > 0 ? "Par\(row.par)" : "—")
                        .frame(width: 38, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text("\(row.score)타(\(row.putts)p)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.par > 0 ? ScoreFormat.relativeToPar(row.score - row.par) : "")
                        .frame(width: 26, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }

            Divider()

            Text("합계 \(snapshot.totalStrokes)타 · \(totalPutts)퍼트 · \(ScoreFormat.relativeToPar(snapshot.relativeToPar))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var totalPutts: Int {
        snapshot.puttCounts.reduce(0, +)
    }

    /// 세 배열의 길이가 어긋난 값이 들어와도 인덱스를 벗어나지 않도록 가장 짧은 길이에 맞춘다.
    private var rows: [ScorecardRow] {
        let count = min(snapshot.holeScores.count, snapshot.holePars.count, snapshot.puttCounts.count)
        return (0 ..< count).map { index in
            ScorecardRow(holeNumber: index + 1,
                         par: snapshot.holePars[index],
                         score: snapshot.holeScores[index],
                         putts: snapshot.puttCounts[index])
        }
    }
}

private struct ScorecardRow {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int
}

#Preview {
    Scorecard(snapshot: RoundSnapshot(startedAt: Date(),
                                      courseName: "테스트CC",
                                      currentHoleIndex: 2,
                                      holeScores: [4, 3, 6],
                                      holePars: [4, 3, 5],
                                      puttCounts: [2, 1, 2]))
}
```

- [ ] **Step 7: 카운터 화면** — `WatchApp/Features/Round/Counter/CounterView.swift`

`+`/`−`에 서로 다른 햅틱을 준다 (spec §4 — 오조작 인지용).

```swift
import SwiftUI
import WatchKit

struct CounterView: View {
    @ObservedObject var viewModel: RoundViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                header
                currentHoleScore
                strokeButtons
                modeAndPar
                HoleNavigation(canGoToPrevious: viewModel.canGoToPreviousHole,
                               onPrevious: viewModel.goToPreviousHole,
                               onNext: viewModel.goToNextHole)

                Divider().padding(.top, 4)
                Scorecard(snapshot: viewModel.snapshot)
            }
            .padding(.horizontal, 4)
        }
    }

    private var header: some View {
        HStack {
            Text("H\(viewModel.currentHoleNumber) · Par \(viewModel.currentPar)")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(ScoreFormat.relativeToPar(viewModel.relativeToPar))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
        }
    }

    private var currentHoleScore: some View {
        Text("\(viewModel.currentScore)타 · \(viewModel.currentPutts)퍼트")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
    }

    private var strokeButtons: some View {
        HStack(spacing: 12) {
            StrokeButton(systemName: "plus", tint: .green) {
                viewModel.incrementStroke()
                WKInterfaceDevice.current().play(.click)
            }
            StrokeButton(systemName: "minus", tint: .orange) {
                viewModel.decrementStroke()
                WKInterfaceDevice.current().play(.directionDown)
            }
        }
    }

    private var modeAndPar: some View {
        HStack(spacing: 4) {
            ModeToggle(mode: $viewModel.inputMode)
            Button {
                viewModel.beginParEditing()
            } label: {
                Text("Par")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 44, minHeight: 28)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.25), in: Capsule())
        }
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CounterView(viewModel: viewModel)
}
```

- [ ] **Step 8: 워치 타깃 빌드**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`. 아직 어느 화면에도 연결되지 않았지만 컴파일은 통과해야 한다.

- [ ] **Step 9: 커밋**

```bash
git add WatchApp/Features/Round/ParSelection WatchApp/Features/Round/Counter
git commit -m "✨ feat: 파 선택 화면과 카운터 화면 구현"
```

---

### Task 9: 컨트롤·메트릭 페이지와 3페이지 세션 화면

`TabView`로 세 페이지를 묶고 워크아웃 세션 수명주기를 붙인다.

**Files:**
- Create: `WatchApp/Features/Round/Controls/ControlsView.swift`
- Create: `WatchApp/Features/Round/Metrics/MetricsView.swift`
- Create: `WatchApp/Features/Round/RoundSessionView.swift`

**Interfaces:**
- Consumes: `RoundViewModel`(`phase`, `start()`, `finish()`), `WorkoutConfiguration.golf`(Task 4), `WorkoutSessionService`(`isPaused`, `pauseWorkout()`, `resumeWorkout()`, `startWorkout()`, `stopWorkout()`, `requestAuthorization()`, `formattedElapsed()`, `currentHeartRate`, `currentCalories`, `currentDistanceMeters`)(Task 2), `ParSelectionView`·`CounterView`(Task 8)
- Produces: `RoundSessionView(resuming:)` — Task 10의 `HomeView`가 `navigationDestination`으로 띄운다

- [ ] **Step 1: 컨트롤 페이지** — `WatchApp/Features/Round/Controls/ControlsView.swift`

물 잠금(water lock)은 오터치 방지 수단이다 (spec §4). 해제는 crown 길게 돌리기 — 시스템이 처리한다.

```swift
import SwiftUI
import WatchKit
import WorkoutCore

struct ControlsView: View {
    @ObservedObject var healthKit: WorkoutSessionService
    let onEndRound: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button {
                if healthKit.isPaused {
                    healthKit.resumeWorkout()
                } else {
                    healthKit.pauseWorkout()
                }
            } label: {
                Label(healthKit.isPaused ? "재개" : "일시정지",
                      systemImage: healthKit.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .background(Color.yellow.opacity(0.8), in: Capsule())
            .foregroundStyle(.black)

            Button(action: onEndRound) {
                Label("라운드 종료", systemImage: "flag.checkered")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .background(Color.red.opacity(0.8), in: Capsule())
            .foregroundStyle(.white)

            Button {
                WKInterfaceDevice.current().enableWaterLock()
            } label: {
                Label("잠금", systemImage: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .background(Color.blue.opacity(0.7), in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
    }
}
```

- [ ] **Step 2: 메트릭 페이지** — `WatchApp/Features/Round/Metrics/MetricsView.swift`

```swift
import SwiftUI
import WorkoutCore

struct MetricsView: View {
    @ObservedObject var healthKit: WorkoutSessionService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(healthKit.formattedElapsed())
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(healthKit.isPaused ? Color.yellow.opacity(0.5) : .yellow)
                .contentTransition(.numericText())

            metricRow(value: heartRateText, unit: "bpm", color: .red)
            metricRow(value: String(format: "%.0f", healthKit.currentCalories), unit: "kcal", color: .orange)
            metricRow(value: distanceText, unit: "km", color: .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    private func metricRow(value: String, unit: String, color: Color) -> some View {
        HStack(alignment: .bottom, spacing: 5) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 3)
        }
    }

    private var heartRateText: String {
        healthKit.currentHeartRate > 0 ? String(format: "%.0f", healthKit.currentHeartRate) : "--"
    }

    private var distanceText: String {
        String(format: "%.2f", healthKit.currentDistanceMeters / 1000)
    }
}

#if DEBUG
    #Preview {
        let service = WorkoutSessionService(configuration: .golf)
        service.setLiveMetricsForTesting(heartRate: 98, calories: 320, elapsedSeconds: 5430, distanceMeters: 6240)
        return MetricsView(healthKit: service)
    }
#endif
```

- [ ] **Step 3: 3페이지 세션 화면** — `WatchApp/Features/Round/RoundSessionView.swift`

기본 페이지는 가운데(카운터)다. `selectedTab` 초기값 1이 그 역할을 한다.

```swift
import SwiftUI
import WorkoutCore

struct RoundSessionView: View {
    @StateObject private var viewModel: RoundViewModel
    @StateObject private var healthKit = WorkoutSessionService(configuration: .golf)
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1

    /// 진행 중 스냅샷이 있으면 그 라운드를 이어서, 없으면 새 라운드를 시작한다.
    init(resuming snapshot: RoundSnapshot? = nil) {
        if let snapshot {
            _viewModel = StateObject(wrappedValue: RoundViewModel(resuming: snapshot))
        } else {
            _viewModel = StateObject(wrappedValue: RoundViewModel())
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ControlsView(healthKit: healthKit, onEndRound: endRound)
                .tag(0)
            centerPage
                .tag(1)
            MetricsView(healthKit: healthKit)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear(perform: startRound)
    }

    @ViewBuilder
    private var centerPage: some View {
        switch viewModel.phase {
        case .parSelection:
            ParSelectionView(viewModel: viewModel)
        case .counting:
            CounterView(viewModel: viewModel)
        }
    }

    private func startRound() {
        viewModel.start()
        Task {
            await healthKit.requestAuthorization()
            healthKit.startWorkout()
        }
    }

    /// 워크아웃을 끝내고 스냅샷을 지운 뒤 홈으로 돌아간다.
    /// 종료 요약 화면과 iOS 전송은 plan ④에서 이 자리에 들어온다.
    private func endRound() {
        viewModel.finish()
        Task { _ = await healthKit.stopWorkout() }
        dismiss()
    }
}
```

- [ ] **Step 4: 워치 타깃 빌드**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/Round/Controls WatchApp/Features/Round/Metrics WatchApp/Features/Round/RoundSessionView.swift
git commit -m "✨ feat: 라운드 세션 3페이지 화면과 컨트롤·메트릭 구현"
```

---

### Task 10: 홈 화면과 앱 진입점

"라운드 시작" 버튼 하나와, 실행 시 진행 중 스냅샷이 있으면 라운드로 바로 복귀하는 분기를 만든다.

**Files:**
- Create: `WatchApp/Features/Home/HomeView.swift`
- Modify: `WatchApp/WatchApp.swift`

**Interfaces:**
- Consumes: `RoundSessionView(resuming:)`(Task 9), `RoundSnapshotPublisher.loadCurrent()`(Task 4)
- Produces: `HomeView` — `WatchApp.swift`의 루트 뷰

- [ ] **Step 1: 홈 화면** — `WatchApp/Features/Home/HomeView.swift`

9/18홀 선택 UI는 없다 — 종료 시점까지 기록된 홀 수가 그 라운드의 길이다 (spec §3). 최근 라운드 요약은 워치에 완료 기록이 없어 표시하지 않는다 (이 문서 상단 "설계 결정" 3번).

```swift
import SwiftUI

struct HomeView: View {
    @State private var isRoundActive = false
    @State private var resumingSnapshot: RoundSnapshot?

    private let publisher = RoundSnapshotPublisher()

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Spacer()

                Text("GolfCounter")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.green)

                Button {
                    resumingSnapshot = nil
                    isRoundActive = true
                } label: {
                    Text("라운드 시작")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
                .background(Color.green.opacity(0.85), in: Capsule())
                .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 8)
            .navigationDestination(isPresented: $isRoundActive) {
                RoundSessionView(resuming: resumingSnapshot)
            }
        }
        .onAppear(perform: resumeIfNeeded)
    }

    /// 크래시·강제종료 후 실행되면 진행 중 스냅샷으로 라운드를 이어간다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 RoundSessionView가 새로 시작한다.
    private func resumeIfNeeded() {
        guard !isRoundActive, let snapshot = publisher.loadCurrent() else { return }
        resumingSnapshot = snapshot
        isRoundActive = true
    }
}

#Preview {
    HomeView()
}
```

- [ ] **Step 2: 앱 진입점 교체** — `WatchApp/WatchApp.swift` 전체를 아래로 교체

```swift
import SwiftUI

@main
struct GolfCounterWatchApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

- [ ] **Step 3: 워치 타깃 빌드**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: 커밋**

```bash
git add WatchApp/Features/Home/HomeView.swift WatchApp/WatchApp.swift
git commit -m "✨ feat: 홈 화면과 라운드 복구 진입 구현"
```

---

### Task 11: 전체 검증 + 육안 확인 + PR

**Files:** 없음 (검증만)

- [ ] **Step 1: 포맷·린트**

```bash
cd /Users/yj/Workspace/Projects/golf-counter
make fix && make lint && make format
```

Expected: 위반 0. `make fix`로 변경된 파일이 생기면 `git add -A && git commit -m "🎨 style: make fix 결과 반영"`로 별도 커밋한다.

- [ ] **Step 2: 세 스킴 전체 빌드**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -3
```

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -3
```

Expected: 3개 모두 `BUILD SUCCEEDED`.

- [ ] **Step 3: 전체 테스트**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -5
```

```bash
cd /Users/yj/Workspace/Projects/ralli-kit && swift test 2>&1 | tail -3
```

Expected:
- iosTests 2건 PASS
- watchosTests 45건 PASS — 기존 `RoundSnapshotTests` 4 + `ComplicationStateTests` 5, 신규 `ScoreFormatTests` 3 + `RoundSnapshotPublisherTests` 3 + `RoundViewModelTests` 9 + `RoundViewModelHoleFlowTests` 10 + `RoundViewModelSnapshotTests` 11
- ralli-kit 전체 PASS (WorkoutCore 24건 포함)

- [ ] **Step 4: 워치 시뮬레이터 육안 확인 (수동)**

Xcode에서 `GolfCounter Watch App` 스킴을 워치 시뮬레이터로 Run하고 확인한다. 시뮬레이터는 심박·칼로리·거리 값이 0에 머무르므로, 메트릭 페이지는 경과 시간이 흐르는지만 본다 (실제 값은 기기 확인 대상).

1. 홈 → "라운드 시작" 탭 → 파 선택 화면(Par 3/4/5 세로 배치)
2. Par 4 탭 → 카운터 화면 진입, 헤더가 `H1 · Par 4`
3. `+` 5회 → `5타 · 0퍼트`, 헤더 우측 `+1`
4. 토글을 "퍼팅"으로 → `+` 2회 → `7타 · 2퍼트`
5. 토글을 "스윙"으로 → `−`를 5회 이상 → **`2타 · 2퍼트`에서 멈춘다** (타수 ≥ 퍼팅 불변식)
6. crown으로 아래 스크롤 → 스코어카드에 `H1 Par4 2타(2p) -2` + 합계 행
7. "다음" 탭 → 파 선택 화면 재등장, 토글이 "스윙"으로 리셋
8. "이전" 탭 → 파가 이미 있는 H1이므로 **파 선택을 건너뛰고 바로 카운터**
9. `[Par]` 탭 → 파 선택 화면 재등장, 현재 값(Par 4)이 하이라이트
10. 왼쪽 페이지(컨트롤) → 일시정지/재개 토글 동작, "잠금" 탭 시 물 잠금 활성화
11. **컴플리케이션 연동**: 워치 시뮬레이터 시계 화면에 컴플리케이션을 올려둔 상태에서 라운드를 시작하면 배경이 초록으로 바뀌고 rectangular에 `H1 · E`가 뜬다. "라운드 종료" 후에는 평상시(파랑 + "라운드 시작")로 돌아온다 — plan ②에서 검증하지 못했던 전환이 여기서 처음 확인된다
12. **복구 확인**: 라운드 중 시뮬레이터에서 앱을 강제 종료(Stop) 후 다시 Run → 홈을 거치지 않고 진행 중이던 홀·타수 그대로 카운터 화면으로 복귀

- [ ] **Step 5: ralli-kit PR 머지**

golf-counter PR보다 먼저 머지한다.

```bash
cd /Users/yj/Workspace/Projects/ralli-kit
gh pr merge --merge --delete-branch
git checkout main && git pull
```

- [ ] **Step 6: golf-counter PR 생성**

```bash
cd /Users/yj/Workspace/Projects/golf-counter
git push -u origin feat/watch-counter-core
gh pr create --title "✨ feat: 워치 카운터 코어 구현 (plan ③)" --body "$(cat <<'EOF'
## 요약
- `RoundViewModel` — 카운터 불변식(타수 ≥ 퍼팅, 하한 0, 상한 없음), 파 선택 조건, 홀 이동, 스냅샷 발행·복구. UI 프레임워크 무의존 순수 로직
- `RoundSnapshotPublisher` — 스냅샷 저장/삭제 + `WidgetCenter.reloadAllTimelines()`를 한 동작으로 묶어 ViewModel에 프로토콜로 주입
- 워치 화면 — 홈 / 파 선택 / 카운터(+스코어카드) / 컨트롤 / 메트릭, 3페이지 TabView
- `ScoreFormat` — 파 대비 스코어 표기("E"/"+n"/"-n")를 컴플리케이션과 공유
- ralli-kit `WorkoutCore`에 거리·걸음수 수집 추가 (별도 PR, 선행 머지)

## 테스트
- watchosTests 45건, iosTests 2건 PASS
- 세 스킴 BUILD SUCCEEDED, `make lint`/`make format` 위반 0
- 시뮬레이터 육안 확인: 카운터 불변식, 파 선택 분기, 홀 이동 모드 리셋, 컴플리케이션 전환, 강제종료 복구

## spec 대비 결정 사항
- 크래시 복구는 스냅샷만 — `HKWorkoutSession`은 새로 시작한다 (스코어는 온전히 복구됨)
- 홈의 "최근 라운드 요약"(spec §4)은 미구현 — 워치에 완료 기록을 두지 않는다는 spec §14와 충돌해 데이터원이 없다
- "라운드 종료"는 워크아웃 종료 + 스냅샷 삭제까지만 — 종료 요약과 전송은 plan ④

## 범위 밖
- 라운드 결과 저장·전송 (plan ④), 문자열 로컬라이즈 (plan ⑦), MapKit 골프장 감지 (plan ⑧ — `courseName`은 현재 항상 nil)

참조: `docs/superpowers/plans/2026-08-04-watch-counter-core.md`
EOF
)"
```

---

## 완료 기준

- [x] ralli-kit `swift test` 전체 PASS (WorkoutCore 26건 — `typesToShare` 수정으로 24건에서 증가), tennis_counter 워치 타깃 BUILD SUCCEEDED
- [x] `watchosTests` 49건 PASS (플랜의 "45건"은 집계 오류, 위 "플랜 문서 자체의 오류" 참조), `iosTests` 3건 PASS (플랜의 "2건"도 같은 이유)
- [x] 세 스킴(`GolfCounter`, `GolfCounter Watch App`, `ComplicationAppExtension`) BUILD SUCCEEDED
- [x] `make lint`·`make format` 위반 0
- [ ] 시뮬레이터에서 Task 11 Step 4의 12개 항목 전부 확인 — 사용자가 Xcode에서 직접 진행 예정
- [x] pbxproj 변경 없음 (synchronized group 덕분에 파일 추가만으로 반영)
- [x] ralli-kit PR 머지 후 golf-counter PR 생성 — [ralli-kit#2](https://github.com/qlrogo91lp/ralli-kit/pull/2) 머지 완료, [golf_counter#7](https://github.com/qlrogo91lp/golf_counter/pull/7) 생성·리뷰 대기
