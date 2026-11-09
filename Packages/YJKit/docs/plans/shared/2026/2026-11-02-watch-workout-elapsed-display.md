# 워치 운동 경과시간 표시 개선 Implementation Plan

> **For agentic workers:** 승인 후 `superpowers:executing-plans`로 단계별 실행한다. 이 문서는 분석·구현 플랜이며 구현 승인이 아니다. 추가 하위 세션을 만들지 않는다.

**상태:** 사용자 검토 대기 · 2026-11-02 · 코드/브랜치/커밋/PR 미착수

**Goal:** 세 앱 워치의 운동 경과시간이 timer·health 이벤트 도착 간격에 끌려 머물다가 급히 바뀌는 표시 경로를 개선한다.

**Architecture:** 표시용 기준시각과 화면 갱신을 분리한다. WorkoutCore의 순수 기준시각 값과 WorkoutUI의 시스템 timer text를 사용하고, HaruchiFit은 기존 SegmentTracker의 시간 원본을 유지한다. 기존 저장·전송용 시간의 의미 통합은 별도 승인 대상으로 남긴다.

**Tech Stack:** Swift / SwiftUI / Combine / HealthKit / Swift Testing. 패키지 최소 iOS 17, watchOS 10.

**Spec:** 이번 요청과 본 문서의 범위·표시 계약이 검토 대상 설계다. [기존 탐색](../../../ideas/elapsed-seconds-tick-counter.md)은 배경 자료이며 현재 코드보다 우선하지 않는다. [HaruchiFit 정지 제외 설계](../../../../../../Apps/HaruchiFit/docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md)의 구간·저장 계약은 유지한다.

## 제약과 검토 초점

- 루트와 세 앱 `CLAUDE.md` 적용. 컴포넌트에는 ViewModel 대신 값 전달. ViewModel에 SwiftUI import 금지. 코어는 종목 도메인을 모른다.
- 이번 세션에서 쓰는 파일은 본 문서와 루트 TODO의 관련 항목뿐이다. 기존 사용자 변경은 보존한다.
- 기존 public initializer는 유지하고 새 optional 인자는 기본값을 둔다. 프로젝트 파일·타깃·의존성·폴더 체계는 변경하지 않는다.
- 이번 승인 대상은 **워치 표시**다. `elapsedSeconds` 카운터를 통째로 교체하면 저장·폰 앵커까지 바뀌므로 이번 플랜에서는 교체하지 않는다.
- 주의할 다섯 조건: 신호가 없는 동안 시간 진행, 분수초 pause/resume 반복, AOD/화면 꺼짐 후 복귀, 종료 처리 지연·연속 세션, 워치 표시와 기존 폰·저장값 차이. 아래 테스트와 실기기 절차에서 각각 확인한다.

## 1. 현재 코드에서 확인한 것

사용자가 실기기에서 확인한 사실은 **숫자가 균일하게 바뀌지 않고 머물다가 빠르게 바뀐다**는 현상이다. 어느 앱·watchOS·기기·AOD 조건에서 얼마나 발생하는지는 추가 계측 전 미확정이다. 아래는 코드 증거이며 그 현상의 실기기 원인 확정이 아니다.

