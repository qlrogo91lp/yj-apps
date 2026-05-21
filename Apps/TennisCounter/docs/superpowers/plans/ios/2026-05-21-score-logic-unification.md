# Score Logic Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS/Watch ScoreViewModel 로직을 통일하고, 게임 임계값(5/6) 선택, 무승부(draw) 경로 완성, 설정 저장을 구현한다.

**Architecture:** 세트 완료 판정을 Watch 방식(`tieBreakInProgress` 플래그 + `checkSetUpdate()`)으로 통일. iOS `matchResult: MatchResult?`로 win/loss/draw를 단일 프로퍼티로 관리. `gameThreshold` 를 `MatchOptions`에 추가해 5/6게임 선택을 양 플랫폼에 전파.

**Tech Stack:** Swift, SwiftUI, Combine, UserDefaults, WatchConnectivity

---

## 파일 맵

| 파일 | 작업 |
|------|------|
| `Shared/Models/MatchOptions.swift` | `gameThreshold: Int` 추가 (default 6) |
| `Shared/Services/WatchConnectivityService.swift` | `SessionStartMessage`에 `gameThreshold` 직렬화 추가 |
| `iOSApp/Features/Match/Mode/ModeViewModel.swift` | `gameThreshold` + UserDefaults 전체 설정 저장 |
| `WatchApp/Features/Match/Mode/ModeViewModel.swift` | 동일 |
| `iOSApp/Features/Match/Score/ScoreViewModel.swift` | `checkSetUpdate()` 통일, `matchResult` 도입, draw 경로 |
| `WatchApp/Features/Match/Score/ScoreViewModel.swift` | `checkSetUpdate()` 버그 수정, draw 경로, `gameThreshold` |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `finishMatch(result:)` 시그니처 변경 |
| `iOSApp/Features/Match/Score/ScoreView.swift` | `onMatchFinished` 콜백 타입 변경, 컴포넌트 이름 변경 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` | `finishMatch` 호출 업데이트 |
| `iOSApp/Features/Match/Mode/ModeView.swift` | Segmented Picker 추가 |
| `WatchApp/Features/Match/Mode/ModeView.swift` | Segmented Picker 추가 |
| `iOSApp/Features/Match/Score/Components/PlayerScoreZone.swift` | 파일명·타입명 → `PlayerPointZone` |
| `WatchApp/Features/Match/Score/Components/PlayerScoreButton.swift` | 파일명·타입명 → `PlayerPointButton` |
| `iOSApp/en.lproj/Localizable.strings` | `mode_game_threshold` 키 추가 |
| `iOSApp/ko.lproj/Localizable.strings` | 동일 |
| `WatchApp/en.lproj/Localizable.strings` | 동일 |
| `WatchApp/ko.lproj/Localizable.strings` | 동일 |
| `iosTests/Match/ScoreViewModelTests.swift` | ScoreViewModel 버그 재현 + 신규 기능 테스트 |
| `watchosTests/Match/ScoreViewModelTests.swift` | 동일 |

---

## Task 1: MatchOptions + SessionStartMessage — gameThreshold 추가

**Files:**
- Modify: `Shared/Models/MatchOptions.swift`
- Modify: `Shared/Services/WatchConnectivityService.swift`

- [ ] **Step 1: MatchOptions에 gameThreshold 추가 (default 6, 기존 호출부 변경 불필요)**

`Shared/Models/MatchOptions.swift` 전체를 아래로 교체:

```swift
import Foundation

struct MatchOptions {
    let mode: MatchFormat
    let noAdRule: Bool
    let noTieRule: Bool
    let gameThreshold: Int

    init(mode: MatchFormat, noAdRule: Bool, noTieRule: Bool, gameThreshold: Int = 6) {
        self.mode = mode
        self.noAdRule = noAdRule
        self.noTieRule = noTieRule
        self.gameThreshold = gameThreshold
    }
}
```

- [ ] **Step 2: SessionStartMessage에 gameThreshold 직렬화 추가**

`Shared/Services/WatchConnectivityService.swift`의 `SessionStartMessage`를 아래로 교체:

```swift
struct SessionStartMessage {
    let sessionId: UUID
    let options: MatchOptions

