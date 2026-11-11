# 3세트 경기 매치 타이브레이크(10점) 옵션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 3세트 경기에서 세트 스코어가 1-1 이 되면 3세트를 일반 세트 대신 10점 매치 타이브레이크 한 번으로 치르는 옵션을 추가한다 (기본값 꺼짐).

**Architecture:** `MatchFormat` 케이스는 늘리지 않고 `MatchOptions` 에 `matchTieBreak: Bool` 을 더한다. `Score` 는 타이브레이크 목표 점수(7 또는 10)를 상태로 갖고, 두 `ScoreViewModel`(iOS·Watch)이 `finalizeSet` 에서 1-1 을 감지해 목표 10 으로 타이브레이크 모드에 들어간다. 매치 TB 결과는 `SetScore`/`SetRecord` 에 `(10, 7)` 처럼 **그대로** 저장하고, 표시 쪽이 점수가 10 이상이면 `[10–7]` 로 그린다 — SwiftData 스키마는 건드리지 않는다.

**Tech Stack:** SwiftUI, Swift Testing, WatchConnectivity(`ConnectivityCore`)

**Spec:** 없음 (이 플랜이 설계를 겸한다). Linear [YJ-32](https://linear.app/yj-workpace/issue/YJ-32). 리뷰 원문: "3 set match with a Match-Tie-Break … 3rd set will be a Match-Tie-Break and goes until 10."

## 현재 동작 (플랜 작성 시 확인)

- `MatchFormat` = `oneSet` / `bestOfThree`. `setsToWin` 은 1 / 2.
- 모드 화면에는 **게임 수(4·5·6)**, **No-AD**, **No-Tiebreak**(`noTieRule`) 설정이 이미 있다. 포맷 버튼을 누르면 곧바로 경기가 시작되고, 선택 상태는 화면에 표시되지 않는다 (`lastSelectedMode` 만 저장).
- `noTieRule` 이 켜져 있으면 세트가 `threshold`-`threshold`(기본 6-6)일 때 **타이브레이크 없이 경기를 무승부로 끝낸다.** 기본값은 모드 화면 VM 에서 `true` 다. 끄면 7점 타이브레이크로 세트를 끝낸다 (`Score.addTieBreakPoint` 의 `>= 7` 이 하드코딩).
- 타이브레이크로 끝난 세트는 `(threshold+1, threshold)` 로만 기록된다. 타이브레이크 점수는 저장하지 않는다.
- `Match`(SwiftData)는 `mode`, `noAdRule` 만 저장하고 `noTieRule`·`gameThreshold` 는 저장하지 않는다. 세트는 `SetRecord(myGames, yourGames, setNumber)`.
- `ScoreViewModel` 이 iOS(`iOSApp/Features/WorkoutSession/Match/Score/`)와 Watch(`WatchApp/Features/WorkoutSession/Match/Score/`)에 **각각 따로** 있다. 세트·매치 판정 로직도 둘이 중복이다. 이 플랜은 중복을 합치지 않고 같은 방식으로 두 곳을 고친다.
- 워치↔폰은 `SessionStartMessage` 로 `MatchOptions` 를 보내고, 점수는 `ScoreState`(driver → mirror, 표시 전용)로 보낸다.

## Global Constraints

- 새 옵션 기본값은 **꺼짐**. 기존 사용자 동작은 옵션을 켜지 않는 한 바뀌지 않는다
- 매치 TB 는 **`mode == .bestOfThree` 이고 세트 스코어가 1-1 일 때만** 진입한다
- 매치 TB 승자는 세트 1개를 얻는다 → `6-4 3-6 [10-7]` 의 세트 스코어는 2-1. `finalizeSet` 경로를 그대로 쓴다
- 목표 점수 10, 2점 차 필요 (9-9 이후에도 계속). 일반 세트 타이브레이크는 7점 그대로
- **SwiftData `@Model`(`Match`·`SetRecord`)에 프로퍼티를 추가하지 않는다** — CloudKit 스키마가 바뀌면 되돌릴 수 없다
- `SessionStartMessage` 는 구버전 페이로드(키 없음)를 계속 받아야 한다 — 파싱 실패 금지, 키 없으면 `false`
- 로직은 `ScoreViewModel`/`Score` 에 둔다. View 는 값과 콜백만 (루트 `CLAUDE.md` 단방향 규약)
- 테스트: Swift Testing, `@MainActor`, 하나의 `@Test` 는 하나의 시나리오. 이름은 `대상_행위_결과` 형태
- 브랜치 `feat/ralli-match-tiebreak`. 커밋은 gitmoji(`✨`), 푸시·PR 은 사용자 승인 후

## Review Focus

스펙이 말하지 않지만 실제로 부딪힐 입력들. 각 항목의 테스트는 해당 Task 에 들어 있다.

1. **9-9 이후** — 10점에서 끝나지 않고 2점 차까지 간다 (Task 1·3)
2. **No-Tiebreak 로 세트 1·2 가 6-6 무승부로 끝난 경우** — 매치 TB 로 넘어가지 않고 `draw` 로 끝난다 (Task 3)
3. **구버전 `SessionStartMessage`**(키 없음) — `matchTieBreak == false` 로 파싱된다 (Task 2)
4. **되돌리기(undo)** — 매치 TB 마지막 포인트를 되돌리면 다시 10점 목표로 진행되고, 첫 포인트를 되돌리면 2세트 막판 상태로 돌아간다 (Task 3·4)
5. **저장된 기록의 표시** — 세트 점수가 10 이상이면 `[10–7]`, 일반 세트(최대 7)는 그대로 (Task 1·5·6)

---

### Task 1: 모델 — `Score` 목표 점수, `MatchOptions`, `SetScore`

**Files:**
- Modify: `Shared/Models/Score.swift` (`setTieBreakMode` 59-64, `reset` 50-57, `addTieBreakPoint` 110-116, `Snapshot` 133-156)
- Modify: `Shared/Models/MatchOptions.swift`
- Modify: `Shared/Models/SetScore.swift`
- Modify: `Shared/Persistence/SetRecord.swift` (extension 추가, 프로퍼티는 추가하지 않는다)
- Test: `iosTests/Shared/ScoreTests.swift`

**Interfaces:**
- Produces:
  - `Score.standardTieBreakTarget: Int` (= 7), `Score.matchTieBreakTarget: Int` (= 10) — `static let`
  - `Score.tieBreakTarget: Int` — `private(set) var`, 기본 7
  - `Score.setTieBreakMode(target: Int = Score.standardTieBreakTarget)` — 기존 호출부는 그대로 컴파일된다
  - `MatchOptions.matchTieBreak: Bool` — `init(mode:noAdRule:noTieRule:gameThreshold:matchTieBreak:)`, 마지막 인자 기본값 `false`
  - `SetScore.isMatchTieBreak: Bool`, `SetRecord.isMatchTieBreak: Bool` — `max(my, your) >= Score.matchTieBreakTarget`

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`ScoreTests.swift`)

