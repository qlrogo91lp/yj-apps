# 워치 경과시간에서 일시정지 제외 — 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 하루치 워치가 재는 모든 시간(화면·컴플리케이션·구간·저장 총시간)에서 일시정지한 시간을 뺀다.

**Architecture:** `SegmentTracker` 가 정지 누적을 들고 워치의 **단일 시계**가 된다. `WorkoutViewModel` 은 `session.elapsedSeconds`(틱 카운터) 대신 이 시계를 읽는다. `Packages/YJKit` 은 건드리지 않는다 — HealthKit 이 세그먼트를 모르므로 구간에서 정지를 빼는 일은 어차피 앱이 해야 하고, 그 시계를 두 개 둘 이유가 없다.

**Tech Stack:** Swift 6 · SwiftUI · Combine · swift-testing (`@Test`/`#expect`) · watchOS 10

**Spec:** [`docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md`](../../specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md)

## Global Constraints

- **`Packages/YJKit` 을 한 줄도 고치지 않는다.** `WorkoutSessionService.elapsedSeconds` 는 Ralli·골프가 쓴다 (루트 `CLAUDE.md`)
- **`WorkoutRecordMessage` 의 형태를 바꾸지 않는다.** 필드를 더하지 않고 `totalSeconds` 의 *의미*만 바꾼다. iOS 타깃은 손대지 않는다
- **`isPaused` 의 단일 소스는 `WorkoutSessionService` 다.** 낙관적 토글 금지 (루트 `CLAUDE.md` 워크아웃 동작 계약) — `togglePause()` 에서 시계를 건드리지 않고, 서비스가 실제로 바꾼 값이 흘러올 때만 반영한다
- **불변조건: `구간 길이의 합 == totalSeconds`** (반올림 오차 이내). PR #19 가 맞춰놓은 조건이다
- **불변조건: `totalSeconds <= endedAt − startedAt`.** 정지가 있으면 작다. 둘이 같다고 가정하는 코드를 두지 않는다
- 빌드·테스트는 **워크스페이스 기준**이다. 시뮬레이터는 이름이 아니라 UDID 로 지정한다
- 커밋 메시지는 gitmoji prefix (`🐛 fix` / `✅ test` / `📝 docs`)

**테스트 실행 명령** (저장소 루트에서):

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `WatchApp/Features/Workout/SegmentTracker.swift` | 워치의 단일 시계. 구간 경계 + 정지 누적 | 수정 |
| `WatchApp/Features/Workout/WorkoutViewModel.swift` | 배선. 정지 신호를 시계에 전달, 시계 값을 화면·컴플리케이션·저장에 흘림 | 수정 |
| `watchosTests/Workout/SegmentTrackerTests.swift` | 시계 규칙 검증 (순수) | 수정 |
| `watchosTests/Workout/WorkoutViewModelPauseTests.swift` | 배선 검증 | **생성** |
| `Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md` | 3앱 공통 미결 탐색 | 수정 (선례 절 추가) |
| `TODO.md` | 진행 상태 | 수정 |

---

## Task 0: 브랜치를 판다

**Files:** 없음

- [ ] **Step 1: main 최신화 후 브랜치 생성**

```bash
cd /Users/yj/Workspace/yj-apps
git checkout main && git pull
git checkout -b fix/haruchi-elapsed-exclude-pause
```

`main` 직접 push 는 금지다 (루트 `CLAUDE.md`). 머지는 마지막에 `gh pr merge --merge --delete-branch`.

- [ ] **Step 2: 검토받은 스펙 두 개를 먼저 커밋**

스펙 문서는 코드 변경이 없어 원래 `main` 직접 커밋도 가능하지만, 이 플랜의 근거 문서라 같은 브랜치에 실어 PR 에서 함께 읽히게 한다.

```bash
git add Apps/HaruchiFit/docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md \
        Apps/HaruchiFit/docs/specs/shared/2026/2026-09-09-grass-daily-aggregate.md \
        Apps/HaruchiFit/docs/plans/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md
git commit -m "📝 경과시간 정지 제외와 잔디 집계 설계를 확정한다"
```

---

## Task 1: `SegmentTracker` 가 정지를 뺀다