    func toDictionary() -> [String: Any] {
        [
            "type": WCMessageType.sessionStart.rawValue,
            "sessionId": sessionId.uuidString,
            "mode": options.mode.rawValue,
            "noAdRule": options.noAdRule,
            "noTieRule": options.noTieRule,
            "gameThreshold": options.gameThreshold
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.sessionStart.rawValue,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let modeRaw = dict["mode"] as? String,
              let mode = MatchFormat(rawValue: modeRaw) else { return nil }
        sessionId = id
        options = MatchOptions(
            mode: mode,
            noAdRule: dict["noAdRule"] as? Bool ?? true,
            noTieRule: dict["noTieRule"] as? Bool ?? false,
            gameThreshold: dict["gameThreshold"] as? Int ?? 6
        )
    }

    init(sessionId: UUID, options: MatchOptions) {
        self.sessionId = sessionId
        self.options = options
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add Shared/Models/MatchOptions.swift Shared/Services/WatchConnectivityService.swift
git commit -m "feat: MatchOptions에 gameThreshold 추가, SessionStartMessage 직렬화 포함"
```

---

## Task 2: ModeViewModel (iOS + Watch) — gameThreshold + UserDefaults 설정 저장

**Files:**
- Modify: `iOSApp/Features/Match/Mode/ModeViewModel.swift`
- Modify: `WatchApp/Features/Match/Mode/ModeViewModel.swift`

- [ ] **Step 1: iOS ModeViewModel 교체**

`iOSApp/Features/Match/Mode/ModeViewModel.swift` 전체:

```swift
import Foundation

class ModeViewModel: ObservableObject {
    @Published var selectedMode: MatchFormat {
        didSet { UserDefaults.standard.set(selectedMode.rawValue, forKey: "lastSelectedMode") }
    }
    @Published var noAdRule: Bool {
        didSet { UserDefaults.standard.set(noAdRule, forKey: "lastNoAdRule") }
    }
    @Published var noTieRule: Bool {
        didSet { UserDefaults.standard.set(noTieRule, forKey: "lastNoTieRule") }
    }
    @Published var gameThreshold: Int {
        didSet { UserDefaults.standard.set(gameThreshold, forKey: "lastGameThreshold") }
    }

    var options: MatchOptions {
        MatchOptions(mode: selectedMode, noAdRule: noAdRule, noTieRule: noTieRule, gameThreshold: gameThreshold)
    }

    init() {
        let ud = UserDefaults.standard
        selectedMode  = MatchFormat(rawValue: ud.string(forKey: "lastSelectedMode") ?? "") ?? .oneSet
        noAdRule      = ud.object(forKey: "lastNoAdRule") as? Bool ?? true
        noTieRule     = ud.object(forKey: "lastNoTieRule") as? Bool ?? false
        gameThreshold = ud.object(forKey: "lastGameThreshold") as? Int ?? 6
    }
}
```

- [ ] **Step 2: Watch ModeViewModel 교체**

`WatchApp/Features/Match/Mode/ModeViewModel.swift` 전체:

```swift
import Foundation

class ModeViewModel: ObservableObject {
    @Published var selectedMode: MatchFormat {
        didSet { UserDefaults.standard.set(selectedMode.rawValue, forKey: "lastSelectedMode") }
    }
    @Published var noAdRule: Bool {
        didSet { UserDefaults.standard.set(noAdRule, forKey: "lastNoAdRule") }
    }
    @Published var noTieRule: Bool {
        didSet { UserDefaults.standard.set(noTieRule, forKey: "lastNoTieRule") }
    }
    @Published var gameThreshold: Int {
        didSet { UserDefaults.standard.set(gameThreshold, forKey: "lastGameThreshold") }
    }

    var options: MatchOptions {
        MatchOptions(mode: selectedMode, noAdRule: noAdRule, noTieRule: noTieRule, gameThreshold: gameThreshold)
    }

    init() {
        let ud = UserDefaults.standard
        selectedMode  = MatchFormat(rawValue: ud.string(forKey: "lastSelectedMode") ?? "") ?? .oneSet
        noAdRule      = ud.object(forKey: "lastNoAdRule") as? Bool ?? true
        noTieRule     = ud.object(forKey: "lastNoTieRule") as? Bool ?? false
        gameThreshold = ud.object(forKey: "lastGameThreshold") as? Int ?? 6
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Mode/ModeViewModel.swift \
        WatchApp/Features/Match/Mode/ModeViewModel.swift
git commit -m "feat: ModeViewModel에 gameThreshold 추가 및 UserDefaults 설정 저장"
```

---

## Task 3: iOS ScoreViewModel — 버그 수정 + 로직 통일 + draw 경로 (TDD)

**Files:**
- Test: `iosTests/Match/ScoreViewModelTests.swift`
- Modify: `iOSApp/Features/Match/Score/ScoreViewModel.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Match/ScoreViewModelTests.swift`의 `struct ScoreViewModelTests` 안에 추가:

```swift
// MARK: - ScoreViewModel 버그 재현 + 통일 로직

@Test @MainActor func noEarlyEndAt_T6_7to6_noTie() {
    // iOS 버그: noTieRule=true에서 7-6이 세트 종료로 오판정되는 것을 방지
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6))
    for _ in 0..<6 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    // 6-6에서 noTie → 무승부 처리됨, 7번째 게임 진행 불가 확인은 drawAt_T6_noTie에서
    // 실제로는 6-6에서 멈춰야 함 (draw)
    #expect(vm.isMatchOver == true)
    #expect(vm.matchResult == .draw)
}

@Test @MainActor func drawAt_T6_noTie() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6))
    for _ in 0..<6 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(vm.matchResult == .draw)
    #expect(vm.isMatchOver == true)
}

