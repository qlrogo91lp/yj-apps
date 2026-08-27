# 동기화/세션 라이프사이클 신뢰성 라운드2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Live Activity 좀비 누적과 워치→iOS 종료 미전달을 제거하고, 미러 보기전용 배지를 하단으로 옮기며, 인게임 점수 동기화 끊김을 실기기에서 확정할 진단 계측을 추가한다.

**Architecture:** `LiveActivityService.start`를 멱등(기존+고아 종료 후 요청)으로 만들고, iOS `WorkoutSessionViewModel`이 `LiveActivityControlling` 프로토콜로 주입받게 해 이중 시작을 제거·검증한다. `sendWorkoutEnd`를 `sendReliably`로 바꿔 미도달 시 `transferUserInfo`로 큐잉한다. 배지는 상단→하단(undo 자리)으로 이동. 송·수신 경계에 OSLog를 심어 인게임 점수 끊김 지점을 진단한다.

**Tech Stack:** Swift, SwiftUI, ActivityKit, WatchConnectivity, OSLog, Swift Testing (`@Test`/`#expect`).

## Global Constraints

- 한 파일 = 한 타입. ViewModel은 SwiftUI import 금지(순수 로직). View는 비즈니스 로직 금지.
- Swift 파일 생성/삭제는 파일시스템 조작만으로 충분 (`PBXFileSystemSynchronizedRootGroup`).
- 테스트 프레임워크: Swift Testing. ViewModel 테스트는 `@MainActor` 필수. 테스트명 `대상_행위_예상결과`.
- 테스트는 소스와 같은 폴더에 둘 수 없음 → `iosTests/`·`watchosTests/`에서 소스 구조 미러링.
- SwiftLint line length 150/200. SwiftFormat 4-space, max width 150, alphabetical imports. 커밋 전 `make fix`.
- PR 머지는 일반 merge commit (`gh pr merge <n> --merge --delete-branch`), squash 금지.
- 커밋 메시지 끝: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- ActivityKit/WCSession/OSLog/UI는 유닛테스트 불가 영역 — 해당 변경은 **빌드 통과 + 실기기 2대 수동 확인**으로 검증한다(스펙에서 사전 승인). 시뮬레이터로 "정상" 판정 금지.
- 작업 브랜치: `sync-lifecycle-reliability-round2` (이미 생성, 스펙 커밋됨). 각 Task는 이 브랜치 위 단계 커밋. (구현 시 단계별 PR로 분리 가능)