```swift
@Test @MainActor func matchTieBreak_endsAtTenWithTwoPointLead()   // target 10, 나 10-0 → 마지막 addPoint 가 .me, 그 전(9-0)은 nil
@Test @MainActor func matchTieBreak_continuesPastNineAll()        // 9-9 에서 nil, 10-9 에서 nil, 11-9 에서 .me
@Test @MainActor func standardTieBreak_stillEndsAtSeven()         // setTieBreakMode() 기본 인자, 7-0 에서 .me (회귀)
@Test @MainActor func snapshotRestoresTieBreakTarget()            // target 10 에서 makeSnapshot → reset() → restore → 10-0 에서 .me, 7-0 에서는 nil
@Test @MainActor func resetRestoresStandardTieBreakTarget()       // target 10 → reset() → setTieBreakMode() 후 7-0 에서 .me
@Test func setScore_isMatchTieBreakOnlyFromTen()                  // (10,7)·(7,10)·(11,9) true / (7,6)·(6,4)·(7,5) false
```

- [ ] **Step 2: 실패 확인**

Run: `xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test -only-testing:RalliTests/ScoreTests`
Expected: 컴파일 실패 (`setTieBreakMode(target:)`, `isMatchTieBreak` 미정의)

- [ ] **Step 3: 구현**
  - `Score`: `tieBreakTarget` 을 상태로 두고 `addTieBreakPoint` 의 `7` 을 `tieBreakTarget` 으로 바꾼다. `reset()` 은 목표를 7 로 되돌린다. `Snapshot` 에 `tieBreakTarget` 을 추가하고 `makeSnapshot`/`restore` 가 왕복한다 (되돌리기가 목표 점수를 잃으면 안 된다).
  - `Score.applyRemote` 는 건드리지 않는다 — mirror 는 표시 전용이라 목표를 쓰지 않는다.
  - `MatchOptions`, `SetScore`, `SetRecord` 는 위 Interfaces 의 시그니처대로.