@Test @MainActor func tiebreakStartsAt_T6() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 6))
    for _ in 0..<6 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(vm.isTieBreak == true)
    #expect(vm.isMatchOver == false)
}

@Test @MainActor func setWinsAt_T5_5to3() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
    for _ in 0..<3 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
    vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
    #expect(vm.isMatchOver == true)
    #expect(vm.matchResult == .win)
}

@Test @MainActor func setWinsAt_T5_6to4() {
    // T=5에서 5-4 이후 6-4 (2게임 차, 임계값 초과)
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
    for _ in 0..<4 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    // me 5번째 (5-4)
    vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
    #expect(vm.isMatchOver == false)  // 5-4는 아직 종료 아님
    // me 6번째 (6-4) → 2게임 차, 세트 승리
    vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
    #expect(vm.isMatchOver == true)
    #expect(vm.matchResult == .win)
}

@Test @MainActor func tiebreakStartsAt_T5() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5))
    for _ in 0..<5 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(vm.isTieBreak == true)
    #expect(vm.isMatchOver == false)
}

@Test @MainActor func drawAt_T5_noTie() {
    let vm = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 5))
    for _ in 0..<5 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(vm.matchResult == .draw)
    #expect(vm.isMatchOver == true)
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:iosTests/iosTests/drawAt_T6_noTie 2>&1 | grep -E "FAILED|PASSED|error:"
```

Expected: `FAILED` (matchResult 프로퍼티 없음)

- [ ] **Step 3: iOS ScoreViewModel 전체 교체**

`iOSApp/Features/Match/Score/ScoreViewModel.swift` 전체를 아래로 교체:

```swift
import Combine
import Foundation

@MainActor
final class ScoreViewModel: ObservableObject {
    let options: MatchOptions

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published private(set) var matchResult: MatchResult?

    var isMatchOver: Bool { matchResult != nil }
    var didWin: Bool { matchResult == .win }
    var isTieBreak: Bool { score.gameMode == .tieBreak }

    var hasProgress: Bool {
        myGameScore > 0 || yourGameScore > 0 ||
        mySetScore > 0 || yourSetScore > 0 ||
        !completedSets.isEmpty ||
        score.lastAction != .none
    }

    private var tieBreakInProgress = false
    private var isApplyingRemote = false
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init(options: MatchOptions = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) {
        self.options = options
        self.score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreState
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyRemoteState(state) }
            .store(in: &cancellables)