**Files:**
- Modify: `Apps/HaruchiFit/WatchApp/Features/Workout/SegmentTracker.swift`
- Test: `Apps/HaruchiFit/watchosTests/Workout/SegmentTrackerTests.swift`

**Interfaces:**
- Consumes: 없음 (순수 struct)
- Produces:
  - `mutating func pause()` — 정지 시작. 이미 정지 중이면 아무 일도 안 한다
  - `mutating func resume()` — 정지 종료. 정지 중이 아니면 아무 일도 안 한다
  - `var elapsedSeconds: Int` — **정지를 뺀** 세션 경과시간. 정지 중에는 정지 시작 시점 값으로 멈춘다
  - `mutating func reset()` — 기존 동작 + 정지 누적까지 지운다
  - `closeOpenSegment(kind:)` · `startedAt` · `closed` — **시그니처 변경 없음**

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`watchosTests/Workout/SegmentTrackerTests.swift` 의 마지막 `}` 앞에 아래 5개를 추가한다. 파일 상단의 `Clock` 과 `makeTracker()` 헬퍼는 이미 있으니 그대로 쓴다.

```swift
    // MARK: - 일시정지

    @Test("정지한 동안은 경과시간이 늘지 않는다")
    func pauseFreezesElapsed() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(600) // 10분 운동
        tracker.pause()
        clock.advance(300) // 5분 정지 — 이 시간은 세지 않는다

        #expect(tracker.elapsedSeconds == 600)
    }

    @Test("재개하면 정지한 만큼을 뺀 채로 다시 흐른다")
    func resumeExcludesPausedSpan() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(1200) // 20분
        tracker.pause()
        clock.advance(600) // 10분 정지
        tracker.resume()
        clock.advance(1200) // 20분

        #expect(tracker.elapsedSeconds == 2400) // 40분. 정지 10분 제외
    }

    @Test("정지를 사이에 낀 구간에도 정지 시간이 빠진다")
    func pausedTimeIsExcludedFromSegments() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(600) // 근력 10분
        tracker.pause()
        clock.advance(300) // 5분 정지
        tracker.resume()
        clock.advance(600) // 근력 10분 더
        tracker.closeOpenSegment(kind: .strength)
        clock.advance(300) // 유산소 5분
        tracker.closeOpenSegment(kind: .cardio)

        #expect(tracker.closed.map(\.durationSeconds) == [1200, 300])
        #expect(tracker.closed.map(\.startOffset) == [0, 1200])

        let total = tracker.closed.reduce(0) { $0 + $1.durationSeconds }
        #expect(total == tracker.elapsedSeconds)
    }

    @Test("정지·재개를 중복으로 불러도 값이 어긋나지 않는다")
    func repeatedPauseResumeIsIdempotent() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        tracker.resume() // 정지 중이 아닌데 재개 — 무시
        clock.advance(600)
        tracker.pause()
        tracker.pause() // 두 번째는 무시
        clock.advance(300)
        tracker.resume()
        tracker.resume() // 두 번째는 무시
        clock.advance(600)

        #expect(tracker.elapsedSeconds == 1200)
    }

    @Test("정지 중에 세션을 끝내도 구간 합계와 총 시간이 어긋나지 않는다")
    func closingWhilePausedKeepsSumConsistent() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(1200) // 20분 운동
        tracker.pause()
        clock.advance(900) // 15분 정지 — 이 상태로 종료 버튼을 누른다
        tracker.closeOpenSegment(kind: .strength)

        let sum = tracker.closed.reduce(0) { $0 + $1.durationSeconds }
        #expect(sum == 1200)
        #expect(tracker.elapsedSeconds == 1200)
        #expect(sum == tracker.elapsedSeconds)
    }

    @Test("새 세션을 열면 정지 누적도 지운다")
    func resetClearsPausedAccumulation() {
        var (tracker, clock) = makeTracker()
        tracker.reset()
        clock.advance(600)
        tracker.pause()
        clock.advance(600)

        tracker.reset() // 정지 중에 새 세션을 연다
        clock.advance(300)

        #expect(tracker.elapsedSeconds == 300)
    }
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/yj/Workspace/yj-apps
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **컴파일 실패** — `value of type 'SegmentTracker' has no member 'pause'`

- [ ] **Step 3: 최소 구현**

`SegmentTracker.swift` 를 아래로 바꾼다. 파일 상단 문서 주석에 정지 문단을 더한다.

```swift
import Foundation