| 경로 | 현재 계산·갱신 | pause/resume·종료 |
|---|---|---|
| `Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift` | `startTimer()`와 `resumeWorkout()`의 1초 `Timer.scheduledTimer` → main queue → `elapsedSeconds += 1`. 틱 수이며 벽시계 재계산이 아니다 | pause는 Timer 해제, resume은 새 Timer. 메서드가 `isPaused`를 발행하고 HK delegate도 발행한다. delegate의 이벤트 `date`는 현재 버린다. 종료 `WorkoutResult.durationSeconds`는 `Int(endDate - startDate)`로 **정지 포함** |
| Golf `WatchApp/Features/Round/SessionMetrics/SessionMetricsView.swift` | 서비스를 직접 관찰, 틱 값을 `WorkoutMetrics`로 전달 | `RoundSessionView`에서 서비스 pause/resume/stop 호출. 라운드 복구는 점수 스냅샷 복구이며 기존 HK 세션·경과시간 복구가 아니다 |
| Ralli `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `CombineLatest4(elapsed, active kcal, basal kcal, HR)` → `currentMetrics`; `snapshot(of:)`도 틱 값을 읽음 | startMatch/endMatch의 `elapsedAtStart/End` 역시 틱. pause 명령은 폰에서 워치로 전달, 워치에서 제어 |
| HaruchiFit `WatchApp/Features/Workout/WorkoutViewModel.swift`, `SegmentTracker.swift` | `startedAt`, `pausedAccumulated`, `pausedSince`와 주입 `now()`로 정지 제외 시각 차이 계산. 다만 위와 같은 CombineLatest4 도착 시에만 `metrics`를 다시 발행 | 서비스 `isPaused` 구독에서 tracker pause/resume. 구간 종료 전 시간을 붙들어 구간·저장 총시간 계산 |
| 공용 `Sources/WorkoutUI/Watch/WorkoutMetricsView.swift` | `Text(metrics.formattedElapsed)`라는 고정 문자열. `.contentTransition(.numericText())` 적용 | 서비스/VM에서 새 문자열을 줘야 변경. 시스템 timer text나 자체 timeline은 없음 |

HealthKit 매초 조회 가설은 맞지 않는다. service의 Timer는 숫자 증가만 수행한다. 생체 데이터는 `HKLiveWorkoutBuilderDelegate.didCollectDataOf`에서 `statistics(for:)`로 읽으며, 매초 과거 운동을 질의해서 경과시간을 얻는 구조가 아니다. `averageHeartRate(from:to:)`의 별도 조회는 경기 종료용 경로다.

가능한 가설은 (1) run loop와 main queue의 틱 지연, (2) HaruchiFit의 시각 차이 계산이 비균일한 이벤트에 의해 재발행되는 점, (3) SwiftUI 표시·숫자 전환 및 저휘도 갱신 제한이다. Timer가 밀렸다고 누락 틱을 모두 빠르게 재생하는 것은 아니다. HaruchiFit은 다음 이벤트에서 실제 시각 차이를 읽어 값을 건너뛸 수 있다. 현재 증거만으로 어느 가설이 관찰 현상의 주원인인지 단정하지 않는다.

### 저장·iPhone·컴플리케이션 영향

- **Ralli 폰 진행 화면:** `Shared/Services/MatchConnectivity.swift` → `WorkoutMetricsMessage`의 워치 스냅샷/`sentAt` → iOS `WorkoutSessionViewModel.applyIncomingMetrics/recomputeElapsed` → `WorkoutAnchor.interpolatedElapsed`. 폰 Timer는 매초 앵커를 재계산한다. 워치의 심박 발행은 기본 5초 throttle, pause 변경 때도 앵커 송신. 늦거나 덜 센 워치 앵커를 받으면 폰 보간도 보정될 수 있다. 이번에 메시지 형식·빈도·앵커 값·폰 UI는 바꾸지 않는다.
- **Ralli 저장:** 경기 메시지의 `durationSeconds = max(0, elapsedAtEnd - elapsedAtStart)`와 `workoutElapsedSeconds`는 틱 기반이다. 반면 현행 `WorkoutEndMessage` → `WorkoutSessionRecorder` → `WorkoutSessionRecord.elapsedSeconds`는 service의 종료 결과(정지 포함 시각 차이)를 저장한다. `MatchSessionGroup.elapsedSeconds`는 레코드 우선, 레코드가 없는 구버전만 경기 누적 최댓값으로 폴백한다. 따라서 “Ralli의 모든 저장 시간은 틱”이라는 기존 서술은 현재 코드와 다르다. iPhone이 경기 driver인 경로는 폰 앵커 보간값으로 경기 경계를 잡는 점도 별도 고려 대상이다.
- **Golf:** `RoundMetrics`에는 duration 필드가 없다. HK 결과에서 칼로리·심박·거리·걸음 등을 매핑하고, 라운드 시각은 앱이 소유한다. 실시간 iPhone 운동 타이머/앵커 경로는 없다. 표시 개선을 GolfRound 저장 시간 수정으로 확대하지 않는다.
- **HaruchiFit:** `SegmentTracker`가 구간·총시간·스냅샷의 원본. `WorkoutResult.durationSeconds`를 총시간으로 쓰지 않는다. 폰은 `WorkoutRecordMessage`로 받은 결과를 저장하며 이번 대상인 실시간 폰 앵커 경로는 없다.
- **컴플리케이션:** Golf와 Ralli는 점수/라운드 상태 중심이며 경과시간 timer text 경로가 없다. HaruchiFit `Common/WorkoutSnapshot.swift`는 tracker 경과초와 `capturedAt`를 함께 저장하고 `ComplicationState.timerReference = capturedAt - elapsedSeconds`로 계산한다. `HaruchiComplicationExtension.swift`는 실행 중 `.timer`, 정지 중 고정 텍스트를 이미 쓴다. “하루치 컴플리케이션은 service 틱을 일부러 쓴다”는 탐색 문서의 주의 문구는 현재 구현과 다르다. 이번에 snapshot 스키마·위젯 코드를 수정하지 않고 회귀 확인한다.

## 2. Apple 공식 자료 비교와 권장안

2026-11-02 공식 문서 확인. 아래 API 설명에서 제품 동작으로 연결하는 부분은 설계상 추론이며 실기기 측정을 대체하지 않는다.

| 대안 | 근거·장점 | 한계·이번 판단 |
|---|---|---|
| 현재 Timer + 고정 문자열 | [Apple Timer](https://developer.apple.com/documentation/foundation/timer), [Run Loop의 Timer 동작](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html): Timer는 실시간 기제가 아니며 지연·누락 가능 | interval을 줄이거나 `.common` mode만 적용해도 시간 원본/화면 발행 결합을 풀지 못한다. 주 해결책으로 선택하지 않음 |
| `Text(referenceDate, style: .timer)` | [DateStyle.timer](https://developer.apple.com/documentation/swiftui/text/datestyle/timer): 기준 날짜로부터 카운트. [Always On 설계](https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state): 해당 DateStyle의 Text는 AOD에서도 시스템이 갱신 | **1차 권장.** 실행 중 시스템 갱신, 정지 중 고정 문자열. 포맷·로케일·폭은 현재 `%02d:%02d`와 완전히 같다는 보장이 없으므로 검증 게이트 필요 |
| `Text(timerInterval:pauseTime:countsDown:showsHours:)` | [공식 initializer](https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:)): 구간 내 count up/down과 pauseTime 지원. 공식 Markdown availability는 watchOS 9+/iOS 16+로 현재 최소 버전에서 가능 | 유한 종료 구간이 필요하고 resume 때 기준 재설정도 필요. 무한 운동에 임의 상한을 도입할 이유가 적어 우선 사용하지 않음. `.timer`의 AOD 설명을 이 initializer의 동일 동작 보장으로 확대하지 않음 |
| `TimelineView(.periodic(from:by:))` + 기준시각 계산 | [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview): context.date로 계산, cadence 제공. [watchOS timeline](https://developer.apple.com/documentation/watchos-apps/updating-watchos-apps-with-timelines): 미래 Date에 대한 표시를 계산할 수 있어야 함 | 정확한 기존 포맷 유지·cadence별 표현에 적합. 시스템은 요청보다 느린 cadence를 쓸 수 있어 1초 보장 수단이 아니다. **포맷 요구로 시스템 Text를 쓸 수 없을 때의 대안** |

권장 조합은 **기준시각 모델 + `.timer`**다. “기준시각 모델”은 시스템 Text/TimelineView와 경쟁하는 렌더러가 아니라 둘 모두에 필요한 시간 입력이다. 실행 중 기준점은 시작·pause/resume 등 경계에서만 바뀌어야 한다. 매 tick/심박마다 `Date() - Int(elapsed)`로 다시 만들면 분수초 위상이 흔들리므로 금지한다. View의 body/onAppear가 시작 기준을 새로 잡아서도 안 된다.

AOD는 OS가 빈도를 제한한다. 공식 timeline 문서는 활성 workout 같은 background runtime의 AOD 갱신을 대체로 초 단위라고 설명하지만 정확한 1초 간격을 보장하지 않는다. 손목을 내렸을 때 모든 숫자가 같은 속도로 바뀌는 것보다 **복귀 시 현재 값으로 바로 표시되고 누적 지연이 남지 않는 것**을 합격조건으로 삼는다. 전면에서도 하드 실시간 보장은 하지 않는다.

## 3. 제안하는 표시 계약과 인터페이스

이 절은 승인 대상 권장 설계다. 범위가 작은 표시 개선을 위해 기존 저장 경로를 계속 보존한다는 비용을 명시적으로 선택한다.

### WorkoutCore 순수 값

신규 `WorkoutElapsedDisplay: Equatable, Sendable` (Foundation만 import):

- `public init(referenceDate: Date, pausedAt: Date? = nil)`
- `public let referenceDate: Date` — 정지 누적이 반영된 가상 시작시각
- `public let pausedAt: Date?` — nil이면 실행 중, 값이 있으면 그 시각에서 고정
- `public func elapsed(at date: Date) -> TimeInterval` — `max(0, (pausedAt ?? date) - referenceDate)`
- `public func pausing(at date: Date) -> Self` — 중복 pause는 처음 경계를 보존
- `public func resuming(at date: Date) -> Self` — pause 구간만큼 referenceDate 이동, 중복 resume 무효

정수화는 고정 표시 시점에만 한다. 모델 내부에 Timer·HealthKit·문자열·저장 정책은 넣지 않는다.

### 서비스 → Golf/Ralli

`WorkoutSessionService`에 `@Published public private(set) var elapsedDisplay: WorkoutElapsedDisplay?` 추가. 시작 성공 경로의 기존 `now`로 생성하고, 생성 실패/미시작이면 nil. HK delegate가 전달하는 상태 변경 `date`로 pause/resume을 main queue에서 순서대로 반영한다. 시작 직후 `.running` 이벤트는 이미 실행 중인 기준점을 다시 잡지 않는다. stop 요청의 기존 `endDate`로 동기적으로 고정해 HK 저장 완료 대기 중 늘어나지 않게 한다.

상태 적용은 테스트 가능한 `internal func applyElapsedDisplayState(_ state: HKWorkoutSessionState, at date: Date)`로 분리한다. 종료 요청 뒤 도착한 `.running`/`.paused` 이벤트가 고정을 해제하지 않도록 기존 세션 식별 확인과 종료 중 guard를 둔다. 이전 세션 delegate가 새 운동의 모델을 덮어쓰지 않게 한다. 이 guard는 표시 모델에 한정하고 기존 HK 종료 순서/stop waiter는 보존한다.

기존 `isPaused` 발행 시점과 새 표시 경계가 잠시 다를 수 있다. 새 모델이 있을 때 **숫자 정지 여부와 색은 `pausedAt != nil`**로 일관되게 결정한다. 컨트롤 상태·폰 명령 ack 동작의 재설계는 하지 않는다. HK 이벤트가 안 오거나 늦는 경우의 실제 UX는 실기기 게이트에서 확인한다.

기존 `elapsedSeconds`, `formattedElapsed()`, `WorkoutResult`, `WorkoutMetrics`, `WorkoutAnchor`, 메시지는 유지한다. 표시 모델을 저장값이나 기존 앵커에 몰래 연결하지 않는다.

### HaruchiFit → WorkoutUI

`SegmentTracker`에 `var elapsedDisplay: WorkoutElapsedDisplay` 계산 속성 추가. `referenceDate = startedAt + pausedAccumulated`, `pausedAt = pausedSince`로 **기존 원본을 투영**한다. service의 새 시계를 쓰거나 tracker를 공용 시계로 대체하지 않는다. 기존 주입 `now()` 및 정수 구간 계산 유지.

`WorkoutViewModel`에는 `@Published private(set) var elapsedDisplay: WorkoutElapsedDisplay?`를 두고 start/reset, `handlePauseChange`, end 경계에서만 tracker의 값을 발행한다. end에서는 기존 총시간을 붙든 경계의 값으로 표시도 고정한다. start/end의 표시 경계 적용은 `internal func resetElapsedDisplay()`와 `internal func freezeElapsedDisplay()`로 분리해 기존 tracker의 주입 시각으로 검증한다. `SegmentTracker`에는 `func frozenElapsedDisplay() -> WorkoutElapsedDisplay`를 추가해 `elapsedDisplay.pausing(at: now())`를 반환하며, 이 호출이 구간 원본의 pause/저장 상태를 변경하지 않게 한다. 심박/Timer의 CombineLatest4는 기타 메트릭용으로 남되 경과시간 렌더링의 필수 신호가 아니게 한다.

### 공용 UI

기존 initializer에 기본값 인자 추가:

`WorkoutMetricsView.init(metrics: WorkoutMetrics, isPaused: Bool, statusText: String? = nil, elapsedDisplay: WorkoutElapsedDisplay? = nil)`

새 순수 컴포넌트 `WorkoutElapsedText.init(display: WorkoutElapsedDisplay)`를 둔다. 실행 중은 `.timer`, 정지 중은 `WorkoutMetrics.formatSeconds(Int(display.elapsed(at: pausedAt)))`로 렌더링한다. `pausedAt` unwrap은 컴포넌트 내부에서 한다. nil 입력의 기존 호출/프리뷰는 지금의 고정 문자열 fallback을 유지한다.

elapsed 행의 `.contentTransition(.numericText())`를 제거하고 `.monospacedDigit()`와 기존 크기·색을 적용한다. 공통 화면 전체에 Timer/TimelineView를 씌우지 않는다. 시스템 Text의 0초·1시간 전후 레이아웃을 검증하며, 포맷 불일치가 제품 요구상 허용되지 않으면 아래 승인 게이트에 따라 TimelineView 대안으로 플랜을 갱신한다.

### 범위 분리와 알려진 제한

| 이번 표시 트랙 | 별도 승인할 저장 의미 트랙 |
|---|---|
| 실행 중 정지 제외 기준시각, 고정 pause, 시스템 표시 갱신, 세 앱 배선 | YJKit 기존 카운터 대체와 폰 앵커 원본 통합 |
| HaruchiFit tracker·위젯·저장 의미 보존 | WorkoutResult/HKWorkout.duration의 의미 검증과 총시간 정책 통일 |
| 기존 저장·메시지 회귀 검증 | Ralli 경기/세션/구버전 폴백 정리, 과거 기록 보정·마이그레이션 |

**알려진 제한:** 이번 변경 뒤 Golf/Ralli 워치 표시가 실제 시각을 따라가도 기존 폰 앵커·경기 저장 틱 값은 뒤처질 수 있다. Ralli 종료 요약은 정지 포함 시간이라 표시와 차이가 날 수 있다. 이 불일치를 해결했다고 주장하지 않는다. 제품상 이 한계를 수용할지는 구현 승인 전 확인할 결정이다. 수용하지 않으면 저장/앵커 트랙을 별도 설계한 뒤 순서를 정한다. 사용자 동의 없이 해당 트랙을 이번 구현에 끼워 넣지 않는다.

운동 시작 위치 기록, 전반 폴더 리팩터링, `statusText` 제거, 재실행 HK 세션 복구, 시계 수동 변경에 대한 monotonic clock 체계 도입은 범위 밖이다.

## 4. 파일 단위 실행 단계 (모두 승인 후)

### Task 1 — 재현과 포맷 선택 게이트

**Files:** 아직 제품 코드 변경 없음. 결과는 본 문서의 검증 기록에 추가한다.

- [ ] 세 앱의 현행 설치본 버전·기기/watchOS·AOD 설정·표시 화면을 기록하고 아래 실기기 시나리오의 기준 영상을 확보한다.
- [ ] 영상에서 UI의 숫자 변경 시각과 Instruments의 main thread/run loop 지연을 비교한다. 필요한 경우 승인된 디버그 빌드에서만 tick 도착·metrics 발행·pause 이벤트 시각을 일시 계측한다. 생체 수치와 개인 정보는 기록하지 않는다. 관찰 없이 “HealthKit가 느려서”라고 결론 내리지 않는다.
- [ ] Task 3에서 시스템 timer text의 출력/분수초 pause 표현을 먼저 확인한다. 현재 앞자리 0 포맷과 달라도 허용할지 검토한다. 이 선택이 닫히기 전 세 앱 적용을 확정하지 않는다.

### Task 2 — 순수 표시 기준과 서비스 생명주기

**Files:**

- Create: `Packages/YJKit/Sources/WorkoutCore/WorkoutElapsedDisplay.swift` — §3의 순수 값과 경계 연산.
- Create: `Packages/YJKit/Tests/WorkoutCoreTests/WorkoutElapsedDisplayTests.swift` — 지연·정지·재개 계산.
- Modify: `Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift` — optional published 표시 값, 시작·HK 이벤트 날짜·종료 고정·이전 세션 guard. 기존 틱/결과는 그대로.
- Modify: `Packages/YJKit/Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift` — 기존 포맷/주입 테스트에 표시 경계 테스트 추가. 실제 HK 세션 없이 internal 상태 적용 경로 검증. 필요하면 기존 DEBUG 테스트 지원에 표시 start/stop 입력을 추가하되 public production API로 노출하지 않는다.

**Interfaces:** §3 `WorkoutElapsedDisplay`, `elapsedDisplay`, `applyElapsedDisplayState(_:at:)`. 표시 전용 상태는 저장용 카운터로 역류하지 않는다.

- [ ] 실패 테스트부터 작성·실행: `running_withoutTicks_usesDateDifference` — t=100 시작 뒤 callback 없이 t=140.75에서 40.75초.
- [ ] `pauseResume_preservesFraction` — t=110.25 pause, t=130.75 resume, t=131.5에서 11초; paused 동안 임의 시간이 지나도 10.25초. 중복 pause/resume도 같은 값.
- [ ] `resetAfterStop_startsNewReference`, `stop_freezesAtRequestDate`, `staleDelegate_doesNotUnfreezeOrOverwriteNewSession`, `negativeDate_clampsToZero` 작성. 종료 저장에 3초가 걸려도 표시가 더 흐르지 않아야 한다.
- [ ] 최소 구현 후 위 테스트 통과. 기존 `formattedElapsed` 및 result/metrics 테스트도 통과시킨다. 상태 이벤트를 실제 HK 없이 입력하는 테스트는 계산/전이를 검증할 뿐 실제 delegate 지연·순서는 실기기 확인 대상이다.

### Task 3 — 공용 elapsed 행

**Files:**

- Create: `Packages/YJKit/Sources/WorkoutUI/Watch/Components/WorkoutElapsedText.swift` — 표시 값만 받는 시스템 timer text/정지 텍스트.
- Modify: `Packages/YJKit/Sources/WorkoutUI/Watch/WorkoutMetricsView.swift` — optional 인자와 컴포넌트 조합, 숫자 transition 제거, 기존 initializer 사용 호환, preview 추가.

**Interfaces:** §3의 UI initializer 두 개. WorkoutCore는 SwiftUI에 의존하지 않는다.

- [ ] 실행·정지·nil fallback·저휘도 preview를 만든다. View를 그대로 따라 하는 단위 테스트나 새 UI 테스트 타깃은 만들지 않는다.
- [ ] 0초/9초/59초/59:59/1:00:00/2시간 이상을 작은 워치와 큰 워치에서 확인한다. ko/en, 숫자 폭, 1시간 전환, pause 직전/직후의 출력 오차(최대 1초), 접근성 레이블을 확인한다.
- [ ] running 기준점을 preview 재평가나 칼로리 업데이트로 다시 만들지 않는지 검토하고 workspace Watch 빌드로 API·가용성을 확인한다.
- [ ] 포맷 수용 실패 시 `TimelineView` + 동일 모델 + 기존 `formatSeconds`로 대안을 문서화하고 재승인받는다. 앱마다 다른 렌더러를 임의로 도입하지 않는다.

### Task 4 — 세 앱 연결과 시간 계약 회귀

**Files / 역할:**

| 작업 | 파일 | 역할 |
|---|---|---|
| Modify | `Apps/GolfCounter/WatchApp/Features/Round/SessionMetrics/SessionMetricsView.swift` | 서비스 `elapsedDisplay`를 공용 UI에 전달. RoundSessionView/라운드 저장 코드는 변경 불필요 |
| Modify | `Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `@Published private(set) var elapsedDisplay: WorkoutElapsedDisplay?` 추가, service의 표시 publisher만 전달. currentMetrics/경기/폰 앵커는 유지 |
| Modify | `Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionView.swift` | elapsedDisplay 값을 WorkoutMetricsView로 전달 |
| Modify | `Apps/TennisCounter/watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 표시 모델의 경계 발행과 기존 metrics/경기 시간 분리 검증 |
| Modify | `Apps/HaruchiFit/WatchApp/Features/Workout/SegmentTracker.swift` | 기존 시간 상태를 elapsedDisplay 값으로 투영. 기존 구간 계산은 유지 |
| Modify | `Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift` | 시작·정지·재개·종료 때 tracker 표시 값 발행. metrics 신호에 표시 진행을 의존하지 않음 |
| Modify | `Apps/HaruchiFit/WatchApp/Features/Workout/Session/SessionView.swift` | VM 표시 값을 공용 UI로 전달 |
| Modify | `Apps/HaruchiFit/watchosTests/Workout/SegmentTrackerTests.swift` | 표시 투영과 tracker 정수 값이 분수초 경계에서도 일치하는지 검증 |
| Modify | `Apps/HaruchiFit/watchosTests/Workout/WorkoutViewModelPauseTests.swift` | 무신호 진행, 정지·재개 시 즉시 표시 상태 변경 검증 |
| Modify | `Apps/HaruchiFit/watchosTests/Workout/WorkoutViewModelTests.swift` | 종료 시 고정·재시작 초기화·총시간/구간 계약 회귀 |

**Interfaces:** Ralli/Haruchi VM은 위 optional published 값만 UI에 노출한다. Ralli의 테스트는 service DEBUG 입력을 통해 표시 모델을 주입하며 실제 WatchConnectivity/HealthKit를 호출하지 않는다. Haruchi는 기존 주입 now 및 세션 테스트 지원을 사용한다.

- [ ] Ralli 실패 테스트: 틱 elapsed=7, 표시 모델 t=100 시작 후 now=140에서도 표시 모델은 40을 계산하며 기존 currentMetrics/경기/송신 스냅샷은 7 유지. 심박 신호가 없어도 모델은 새 Date에서 진행한다. pause/resume 발행은 기준점을 보존한다.
- [ ] Haruchi 실패 테스트: 심박/서비스 틱을 멈춘 채 주입 now를 30초 이동하면 표시 모델도 30초. `Int(elapsedDisplay.elapsed(at: now)) == segments.elapsedSeconds`; pause 10초/구간 전환/재개/종료로 구간 합계==저장 totalSeconds 유지.
- [ ] 필요한 배선만 구현하고 신규 테스트 및 기존 pause·snapshot·저장 테스트 통과. Golf는 UI 전달만 바뀌므로 배선 자체를 복제하는 테스트는 추가하지 않고 패키지 상태 테스트+workspace 빌드+실기기로 검증한다.
- [ ] Ralli iOS의 `WorkoutSessionViewModelTests`, `MatchEndMessageTests`, `MatchSessionGroupTests` 및 Haruchi `WorkoutViewModelSnapshotTests`, `WorkoutSnapshotTests`(ComplicationState 검증 포함)의 기존 회귀 검사를 실행한다. 기존 테스트 기대값을 새 표시 시각에 맞추어 임의로 바꾸지 않는다.

### Task 5 — 전체 검증·문서·Git (후속 승인 대상)

**Files:** 본 플랜의 결과/미확정 상태와 `TODO.md`의 관련 항목만 상태 갱신. 완료 시 신규 작업 기록 `Packages/YJKit/docs/logs/2026/2026-11-02-watch-workout-elapsed-display.md`에 최종 파일·명령·기기 증거·제한을 남긴다. 기존 탐색 문서는 구현 결과가 확정된 뒤 해당 로그/플랜 링크와 오래된 서술만 교정한다.

- [ ] 아래 자동 검증과 실기기 기준을 실행하고 결과를 기록한다.
- [ ] `git diff --check`, 범위 diff 확인. 위치 기록·폴더 정리·저장 의미 변경이 섞이지 않았는지 검토한다.
- [ ] 실기기 확인이 남으면 “코드 검증 완료 / 실기기 대기”로 표시한다. 구현 완료·현상 해결로 닫지 않는다.

## 5. 의미 있는 자동 검증과 워크스페이스 빌드

**이번 문서 작성 세션에서는 빌드/테스트를 실행하지 않았다.** 아래는 구현 승인 후 검증 명령이다. 현행 CI와 동일하게 root에서 UDID를 선택한다. 독립 패키지 테스트는 루트가 허용한 `make kit-test` 예외이며 앱/확장 빌드는 모두 workspace를 사용한다.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
make kit-test KIT_DESTINATION="id=$IOS"

xcodebuild -workspace YJApps.xcworkspace -scheme 'GolfCounter Watch App' -destination "id=$WATCH" -only-testing:GolfCounterWatchTests test
xcodebuild -workspace YJApps.xcworkspace -scheme 'TennisCounter Watch App' -destination "id=$WATCH" -only-testing:RalliWatchTests test
xcodebuild -workspace YJApps.xcworkspace -scheme 'HaruchiFitWatchTests' -destination "id=$WATCH" test

xcodebuild -workspace YJApps.xcworkspace -scheme GolfCounter -destination "id=$IOS" test
xcodebuild -workspace YJApps.xcworkspace -scheme TennisCounter -destination "id=$IOS" test
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build

xcodebuild -workspace YJApps.xcworkspace -scheme GolfComplicationExtension -destination "id=$WATCH" build
xcodebuild -workspace YJApps.xcworkspace -scheme RalliComplicationExtension -destination "id=$WATCH" build
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiComplicationExtension -destination "id=$WATCH" build
xcodebuild -workspace YJApps.xcworkspace -scheme TennisLiveActivityExtension -destination "id=$IOS" build
make lint
make format
git diff --check
```