        connectivity.$isWatchReachable
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sendScoreState() }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        guard !isMatchOver else { return }
        let gameWon = score.addPoint(side)
        LiveActivityService.shared.update(from: makeScoreState(), score: score)
        guard gameWon != nil else { return }
        if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
        score.resetData()
        checkSetUpdate()
        sendScoreState()
        LiveActivityService.shared.update(from: makeScoreState(), score: score)
    }

    func undo() {
        score.undo()
    }

    func resetAll() {
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        currentSetNumber = 1
        completedSets = []
        matchResult = nil
        tieBreakInProgress = false
        score.noAdRule = options.noAdRule
        score.resetData()
    }

    func applyRemoteState(_ state: ScoreState) {
        isApplyingRemote = true
        myGameScore = state.myGameScore
        yourGameScore = state.yourGameScore
        mySetScore = state.mySetScore
        yourSetScore = state.yourSetScore
        completedSets = state.completedSets.map { (my: $0[0], your: $0[1]) }
        score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
        tieBreakInProgress = state.isTieBreak
        LiveActivityService.shared.update(from: state, score: score)
        isApplyingRemote = false
    }

    // MARK: - Private

    private func checkSetUpdate() {
        let T = options.gameThreshold
        let my = myGameScore, your = yourGameScore

        if tieBreakInProgress {
            if (my == T + 1 && your == T) || (your == T + 1 && my == T) {
                tieBreakInProgress = false
                finalizeSet(winner: my > your ? .me : .opponent)
            }
            return
        }

        if my == T && your == T {
            if options.noTieRule {
                completedSets.append((my: my, your: your))
                matchResult = .draw
            } else {
                score.setTieBreakMode()
                tieBreakInProgress = true
            }
            return
        }

        let maxG = max(my, your), minG = min(my, your)
        guard maxG >= T && (maxG - minG) >= 2 else { return }
        finalizeSet(winner: my > your ? .me : .opponent)
    }

    private func finalizeSet(winner: PlayerSide) {
        completedSets.append((my: myGameScore, your: yourGameScore))
        if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0
        currentSetNumber += 1

        if mySetScore >= options.mode.setsToWin {
            matchResult = .win
        } else if yourSetScore >= options.mode.setsToWin {
            matchResult = .loss
        }
    }

    private func makeScoreState() -> ScoreState {
        let myS = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
        let yourS = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
        return ScoreState(
            myScore: myS, yourScore: yourS,
            myGameScore: myGameScore, yourGameScore: yourGameScore,
            mySetScore: mySetScore, yourSetScore: yourSetScore,
            completedSets: completedSets.map { [$0.my, $0.your] },
            isTieBreak: score.gameMode == .tieBreak
        )
    }

    private func sendScoreState() {
        guard !isApplyingRemote else { return }
        connectivity.sendScoreState(makeScoreState())
    }
}
```

- [ ] **Step 4: 테스트 실행 — 전체 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "FAILED|Test Suite.*passed|error:"
```

Expected: `Test Suite 'iosTests' passed`

- [ ] **Step 5: 커밋**

```bash
git add iosTests/Match/ScoreViewModelTests.swift iOSApp/Features/Match/Score/ScoreViewModel.swift
git commit -m "fix: iOS ScoreViewModel 세트 완료 로직 통일, gameThreshold 지원, draw 경로 추가"
```

---

## Task 4: Watch ScoreViewModel — 버그 수정 + 로직 통일 + draw 경로 (TDD)

**Files:**
- Test: `watchosTests/Match/ScoreViewModelTests.swift`
- Modify: `WatchApp/Features/Match/Score/ScoreViewModel.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Match/ScoreViewModelTests.swift`를 새로 생성하고 아래 내용으로 작성:

```swift
@testable import TennisCounter_Watch_App
import Testing

struct ScoreViewModelTests {

@Test @MainActor func watchNoEarlyEndAt_T6_6to5_noTie() {
    // Watch 버그: noTieRule=true에서 6-5에 세트 종료되는 것 방지
    let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6)
    let vm = ScoreViewModel(options: options)
    var finishCalled = false
    vm.onMatchFinished = { _, _ in finishCalled = true }
    for _ in 0..<5 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
    #expect(vm.myGameScore == 6)
    #expect(vm.yourGameScore == 5)
    #expect(finishCalled == false)
}

@Test @MainActor func watchDrawAt_T6_noTie() {
    let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 6)
    let vm = ScoreViewModel(options: options)
    var finishedResult: MatchResult?
    vm.onMatchFinished = { result, _ in finishedResult = result }
    for _ in 0..<6 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(finishedResult == .draw)
}

@Test @MainActor func watchTiebreakStartsAt_T5() {
    let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false, gameThreshold: 5)
    let vm = ScoreViewModel(options: options)
    var finishCalled = false
    vm.onMatchFinished = { _, _ in finishCalled = true }
    for _ in 0..<5 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(vm.score.gameMode == .tieBreak)
    #expect(finishCalled == false)
}

@Test @MainActor func watchDrawAt_T5_noTie() {
    let options = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: true, gameThreshold: 5)
    let vm = ScoreViewModel(options: options)
    var finishedResult: MatchResult?
    vm.onMatchFinished = { result, _ in finishedResult = result }
    for _ in 0..<5 {
        vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me); vm.addPoint(.me)
        vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent); vm.addPoint(.opponent)
    }
    #expect(finishedResult == .draw)
}

}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:watchosTests/ScoreViewModelTests/watchDrawAt_T6_noTie 2>&1 | grep -E "FAILED|PASSED|error:"
```