/// 세션 안의 구간 경계를 잰다. 근력↔유산소 전환 한 번이 구간 하나를 닫고 다음을 연다.
///
/// **워치의 단일 시계다.** 화면·컴플리케이션·구간·저장 총시간이 모두 여기서 나온다.
/// `WorkoutSessionService.elapsedSeconds` 는 1초 `Timer` 가 올리는 틱 카운터라 손목을 내리면
/// 멈추고, 다시 켜져도 밀린 만큼 따라잡지 않는다 — 실기기에서 40분 세션의 구간이 몇 초로
/// 잡혀 요약이 "근력 0분" 을 띄웠다.
///
/// **일시정지한 시간은 뺀다.** 사용자가 기대하는 "운동한 시간" 이 그 뜻이고, 잔디 농도가
/// 이 값을 입력으로 삼는다 (`docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md`).
/// 정지 상태의 단일 소스는 `WorkoutSessionService` 이며, 이 타입은 전달받기만 한다.
struct SegmentTracker {
    private let now: () -> Date
    private(set) var startedAt: Date
    /// 열려 있는 구간이 시작된 오프셋(초).
    private var openStart = 0
    private(set) var closed: [WorkoutRecordMessage.SegmentPayload] = []

    /// 지금까지 정지로 흘려보낸 시간의 합.
    private var pausedAccumulated: TimeInterval = 0
    /// 정지 중이면 정지가 시작된 시각. 아니면 nil.
    private var pausedSince: Date?

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        startedAt = now()
    }

    /// 세션 시작으로부터 흐른 시간(초). **정지한 시간은 빠져 있다.**
    /// 정지 중에는 정지가 시작된 시점의 값에서 멈춘다.
    var elapsedSeconds: Int {
        let reference = pausedSince ?? now()
        return max(0, Int(reference.timeIntervalSince(startedAt) - pausedAccumulated))
    }

    /// 새 세션을 연다. 쌓인 구간과 정지 누적을 버리고 기준 시각을 다시 잡는다.
    mutating func reset() {
        startedAt = now()
        openStart = 0
        closed = []
        pausedAccumulated = 0
        pausedSince = nil
    }

    /// 정지를 시작한다. 이미 정지 중이면 아무 일도 하지 않는다 —
    /// 중복 신호가 와도 기준 시각을 덮어써 정지 길이를 잃지 않게 한다.
    mutating func pause() {
        guard pausedSince == nil else { return }
        pausedSince = now()
    }

    /// 정지를 끝내고 그 길이를 누적에 더한다. 정지 중이 아니면 아무 일도 하지 않는다.
    mutating func resume() {
        guard let since = pausedSince else { return }
        pausedAccumulated += now().timeIntervalSince(since)
        pausedSince = nil
    }

    /// 열린 구간을 닫고 다음 구간을 연다.
    /// 길이가 0이면 버린다 — 전환을 연달아 눌렀을 때 빈 구간이 쌓이는 것을 막는다.
    mutating func closeOpenSegment(kind: SegmentKind) {
        let elapsed = elapsedSeconds
        let duration = elapsed - openStart
        if duration > 0 {
            closed.append(.init(kind: kind, startOffset: openStart, durationSeconds: duration))
        }
        openStart = elapsed
    }
}
```

- [ ] **Step 4: 테스트 통과를 확인한다**

```bash
cd /Users/yj/Workspace/yj-apps
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **모두 PASS.** 기존 5개(벽시계·전환·0길이·합계·reset)도 그대로 통과해야 한다 — 정지를 안 쓰면 동작이 이전과 같다.

- [ ] **Step 5: 커밋**

```bash
git add Apps/HaruchiFit/WatchApp/Features/Workout/SegmentTracker.swift \
        Apps/HaruchiFit/watchosTests/Workout/SegmentTrackerTests.swift
git commit -m "🐛 세션 시계에서 일시정지한 시간을 뺀다"
```

---

## Task 2: `WorkoutViewModel` 이 그 시계를 읽는다