- [ ] **Step 4: 통과 확인** — Step 2 와 같은 명령. Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Apps/TennisCounter/Shared Apps/TennisCounter/iosTests/Shared/ScoreTests.swift
git commit -m "✨ feat: Score 에 타이브레이크 목표 점수와 매치 TB 옵션 모델을 추가한다"
```

---

### Task 2: 폰↔워치 메시지 — `SessionStartMessage`

**Files:**
- Modify: `Shared/Services/ConnectivityMessages.swift` (`SessionStartMessage` 6-54)
- Test: `iosTests/Shared/ConnectivityMessagesTests.swift`

**Interfaces:**
- Consumes: Task 1 의 `MatchOptions.matchTieBreak`
- Produces: 딕셔너리 키 `"matchTieBreak": Bool` — 없으면 `false`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
@Test func sessionStart_roundTripsMatchTieBreak()                 // matchTieBreak: true → toDictionary → init?(from:) → options.matchTieBreak == true
@Test func sessionStart_withoutMatchTieBreakKeyDefaultsToFalse()  // 구버전 페이로드(키 제거) → 파싱 성공, matchTieBreak == false
```

- [ ] **Step 2: 실패 확인** — `-only-testing:RalliTests/ConnectivityMessagesTests`. Expected: FAIL

- [ ] **Step 3: 구현** — `toDictionary` 에 키를 쓰고 `init?(from:)` 에서 `dict["matchTieBreak"] as? Bool ?? false` 로 읽는다. 기존 `noTieRule` 처리와 같은 패턴.

- [ ] **Step 4: 통과 확인** — Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Apps/TennisCounter/Shared/Services/ConnectivityMessages.swift Apps/TennisCounter/iosTests/Shared/ConnectivityMessagesTests.swift
git commit -m "✨ feat: SessionStartMessage 에 매치 TB 옵션을 싣는다"
```

---

### Task 3: iOS `ScoreViewModel` — 매치 TB 진입·종료

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift` (`addPoint` 88-98, `Snapshot` 19-29, `captureSnapshot`/`apply` 155-179, `resetAll` 114-127, `finalizeSet` 209-221)
- Test: `iosTests/WorkoutSession/Match/ScoreViewModelTests.swift`

**Interfaces:**
- Consumes: `Score.setTieBreakMode(target:)`, `Score.matchTieBreakTarget`, `MatchOptions.matchTieBreak`
- Produces: 내부 상태 `matchTieBreakInProgress: Bool` (private). 외부 API 변화 없음 — `isTieBreak` 는 매치 TB 중에도 `true`

동작 규칙 (구현자가 혼자 정할 수 없는 부분):
1. `finalizeSet` 에서 매치가 아직 안 끝났고, `options.matchTieBreak && options.mode == .bestOfThree` 이며 `mySetScore == yourSetScore == setsToWin - 1` 이면 `score.setTieBreakMode(target: Score.matchTieBreakTarget)` 로 들어가고 `matchTieBreakInProgress = true`. 게임 스코어는 0:0 유지.
2. `addPoint` 에서 매치 TB 중 `score.addPoint` 가 승자를 돌려주면 **게임 스코어를 올리지 않는다.** `score.resetData()` 가 점수를 지우기 **전에** `score.myTieBreak`/`yourTieBreak` 를 읽어 `completedSets` 에 `(my, your)` 로 추가하고, 승자의 `setScore` 를 올려 `matchResult` 를 `.win`/`.loss` 로 정한 뒤 `matchTieBreakInProgress = false`.
3. `matchTieBreakInProgress` 는 `Snapshot` 에 포함되어 undo 로 복원된다. `resetAll` 은 `false` 로 되돌린다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (테스트 파일의 기존 게임·세트 진행 헬퍼를 재사용한다)