Expected: `FAILED`

- [ ] **Step 3: Watch ScoreViewModel `checkSetUpdate()` + `finalizeSet()` 교체**

`WatchApp/Features/Match/Score/ScoreViewModel.swift`의 `checkSetUpdate()` 메서드와 `finalizeSet()` 메서드를 아래로 교체:

```swift
private func checkSetUpdate() {
    let T = options.gameThreshold
    let my = myGameScore, your = yourGameScore

    if tieBreakInProgress {
        if (my == T + 1 && your == T) || (your == T + 1 && my == T) {
            tieBreakInProgress = false
            let winner: PlayerSide = my == T + 1 ? .me : .opponent
            finalizeSet(winner: winner)
        }
        return
    }

    if my == T && your == T {
        if options.noTieRule {
            completedSets.append(SetScore(my: my, your: your))
            onMatchFinished?(.draw, completedSets)
        } else {
            score.setTieBreakMode()
            tieBreakInProgress = true
        }
        return
    }

    let maxG = max(my, your), minG = min(my, your)
    guard maxG >= T && (maxG - minG) >= 2 else { return }
    finalizeSet(winner: my > your ? .me : .opponent)
}

private func finalizeSet(winner: PlayerSide) {
    completedSets.append(SetScore(my: myGameScore, your: yourGameScore))
    if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
    myGameScore = 0
    yourGameScore = 0

    let setsToWin = options.mode.setsToWin
    if mySetScore >= setsToWin {
        onMatchFinished?(.win, completedSets)
    } else if yourSetScore >= setsToWin {
        onMatchFinished?(.loss, completedSets)
    }
}
```

- [ ] **Step 4: 테스트 실행 — 전체 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | grep -E "FAILED|Test Suite.*passed|error:"
```

Expected: `Test Suite 'watchosTests' passed`

- [ ] **Step 5: 커밋**

```bash
git add watchosTests/Match/ScoreViewModelTests.swift WatchApp/Features/Match/Score/ScoreViewModel.swift
git commit -m "fix: Watch ScoreViewModel 세트 완료 로직 통일, gameThreshold 지원, draw 경로 추가"
```

---

## Task 5: iOS finishMatch 시그니처 변경 + ScoreView 콜백 타입 업데이트

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`

- [ ] **Step 1: WorkoutSessionViewModel `finishMatch` 시그니처 변경**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

```swift
// 변경 전
func finishMatch(didWin: Bool, completedSets: [(my: Int, your: Int)]) {
    guard let session = _currentSession else { return }
    session.endedAt = Date()
    session.result = didWin ? .win : .loss
```

```swift
// 변경 후
func finishMatch(result: MatchResult, completedSets: [(my: Int, your: Int)]) {
    guard let session = _currentSession else { return }
    session.endedAt = Date()
    session.result = result
```

- [ ] **Step 2: `buildSession(from:)` draw 처리 수정**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`에서:

```swift
// 변경 전
session.result = msg.result == "win" ? .win : .loss