**빌드 명령:**
```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## File Structure

- `iOSApp/Services/LiveActivityService.swift` — `start` 멱등화, `endAll()` 추가, `LiveActivityControlling` 채택. (Task 1, 2)
- `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` — `liveActivity` 주입, 직접 `LiveActivityService.shared` 호출 제거, `handleIncomingSessionStart` 중복 `start()` 제거. (Task 2)
- `iOSApp/iOSApp.swift` — 앱 시작 시 `endAll()` 1회 호출. (Task 1)
- `Shared/Services/WatchConnectivityService.swift` — `sendWorkoutEnd`를 `sendReliably`로. (Task 3)
- `iOSApp/Features/Match/Score/ScoreView.swift` / `WatchApp/Features/Match/Score/ScoreView.swift` — `MirrorBadge` 하단 이동. (Task 4)
- `Shared/Services/SyncLog.swift` (신규) — OSLog 래퍼. (Task 5)
- `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` — 라이브액티비티 스파이 테스트, stale 종료 테스트. (Task 2, 3)

---

## Task 1: LiveActivityService 멱등 start + 고아 정리

**원인 A 해결의 핵심.** ActivityKit 직접 호출이라 유닛테스트 불가 → 빌드 + 실기기 검증.

**Files:**
- Modify: `iOSApp/Services/LiveActivityService.swift`
- Modify: `iOSApp/iOSApp.swift:10-27` (App init)

**Interfaces:**
- Produces: `LiveActivityService.start(mode:)` (멱등), `LiveActivityService.endAll()` (고아 포함 전체 종료)

- [x] **Step 1: `start(mode:)`를 멱등으로 교체**

`iOSApp/Services/LiveActivityService.swift`의 `start(mode:)`를 아래로 교체. 새 액티비티를 요청한 뒤,
직전 추적 액티비티와 잔존 고아(크래시/이전 실행)를 새로 만든 것만 빼고 모두 종료한다.

```swift
func start(mode: MatchFormat) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let startTime = Date.now
    workoutStartTime = startTime
    let stale = activity
    let attributes = TennisActivityAttributes(matchMode: mode.rawValue)
    var initial = TennisActivityAttributes.ContentState.empty
    initial.workoutStartTime = startTime
    let requested = try? Activity.request(
        attributes: attributes,
        contentState: initial,
        pushType: nil
    )
    activity = requested
    Task {
        await stale?.end(dismissalPolicy: .immediate)
        for other in Activity<TennisActivityAttributes>.activities where other.id != requested?.id {
            await other.end(dismissalPolicy: .immediate)
        }
    }
}
```

- [x] **Step 2: `endAll()` 추가**

같은 파일에 추가. 추적 중인 것 + 모든 고아를 종료한다(앱 시작 시 잔재 청소용).

```swift
func endAll() {
    let current = activity
    activity = nil
    workoutStartTime = nil
    Task {
        await current?.end(dismissalPolicy: .immediate)
        for other in Activity<TennisActivityAttributes>.activities {
            await other.end(dismissalPolicy: .immediate)
        }
    }
}
```

- [x] **Step 3: 앱 시작 시 고아 청소 호출**

`iOSApp/iOSApp.swift`의 `init()` 끝(`MatchPersistenceService.shared.configure(with: context)` 다음 줄)에 추가.
`LiveActivityService`는 `@MainActor`이므로 `Task { @MainActor in }`로 호출.

```swift
        MatchPersistenceService.shared.configure(with: context)
        Task { @MainActor in LiveActivityService.shared.endAll() }
```

- [x] **Step 4: iOS 빌드**

Run: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [x] **Step 5: 포맷/린트 + 커밋**

```bash
make fix
git add iOSApp/Services/LiveActivityService.swift iOSApp/iOSApp.swift
git commit -m "$(cat <<'EOF'
🐛 Live Activity 멱등 start + 고아 정리

start가 기존/고아 액티비티를 종료 후 요청하도록 변경해 좀비 누적 방지.
앱 시작 시 endAll로 이전 실행 잔재 청소.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: LiveActivityControlling 주입 + iOS 이중 start 제거

**원인 A의 두 번째 축(중복 호출).** 여기서 유일한 진짜 유닛테스트(스파이 기반)를 만든다.

**Files:**
- Modify: `iOSApp/Services/LiveActivityService.swift` (프로토콜 채택)
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `LiveActivityService.start(mode:)`, `.update(from:score:)`, `.end()` (Task 1 이후)
- Produces: `protocol LiveActivityControlling`, `WorkoutSessionViewModel.init(liveActivity:)` (기본값 `LiveActivityService.shared`)

- [x] **Step 1: 실패하는 테스트 작성**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` 맨 위(구조체 바깥, import 아래)에 스파이를 추가하고,
구조체 안에 테스트를 추가한다.

```swift
@MainActor
final class LiveActivitySpy: LiveActivityControlling {
    var startCount = 0
    var endCount = 0
    func start(mode: MatchFormat) { startCount += 1 }
    func update(from _: ScoreState, score _: Score) {}
    func end() { endCount += 1 }
}
```

```swift
    @Test @MainActor func remoteSessionStartStartsLiveActivityOnce() {
        let spy = LiveActivitySpy()
        let vm = WorkoutSessionViewModel(liveActivity: spy)
        vm.applyIncomingSessionStartForTest(SessionStartMessage(
            sessionId: UUID(),
            options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false),
            workoutStartDate: Date()
        ))
        #expect(spy.startCount == 1)
    }