**Files:**
- Modify: `Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift`
- Test: `Apps/HaruchiFit/watchosTests/Workout/WorkoutViewModelPauseTests.swift` (생성)

**Interfaces:**
- Consumes: Task 1 의 `SegmentTracker.pause()` · `resume()` · `elapsedSeconds`
- Produces:
  - `init(session:connectivity:remover:defaults:snapshots:now:)` — 마지막 파라미터 `now: @escaping () -> Date = Date.init` **추가**. 기존 호출부는 기본값으로 그대로 컴파일된다
  - `func handlePauseChange(_ paused: Bool)` — internal. 정지 신호를 시계와 컴플리케이션에 반영한다. `@testable import` 로 테스트가 직접 부른다
  - `private func currentMetrics() -> WorkoutMetrics` — `static func snapshot(of:)` 를 대체한다

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`watchosTests/Workout/WorkoutViewModelPauseTests.swift` 를 새로 만든다.

```swift
import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// 정지 신호가 **시계**에 닿는지 본다.
///
/// `session.$isPaused` 스트림은 실제 `HKWorkoutSession` 없이는 흐르지 않으므로
/// (`WorkoutViewModelSnapshotTests` 주석 참고) 스트림이 부르는 지점을 직접 호출한다.
/// 스트림 자체의 연결은 실기기 검증 항목이다.
@MainActor
struct WorkoutViewModelPauseTests {
    private final class Clock {
        var now: Date
        init(_ start: Date = Date(timeIntervalSince1970: 0)) {
            now = start
        }

        func advance(_ seconds: TimeInterval) {
            now.addTimeInterval(seconds)
        }
    }

    private func makeViewModel() -> (WorkoutViewModel, WorkoutSnapshotPublisherSpy, Clock) {
        let clock = Clock()
        let snapshots = WorkoutSnapshotPublisherSpy()
        let viewModel = WorkoutViewModel(connectivity: WorkoutRecordSendingSpy(),
                                         remover: WorkoutRemovingSpy(),
                                         defaults: UserDefaults(suiteName: UUID().uuidString)!,
                                         snapshots: snapshots,
                                         now: { clock.now })
        return (viewModel, snapshots, clock)
    }

    @Test("정지한 시간은 컴플리케이션 스냅샷의 경과시간에서 빠진다")
    func pausedTimeIsExcludedFromSnapshot() throws {
        let (viewModel, spy, clock) = makeViewModel()

        clock.advance(600) // 10분 운동
        viewModel.handlePauseChange(true)
        clock.advance(300) // 5분 정지
        viewModel.handlePauseChange(false)
        clock.advance(600) // 10분 더

        viewModel.switchMode(to: .cardio) // 스냅샷 발행

        let snapshot = try #require(spy.published.last)
        #expect(snapshot.elapsedSeconds == 1200) // 20분. 정지 5분 제외
    }

    @Test("정지 중에 발행된 스냅샷은 멈춘 시각을 담는다")
    func snapshotDuringPauseHoldsFrozenElapsed() throws {
        let (viewModel, spy, clock) = makeViewModel()

        clock.advance(900) // 15분
        viewModel.handlePauseChange(true)
        clock.advance(1800) // 30분을 멈춰 있었다

        viewModel.switchMode(to: .cardio)

        let snapshot = try #require(spy.published.last)
        #expect(snapshot.elapsedSeconds == 900)
    }

    @Test("정지 신호가 중복으로 와도 경과시간이 어긋나지 않는다")
    func duplicatePauseSignalsDoNotDrift() throws {
        let (viewModel, spy, clock) = makeViewModel()

        clock.advance(600)
        viewModel.handlePauseChange(true)
        viewModel.handlePauseChange(true)
        clock.advance(300)
        viewModel.handlePauseChange(false)
        viewModel.handlePauseChange(false)
        clock.advance(600)

        viewModel.switchMode(to: .cardio)

        let snapshot = try #require(spy.published.last)
        #expect(snapshot.elapsedSeconds == 1200)
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/yj/Workspace/yj-apps
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **컴파일 실패** — `extra argument 'now' in call` 과 `value of type 'WorkoutViewModel' has no member 'handlePauseChange'`

- [ ] **Step 3: 시계를 주입받게 고친다**

`WorkoutViewModel.swift` 에서 `segments` 선언을 바꾼다.

```swift
    /// 워치의 단일 시계. **`session.elapsedSeconds` 를 쓰지 않는다** — 틱 카운터라 손목을
    /// 내리면 멈추고 정지 시간도 이 타입만 정확히 뺀다 (`SegmentTracker` 주석).
    /// 세션 시작 시각도 여기가 단일 소스다.
    private var segments: SegmentTracker
