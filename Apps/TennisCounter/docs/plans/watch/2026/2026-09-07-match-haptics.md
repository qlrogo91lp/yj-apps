# 워치 경기 햅틱 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워치에서 경기 중 일어나는 이벤트(포인트·되돌리기·게임·세트·매치 종료·저장 결과·폰의 일시정지 명령)를 화면을 보지 않고도 촉각으로 구분할 수 있게 한다.

**Architecture:** 이벤트를 `MatchHapticEvent` enum 으로 정의하고, `WKHapticType` 매핑은 `MatchHaptics` 한 파일만 안다. ViewModel 은 `MatchHapticsPlaying` 프로토콜로 주입받아 `play(_:)` 만 부르므로 테스트는 스파이로 "어떤 이벤트가 몇 번" 을 센다. `ScoreViewModel.addPoint` 한 번에 포인트→게임→세트→매치가 연쇄될 수 있어, 판정 메서드들이 이벤트를 **반환**하고 `addPoint` 가 최상위 이벤트 하나만 재생한다.

**Tech Stack:** watchOS / SwiftUI / WatchKit `WKInterfaceDevice` / Swift Testing

**Spec:** 별도 스펙 없음 — 2026-09-07 대화에서 확정. 아래 §결정 사항.

## 결정 사항 (2026-09-07)