```

- [x] **Step 2: 컴파일 실패 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
Expected: 컴파일 실패 — `LiveActivityControlling` 미정의, `init(liveActivity:)` 없음.

- [x] **Step 3: 프로토콜 정의 + 채택**

`iOSApp/Services/LiveActivityService.swift` 상단(`final class LiveActivityService` 위)에 프로토콜 추가하고
클래스가 채택하도록 선언만 바꾼다(메서드 시그니처는 동일).

```swift
@MainActor
protocol LiveActivityControlling {
    func start(mode: MatchFormat)
    func update(from state: ScoreState, score: Score)
    func end()
}
```

```swift
final class LiveActivityService: LiveActivityControlling {
```

- [x] **Step 4: VM에 주입 + 직접 호출 치환 + 중복 start 제거**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`:

(a) 저장 프로퍼티/이니셜라이저 — `connectivity` 선언 아래에 `liveActivity` 추가하고 `init`을 주입식으로:

```swift
    private let connectivity = WatchConnectivityService.shared
    private let liveActivity: LiveActivityControlling
    private(set) var isDriver = false

    init(liveActivity: LiveActivityControlling = LiveActivityService.shared) {
        self.liveActivity = liveActivity
        setupScoreSync()
        setupConnectivityBindings()
    }
```

(b) 본문의 `LiveActivityService.shared.` 5곳을 `liveActivity.`로 치환:
- `:49` `LiveActivityService.shared.update(from: state, score: scoreVM.score)` → `liveActivity.update(from: state, score: scoreVM.score)`
- `:96` `LiveActivityService.shared.end()` → `liveActivity.end()`
- `:167` `LiveActivityService.shared.start(mode: options.mode)` → `liveActivity.start(mode: options.mode)`
- `:189` `LiveActivityService.shared.end()` → `liveActivity.end()`
- `:223` `LiveActivityService.shared.end()` → `liveActivity.end()`
- `:243` `LiveActivityService.shared.update(from: state, score: scoreVM.score)` → `liveActivity.update(from: state, score: scoreVM.score)`

(c) `handleIncomingSessionStart`의 **중복 `start()` 호출 제거**. 현재:

```swift
    private func handleIncomingSessionStart(_ msg: SessionStartMessage) {
        if case .playing = phase {
            guard isDriver, msg.sessionId.uuidString < sessionId.uuidString else { return }
        }
        sessionId = msg.sessionId
        startSession(startDate: msg.workoutStartDate)
        startMatch(options: msg.options, isRemote: true)
        LiveActivityService.shared.start(mode: msg.options.mode)
    }
```

를 마지막 줄 삭제로 변경(`startMatch`가 이미 `liveActivity.start`를 호출함):

```swift
    private func handleIncomingSessionStart(_ msg: SessionStartMessage) {
        if case .playing = phase {
            guard isDriver, msg.sessionId.uuidString < sessionId.uuidString else { return }
        }
        sessionId = msg.sessionId
        startSession(startDate: msg.workoutStartDate)
        startMatch(options: msg.options, isRemote: true)
    }
```

- [x] **Step 5: 테스트 통과 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
Expected: `remoteSessionStartStartsLiveActivityOnce` 및 기존 테스트 전부 PASS.

- [x] **Step 6: 포맷/린트 + 커밋**

```bash
make fix
git add iOSApp/Services/LiveActivityService.swift iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "$(cat <<'EOF'
🐛 iOS 원격 세션 시작 시 Live Activity 이중 start 제거

LiveActivityControlling 주입으로 시작 호출을 검증 가능하게 하고,
handleIncomingSessionStart의 중복 start 호출 제거.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: workoutEnd 신뢰성 전송 + stale 종료 안전 가드 검증

**원인 B 해결.** 전송 경로(WCSession)는 유닛테스트 불가 → 한 줄 변경 + 빌드 + 실기기. 단, reliable 전환의
안전 근거(늦게 온 stale 종료를 sessionId 가드가 무시)를 수신측 테스트로 고정한다.

**Files:**
- Modify: `Shared/Services/WatchConnectivityService.swift:272-277`
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `WorkoutSessionViewModel.handleIncomingWorkoutEndForTest(_:)`, `.currentSessionIdForTest`, `.startMatch(options:isRemote:)`, `.endSession(notifyRemote:)` (기존)

- [x] **Step 1: 안전 가드 테스트 작성 (실패 예상 없음 — 회귀 방지용 고정)**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` 구조체 안에 추가. 종료 신호가 reliable로
큐잉돼 **늦게** 도착해도, 현재 진행 중인(다른 sessionId) 매치를 끝내지 않아야 함을 검증.

```swift
    @Test @MainActor func staleWorkoutEndDoesNotEndCurrentMatch() {
        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        let unrelated = UUID()
        vm.handleIncomingWorkoutEndForTest(unrelated)
        #expect(vm.remoteWorkoutEnded == false)
        guard case .playing = vm.phase else {
            Issue.record("stale 종료는 무시되고 playing 유지되어야 함")
            return
        }
    }
```

- [x] **Step 2: 테스트 실행 (현재 코드로도 PASS — 가드 존재 확인)**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
Expected: `staleWorkoutEndDoesNotEndCurrentMatch` PASS (수신측 sessionId 가드가 이미 무시).

> 참고: iOS는 `handleIncomingSessionStart`에서만 `sessionId`가 바뀌므로, 로컬 driver 매치의 `sessionId`는
> init 값이다. `unrelated`는 그와 다르고 `hasSyncedSession == true`(startMatch가 설정)이므로 가드에서 무시된다.

- [x] **Step 3: `sendWorkoutEnd`를 reliable로 전환**

`Shared/Services/WatchConnectivityService.swift`의 `sendWorkoutEnd`를 `sendRealtimeOnly` → `sendReliably`로 변경.

```swift
    func sendWorkoutEnd(sessionId: UUID) {
        sendReliably([
            "type": WCMessageType.workoutEnd.rawValue,
            "sessionId": sessionId.uuidString,
        ])
    }
```

- [x] **Step 4: 빌드 + 테스트**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
Expected: 전체 PASS.

또 워치 빌드:
Run: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`
Expected: BUILD SUCCEEDED

- [x] **Step 5: 포맷/린트 + 커밋**

```bash
make fix
git add Shared/Services/WatchConnectivityService.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "$(cat <<'EOF'
🐛 workoutEnd를 sendReliably로 전환해 미도달 시 종료 신호 유실 방지

워치 종료 시 폰이 백그라운드여도 transferUserInfo로 큐잉되어 iOS가 종료됨.
늦게 온 stale 종료는 기존 sessionId 가드가 무시(회귀 방지 테스트 추가).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3b: workoutEnd 타임스탬프 staleness 가드 (최종 리뷰 fix)

**최종 whole-branch 리뷰에서 발견된 Important 회귀 수정.** Task 3의 `sendReliably` 전환으로 미도달
종료 신호가 `transferUserInfo`로 큐잉돼 앱 재실행 후까지 살아남고, 뒤늦게 배달되면 `receivedWorkoutEnd`가
세팅돼 다음 매치 진입 시 사용자가 튕긴다. `workoutEnd`에 보낸 시각을 실어, 수신측이 60초 초과 신호를
무시한다. `sentAt`이 없는 구버전 메시지는 기존 동작 보존.

**Files:**
- Modify: `Shared/Services/WatchConnectivityService.swift` (`sendWorkoutEnd`, `handle`, 헬퍼 추가)
- Test: `iosTests/Shared/WatchConnectivityStalenessTests.swift` (신규)

- [x] **Step 1:** `isWorkoutEndStale(sentAt:now:)` staleness 헬퍼 실패 테스트 작성 (nil→false, fresh→false, old→true)
- [x] **Step 2:** 컴파일 실패 확인
- [x] **Step 3:** `static workoutEndStalenessThreshold: TimeInterval = 60` + 결정적(`now` 주입) 헬퍼 구현
- [x] **Step 4:** `sendWorkoutEnd`에 `sentAt` 추가
- [x] **Step 5:** `handle()`의 `workoutEnd` case에서 stale 신호 무시
- [x] **Step 6:** iOS 테스트 + Watch 빌드 통과
- [x] **Step 7:** `make fix` + 커밋 (`9ca5f35`)

---

## Task 4: 미러 보기전용 배지 하단 이동 (iOS/Watch)

**원인 C.** UI 변경 → 빌드 + 시각 확인. undo(driver)와 배지(mirror)는 상호배타라 하단 자리를 공유한다.

**Files:**
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift:59-72`
- Modify: `WatchApp/Features/Match/Score/ScoreView.swift:34-64`

- [x] **Step 1: iOS — 배지를 상단에서 하단(undo 자리)으로 이동**

`iOSApp/Features/Match/Score/ScoreView.swift`에서 상단 배지 블록(현재 `:67-72`)을 제거하고,
undo 블록(현재 `:59-65`)을 driver/mirror 분기로 바꾼다. 기존:

```swift
            if viewModel.score.lastAction != .none {
                VStack {
                    Spacer()
                    UndoButton(action: { viewModel.undo() })
                        .padding(.bottom, 150)
                }
            }