```

`init` 시그니처에 `now` 를 더하고, 첫 줄에서 `segments` 를 만든다.

```swift
    init(session: WorkoutSessionService = WorkoutSessionService(configuration: .strength),
         connectivity: WorkoutRecordSending,
         remover: WorkoutRemoving = HealthKitWorkoutRemover(),
         defaults: UserDefaults = .standard,
         snapshots: WorkoutSnapshotPublishing = WorkoutSnapshotPublisher(),
         now: @escaping () -> Date = Date.init)
    {
        self.session = session
        self.connectivity = connectivity
        self.remover = remover
        self.defaults = defaults
        self.snapshots = snapshots
        segments = SegmentTracker(now: now)
```

- [ ] **Step 4: 정지 구독이 시계를 건드리게 한다**

`init` 안의 두 번째 `session.$isPaused` 구독에서 sink 본문을 `handlePauseChange` 호출로 바꾼다.

```swift
        // 정지/재개는 **여기서만** 시계와 컴플리케이션에 닿는다. `togglePause()` 에서 부르면
        // 세션이 실제로 멈췄는지 모르는 채 값을 지어내는 꼴이라(낙관적 토글 — 루트 `CLAUDE.md`
        // 워크아웃 계약), 서비스가 실제로 바꾼 값만 흘려보낸다.
        session.$isPaused
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] paused in
                MainActor.assumeIsolated {
                    self?.handlePauseChange(paused)
                }
            }
            .store(in: &cancellables)
```

`publishSnapshot` 바로 위에 메서드를 더한다.

```swift
    /// 정지/재개를 시계와 컴플리케이션에 반영한다.
    ///
    /// **`session.$isPaused` 구독만 이걸 부른다.** 시계는 세션이 실제로 멈춘 뒤에만 멈춰야
    /// 저장값과 화면이 갈리지 않는다. 시계는 단계와 무관하게 갱신하고, 발행만 진행 중일 때 한다.
    func handlePauseChange(_ paused: Bool) {
        if paused {
            segments.pause()
        } else {
            segments.resume()
        }
        guard phase == .active else { return }
        publishSnapshot(isPaused: paused)
    }
```

- [ ] **Step 5: 화면·컴플리케이션의 경과시간 소스를 바꾼다**

`init` 안의 `CombineLatest4` 블록을 바꾼다. `assign(to:)` 대신 sink 를 쓰는 것은 `self` 를 읽어야 하기 때문이다 — 같은 파일의 `isPaused` 구독과 같은 모양이다.

```swift
        // 값이 바뀌었다는 신호는 세션에서 오지만, **경과시간은 시계에서 읽는다.**
        Publishers.CombineLatest4(
            session.$elapsedSeconds,
            session.$currentCalories,
            session.$currentBasalCalories,
            session.$currentHeartRate
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.metrics = self.currentMetrics()
            }
        }
        .store(in: &cancellables)
```

파일 맨 아래의 `static func snapshot(of:)` 를 지우고 인스턴스 메서드로 바꾼다.

```swift
    /// 총 칼로리는 활동 + 휴식이다 (YJKit README).
    /// **경과시간만 시계에서 온다** — 나머지는 세션이 낸 값 그대로다.
    private func currentMetrics() -> WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(segments.elapsedSeconds),
                       activeCalories: session.currentCalories,
                       totalCalories: session.currentCalories + session.currentBasalCalories,
                       heartRate: session.currentHeartRate)
    }