```swift
@Test @MainActor func matchTieBreak_startsAtOneAllInBestOfThree()        // 세트1 내가, 세트2 상대가 6-0 → isTieBreak true, 게임 0:0, mySetScore == yourSetScore == 1, matchResult nil
@Test @MainActor func matchTieBreak_notStartedWhenOptionOff()            // 같은 진행, matchTieBreak false → isTieBreak false, 일반 3세트
@Test @MainActor func matchTieBreak_notStartedWhenMatchAlreadyDecided()  // 세트1·2 연속 내가 → matchResult .win, isTieBreak false
@Test @MainActor func matchTieBreak_startsEvenWithNoTieRuleOn()          // noTieRule true 여도 세트가 6-4 로 정상 종료되면 진입
@Test @MainActor func matchTieBreak_winEndsMatchAndRecordsPoints()       // 내가 10-7 → matchResult .win, completedSets.last == (10, 7), mySetScore 2, 게임 스코어 0:0
@Test @MainActor func matchTieBreak_lossRecordsLoss()                    // 상대가 10-8 → .loss, completedSets.last == (8, 10)
@Test @MainActor func matchTieBreak_continuesPastNineAll()               // 9-9 → matchResult nil, 이어서 11-9 → .win, completedSets.last == (11, 9)
@Test @MainActor func matchTieBreak_undoOfWinningPointRestoresTarget()   // 10-7 승리 직후 undo → matchResult nil, 점수 9-7, 다시 내가 득점 → .win (목표 10 유지)
@Test @MainActor func matchTieBreak_undoOfFirstPointReturnsToSetTwoEnd() // 매치 TB 첫 포인트 undo → isTieBreak false, 세트 스코어 1-0, 게임은 세트2 막판 상태
@Test @MainActor func noTieDrawAtSixAll_endsMatchBeforeMatchTieBreak()   // noTieRule true + 세트2 6-6 → matchResult .draw, isTieBreak false
```

- [ ] **Step 2: 실패 확인** — `xcodebuild … -scheme "TennisCounter" -destination "id=$IOS" test -only-testing:RalliTests/ScoreViewModelTests`. Expected: FAIL (10 개 중 `startsAtOneAll`, `win`, `loss`, `continues`, `undo` 2 개 + `startsEvenWithNoTie`; 나머지 `notStarted…`·`noTieDraw…` 는 현재 동작과 같아 PASS 일 수 있다 — 회귀 방지용)

- [ ] **Step 3: 구현** — 위 동작 규칙 1~3. `Snapshot` 에 `matchTieBreakInProgress` 추가.

- [ ] **Step 4: 통과 확인** — Step 2 명령 + `-only-testing:RalliTests` 전체. Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Apps/TennisCounter/iOSApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift Apps/TennisCounter/iosTests/WorkoutSession/Match/ScoreViewModelTests.swift
git commit -m "✨ feat: iOS 점수 VM 이 1-1 에서 10점 매치 타이브레이크로 진입한다"
```

---

### Task 4: Watch `ScoreViewModel` — 같은 규칙 + 햅틱

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift` (`addPoint` 70-84, `Snapshot` 17-26, `captureSnapshot`/`apply` 132-154, `resetAll` 106-118, `finalizeSet` 189-206)
- Test: `watchosTests/WorkoutSession/Match/ScoreViewModelTests.swift`, `watchosTests/WorkoutSession/Match/ScoreViewModelHapticsTests.swift`