Watch test 명령은 호스트 Watch 앱 빌드도 수행한다. 패키지는 watchOS 전용 UI/생명주기를 iOS kit-test만으로 검증할 수 없으므로 세 Watch 앱의 빌드·테스트가 필수다. 성공 기준은 각 명령 exit 0와 TEST/BUILD SUCCEEDED, 신규 시간 시나리오 통과다. 실패가 기존 환경 문제인지 변경 회귀인지 나눠 보고한다. 실제 기기 배포·계측 전에 배포 대상과 설치본을 식별한다.

## 6. 실기기 합격조건

세 앱 각각 동일한 절차로 전/후 비교한다. Watch 모델·OS·앱 빌드·AOD on/off·표시 화면·영상 시간을 기록한다. 시뮬레이터 AOD는 UI 보조 검사이며 실기기 판정의 대체가 아니다.

| 조건 | 절차와 합격 판정 |
|---|---|
| 전면 균일성 | 지표 화면을 2분 관찰/촬영. 첫 표시 이후 1초 숫자가 반복적으로 1.5초 이상 머물고 뒤이어 0.5초 이내에 두 번 바뀌는 패턴이 없어야 한다. 이는 제품 검수용 제안 허용치이며 OS 보장 수치가 아니다. 실패하면 main thread 부하/렌더링 계측으로 재분석 |
| 신호 독립성 | 테스트 입력에서 심박·칼로리·서비스 tick을 발행하지 않아도 기준시각 모델로 계속 진행. 실기기 심박 수집 공백에서도 경과시간이 생체 신호를 기다리는 현상 없음 |
| 손목 내림/AOD/복귀 | AOD on에서 30초·2분 손목 내림, AOD off에서도 반복. 복귀 첫 정상 프레임에서 기대 정지 제외 시간과 1초 이내. 밀린 초를 차례로 빠르게 재생하지 않음. AOD 중 정확한 1Hz는 필수 조건 아님 |
| pause/resume | 20초 진행→30초 pause→20초 진행, 세 번 반복. pause 반영 후 값 고정, resume 직후 0으로 리셋/역행 없음. 분수초 반복 누적 오차 1초 이내. Ralli는 폰 pause 명령 왕복도 확인 |
| 종료/재시작 | 실행 중/정지 중 각각 종료. 저장 대기 동안 숫자가 증가하지 않고 새 운동은 0부터 시작. 늦은 delegate가 새 표시를 덮어쓰지 않음 |
| 포맷·레이아웃 | 작은/큰 워치, ko/en, 1시간 경계에서 잘림·크기 튐 없음. 시스템 timer의 앞자리 0 차이는 승인된 포맷 선택과 일치 |
| 폰·저장 회귀 | Ralli 폰의 anchor/pause 동작·경기 저장·최종 레코드 기존 의미 유지. 워치 새 표시와 다른 값이 발생하면 차이/경로를 기록하며 표시 수정의 해결 범위를 구분. Golf의 점수 저장과 Haruchi의 구간합==totalSeconds 유지 |
| 컴플리케이션 | Haruchi 실행→pause→resume→종료에서 timer/고정 문자열/초기 상태 전환 정상, 워치 표시와 정수화 수준 차이 이내. Golf/Ralli 점수·라운드 표시는 기존과 같음 |