```

`publishSnapshot` 의 경과시간도 시계에서 읽는다.

```swift
    /// 컴플리케이션이 읽을 상태를 내보낸다.
    ///
    /// **경과시간은 시계에서 가져온다** — 워치가 단일 소스라는 계약(루트 `CLAUDE.md`)을 지키되,
    /// 정지를 뺀 정확한 값이어야 `ComplicationState` 가 `capturedAt - elapsedSeconds` 로
    /// 타이머 기준점을 제대로 잡는다.
    private func publishSnapshot(isPaused: Bool) {
        snapshots.publish(WorkoutSnapshot(startedAt: segments.startedAt,
                                          mode: mode,
                                          isPaused: isPaused,
                                          elapsedSeconds: segments.elapsedSeconds,
                                          capturedAt: Date()))
    }
```

- [ ] **Step 6: 테스트 통과를 확인한다**

```bash
cd /Users/yj/Workspace/yj-apps
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **모두 PASS.** 기존 `WorkoutViewModelSnapshotTests` 의 *"세션이 없으면 경과시간은 0 이다"* 도 통과한다 — 실제 시계로 만든 `SegmentTracker` 는 `init` 직후 경과시간이 0이다.

- [ ] **Step 7: 커밋**

```bash
git add Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift \
        Apps/HaruchiFit/watchosTests/Workout/WorkoutViewModelPauseTests.swift
git commit -m "🐛 화면과 컴플리케이션이 틱 대신 세션 시계를 읽는다"
```

---

## Task 3: 저장되는 총 시간을 시계에서 낸다

**Files:**
- Modify: `Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift:150-180` (`end()` 와 `record(from:)`)
- Test: `Apps/HaruchiFit/watchosTests/Workout/SegmentTrackerTests.swift`

**Interfaces:**
- Consumes: Task 1 의 `elapsedSeconds` · `closeOpenSegment(kind:)`
- Produces: `private func record(from result: WorkoutResult, totalSeconds: Int) -> WorkoutRecordMessage` — 파라미터가 하나 늘었다

**왜 값을 미리 붙드나** — `end()` 는 구간을 닫은 뒤 `await session.stopWorkout()` 을 기다린다. HealthKit 마무리에 시간이 걸리므로, 그 **뒤에** `segments.elapsedSeconds` 를 읽으면 구간 합계보다 커진다. 구간을 닫은 직후에는 `elapsedSeconds == 닫힌 구간 길이의 합` 이 정확히 성립한다.

- [ ] **Step 1: 불변조건을 고정하는 테스트를 쓴다**

`SegmentTrackerTests.swift` 의 "일시정지" 섹션 끝에 추가한다.

```swift
    @Test("구간을 닫은 직후의 경과시간은 구간 합계와 정확히 같다 — 저장 총시간이 이 값이다")
    func elapsedEqualsSegmentSumRightAfterClosing() {
        var (tracker, clock) = makeTracker()
        tracker.reset()

        clock.advance(900) // 근력 15분
        tracker.pause()
        clock.advance(600) // 10분 정지
        tracker.resume()
        clock.advance(300) // 근력 5분 더
        tracker.closeOpenSegment(kind: .strength)
        clock.advance(600) // 유산소 10분
        tracker.closeOpenSegment(kind: .cardio)

        let totalSeconds = tracker.elapsedSeconds // end() 가 붙드는 그 시점
        let sum = tracker.closed.reduce(0) { $0 + $1.durationSeconds }

        #expect(totalSeconds == sum)
        #expect(totalSeconds == 1800) // 30분. 정지 10분 제외

        // 종료 처리(HealthKit 마무리)에 시간이 걸려도 붙든 값은 변하지 않는다
        clock.advance(12)
        #expect(totalSeconds == sum)
    }
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/yj/Workspace/yj-apps
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **PASS.** 이 테스트는 Task 1 구현으로 이미 성립한다 — 회귀를 막는 잠금장치다. 실패한다면 Task 1 의 `closeOpenSegment` 나 `elapsedSeconds` 가 잘못된 것이니 거기부터 고친다.

- [ ] **Step 3: `end()` 가 총 시간을 붙들게 한다**

```swift
    @discardableResult
    func end() async -> WorkoutResult? {
        // stopWorkout() 보다 먼저 닫는다. 그쪽이 총 시간을 재는 시점과 가장 가까워야
        // 구간 합계와 총 시간이 어긋나지 않는다 — HealthKit 마무리에 시간이 걸린다.
        segments.closeOpenSegment(kind: mode)
        // **여기서 붙든다.** stopWorkout() 뒤에 읽으면 마무리에 걸린 시간만큼 구간 합계보다 커진다.
        let totalSeconds = segments.elapsedSeconds

        let result = await session.stopWorkout()
        WKInterfaceDevice.current().play(.stop)
        // 세션이 끝났으니 컴플리케이션은 평상시 표시로 돌아간다. 저장/버리기와 무관하다.
        snapshots.clear()

        enterSummary(with: result.map { record(from: $0, totalSeconds: totalSeconds) })
        return result
    }