**Interfaces:**
- Consumes: Task 3 의 **동작 규칙 1~3** 과 동일. 단 Watch VM 은 `onMatchFinished?(result, completedSets)` 와 `haptics.play(...)` 를 부른다 — 매치 TB 종료도 기존 `finalizeSet` 처럼 `.matchFinished(.win/.loss)` 와 `onMatchFinished` 를 **정확히 한 번** 호출해야 한다
- Produces: 외부 API 변화 없음

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
// ScoreViewModelTests.swift — Task 3 의 10 개와 같은 시나리오 (이름 앞에 watch 접두사, 기존 컨벤션 `watchNoEarlyEndAt_…`)
// 추가 1개:
@Test @MainActor func watchMatchTieBreak_finishesOnceThroughCallback()   // 10-7 → onMatchFinished 1 회 호출 (.win, 마지막 세트 (10, 7))
// ScoreViewModelHapticsTests.swift
@Test @MainActor func setWonHaptic_playsWhenMatchTieBreakStarts()        // 세트2 종료 포인트 → .setWon (진입 자체로 별도 햅틱 없음)
@Test @MainActor func matchFinishedHaptic_playsOnMatchTieBreakWin()      // 10-7 → .matchFinished(.win) 한 번
```

- [ ] **Step 2: 실패 확인** — `xcodebuild … -scheme "TennisCounter Watch App" -destination "id=$WATCH" test -only-testing:RalliWatchTests`. Expected: FAIL

- [ ] **Step 3: 구현** — Task 3 와 같은 규칙. 매치 TB 종료 시 `checkSetUpdate` 대신 `addPoint` 안에서 처리하되 반환되는 `MatchHapticEvent` 우선순위(`event = … ?? .gameWon`)와 `withAnimation` 블록 구조는 유지한다.

- [ ] **Step 4: 통과 확인** — Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Apps/TennisCounter/WatchApp/Features/WorkoutSession/Match/Score/ScoreViewModel.swift Apps/TennisCounter/watchosTests
git commit -m "✨ feat: 워치 점수 VM 에 10점 매치 타이브레이크를 추가한다"
```

---

### Task 5: iOS UI — 토글과 `[10–7]` 표기

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/Match/Mode/ModeViewModel.swift` — `matchTieBreak` 프로퍼티, 키 `lastMatchTieBreak`, 기본 `false`, `options` 에 반영
- Modify: `iOSApp/Features/WorkoutSession/Match/Mode/ModeView.swift` — `mode_no_tie` 토글 아래에 `Toggle` 추가
- Modify: `iOSApp/Features/WorkoutSession/Match/Result/MatchResultView.swift` (세트 칩 32-39) — `set.isMatchTieBreak` 이면 `[10–7]`
- Modify: `iOSApp/Features/History/Components/MatchCard.swift` (`setChips` 105-115) — `set.isMatchTieBreak` 이면 `[10–7]`
- Modify: `iOSApp/Localizable.xcstrings` — `mode_match_tiebreak` (ko / en)
- Test: `iosTests/` 에 `ModeViewModelTests` 가 없다면 만들지 않는다 (View 는 테스트하지 않는다). `ModeViewModel` 은 UserDefaults 래퍼라 수동 확인

**Interfaces:**
- Consumes: Task 1 의 `SetScore.isMatchTieBreak`, `SetRecord.isMatchTieBreak`, `MatchOptions.matchTieBreak`

- [ ] **Step 1: `ModeViewModel` + `ModeView` 구현.** 토글은 항상 보인다 (이 화면은 포맷 선택 상태가 없고, `mode_no_ad`·`mode_no_tie` 도 같은 방식으로 항상 보인다). `oneSet` 에서는 효과가 없다.
- [ ] **Step 2: 문자열 추가.** 카피 초안 — ko `3세트는 매치 타이브레이크 (10점)` / en `Match tiebreak as 3rd set (10)`. String Catalog 는 Xcode 가 추출 상태(`extractionState`)를 갱신하므로 빌드 후 diff 를 확인한다.
- [ ] **Step 3: 표기 구현.** 칩의 승패 색(`myGames > yourGames`)은 그대로 두고 문자열만 `[10–7]` 로 바꾼다.
- [ ] **Step 4: 빌드** — `xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build`. Expected: BUILD SUCCEEDED
- [ ] **Step 5: Commit**

```bash
git add Apps/TennisCounter/iOSApp
git commit -m "✨ feat: iOS 모드 화면에 매치 TB 토글과 결과·기록의 [10–7] 표기를 추가한다"
```

---

### Task 6: Watch UI — 토글과 `[10–7]` 표기

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/Match/Mode/ModeViewModel.swift` — Task 5 와 같은 프로퍼티·키(`lastMatchTieBreak`)
- Modify: `WatchApp/Features/WorkoutSession/Match/Mode/ModeView.swift` — `mode_no_tie` 토글 아래에 `Toggle`
- Modify: `WatchApp/Features/WorkoutSession/Match/Result/MatchResultView.swift` (세트 칩 29-36) — `[10–7]`
- Modify: `WatchApp/Localizable.xcstrings` — `mode_match_tiebreak`. 워치는 줄이 좁아 짧은 카피: ko `3세트 매치 TB` / en `Match TB`