            if !isDriver {
                VStack {
                    MirrorBadge().padding(.top, 8)
                    Spacer()
                }
            }
```

을 아래로 교체(둘 다 하단 같은 위치):

```swift
            if isDriver {
                if viewModel.score.lastAction != .none {
                    VStack {
                        Spacer()
                        UndoButton(action: { viewModel.undo() })
                            .padding(.bottom, 150)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    MirrorBadge()
                        .padding(.bottom, 150)
                }
            }
```

- [x] **Step 2: Watch — 배지를 상단에서 하단(undo overlay 자리)으로 이동**

`WatchApp/Features/Match/Score/ScoreView.swift`에서 상단 배지 블록(현재 `:34-39`)을 제거하고,
하단 undo overlay(현재 `:56-60`)에 mirror일 때 배지를 넣는다. 상단 블록 삭제:

```swift
            if !flowViewModel.isDriver {
                VStack {
                    MirrorBadge().padding(.top, 4)
                    Spacer()
                }
            }
```

→ 삭제. 그리고 `.overlay(alignment: .bottom)` 블록(현재 `:56-61`)을 아래로 교체:

```swift
                .overlay(alignment: .bottom) {
                    if !flowViewModel.isDriver {
                        MirrorBadge()
                            .padding(.bottom, isSmall ? 20 : 25)
                    } else if viewModel.score.lastAction != .none {
                        UndoButton { viewModel.undo() }
                            .padding(.bottom, isSmall ? 20 : 25)
                    }
                }
```

- [x] **Step 3: iOS/Watch 빌드**

Run:
```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```
Expected: 둘 다 BUILD SUCCEEDED

- [x] **Step 4: 포맷/린트 + 커밋**

```bash
make fix
git add iOSApp/Features/Match/Score/ScoreView.swift WatchApp/Features/Match/Score/ScoreView.swift
git commit -m "$(cat <<'EOF'
✨ 미러 보기전용 배지를 하단 undo 자리로 이동

미러 기기는 undo가 표시되지 않으므로 그 하단 공간에 배지를 배치.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 인게임 점수 동기화 진단 OSLog

**원인 D 진단.** 블라인드 수정 없이, 송·수신 경계 값을 실기기에서 확인할 계측만 추가. 릴리스(TestFlight)
빌드라 `privacy: .public` 필수. 원인 확정 후 제거.

**Files:**
- Create: `Shared/Services/SyncLog.swift`
- Modify: `Shared/Services/WatchConnectivityService.swift` (`sendScoreState`)
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (`handleIncomingScoreState`)

**Interfaces:**
- Produces: `enum SyncLog { static func sent(_:); static func recv(_:) }`

- [x] **Step 1: SyncLog 래퍼 생성**

`Shared/Services/SyncLog.swift` 생성. 동적 값은 호출부에서 `privacy: .public`로 보간하므로, 래퍼는
완성된 문자열을 받아 `.public`으로 한 번 더 감싼다.

```swift
import OSLog

enum SyncLog {
    private static let logger = Logger(subsystem: "com.yj.TennisCounter.sync", category: "score")

    static func sent(_ message: String) {
        logger.notice("SENT \(message, privacy: .public)")
    }

    static func recv(_ message: String) {
        logger.notice("RECV \(message, privacy: .public)")
    }
}
```

- [x] **Step 2: 워치 송신 지점 계측**

`Shared/Services/WatchConnectivityService.swift`의 `sendScoreState`에 로그 추가.

```swift
    func sendScoreState(_ state: ScoreState) {
        SyncLog.sent("my=\(state.myScore) your=\(state.yourScore) sets=\(state.completedSets.count) tie=\(state.isTieBreak) reachable=\(WCSession.default.isReachable)")
        sendReliably(state.toDictionary())
    }
```

- [x] **Step 3: iOS 수신 지점 계측**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 `handleIncomingScoreState`에 로그 추가
(가드 통과 여부를 보려고 가드 앞·뒤 모두 찍는다).

```swift
    private func handleIncomingScoreState(_ state: ScoreState) {
        SyncLog.recv("my=\(state.myScore) your=\(state.yourScore) sets=\(state.completedSets.count) isDriver=\(isDriver) phase=\(String(describing: phase))")
        guard !isDriver, case .playing = phase else { return }
        scoreVM.applyRemoteState(state)
        liveActivity.update(from: state, score: scoreVM.score)
    }
```

> 주: Task 2 적용 후이므로 `liveActivity.update`. Task 2 미적용 상태에서 작업하면 `LiveActivityService.shared.update`.

- [x] **Step 4: iOS/Watch 빌드**

Run:
```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```
Expected: 둘 다 BUILD SUCCEEDED

- [x] **Step 5: 포맷/린트 + 커밋**

```bash
make fix
git add Shared/Services/SyncLog.swift Shared/Services/WatchConnectivityService.swift iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
git commit -m "$(cat <<'EOF'
🔍 인게임 점수 동기화 진단용 OSLog 추가 (워치 송신 / iOS 수신)

subsystem com.yj.TennisCounter.sync, privacy:.public.
TestFlight 진단 후 제거 예정.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 진단 빌드 검증 (수동, TestFlight 2대)

코드 변경 없음. Task 1~5를 한 빌드로 TestFlight 업로드 후 실기기 2대로 검증.

- [ ] **Step 1: 아카이브 + TestFlight 업로드** (Xcode Organizer 또는 기존 배포 플로우)

- [ ] **Step 2: Live Activity** — 매치 시작 시 잠금화면에 **1개만** 뜨고, 종료/홈 이탈 시 사라지는지. 왕복해도 안 쌓이는지.

- [ ] **Step 3: 워치→iOS 종료** — 폰을 백그라운드로 둔 채 워치에서 운동 종료 → iOS도 세션 종료되고 Live Activity 사라지는지.

- [ ] **Step 4: 보기전용 배지** — 미러 기기 점수 화면 **하단**에 배지 표시, driver는 undo 표시되는지.

- [ ] **Step 5: 인게임 점수 진단** — 워치(driver)에서 게임 안 끝나는 점수 1개(15) 입력 → iOS 화면 확인. Mac에 기기 연결 후 Console.app에서 subsystem `com.yj.TennisCounter.sync` 필터로 워치 `SENT my=15` / iOS `RECV my=?` 교차 확인.
  - iOS가 즉시 15 표시 → 버그 없음. **Task 5 로그 제거 커밋** 후 종결.
  - 0에 멈춤 → 로그로 끊김 지점(미송신/미수신/미적용) 확정 → **후속 plan으로 실제 수정**.

- [ ] **Step 6: 운동 경과시간(2차)** — 워치 pause 시 양 기기 경과시간 드리프트 관찰. 재현되면 후속 항목으로 기록.

---

## Self-Review (작성자 체크 완료)

- **스펙 커버리지:** 원인 A→Task 1·2, B→Task 3, C→Task 4, D→Task 5·6, E→Task 6 Step 6. 결정표 1~5 모두 반영.
- **플레이스홀더:** 없음. 모든 코드 스텝에 실제 코드 포함.
- **타입 일관성:** `LiveActivityControlling`(start/update/end) — 프로토콜·스파이·VM 주입 시그니처 일치. `SyncLog.sent/recv` 정의·호출 일치. `endAll()` 정의(Task 1)·호출(Task 1 Step 3) 일치.
- **테스트 한계 명시:** ActivityKit/WCSession/OSLog/UI는 유닛테스트 불가 — 빌드+실기기로 검증(스펙 사전 승인). 유일한 신규 유닛테스트는 Task 2(스파이)·Task 3(가드 고정).