```

- [ ] **Step 4: `record(from:)` 이 그 값을 쓰게 한다**

```swift
    /// **총 시간은 `WorkoutResult.durationSeconds` 를 쓰지 않는다.** 그쪽은 정지를 포함한
    /// 벽시계라 구간 합계와 어긋난다. 호출부가 구간을 닫은 시점에 붙든 값을 넘긴다.
    ///
    /// `endedAt - startedAt` 은 정지가 있으면 `totalSeconds` 보다 크다. **둘이 같다고
    /// 가정하는 코드를 두지 않는다.**
    private func record(from result: WorkoutResult, totalSeconds: Int) -> WorkoutRecordMessage {
        WorkoutRecordMessage(healthKitUUID: result.healthKitUUID,
                             startedAt: segments.startedAt,
                             endedAt: Date(),
                             totalSeconds: totalSeconds,
                             activeCalories: result.caloriesBurned,
                             totalCalories: result.totalCaloriesBurned,
                             averageHeartRate: result.averageHeartRate,
                             segments: segments.closed)
    }
```

- [ ] **Step 5: 전체 테스트 통과를 확인한다**

```bash
cd /Users/yj/Workspace/yj-apps
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **모두 PASS** (기존 W2 저장/버리기 테스트 포함).

- [ ] **Step 6: lint · format**

```bash
cd /Users/yj/Workspace/yj-apps
make fix
git diff --stat
```

- [ ] **Step 7: 커밋**

```bash
git add Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift \
        Apps/HaruchiFit/watchosTests/Workout/SegmentTrackerTests.swift
git commit -m "🐛 저장되는 총 시간에서 일시정지를 뺀다"
```

---

## Task 4: 문서를 맞춘다

**Files:**
- Modify: `Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md`
- Modify: `TODO.md`

- [ ] **Step 1: 탐색 문서에 선례를 남긴다**

`elapsed-seconds-tick-counter.md` 의 `## 추천` 절 **바로 앞**에 아래를 삽입한다. 다음 사람이 A안을 "또 반복된 실수" 로 읽지 않게 하는 게 목적이다.

```markdown
## 하루치가 먼저 간 길 (2026-09-09)

하루치는 **앱 레이어(`SegmentTracker`)에서 정지 제외**로 갔다. 형식상 A안이지만
**임시방편이 아니라 의도된 선택이다.**

- HealthKit 은 세그먼트를 모른다 (아키텍처 2절, 실기기로 확정). 그러니 **구간별 시간에서
  정지를 빼는 일은 앱이 할 수밖에 없다** — D안(`HKWorkout.duration`)이 총 시간을 해결해줘도
  구간은 못 해결하고, 그러면 `구간 합계 == 총 시간` 이 다시 깨진다
- 시계를 둘 이유가 없어 화면·컴플리케이션·구간·저장 총시간이 모두 `SegmentTracker` 를 읽는다
- 하루치는 미출시라 **보정할 과거 데이터가 없다.** Ralli 는 그 문제를 안고 있어 같은 선택을
  그대로 복사할 수 없다

설계: [하루치 스펙](../../../../Apps/HaruchiFit/docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md)

**YJKit 통합 결정은 그대로 열려 있다.** 아래 "정해야 할 것" 3가지는 하나도 안 닫혔다.
```

- [ ] **Step 2: TODO.md 의 상태를 뒤집는다**

**행은 이미 있다** — 스펙·플랜 커밋에서 만들어 뒀다. 상태만 바꾼다.

`## HaruchiFit` 의 「집 맥북에서 할 것」에서 이 줄을