- [ ] **Step 1: 구현** — Task 5 와 같은 방식.
- [ ] **Step 2: 빌드** — `xcodebuild … -scheme "TennisCounter Watch App" -destination "id=$WATCH" build`. Expected: BUILD SUCCEEDED
- [ ] **Step 3: Commit**

```bash
git add Apps/TennisCounter/WatchApp
git commit -m "✨ feat: 워치 모드 화면에 매치 TB 토글과 결과의 [10–7] 표기를 추가한다"
```

---

### Task 7: 검증

- [ ] **Step 1:** `make lint && make format` (Expected: 새 경고 없음. 있으면 `make fix`)
- [ ] **Step 2:** iOS 전체 테스트 `-scheme "TennisCounter" … test -only-testing:RalliTests`, Watch 전체 `-scheme "TennisCounter Watch App" … test -only-testing:RalliWatchTests`. Expected: 전부 PASS
- [ ] **Step 3:** Live Activity·Complication 스킴 빌드 (`TennisLiveActivityExtension`, `RalliComplicationExtension`) — 공유 모델을 건드렸으므로 컴파일만 확인
- [ ] **Step 4: 수동 확인** (xcodebuild 로 끝나지 않는 항목 — 사용자 확인)
  - 토글 끈 채로 3세트 경기: 1-1 이후 일반 3세트 (**기존 동작 불변**)
  - 토글 켠 채 1-1: 점수 패드가 0부터 시작하고 게임 스코어 0:0 + `TIE` 표시, 10점·2점 차에서 종료
  - 폰·워치 양쪽 시작(워치→폰 미러링)에서 토글 값이 같이 적용되는지, mirror 쪽에 10 이상 점수가 정상 표시되는지
  - Live Activity 잠금화면 점수가 10 이상에서도 깨지지 않는지
  - 결과 화면·기록 카드에서 `[10–7]` 표기, 기존 기록의 일반 세트는 그대로
  - iOS 점수 수정 시트로 세트 스코어를 1-1 로 고쳤을 때 (매치 TB 자동 진입은 하지 않는 것이 기대 동작)

---

## 열린 결정 (승인 전에 확인)

| # | 결정 | 이 플랜의 선택 | 대안 |
|---|---|---|---|
| A | 토글 노출 | 항상 표시 (`oneSet` 에서는 효과 없음). 모드 화면에 포맷 선택 상태가 없어 "3세트일 때만 표시"가 불가능 | 포맷을 3개로 쪼개 선택지로 노출 |
| B | 기록 저장 | `SetRecord` 에 `(10, 7)` 그대로 저장, 표시에서 10 이상이면 `[ ]`. 일반 세트 게임 수는 최대 7 이라 구분이 모호하지 않다. 스키마 변경 없음 | `Match` 에 `matchTieBreak` 필드 추가 (CloudKit 스키마 변경 필요) |
| C | 점수 화면 라벨 | 기존 `TIE` 재사용 | 매치 TB 전용 라벨 (`MTB`) — 문자열 2 곳 추가 |
| D | 카피 | Task 5·6 의 초안 | 사용자 확정 필요 |
| E | 범위 | 3세트 대체 방식만. "마지막 세트 6-6 에서 10점" 방식과 5세트는 제외 | 별도 이슈 |
| F | 스토어 문구 | 이 플랜 범위 밖. 구현이 머지되면 `APPSTORE.md` 출시 노트에 한 줄 (별도 PR) | — |

## 후속

- 승인 후 이 문서를 `main` 에 직접 커밋(문서 예외 규칙)하고 **YJ-32 에 GitHub URL 링크를 단다.** 링크는 커밋 이후에만 열린다.
- 구현은 브랜치 `feat/ralli-match-tiebreak` + PR(본문에 `YJ-32`). 머지는 `gh pr merge <n> --merge --delete-branch`.