// 변경 후
session.result = MatchResult(rawValue: msg.result) ?? .loss
```

- [ ] **Step 3: ScoreView `onMatchFinished` 콜백 타입 변경**

`iOSApp/Features/Match/Score/ScoreView.swift` 상단 선언부:

```swift
// 변경 전
let onMatchFinished: (Bool, [(my: Int, your: Int)]) -> Void
...
init(options: MatchOptions,
     onMatchFinished: @escaping (Bool, [(my: Int, your: Int)]) -> Void,

// 변경 후
let onMatchFinished: (MatchResult, [(my: Int, your: Int)]) -> Void
...
init(options: MatchOptions,
     onMatchFinished: @escaping (MatchResult, [(my: Int, your: Int)]) -> Void,
```

- [ ] **Step 4: ScoreView의 `onChange` 업데이트**

`iOSApp/Features/Match/Score/ScoreView.swift`에서:

```swift
// 변경 전
.onChange(of: viewModel.isMatchOver) { _, isOver in
    if isOver { onMatchFinished(viewModel.didWin, viewModel.completedSets) }
}

// 변경 후
.onChange(of: viewModel.matchResult) { _, result in
    if let result { onMatchFinished(result, viewModel.completedSets) }
}
```

- [ ] **Step 5: WorkoutSessionView 호출부 업데이트**

`iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`에서:

```swift
// 변경 전
onMatchFinished: { didWin, sets in
    viewModel.finishMatch(didWin: didWin, completedSets: sets)
},

// 변경 후
onMatchFinished: { result, sets in
    viewModel.finishMatch(result: result, completedSets: sets)
},
```

- [ ] **Step 6: Preview 호출부 수정**

`iOSApp/Features/Match/Score/ScoreView.swift` 하단 Preview:

```swift
// 변경 전
onMatchFinished: { _, _ in }

// 변경 후
onMatchFinished: { _, _ in }
// (타입이 바뀌어도 클로저 본문이 비어있어 컴파일 통과)
```

- [ ] **Step 7: 빌드 + 테스트 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "FAILED|Test Suite.*passed|error:"
```

Expected: `Test Suite 'iosTests' passed`

- [ ] **Step 8: 커밋**

```bash
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift \
        iOSApp/Features/Match/Score/ScoreView.swift \
        iOSApp/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "feat: iOS finishMatch MatchResult 타입으로 통일, draw 전달 경로 완성"
```

---

## Task 6: ModeView (iOS + Watch) — Segmented Picker + 로컬라이제이션

**Files:**
- Modify: `iOSApp/Features/Match/Mode/ModeView.swift`
- Modify: `WatchApp/Features/Match/Mode/ModeView.swift`
- Modify: `iOSApp/en.lproj/Localizable.strings`
- Modify: `iOSApp/ko.lproj/Localizable.strings`
- Modify: `WatchApp/en.lproj/Localizable.strings`
- Modify: `WatchApp/ko.lproj/Localizable.strings`

- [ ] **Step 1: 로컬라이제이션 키 추가 (4개 파일)**

`iOSApp/en.lproj/Localizable.strings`에 추가:
```
"mode_game_threshold" = "Games";
```

`iOSApp/ko.lproj/Localizable.strings`에 추가:
```
"mode_game_threshold" = "게임 수";
```

`WatchApp/en.lproj/Localizable.strings`에 추가:
```
"mode_game_threshold" = "Games";
```

`WatchApp/ko.lproj/Localizable.strings`에 추가:
```
"mode_game_threshold" = "게임 수";
```

- [ ] **Step 2: iOS ModeView — Segmented Picker 추가**

`iOSApp/Features/Match/Mode/ModeView.swift` 전체:

```swift
import SwiftUI

struct ModeView: View {
    @ObservedObject var viewModel: WorkoutSessionViewModel
    @StateObject private var selectionVM = ModeViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                    ModeOptionItem(format: format) {
                        selectionVM.selectedMode = format
                        viewModel.startMatch(options: selectionVM.options)
                    }
                }

                Divider().background(Color.white.opacity(0.2))

                HStack {
                    Text(String(localized: "mode_game_threshold"))
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $selectionVM.gameThreshold) {
                        Text("5").tag(5)
                        Text("6").tag(6)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }

                Toggle(String(localized: "mode_no_ad"), isOn: $selectionVM.noAdRule)
                    .font(.system(size: 15))
                    .tint(.green)

                Toggle(String(localized: "mode_no_tie"), isOn: $selectionVM.noTieRule)
                    .font(.system(size: 15))
                    .tint(.green)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    ModeView(viewModel: WorkoutSessionViewModel())
}
```

- [ ] **Step 3: Watch ModeView — Segmented Picker 추가**

`WatchApp/Features/Match/Mode/ModeView.swift` 전체:

```swift
import SwiftUI

struct ModeView: View {
    @ObservedObject var viewModel: WorkoutSessionViewModel
    @StateObject private var selectionVM = ModeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ModeOptionItem(mode: .oneSet) {
                    selectionVM.selectedMode = .oneSet
                    viewModel.startMatch(options: selectionVM.options)
                }

                ModeOptionItem(mode: .bestOfThree) {
                    selectionVM.selectedMode = .bestOfThree
                    viewModel.startMatch(options: selectionVM.options)
                }

                Divider().background(Color.white.opacity(0.2))

                HStack {
                    Text(String(localized: "mode_game_threshold"))
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $selectionVM.gameThreshold) {
                        Text("5").tag(5)
                        Text("6").tag(6)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }

                Toggle(String(localized: "mode_no_ad"), isOn: $selectionVM.noAdRule)
                    .font(.system(size: 14))
                    .toggleStyle(SwitchToggleStyle(tint: .green))

                Toggle(String(localized: "mode_no_tie"), isOn: $selectionVM.noTieRule)
                    .font(.system(size: 14))
                    .toggleStyle(SwitchToggleStyle(tint: .green))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: 두 타겟 모두 `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/Mode/ModeView.swift \
        WatchApp/Features/Match/Mode/ModeView.swift \
        iOSApp/en.lproj/Localizable.strings \
        iOSApp/ko.lproj/Localizable.strings \
        WatchApp/en.lproj/Localizable.strings \
        WatchApp/ko.lproj/Localizable.strings
git commit -m "feat: ModeView에 게임 수 Segmented Picker 추가 (iOS + Watch)"
```

---

## Task 7: 컴포넌트 이름 변경 (PlayerScoreZone → PlayerPointZone, PlayerScoreButton → PlayerPointButton)

**Files:**
- Rename: `iOSApp/Features/Match/Score/Components/PlayerScoreZone.swift` → `PlayerPointZone.swift`
- Rename: `WatchApp/Features/Match/Score/Components/PlayerScoreButton.swift` → `PlayerPointButton.swift`
- Modify: `iOSApp/Features/Match/Score/ScoreView.swift` (참조 업데이트)
- Modify: `WatchApp/Features/Match/Score/ScoreView.swift` (참조 업데이트)

- [ ] **Step 1: iOS 파일 이름 변경 및 타입명 수정**

```bash
mv "iOSApp/Features/Match/Score/Components/PlayerScoreZone.swift" \
   "iOSApp/Features/Match/Score/Components/PlayerPointZone.swift"
```

`iOSApp/Features/Match/Score/Components/PlayerPointZone.swift` 내부에서 타입명 변경:

```swift
// 변경 전
struct PlayerScoreZone: View {

// 변경 후
struct PlayerPointZone: View {
```

Preview 부분도 변경:
```swift
// 변경 전
PlayerScoreZone(displayScore: "40", playerLabel: "나", color: .green, onTap: {}, onLongPress: {})
PlayerScoreZone(displayScore: "15", playerLabel: "상대", color: .orange, onTap: {}, onLongPress: {})

// 변경 후
PlayerPointZone(displayScore: "40", playerLabel: "나", color: .green, onTap: {}, onLongPress: {})
PlayerPointZone(displayScore: "15", playerLabel: "상대", color: .orange, onTap: {}, onLongPress: {})
```

- [ ] **Step 2: iOS ScoreView 참조 업데이트**

`iOSApp/Features/Match/Score/ScoreView.swift`에서:

```swift
// 변경 전 (2곳)
PlayerScoreZone(

// 변경 후
PlayerPointZone(
```

- [ ] **Step 3: Watch 파일 이름 변경 및 타입명 수정**

```bash
mv "WatchApp/Features/Match/Score/Components/PlayerScoreButton.swift" \
   "WatchApp/Features/Match/Score/Components/PlayerPointButton.swift"
```

`WatchApp/Features/Match/Score/Components/PlayerPointButton.swift` 내부:

```swift
// 변경 전
struct PlayerScoreButton: View {

// 변경 후
struct PlayerPointButton: View {
```

- [ ] **Step 4: Watch ScoreView 참조 업데이트**

`WatchApp/Features/Match/Score/ScoreView.swift`에서:

```swift
// 변경 전 (2곳)
PlayerScoreButton(

// 변경 후
PlayerPointButton(
```

- [ ] **Step 5: 빌드 + 전체 테스트 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "FAILED|Test Suite.*passed|error:"
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | grep -E "FAILED|Test Suite.*passed|error:"
```

Expected: 두 타겟 모두 `Test Suite ... passed`

- [ ] **Step 6: 커밋**

```bash
git add iOSApp/Features/Match/Score/Components/PlayerPointZone.swift \
        WatchApp/Features/Match/Score/Components/PlayerPointButton.swift \
        iOSApp/Features/Match/Score/ScoreView.swift \
        WatchApp/Features/Match/Score/ScoreView.swift
git commit -m "refactor: PlayerScoreZone → PlayerPointZone, PlayerScoreButton → PlayerPointButton"
```