위 전면 허용치는 승인 전 조정 가능한 제안이다. 현상 재현이 안 되면 미재현으로 기록하고 원인 해결이라고 쓰지 않는다.

## 7. 미확정 결정과 승인 게이트

1. **표시만 먼저 개선하는 범위 수용 여부:** 새 워치 표시와 기존 폰 앵커/경기 저장/정지 포함 최종 요약 차이를 이 트랙에서 남겨도 되는가. 권장: 이 한계를 명시하고 표시 트랙부터 검증하되, 사용자 수용이 있어야 구현한다.
2. **포맷:** 시스템 `.timer`의 로케일별 앞자리 0/시간 표현을 허용하는가. 권장: 가능하면 시스템 표현 사용. 기존 문자열 형식의 엄밀한 유지가 필수면 TimelineView 대안 재승인.
3. **실제 원인:** 기기/OS/AOD 조건과 tick→metrics→화면 지연 위치는 미확정. 계측 결과가 가설과 다르면 Task 1에서 설계를 다시 검토한다.
4. **HK 상태 경계 지연:** Golf/Ralli는 delegate date, Haruchi는 기존 서비스 isPaused 수신 시각을 쓴다. 이번에 Haruchi 저장 의미까지 바꾸지 않는다. 경계 차이가 제품 허용치를 넘으면 별도 통합 설계 대상으로 보고한다.
5. **시계 변경/재시작 복구:** Date 기반 가상 시작시각이므로 시스템 시각 변경 영향을 받는다. 이번은 앱이 살아 있는 운동 표시가 대상이다. monotonic 보정·세션 복구는 별도 결정이다.
6. **저장 통합 후속:** pause 제외 총시간·HKWorkout.duration·구간·폰 anchor의 일관성 및 Ralli 과거 데이터 보정 가능성을 별도 실측/플랜에서 판단한다. 이번 문서가 그 변경을 승인하지 않는다.