```markdown
- [ ] **워치 시간에서 일시정지 제외** — 스펙·플랜 완료 · 구현 대기. 잔디 집계(#1)의 선행이다.
```

아래로 바꾼다.

```markdown
- [x] **워치 시간에서 일시정지 제외** — `SegmentTracker` 가 워치 단일 시계가 됐다 (PR #<번호>)
- [ ] **정지 제외 실기기 검증** — 5분 정지 후 총 시간, 구간 합계 일치,
      **WC 재검증 2항목**(컴플리케이션 경과시간·일시정지 시 멈춤), 손목 30초 내림
```

`## YJKit — 확인 필요` 절의 하루치 관련 문장에서 **"결정 대기"** 를 **"하루치는 앱 레이어에서 정지 제외로 확정 (PR #<번호>). YJKit 통합은 그대로 열려 있다"** 로 바꾼다.

- [ ] **Step 3: 커밋**

```bash
git add Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md TODO.md
git commit -m "📝 정지 제외 선례를 탐색 문서와 TODO 에 반영한다"
```

---

## Task 5: PR 을 낸다

- [ ] **Step 1: 푸시**

```bash
cd /Users/yj/Workspace/yj-apps
git push -u origin fix/haruchi-elapsed-exclude-pause
```

- [ ] **Step 2: PR 생성**

```bash
gh pr create --title "🐛 워치 경과시간에서 일시정지를 뺀다" --body "$(cat <<'BODY'
## 무엇을

하루치 워치가 재는 모든 시간에서 일시정지한 시간을 뺀다. `SegmentTracker` 가 워치의 단일 시계가 되고, 화면·컴플리케이션·구간·저장 총시간이 모두 여기서 나온다.

## 왜

세트 사이에 정지를 누르면 45분 운동이 70분으로 기록된다. 잔디 집계(Phase 2 #1)의 입력이 이 값이라 농도가 통째로 한 단계 밀린다. 하루치는 미출시라 보정할 과거 데이터가 없는 지금이 가장 싼 시점이다.

## 어떻게

- `SegmentTracker` 에 정지 누적(`pause()`/`resume()`)을 넣고 `elapsedSeconds` 가 정지를 뺀다
- `WorkoutViewModel` 이 `session.elapsedSeconds`(틱 카운터) 대신 이 시계를 읽는다
- 저장 총시간은 **구간을 닫은 시점에 붙든 값**이다 — `stopWorkout()` 뒤에 읽으면 HealthKit 마무리 시간만큼 구간 합계보다 커진다

**`Packages/YJKit` 은 건드리지 않았다.** HealthKit 이 세그먼트를 모르므로 구간에서 정지를 빼는 일은 어차피 앱 몫이다. 3앱 공통 결정은 [탐색 문서](Packages/YJKit/docs/ideas/elapsed-seconds-tick-counter.md)에 열린 채로 둔다.

## 검증

- 워치 유닛 테스트 (`HaruchiFitWatchTests`) — 정지 제외, 중복 신호, reset, 구간 합계 == 총시간
- **실기기 미완** — 5분 정지 후 총 시간, WC 재검증 2항목, 손목 30초 내림

## 문서

[스펙](Apps/HaruchiFit/docs/specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md) · [플랜](Apps/HaruchiFit/docs/plans/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01A2YCLgEisEvpKSHNpHfNZv
BODY
)"
```

- [ ] **Step 3: CI 통과 확인 후 머지**

```bash
gh pr checks --watch
gh pr merge --merge --delete-branch
```

---

## 실기기 검증 (머지 후, 사용자)

- [ ] 20분쯤 돌리다 5분 정지 후 재개 → 요약의 총 시간이 **정지를 뺀 값**인지
- [ ] 구간 종목별 분의 합이 총 시간과 맞는지
- [ ] **WC 재검증** — 컴플리케이션 경과시간, 일시정지 시 멈춤 (이 작업이 스냅샷 소스를 바꿨다)
- [ ] 워크아웃 중 손목을 30초 내렸다 올렸을 때 화면 시간이 **건너뛰어 있는지**
      (틱이었을 땐 멈춰 있었다). 이건 탐색 문서의 확인 항목 2번이기도 하다