| 논점 | 결정 | 이유 |
|---|---|---|
| 플랫폼 | **워치 전용** | 테니스는 화면을 못 보는 상황이 기본. iOS 는 눈으로 보며 조작한다 |
| 포인트 내/상대 구분 | **안 함** — 둘 다 `.click` (A안) | 위아래 버튼 위치로 이미 구분된다. 되돌리기 `.directionDown` 을 골프와 같게 유지 |
| 연쇄 이벤트 | **최상위 하나만** | 포인트→게임→세트→매치가 한 탭에 겹치면 뭉개진다 |
| 저장 ACK (#6) | 넣는다 — `.success`/`.failure` | 워치→폰 저장은 비동기라 손목을 내린 뒤 결과가 온다. 실패를 놓치면 기록이 날아간다 |
| 폰 일시정지 명령 (#7) | 넣는다 — `.stop`/`.start` | 폰에서 눌렀는데 워치가 조용하면 멈춘 줄 모른다. 워치 자체 버튼은 눈으로 보니 제외 |
| 타이브레이크 진입 (#8) | **보류** — `.gameWon` 으로 처리 | 규칙이 바뀌는 순간이지만 화면을 보게 되는 순간이기도 하다 |
| 미러 상태 (`applyRemoteState`) | 조용 | 폰으로 치는 사람의 보조 화면. `addPoint` 를 안 타니 별도 분기 없이 자동 |
| 화면 조작 버튼 (모드 선택·취소·다시하기) | 없음 | 눈으로 보고 누른다 |
| 설정 연동 | **이번엔 안 함** | 저장 위치(워치 로컬 vs iOS 동기화)가 설정 페이지(작업 #8) 결정에 달렸다. §후속 참고 |

**햅틱 어휘** — 골프·하루치와 같은 단어를 쓴다.

| 이벤트 | `WKHapticType` | 빈도 |
|---|---|---|
| `.point` | `.click` | 매 포인트 (~20초) |
| `.undo` | `.directionDown` | 가끔 |
| `.gameWon` | `.start` | 4~6 포인트마다 |
| `.setWon` | `.notification` | 세트마다 |
| `.matchFinished(.win)` | `.success` | 경기당 1회 |
| `.matchFinished(.loss)` | `.failure` | |
| `.matchFinished(.draw)` | `.notification` | |
| `.saveSucceeded` / `.saveFailed` | `.success` / `.failure` | 저장당 1회 |
| `.paused` / `.resumed` | `.stop` / `.start` | 폰 명령 시 |

## Global Constraints

- **iOS 타깃·`Shared/` 는 건드리지 않는다.** 모든 변경은 `WatchApp/` 과 `watchosTests/` 안이다.
- ViewModel 은 `WatchKit` 을 import 하지 않는다 — `MatchHapticsPlaying` 프로토콜만 안다. `WKInterfaceDevice` 는 `MatchHaptics.swift` 한 파일에만 나온다.
- 기존 테스트가 전부 그대로 통과해야 한다. 주입 파라미터는 **기본값**을 줘서 기존 호출부·테스트가 안 바뀌게 한다.
- 테스트 프레임워크는 **Swift Testing**, ViewModel 테스트는 `@MainActor`. 테스트 모듈은 `@testable import TennisCounter_Watch_App`.
- SwiftLint: line length 경고 150 / 오류 200. SwiftFormat: 4-space indent, imports 알파벳순, trailing comma.
- 브랜치 **`feat/ralli`**, 메인 체크아웃. 커밋은 gitmoji (`✨` 기능, `✅` 테스트).
- 각 태스크는 **실패하는 테스트 → 실패 확인 → 최소 구현 → 통과 확인 → 커밋**.

**빌드·테스트 명령** (루트에서)

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

# 워치 테스트 전체 (워치 스킴엔 iOS 테스트 타깃도 들어 있어 -only-testing 필수)
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:watchosTests test

# 단일 파일
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:watchosTests/ScoreViewModelHapticsTests test

make lint && make format
```

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `WatchApp/Services/MatchHaptics.swift` | 생성 | `MatchHapticEvent` · `MatchHapticsPlaying` · `MatchHaptics`(WKHapticType 매핑) |
| `watchosTests/Services/MatchHapticsTests.swift` | 생성 | 매핑 표 검증 |
| `watchosTests/Support/HapticsSpy.swift` | 생성 | 테스트 공용 스파이 |
| `WatchApp/Features/Match/Score/ScoreViewModel.swift` | 수정 | `haptics` 주입, `addPoint`/`undo` 재생, 판정 메서드가 이벤트 반환 |
| `watchosTests/Match/ScoreViewModelHapticsTests.swift` | 생성 | 점수 이벤트 6개 시나리오 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 수정 | `haptics` 주입·전달, 저장 ACK·타임아웃·pause 명령 재생 |
| `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 수정 | 저장·pause 햅틱 테스트 5개 추가 |

`WatchApp/Services/` 폴더가 없으면 만든다 (골프는 `WatchApp/Services/` 에 `WorkoutConfiguration+Golf` 를 둔다 — 같은 자리).

---

### Task 1: `MatchHaptics` — 이벤트·프로토콜·매핑

**Files:**
- Create: `Apps/TennisCounter/WatchApp/Services/MatchHaptics.swift`
- Create: `Apps/TennisCounter/watchosTests/Services/MatchHapticsTests.swift`
- Create: `Apps/TennisCounter/watchosTests/Support/HapticsSpy.swift`

**Interfaces:**
- Produces:
  - `enum MatchHapticEvent: Equatable { case point, undo, gameWon, setWon, matchFinished(MatchResult), saveSucceeded, saveFailed, paused, resumed }`
  - `protocol MatchHapticsPlaying { func play(_ event: MatchHapticEvent) }`
  - `struct MatchHaptics: MatchHapticsPlaying` + `static func type(for: MatchHapticEvent) -> WKHapticType`
  - 테스트용 `final class HapticsSpy: MatchHapticsPlaying { var played: [MatchHapticEvent] }`

- [ ] **Step 1: 매핑 테스트 작성**

`Apps/TennisCounter/watchosTests/Services/MatchHapticsTests.swift`:

```swift
@testable import TennisCounter_Watch_App
import Testing
import WatchKit

struct MatchHapticsTests {
    @Test func scoreEventsUseSharedVocabularyWithGolf() {
        #expect(MatchHaptics.type(for: .point) == .click)
        #expect(MatchHaptics.type(for: .undo) == .directionDown)
        #expect(MatchHaptics.type(for: .gameWon) == .start)
        #expect(MatchHaptics.type(for: .setWon) == .notification)
    }

    @Test func matchResultMapsToSuccessFailureNotification() {
        #expect(MatchHaptics.type(for: .matchFinished(.win)) == .success)
        #expect(MatchHaptics.type(for: .matchFinished(.loss)) == .failure)
        #expect(MatchHaptics.type(for: .matchFinished(.draw)) == .notification)
    }

    @Test func saveAndPauseEvents() {
        #expect(MatchHaptics.type(for: .saveSucceeded) == .success)
        #expect(MatchHaptics.type(for: .saveFailed) == .failure)
        #expect(MatchHaptics.type(for: .paused) == .stop)
        #expect(MatchHaptics.type(for: .resumed) == .start)
    }
}
```

- [ ] **Step 2: 스파이 작성**

`Apps/TennisCounter/watchosTests/Support/HapticsSpy.swift`:

```swift
@testable import TennisCounter_Watch_App

/// 어떤 햅틱 이벤트가 어떤 순서로 재생됐는지 기록한다.
final class HapticsSpy: MatchHapticsPlaying {
    private(set) var played: [MatchHapticEvent] = []

    func play(_ event: MatchHapticEvent) {
        played.append(event)
    }
}
```

- [ ] **Step 3: 실패 확인**

Run:
```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:watchosTests/MatchHapticsTests test 2>&1 | grep -E "error:" | head -3
```
Expected: `cannot find 'MatchHaptics' in scope`.

- [ ] **Step 4: 구현**

`Apps/TennisCounter/WatchApp/Services/MatchHaptics.swift`:

```swift
import WatchKit

/// 경기 중 촉각으로 구분해야 하는 이벤트. 어떤 `WKHapticType` 으로 울릴지는 `MatchHaptics` 만 안다.
enum MatchHapticEvent: Equatable {
    case point
    case undo
    case gameWon
    case setWon
    case matchFinished(MatchResult)
    case saveSucceeded
    case saveFailed
    case paused
    case resumed
}

protocol MatchHapticsPlaying {
    func play(_ event: MatchHapticEvent)
}

/// 어휘는 골프·하루치와 맞춘다 — `.click` 은 입력, `.directionDown` 은 되돌리기.
/// 자주 오는 이벤트일수록 가볍게, 드문 이벤트일수록 세게.
///
/// 설정 연동(작업 #8)은 `play(_:)` 첫 줄에서 건다 — 이벤트가 여기까지는 그대로 흘러오고 마지막 관문에서 거른다.
struct MatchHaptics: MatchHapticsPlaying {
    func play(_ event: MatchHapticEvent) {
        WKInterfaceDevice.current().play(Self.type(for: event))
    }

    static func type(for event: MatchHapticEvent) -> WKHapticType {
        switch event {
        case .point: .click
        case .undo: .directionDown
        case .gameWon: .start
        case .setWon: .notification
        case .matchFinished(.win): .success
        case .matchFinished(.loss): .failure
        case .matchFinished(.draw): .notification
        case .saveSucceeded: .success
        case .saveFailed: .failure
        case .paused: .stop
        case .resumed: .start
        }
    }
}
```

- [ ] **Step 5: 통과 확인**

Run: Step 3 명령에서 `grep -E "passed|failed"`.
Expected: `MatchHapticsTests` 3 tests passed.

- [ ] **Step 6: 린트 + 커밋**

```bash
make lint && make format
git add Apps/TennisCounter/WatchApp/Services/MatchHaptics.swift \
        Apps/TennisCounter/watchosTests/Services/MatchHapticsTests.swift \
        Apps/TennisCounter/watchosTests/Support/HapticsSpy.swift
git commit -m "✨ MatchHaptics — 워치 경기 이벤트와 햅틱 패턴 매핑"
```

---

### Task 2: `ScoreViewModel` — 점수 이벤트 재생, 연쇄 시 최상위 하나만

**Files:**
- Modify: `Apps/TennisCounter/WatchApp/Features/Match/Score/ScoreViewModel.swift`
- Create: `Apps/TennisCounter/watchosTests/Match/ScoreViewModelHapticsTests.swift`

**Interfaces:**
- Consumes: `MatchHapticsPlaying`, `MatchHapticEvent`, `HapticsSpy` (Task 1)
- Produces: `ScoreViewModel.init(options: MatchOptions, haptics: MatchHapticsPlaying = MatchHaptics())`. 기존 `init(options:)` 호출부는 그대로 컴파일된다.

- [ ] **Step 1: 실패하는 테스트 작성**

`Apps/TennisCounter/watchosTests/Match/ScoreViewModelHapticsTests.swift`:

```swift
@testable import TennisCounter_Watch_App
import Testing

/// 포인트 4개로 게임 하나를 끝내는 헬퍼. noAd 라 듀스 없이 4연속이면 게임이다.
private func winGame(_ vm: ScoreViewModel, for side: PlayerSide) {
    for _ in 0 ..< 4 { vm.addPoint(side) }
}

struct ScoreViewModelHapticsTests {
    private let oneSet = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)

    @Test @MainActor func pointPlaysClickForBothSides() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        vm.addPoint(.me)
        vm.addPoint(.opponent)

        #expect(spy.played == [.point, .point])
    }

    @Test @MainActor func undoPlaysUndo() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)
        vm.addPoint(.me)

        vm.undo()

        #expect(spy.played.last == .undo)
    }

    @Test @MainActor func undoWithNothingToUndoStaysSilent() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        vm.undo()

        #expect(spy.played.isEmpty)
    }

    @Test @MainActor func gameWinningPointPlaysGameWonOnly() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        winGame(vm, for: .me)

        // 마지막 포인트는 .point 가 아니라 .gameWon 하나만
        #expect(spy.played == [.point, .point, .point, .gameWon])
    }

    @Test @MainActor func setWinningPointPlaysSetWonOnly() {
        let spy = HapticsSpy()
        // 세트 하나로 매치가 끝나지 않도록 3세트 매치
        let vm = ScoreViewModel(options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
                                haptics: spy)

        for _ in 0 ..< 6 { winGame(vm, for: .me) } // 6-0 세트

        #expect(spy.played.last == .setWon)
        #expect(spy.played.filter { $0 == .gameWon }.count == 5) // 6번째 게임은 .setWon 으로 흡수
        #expect(vm.mySetScore == 1)
    }

    @Test @MainActor func matchWinningPointPlaysMatchFinishedOnly() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        for _ in 0 ..< 6 { winGame(vm, for: .me) } // 원세트 6-0 → 매치 종료

        #expect(spy.played.last == .matchFinished(.win))
        #expect(!spy.played.contains(.setWon)) // 세트·게임은 매치 종료에 흡수
    }

    @Test @MainActor func opponentMatchWinPlaysLoss() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        for _ in 0 ..< 6 { winGame(vm, for: .opponent) }

        #expect(spy.played.last == .matchFinished(.loss))
    }

    @Test @MainActor func remoteStateStaysSilent() {
        let spy = HapticsSpy()
        let vm = ScoreViewModel(options: oneSet, haptics: spy)

        vm.applyRemoteState(ScoreState(myScore: 1, yourScore: 0,
                                       myGameScore: 3, yourGameScore: 2,
                                       mySetScore: 0, yourSetScore: 0,
                                       completedSets: [], isTieBreak: false))

        #expect(spy.played.isEmpty)
    }
}
```

`ScoreState` 는 `Shared/Services/ConnectivityMessages.swift` 의 memberwise init (필드 순서: `myScore, yourScore, myGameScore, yourGameScore, mySetScore, yourSetScore, completedSets: [[Int]], isTieBreak`).

- [ ] **Step 2: 실패 확인**

Run:
```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:watchosTests/ScoreViewModelHapticsTests test 2>&1 | grep -E "error:" | head -3
```
Expected: `extra argument 'haptics' in call`.

- [ ] **Step 3: 구현**

`ScoreViewModel.swift` 변경 4곳.

(a) 프로퍼티·init — `private var cancellables` 아래에 추가하고 init 시그니처를 바꾼다:

```swift
    private let haptics: MatchHapticsPlaying

    init(options: MatchOptions, haptics: MatchHapticsPlaying = MatchHaptics()) {
        self.options = options
        self.haptics = haptics
        score.noAdRule = options.noAdRule
```
(기존 init 본문의 나머지 줄은 그대로.)

(b) `addPoint` — 판정 결과를 이벤트로 받아 마지막에 하나만 재생:

```swift
    func addPoint(_ side: PlayerSide) {
        snapshots.append(captureSnapshot())
        var event: MatchHapticEvent = .point
        if score.addPoint(side) != nil {
            withAnimation(.bouncy) {
                if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
            }
            score.reset()
            // 게임 → 세트 → 매치가 한 포인트에 겹칠 수 있다. 가장 상위 이벤트 하나만 울린다.
            event = checkSetUpdate() ?? .gameWon
        }
        haptics.play(event)
        onStateChanged?()
    }
```

(c) `undo` — 되돌릴 게 있을 때만:

```swift
    func undo() {
        guard let snapshot = snapshots.popLast() else { return }
        apply(snapshot)
        haptics.play(.undo)
        onStateChanged?()
    }
```

(d) `checkSetUpdate` / `finalizeSet` — 반환값 추가. 로직은 그대로, `return` 에 이벤트만 실린다:

```swift
    /// 세트·매치 판정. 세트나 매치가 끝났으면 그 이벤트를, 아니면 nil 을 돌려준다.
    /// 타이브레이크 진입은 nil — 게임 획득 햅틱으로 충분하다 (2026-09-07 보류 결정).
    private func checkSetUpdate() -> MatchHapticEvent? {
        let threshold = options.gameThreshold
        let my = myGameScore, your = yourGameScore

        if tieBreakInProgress {
            if (my == threshold + 1 && your == threshold) || (your == threshold + 1 && my == threshold) {
                tieBreakInProgress = false
                let winner: PlayerSide = my == threshold + 1 ? .me : .opponent
                return finalizeSet(winner: winner)
            }
            return nil
        }

        if my == threshold, your == threshold {
            if options.noTieRule {
                completedSets.append(SetScore(my: my, your: your))
                onMatchFinished?(.draw, completedSets)
                return .matchFinished(.draw)
            } else {
                score.setTieBreakMode()
                tieBreakInProgress = true
            }
            return nil
        }

        let maxG = max(my, your), minG = min(my, your)
        guard maxG >= threshold, (maxG - minG) >= 2 else { return nil }
        return finalizeSet(winner: my > your ? .me : .opponent)
    }

    private func finalizeSet(winner: PlayerSide) -> MatchHapticEvent {
        completedSets.append(SetScore(my: myGameScore, your: yourGameScore))
        if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0

        let setsToWin = options.mode.setsToWin
        if mySetScore >= setsToWin {
            onMatchFinished?(.win, completedSets)
            return .matchFinished(.win)
        } else if yourSetScore >= setsToWin {
            onMatchFinished?(.loss, completedSets)
            return .matchFinished(.loss)
        }
        return .setWon
    }
```

- [ ] **Step 4: 통과 확인 — 새 테스트 + 기존 테스트**

Run:
```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:watchosTests/ScoreViewModelHapticsTests \
  -only-testing:watchosTests/ScoreViewModelTests test 2>&1 | grep -E "passed|failed"
```
Expected: 두 스위트 전부 passed. 기존 `ScoreViewModelTests` 는 기본 `MatchHaptics()` 로 생성되는데 시뮬레이터에서 `WKInterfaceDevice.play` 는 no-op 이라 안전하다.

- [ ] **Step 5: 린트 + 커밋**

```bash
make lint && make format
git add Apps/TennisCounter/WatchApp/Features/Match/Score/ScoreViewModel.swift \
        Apps/TennisCounter/watchosTests/Match/ScoreViewModelHapticsTests.swift
git commit -m "✨ 워치 점수 이벤트에 햅틱 — 연쇄 시 최상위 하나만 울린다"
```

---

### Task 3: `WorkoutSessionViewModel` — 저장 ACK·폰 일시정지 명령

**Files:**
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `Apps/TennisCounter/watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `MatchHapticsPlaying`, `HapticsSpy`, `ScoreViewModel.init(options:haptics:)` (Task 1·2)
- Produces: `WorkoutSessionViewModel.init(healthKit:metricsThrottle:ackTimeoutSeconds:haptics:)` — `haptics` 기본값 `MatchHaptics()`. 같은 인스턴스를 `scoreVM` 에도 넘긴다.

- [ ] **Step 1: 실패하는 테스트 추가**

`WorkoutSessionViewModelTests.swift` 끝, 마지막 `}` 앞에 추가:

```swift
    // MARK: - Haptics

    @Test @MainActor func saveAckSuccessPlaysSaveSucceeded() {
        let spy = HapticsSpy()
        let vm = WorkoutSessionViewModel(haptics: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()

        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: true))

        #expect(spy.played.last == .saveSucceeded)
    }

    @Test @MainActor func saveAckFailurePlaysSaveFailed() {
        let spy = HapticsSpy()
        let vm = WorkoutSessionViewModel(haptics: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()

        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: vm.activeSessionId, success: false))

        #expect(spy.played.last == .saveFailed)
    }

    @Test @MainActor func saveAckTimeoutPlaysSaveFailed() async throws {
        let spy = HapticsSpy()
        let vm = WorkoutSessionViewModel(ackTimeoutSeconds: 0.05, haptics: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()

        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(spy.played.last == .saveFailed)
    }

    @Test @MainActor func mismatchedSaveAckStaysSilent() {
        let spy = HapticsSpy()
        let vm = WorkoutSessionViewModel(haptics: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.saveCurrentMatch()

        vm.handleMatchSaveResultForTest(MatchSaveResultMessage(sessionId: UUID(), success: true))

        #expect(!spy.played.contains(.saveSucceeded))
    }

    @Test @MainActor func remotePauseAndResumeCommandsPlayStopAndStart() {
        let spy = HapticsSpy()
        let vm = WorkoutSessionViewModel(haptics: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        vm.handleIncomingPauseCommandForTest(WorkoutPauseMessage(sessionId: vm.activeSessionIdForTest, shouldPause: true))
        vm.handleIncomingPauseCommandForTest(WorkoutPauseMessage(sessionId: vm.activeSessionIdForTest, shouldPause: false))

        #expect(spy.played.suffix(2) == [.paused, .resumed])
    }

    @Test @MainActor func mismatchedPauseCommandStaysSilent() {
        let spy = HapticsSpy()
        let vm = WorkoutSessionViewModel(haptics: spy)
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))

        vm.handleIncomingPauseCommandForTest(WorkoutPauseMessage(sessionId: UUID(), shouldPause: true))

        #expect(!spy.played.contains(.paused))
    }
```

- [ ] **Step 2: 실패 확인**

Run:
```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:watchosTests/WorkoutSessionViewModelTests test 2>&1 | grep -E "error:" | head -3
```
Expected: `extra argument 'haptics' in call`.

- [ ] **Step 3: 구현**

`WorkoutSessionViewModel.swift` 변경 4곳.

(a) `scoreVM` 을 init 에서 만들도록 바꾸고 `haptics` 를 보관한다. 22행의

```swift
    let scoreVM = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
```
→
```swift
    let scoreVM: ScoreViewModel
    private let haptics: MatchHapticsPlaying
```

(b) init 시그니처와 첫 줄들:

```swift
    init(healthKit: WorkoutSessionService = WorkoutSessionService(configuration: .tennis),
         metricsThrottle: TimeInterval = 5, ackTimeoutSeconds: TimeInterval = 8,
         haptics: MatchHapticsPlaying = MatchHaptics())
    {
        self.healthKit = healthKit
        self.metricsThrottle = metricsThrottle
        self.ackTimeoutSeconds = ackTimeoutSeconds
        self.haptics = haptics
        scoreVM = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false),
                                 haptics: haptics)
```
(init 본문 나머지는 그대로. `scoreVM` 을 쓰는 `setupScoreSync()` 호출이 프로퍼티 초기화 **뒤**에 오는지 확인한다 — 지금도 init 안에서 부르므로 순서만 지키면 된다.)

(c) 저장 ACK — `handleMatchSaveResult` 마지막 줄과 `saveCurrentMatch` 의 타임아웃 클로저:

```swift
    private func handleMatchSaveResult(_ result: MatchSaveResultMessage) {
        guard result.sessionId == activeSessionId else { return }
        guard saveAckState == .pending || saveAckState == .failed else { return }
        connectivity.receivedMatchSaveResult = nil
        saveAckState = result.success ? .succeeded : .failed
        haptics.play(result.success ? .saveSucceeded : .saveFailed)
    }
```

```swift
        DispatchQueue.main.asyncAfter(deadline: .now() + ackTimeoutSeconds) { [weak self] in
            guard let self, saveAttemptToken == token, saveAckState == .pending else { return }
            saveAckState = .failed
            haptics.play(.saveFailed)
        }
```

(d) 폰 명령 — `handleIncomingPauseCommand`:

```swift
    @discardableResult
    private func handleIncomingPauseCommand(_ msg: WorkoutPauseMessage) -> Bool {
        guard msg.sessionId == activeSessionId else { return false }
        connectivity.receivedPauseCommand = nil
        if msg.shouldPause {
            healthKit.pauseWorkout()
            haptics.play(.paused)
        } else {
            healthKit.resumeWorkout()
            haptics.play(.resumed)
        }
        return true
    }
```

워치 자체 버튼(`pauseWorkout()`/`resumeWorkout()`)은 건드리지 않는다 — 사용자가 화면을 보며 누른다.

- [ ] **Step 4: 워치 테스트 전체 통과 확인**

Run:
```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" \
  -only-testing:watchosTests test 2>&1 | grep -E "Test Suite .* (passed|failed)" | tail -5
```
Expected: 전부 passed. 기존 테스트는 기본 `MatchHaptics()` 로 돌고 시뮬레이터에서 no-op.

- [ ] **Step 5: iOS 스킴도 빌드되는지**

`Shared/` 는 안 건드렸지만 확인한다.

Run:
```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -2
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: 린트 + 커밋**

```bash
make lint && make format
git add Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift \
        Apps/TennisCounter/watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "✨ 워치 저장 결과·폰 일시정지 명령에 햅틱"
```

---

### Task 4: 실기기 확인 (사람이 한다)

시뮬레이터는 햅틱을 재생하지 않는다. 실제 워치에서:

- [ ] 포인트 탭 — 가벼운 클릭. 두 버튼이 같은 느낌
- [ ] 되돌리기 — "내려가는" 느낌. 포인트와 구분되는지
- [ ] 게임 획득 포인트 — 클릭이 **아니라** `.start` 하나만 오는지
- [ ] 세트 획득 — `.notification`. 게임보다 확실히 큰지
- [ ] 매치 종료 — 승/패 다르게 오는지. 결과 화면 전환과 같은 순간인지
- [ ] 저장 → 폰 ACK — 손목을 내린 상태에서 `.success` 가 오는지. 폰 앱을 죽이고 저장 → 8초 뒤 `.failure`
- [ ] 폰에서 일시정지/재개 — 워치가 `.stop`/`.start` 로 반응하는지
- [ ] 폰으로 경기 진행(워치 미러) — 워치가 **조용한지**

패턴이 마음에 안 들면 `MatchHaptics.type(for:)` 표만 바꾼다. 다른 파일은 건드릴 이유가 없다.

---

## 후속 (이번 커밋에 넣지 않는다)

- **설정 연동 (작업 #8)** — 진입점은 `MatchHaptics.play(_:)` 첫 줄. `guard preferences.isEnabled(for: event) else { return }` 한 줄이면 전체 on/off 든 그룹별(점수 / 저장 알림 / 일시정지 알림)이든 걸린다. `MatchHapticEvent` 케이스가 곧 설정 항목이다. 값을 워치 로컬에 둘지 iOS 설정 페이지에서 `applicationContext` 로 동기화할지는 #8 에서 정한다.
- **타이브레이크 진입 (#8 보류)** — 넣기로 하면 `checkSetUpdate` 의 `score.setTieBreakMode()` 분기에서 `.tieBreakStarted` 를 반환하고 매핑 표에 `.retry` 한 줄.
- **골프·하루치 공용화** — 세 앱이 같은 어휘를 쓰게 되면 `MatchHapticsPlaying` 패턴을 YJKit `WorkoutUI` 로 올릴 수 있다. 지금은 앱마다 이벤트가 달라 시기상조.

## Self-Review

- 결정 사항 → 워치 전용(파일 구조 전체), A안(Task 1 매핑·Task 2 테스트 `pointPlaysClickForBothSides`), 최상위 하나만(Task 2 `addPoint` + 테스트 3개), #6(Task 3 c), #7(Task 3 d), #8 보류(`checkSetUpdate` nil 반환 + 후속), 미러 조용(Task 2 `remoteStateStaysSilent`), 설정 후속 ✅
- 타입 일관성 — `MatchHapticEvent` 케이스 9개가 Task 1 정의·매핑·테스트, Task 2·3 사용에서 같은 이름 ✅. `HapticsSpy.played` 를 Task 2·3 이 같은 이름으로 읽음 ✅. `init(options:haptics:)` / `init(healthKit:metricsThrottle:ackTimeoutSeconds:haptics:)` 정의와 호출 일치 ✅
- 제약 — ViewModel 은 `WatchKit` import 없음 (Task 2·3 코드에 없음) ✅. 기본값 주입으로 기존 테스트 무변경 ✅
- 플레이스홀더 없음. `ScoreState` fixture 는 `ConnectivityMessages.swift` 의 memberwise init 순서로 확인했다.