## 8. 추후 승인 후 Git 절차

이 세션에서는 브랜치 생성·스테이징·커밋·PR·push를 하지 않는다. 플랜 검토가 구현 승인이나 Git 승인으로 자동 전환되지 않는다.

구현·작업 브랜치 절차까지 승인되면 현행 checkout의 사용자 diff를 다시 확인한다. 기존 변경을 stash/reset하거나 섞어 커밋하지 않는다. 네이티브 worktree 도구가 있으면 우선하고, 없으면 루트 규약에 맞춰 형제 경로 `../yj-apps-worktrees/watch-workout-elapsed-display`에 트랙 하나의 worktree/브랜치를 생성한다. 유지보수 경계는 표시 트랙 하나다.

검증 결과와 실기기 대기를 문서화한 뒤 사용자 검토를 거쳐 승인된 파일만 명시적으로 stage한다. gitmoji 커밋(예: `🐛 fix: stabilize watch workout elapsed display`)과 PR을 만들고 일반 merge commit으로 통합한다. main 직접 push는 하지 않는다. 문서만 직접 커밋할 수 있는 저장소 예외도 이번 세션의 사용자 금지보다 우선하지 않는다. worktree 제거 시 해당 DerivedData 정리는 트랙 종료·수동 확인 완료 후 수행한다.
