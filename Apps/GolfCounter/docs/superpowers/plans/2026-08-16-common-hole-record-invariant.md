# common: 홀 기록 불변식 — par-only 홀 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 파는 골랐지만 한 타도 치지 않은 홀(par-only 홀)이 저장·전송을 넘어가지 못하게 막고, 그래도 남아 있는 것을 화면이 잘못 그리지 않게 한다.

**Architecture:** par-only 홀은 라운드 **진행 중에는 정상 상태다** — 파 선택 화면이 카운터보다 먼저 오므로 모든 홀이 반드시 그 상태를 거친다. 그래서 입력을 막지 않고 **경계에서 정규화한다**: 워치 라운드 종료와 iOS 편집 저장에서 그런 홀의 파를 0으로 되돌려 이미 존재하는 "기록 없는 홀"로 흡수시킨다. 정규화는 새 상태를 만들지 않으므로 `trimmed()`·전송·표시가 전부 기존 경로를 탄다. 여기에 더해 `recordedHoleCount`를 오버파와 **같은 필터**로 통일해 두 지표가 항상 같은 홀 집합을 보게 하고, 두 뷰의 행 게이트를 좁혀 레거시 데이터를 방어한다.

**Tech Stack:** Swift 5(language mode) / SwiftData / SwiftUI / Swift Testing. 새 의존성 없음.

**참조 spec:** `docs/superpowers/specs/2026-08-16-hole-record-invariant-design.md` — 이 plan은 그 문서의 §5(정규화)·§6(표시 방어)·§7(기록 홀 수 정정)을 코드로 옮긴다. 섹션 번호 참조는 전부 이 spec 기준이다.

**선행 작업:** [PR #20](https://github.com/qlrogo91lp/golf_counter/pull/20)(`2026-08-16-common-relative-to-par-aggregation.md`)이 머지되어 `Shared/Models/ScoreAggregate.swift`가 존재해야 한다. **머지 완료됨** (merge commit `c2c42a2`).

**후속 plan:** ⑥ `2026-08-13-ios-stats.md` (통계 탭) — 평균 오버파와 18홀 판정이 여기서 정하는 규칙을 그대로 물려받는다. 이 plan을 ⑥보다 **먼저** 끝낸다.

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0** (ralli-kit 최소 요구)
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `🐛 fix:` / `♻️ refactor:` / `✅ test:` / `📝 docs:`), **main 직접 커밋 금지** — 브랜치 + PR, 머지는 `gh pr merge <n> --merge --delete-branch`
- 빌드 검증 시뮬레이터: iOS는 `iPhone 17 Pro`, watch/complication은 `Apple Watch Series 11 (46mm)`
- 파일 네이밍·폴더 규칙: `CLAUDE.md` 컨벤션 — **한 파일 = 한 타입**, `Shared/Models/`에는 플랫폼 독립 순수 struct/enum만
- 테스트: Swift Testing(`@Test`/`#expect`), 테스트명은 한국어 `대상_행위_예상결과`. **View는 테스트하지 않는다**
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`
- 새 파일을 만들지 않으므로 **pbxproj는 손대지 않는다**
- **기존 동작 중 바꾸지 않는 것**: `totalStrokes`·`totalPutts`·`totalPar`는 필터 없는 원시 합계 그대로. `trimmed()`의 규칙(말단 `par == 0`만 제거)도 그대로. 다이얼로그·시트·스코어카드의 **문구와 레이아웃**은 건드리지 않는다 — 숫자와 분기만 바뀐다

## 파일 구조

| 파일 | 책임 | Task |
|------|------|------|
| `Shared/Models/ScoreAggregate.swift` (수정) | `recordedHoleCount` 추가 — 집계 규칙이 존재하는 유일한 장소 | 1 |
| `watchosTests/Shared/ScoreAggregateTests.swift` (수정) | 새 규칙의 단위 테스트 | 1 |
| `Shared/Models/RoundSnapshot.swift` (수정) | `recordedHoleCount`를 `ScoreAggregate` 호출로 교체 | 2 |
| `Shared/Persistence/GolfRound.swift` (수정) | 같음 | 2 |
| `watchosTests/Shared/RoundSnapshotTrimTests.swift` (수정) | 회귀 테스트 추가 + 이름 정정 | 2 |
| `iosTests/Shared/GolfRoundTests.swift` (수정) | **옛 정의를 고정한 테스트 1건 수정** + 이름 정정 | 2 |
| `WatchApp/Features/Round/HoleProgress.swift` (수정) | `clearUnplayedHoles()` 추가 | 3 |
| `WatchApp/Features/Round/RoundViewModel.swift` (수정) | `finishRound()`에서 정규화 | 3 |
| `watchosTests/Round/HoleProgressTests.swift` (수정) | 정규화 단위 테스트 | 3 |
| `watchosTests/Round/RoundViewModelTransmissionTests.swift` (수정) | 종료→전송 통합 테스트 | 3 |
| `iOSApp/Features/History/Detail/RoundEditViewModel.swift` (수정) | 타수 0이면 파도 0으로 되쓰기 | 4 |
| `iosTests/Features/History/Detail/RoundEditViewModelTests.swift` (수정) | 되쓰기 테스트 | 4 |
| `iOSApp/Features/History/Detail/Components/HoleRow.swift` (수정) | 행 게이트를 좁힘 | 5 |
| `WatchApp/Features/Round/Scorecard/ScorecardView.swift` (수정) | 같음 | 5 |
| `docs/superpowers/specs/2026-08-13-ios-history-stats-design.md` (수정) | §3 용어 정정 | 6 |

### 기존 테스트에 대한 경고 — 반드시 읽을 것

`recordedHoleCount` 정의를 바꾸므로 기존 테스트를 전수 확인했다. **정확히 한 건이 깨지고, 그것은 의도된 것이다.**

- **깨진다 (Task 2에서 고친다)**: `iosTests/Shared/GolfRoundTests.swift`의 `파만고르고_한타도치지않은홀은_오버파에_반영되지않는다()` 마지막 단언. PR #20이 작성하면서 옛 스펙 §3의 "유효 홀 ≠ 집계 대상 홀" 구분을 주석까지 달아 고정해 두었다. 이 plan이 그 구분을 없애므로 **이 테스트는 새 정의에 맞게 고치는 것이 맞다.** Task 2가 정확한 수정 내용을 지시한다
- **안 깨진다 (확인 완료)**: `RoundSnapshotTrimTests`의 3건, `RoundViewModelHoleFlowTests:232,274`, `RoundViewModelTransmissionTests:204`, `GolfRoundTests`의 `isFullRound` 2건, `RoundEditViewModelTests:98` — 전부 픽스처가 파 있는 홀에 타수도 넣어 두어 새 정의로도 같은 값이 나온다

**위에 없는 테스트가 깨지면 멈추고 보고할 것.** 그 테스트가 par-only 홀이 세어지는 동작을 encode하고 있었다는 뜻이므로, 조용히 기대값을 고치지 않는다.

---

### Task 1: `ScoreAggregate.recordedHoleCount` 신설

**Files:**
- Modify: `Shared/Models/ScoreAggregate.swift`
- Test: `watchosTests/Shared/ScoreAggregateTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: `static func recordedHoleCount(holeScores: [Int], holePars: [Int]) -> Int`

이 태스크는 호출부를 바꾸지 않는다. Task 2가 두 타입을 이 함수로 갈아끼운다 — 그때까지 이 함수는 테스트에서만 쓰인다. 의도된 순서다.

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Shared/ScoreAggregateTests.swift`의 마지막 `}` 앞에 추가한다. 기존 `relativeToPar` 테스트 5건은 건드리지 않는다:

```swift

    @Test func 기록홀수는_파와타수가_모두있는홀만_센다() {
        let value = ScoreAggregate.recordedHoleCount(holeScores: [4, 3, 6],
                                                     holePars: [4, 3, 5])

        #expect(value == 3)
    }

    @Test func 기록홀수는_파만고른홀을_세지않는다() {
        // 파는 골랐지만 한 타도 치지 않은 홀. 오버파에서 빠지므로 홀 수에서도 빠져야
        // "18홀인데 17홀치 스코어"라는 어긋남이 안 생긴다 (spec §2.2).
        let value = ScoreAggregate.recordedHoleCount(holeScores: [4, 0, 5],
                                                     holePars: [4, 4, 4])

        #expect(value == 2)
    }

    @Test func 기록홀수는_파가0인홀을_세지않는다() {
        // 파 선택 화면을 넘기지 않고 건너뛴 홀. 옛 정의도 세지 않았다.
        let value = ScoreAggregate.recordedHoleCount(holeScores: [4, 0, 5],
                                                     holePars: [4, 0, 4])

        #expect(value == 2)
    }

    @Test func 기록홀수는_배열길이가_다르면_짧은쪽까지만_본다() {
        let value = ScoreAggregate.recordedHoleCount(holeScores: [4, 3, 6, 5],
                                                     holePars: [4, 3, 5])

        #expect(value == 3)
    }

    @Test func 기록홀수는_빈배열이면_0이다() {
        #expect(ScoreAggregate.recordedHoleCount(holeScores: [], holePars: []) == 0)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 컴파일 실패 — `type 'ScoreAggregate' has no member 'recordedHoleCount'`

- [ ] **Step 3: `recordedHoleCount` 작성**

`Shared/Models/ScoreAggregate.swift`의 `relativeToPar(holeScores:holePars:)` 아래, `enum`의 닫는 `}` 앞에 추가한다:

```swift

    /// 집계 대상 홀(`par > 0 && score > 0`)의 개수.
    ///
    /// `relativeToPar`와 **같은 필터**를 쓴다 — 두 지표가 항상 같은 홀 집합을 본다 (spec §7.1).
    /// 파만 고르고 한 타도 치지 않은 홀은 세지 않는다: 저장·전송 경계에서 정규화되어
    /// 사라질 홀이므로, 세면 홀 수와 오버파가 다른 홀 집합을 보게 된다.
    ///
    /// 배열 길이가 다르면 짧은 쪽까지만 본다 — `relativeToPar`와 같다.
    static func recordedHoleCount(holeScores: [Int], holePars: [Int]) -> Int {
        zip(holeScores, holePars)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .count
    }
```

`relativeToPar`와 필터가 글자 그대로 같아야 한다 (`$0.0 > 0 && $0.1 > 0`). 두 함수가 갈라지면 이 plan의 목적이 무너진다.

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` — 새 테스트 5건 포함 워치 타깃 전부 PASS

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add Shared/Models/ScoreAggregate.swift watchosTests/Shared/ScoreAggregateTests.swift
git commit -m "✨ feat: ScoreAggregate에 기록 홀 수 집계 추가"
```

---

### Task 2: 두 타입이 `ScoreAggregate.recordedHoleCount`를 쓰게 교체

**Files:**
- Modify: `Shared/Models/RoundSnapshot.swift` (`recordedHoleCount` 계산 프로퍼티)
- Modify: `Shared/Persistence/GolfRound.swift` (`recordedHoleCount` 계산 프로퍼티)
- Test: `watchosTests/Shared/RoundSnapshotTrimTests.swift`, `iosTests/Shared/GolfRoundTests.swift`

**Interfaces:**
- Consumes: `ScoreAggregate.recordedHoleCount(holeScores:holePars:)` (Task 1)
- Produces: 없음 (두 프로퍼티의 시그니처 그대로, 의미만 교정)

두 타입을 **한 태스크에서 함께** 바꾼다. 하나만 바꾸면 워치 요약과 iOS 뱃지가 서로 다른 수를 보이는 중간 상태가 생기는데, 그 상태에는 아무 가치가 없다.

이 태스크가 **사용자 눈에 보이는 값을 바꾼다** — 워치 종료 다이얼로그 문구, 워치 요약 헤더, iOS 리스트 `N홀` 뱃지, `isFullRound` 판정.

- [ ] **Step 1: 실패하는 회귀 테스트 작성 (워치)**

`watchosTests/Shared/RoundSnapshotTrimTests.swift`의 마지막 `}` 앞에 추가한다. 파일 상단의 `snapshot(currentHoleIndex:holeScores:holePars:puttCounts:)` 헬퍼를 재사용한다:

```swift

    @Test func 기록홀수_파만고르고_한타도치지않은홀은_세지않는다() {
        // 3번 홀은 파만 고르고 종료한 홀 — 워치 종료 경로로 만들 수 있다 (spec §4.1).
        let value = snapshot(currentHoleIndex: 2,
                             holeScores: [4, 5, 0],
                             holePars: [4, 5, 4],
                             puttCounts: [2, 2, 0])

        // 옛 정의(파가 있는 홀 개수)라면 3이 나온다.
        #expect(value.recordedHoleCount == 2)
    }
```

같은 파일에서 기존 테스트 이름 하나를 정정한다 (동작은 그대로 통과하지만 이름이 새 규칙과 어긋난다):

```swift
    @Test func 기록홀수는_파가있는_홀_개수다() {
```

를 다음으로 바꾼다:

```swift
    @Test func 기록홀수는_파와타수가_모두있는_홀_개수다() {
```

- [ ] **Step 2: 실패하는 회귀 테스트 작성 (iOS) + 옛 정의를 고정한 테스트 수정**

`iosTests/Shared/GolfRoundTests.swift`에서 **기존 테스트 `파만고르고_한타도치지않은홀은_오버파에_반영되지않는다()`의 마지막 두 줄을 교체한다.** 이 테스트는 PR #20이 옛 스펙 §3 정의를 의도적으로 고정해 둔 것이고, 이 plan이 그 정의를 바꾼다.

교체 대상 (주석 포함):

```swift
        // 파가 있는 홀이므로 기록 홀 수에는 그대로 들어간다 — 유효 홀 ≠ 집계 대상 홀 (spec §3).
        #expect(round.recordedHoleCount == 3)
```

새 내용:

```swift
        // 기록 홀 수도 오버파와 같은 필터를 쓴다 — 이 홀은 어느 쪽에도 안 들어간다 (spec §7.1).
        #expect(round.recordedHoleCount == 2)
```

같은 파일에서 기존 테스트 이름 하나를 정정한다:

```swift
    @Test func recordedHoleCount_파가있는홀만_센다() {
```

를 다음으로 바꾼다:

```swift
    @Test func recordedHoleCount_파와타수가_모두있는홀만_센다() {
```

그 테스트 안의 주석도 한 줄 정정한다. 교체 대상:

```swift
        // 3번째 홀은 워치에서 건너뛴 홀 — par 0이라 세지 않는다.
```

새 내용:

```swift
        // 3번째 홀은 워치에서 건너뛴 홀 — par와 타수가 모두 0이라 세지 않는다.
```

- [ ] **Step 3: 테스트가 실패하는지 확인 (두 타깃)**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 워치는 `기록홀수_파만고르고_한타도치지않은홀은_세지않는다` FAIL (`3 == 2`), iOS는 `파만고르고_한타도치지않은홀은_오버파에_반영되지않는다` FAIL (`3 == 2`). **다른 실패가 함께 뜨면 멈추고 보고할 것** — 위 "기존 테스트에 대한 경고"의 목록에 없는 테스트가 깨졌다는 뜻이다.

- [ ] **Step 4: `RoundSnapshot.recordedHoleCount` 교체**

`Shared/Models/RoundSnapshot.swift`에서 아래 코드를 doc comment째로 교체한다.

교체 대상:

```swift
    /// 파가 기록된 홀 수 = 유효 홀의 개수 (spec §3). 종료 확인 문구와 요약 헤더가 쓴다.
    ///
    /// 건너뛴 홀(`par == 0`)은 배열 **중간**에 남아 있어도 세지 않는다 —
    /// `GolfRound.recordedHoleCount`와 같은 규칙이라 워치 요약과 iOS 기록 뱃지가 같은 수를 보인다.
    /// 말단 0은 `filter`가 알아서 걸러내므로 `trimmed()`를 거칠 필요가 없다.
    var recordedHoleCount: Int {
        holePars.filter { $0 > 0 }.count
    }
```

새 내용:

```swift
    /// 집계 대상 홀(파와 타수가 모두 있는 홀)의 개수. 규칙은 `ScoreAggregate` 참조 (spec §7).
    ///
    /// 종료 확인 문구와 요약 헤더가 쓴다. `GolfRound.recordedHoleCount`와 같은 규칙이라
    /// 워치 요약과 iOS 기록 뱃지가 같은 수를 보인다. 배열 중간에 낀 건너뛴 홀도, 말단의
    /// 미기록 홀도 필터가 알아서 걸러내므로 `trimmed()`를 거칠 필요가 없다.
    var recordedHoleCount: Int {
        ScoreAggregate.recordedHoleCount(holeScores: holeScores, holePars: holePars)
    }
```

- [ ] **Step 5: `GolfRound.recordedHoleCount` 교체**

`Shared/Persistence/GolfRound.swift`에서 아래 코드를 doc comment째로 교체한다.

교체 대상:

```swift
    /// 파가 기록된 홀 수. 워치에서 건너뛴 홀(par == 0)은 세지 않는다 (spec §3).
    /// 기록 리스트의 `N홀` 뱃지와 통계의 18홀 판정이 같은 값을 쓴다.
    var recordedHoleCount: Int {
        holePars.filter { $0 > 0 }.count
    }
```

새 내용:

```swift
    /// 집계 대상 홀(파와 타수가 모두 있는 홀)의 개수. 규칙은 `ScoreAggregate` 참조 (spec §7).
    /// 기록 리스트의 `N홀` 뱃지와 통계의 18홀 판정이 같은 값을 쓴다.
    var recordedHoleCount: Int {
        ScoreAggregate.recordedHoleCount(holeScores: holeScores, holePars: holePars)
    }
```

`isFullRound`는 그대로 둔다 — `recordedHoleCount == 18`이라는 식은 안 바뀌고, 의미만 "18홀 전부 점수가 있는 라운드"로 좁아진다.

- [ ] **Step 6: 세 타깃 테스트·빌드 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: 워치·iOS 모두 `** TEST SUCCEEDED **`, 컴플리케이션 `** BUILD SUCCEEDED **`

- [ ] **Step 7: 커밋**

```bash
make lint && make format
git add Shared/Models/RoundSnapshot.swift Shared/Persistence/GolfRound.swift \
        watchosTests/Shared/RoundSnapshotTrimTests.swift iosTests/Shared/GolfRoundTests.swift
git commit -m "🐛 fix: 기록 홀 수를 오버파와 같은 필터로 통일"
```

---

### Task 3: 워치 — 종료 시 미타구 홀 정규화

**Files:**
- Modify: `WatchApp/Features/Round/HoleProgress.swift` (`clearUnplayedHoles()` 추가)
- Modify: `WatchApp/Features/Round/RoundViewModel.swift` (`finishRound()`)
- Test: `watchosTests/Round/HoleProgressTests.swift`, `watchosTests/Round/RoundViewModelTransmissionTests.swift`

**Interfaces:**
- Consumes: 없음 (Task 1·2와 독립적으로 동작하지만, Task 2가 끝나야 테스트의 `recordedHoleCount` 기대값이 맞는다)
- Produces: `HoleProgress.clearUnplayedHoles()` — `mutating`, 반환값 없음

- [ ] **Step 1: 실패하는 단위 테스트 작성 (`HoleProgress`)**

`watchosTests/Round/HoleProgressTests.swift`의 마지막 `}` 앞에 추가한다:

```swift

    // MARK: - clearUnplayedHoles (종료 시 미타구 홀 정규화)

    @Test func 미타구홀정리_파만있는_현재홀의_파를_지운다() {
        var progress = HoleProgress(holeCount: 18)
        progress.setPar(4)

        progress.clearUnplayedHoles()

        #expect(progress.holePars == [0])
        #expect(progress.holeScores == [0])
    }

    @Test func 미타구홀정리_이전버튼으로_두고온홀도_지운다() {
        // 홀 1을 치고 홀 2에서 파만 고른 뒤 이전 버튼으로 홀 1에 돌아온 상태 (spec §4.2).
        // 홀 2는 현재 홀이 아니므로, 대상을 현재 홀로 좁히면 놓친다.
        var progress = HoleProgress(holeCount: 18)
        progress.setPar(4)
        progress.apply(.swing)
        progress.advanceToNextHole()
        progress.setPar(3)
        progress.retreatToPreviousHole()

        progress.clearUnplayedHoles()

        #expect(progress.holePars == [4, 0])
        #expect(progress.holeScores == [1, 0])
        #expect(progress.currentHoleIndex == 0)
    }

    @Test func 미타구홀정리_타수가있는홀은_건드리지않는다() {
        var progress = HoleProgress(holeCount: 18)
        progress.setPar(4)
        progress.apply(.swing)
        progress.apply(.putt)

        progress.clearUnplayedHoles()

        #expect(progress.holePars == [4])
        #expect(progress.holeScores == [2])
        #expect(progress.puttCounts == [1])
    }

    @Test func 미타구홀정리_파가_원래_0인홀은_그대로다() {
        var progress = HoleProgress(holeCount: 18)
        progress.setPar(4)
        progress.apply(.swing)
        progress.advanceToNextHole()

        progress.clearUnplayedHoles()

        #expect(progress.holePars == [4, 0])
        #expect(progress.holeScores == [1, 0])
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 컴파일 실패 — `value of type 'HoleProgress' has no member 'clearUnplayedHoles'`

- [ ] **Step 3: `clearUnplayedHoles()` 작성**

`WatchApp/Features/Round/HoleProgress.swift`의 `setPar(_:)` 바로 아래, `// MARK: - 홀 이동` 위에 추가한다:

```swift

    /// 파는 있는데 한 타도 치지 않은 홀의 파를 지워 "기록 없는 홀"로 되돌린다.
    ///
    /// `RoundViewModel.skipCurrentHole()`이 홀 이동 경계에서 현재 홀 하나에 하는 일을,
    /// 라운드 종료 경계에서 남아 있는 **모든** 홀에 대해 한다 (spec §5.2). 이전 홀 버튼으로
    /// 되돌아가 두고 온 홀은 현재 홀이 아니므로, 대상을 현재 홀로 좁히면 놓친다 (spec §4.2).
    ///
    /// 타수가 있는 홀은 건드리지 않는다 — 파를 지우면 그 타수가 미아가 되고,
    /// `par == 0 && score > 0`은 어느 화면도 해석할 수 없는 상태다.
    mutating func clearUnplayedHoles() {
        for index in holePars.indices where index < holeScores.count {
            if holePars[index] > 0, holeScores[index] == 0 {
                holePars[index] = 0
            }
        }
    }
```

`index < holeScores.count` 가드가 필요한 이유: 세 배열의 길이가 항상 같다는 것이 이 타입의 불변식이지만, 복구 `init`은 어긋난 값을 받을 수 있다. 짧은 쪽까지만 보는 것이 `ScoreAggregate`의 `zip` 동작과도 일치한다.

- [ ] **Step 4: 단위 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 실패하는 통합 테스트 작성 (`RoundViewModel`)**

`watchosTests/Round/RoundViewModelTransmissionTests.swift`의 마지막 `}` 앞에 추가한다. 파일 상단의 `makeViewModel(holeCount:publisher:transmitter:)`와 `playHole(_:par:strokes:)` 헬퍼를 재사용한다:

```swift

    // MARK: - 종료 시 미타구 홀 정규화

    @Test func 종료하면_파만고른_말단홀이_전송에서_빠진다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole()
        viewModel.selectPar(3) // 파만 고르고 종료

        viewModel.finishRound()
        viewModel.applyMetrics(nil)
        viewModel.saveAndTransmit()

        // 파가 0으로 돌아간 뒤 말단이므로 trimmed()가 배열에서 아예 제거한다.
        #expect(transmitter.sent.first?.holePars == [4])
        #expect(transmitter.sent.first?.holeScores == [5])
        #expect(viewModel.recordedHoleCount == 1)
    }

    @Test func 종료하면_이전버튼으로_두고온_파만고른홀도_정리된다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole()
        viewModel.selectPar(3) // 홀 2에 파만 남기고
        viewModel.goToPreviousHole() // 홀 1로 돌아와 종료 (spec §4.2)

        viewModel.finishRound()
        viewModel.applyMetrics(nil)
        viewModel.saveAndTransmit()

        #expect(transmitter.sent.first?.holePars == [4])
        #expect(viewModel.recordedHoleCount == 1)
    }

    @Test func 전부_파만고른_라운드는_빈라운드로_처리된다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        viewModel.selectPar(4)

        viewModel.finishRound()
        viewModel.applyMetrics(nil)
        viewModel.saveAndTransmit()

        // 기록 홀이 0이므로 iOS에 빈 라운드를 만들지 않는다 (spec §5.3).
        #expect(transmitter.sent.isEmpty)
        #expect(viewModel.didComplete)
    }
```

- [ ] **Step 6: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 새 테스트 **3건 중 2건** FAIL — `종료하면_파만고른_말단홀이_전송에서_빠진다`와 `종료하면_이전버튼으로_두고온_파만고른홀도_정리된다`가 `holePars`를 `[4, 3]`으로 전송해 실패한다.

세 번째 `전부_파만고른_라운드는_빈라운드로_처리된다`는 **이 시점에 이미 통과한다** — Task 2가 `recordedHoleCount`를 집계 대상 홀 기준으로 바꿔 놓아, 정규화 없이도 0홀 가드가 걸리기 때문이다. 그래도 남기는 이유는 정규화가 붙은 뒤에도 이 경로가 유지되는지 고정하기 위해서다(spec §5.3). **RED가 안 뜬다고 이 테스트를 지우지 말 것.**

- [ ] **Step 7: `finishRound()`에 정규화 연결**

`WatchApp/Features/Round/RoundViewModel.swift`에서 아래 코드를 doc comment째로 교체한다.

교체 대상:

```swift
    /// 종료 확인에서 호출한다. 워크아웃 종료는 View가 async로 진행하고,
    /// 도착한 결과는 `applyMetrics(_:)`로 들어온다 (spec §7).
    func finishRound() {
        endedAt = Date()
        isFinished = true
    }
```

새 내용:

```swift
    /// 종료 확인에서 호출한다. 워크아웃 종료는 View가 async로 진행하고,
    /// 도착한 결과는 `applyMetrics(_:)`로 들어온다 (spec §7).
    ///
    /// 먼저 미타구 홀을 정규화한다 — `isFinished`를 세우는 순간 요약 화면이 뜨므로,
    /// 그 전에 배열이 정리돼 있어야 요약과 전송이 같은 값을 본다 (spec §5.2).
    ///
    /// 정규화를 종료 확인 **다이얼로그보다 뒤**에 두는 것이 핵심이다. 다이얼로그 전에
    /// 현재 홀의 파를 지우면 `phase`가 파 선택으로 튕겨, 사용자가 "취소"를 눌렀을 때
    /// 홀이 초기화된 것처럼 보인다 (spec §5.1). 다이얼로그 문구의 정확성은
    /// `recordedHoleCount`가 집계 대상 홀을 세는 것으로 이미 보장된다.
    func finishRound() {
        progress.clearUnplayedHoles()
        publishSnapshot()
        endedAt = Date()
        isFinished = true
    }
```

`publishSnapshot()`을 부르는 이유: 상태가 실제로 바뀌었고, App Group 스냅샷은 컴플리케이션과 크래시 복구의 데이터원이다. 발행하지 않으면 종료와 전송 사이에 크래시가 났을 때 정규화 이전 상태로 복구된다. `skipCurrentHole()`도 같은 이유로 발행한다.

- [ ] **Step 8: 통합 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` — 새 테스트 7건 포함 워치 타깃 전부 PASS

- [ ] **Step 9: 커밋**

```bash
make lint && make format
git add WatchApp/Features/Round/HoleProgress.swift WatchApp/Features/Round/RoundViewModel.swift \
        watchosTests/Round/HoleProgressTests.swift watchosTests/Round/RoundViewModelTransmissionTests.swift
git commit -m "✨ feat: 워치 라운드 종료 시 미타구 홀 정규화"
```

---

### Task 4: iOS — 편집 저장 시 정규화

**Files:**
- Modify: `iOSApp/Features/History/Detail/RoundEditViewModel.swift` (`apply(to:holeIndex:)`)
- Test: `iosTests/Features/History/Detail/RoundEditViewModelTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (`apply(to:holeIndex:)`의 시그니처 그대로, 되쓰기 규칙만 추가)

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Features/History/Detail/RoundEditViewModelTests.swift`의 마지막 `}` 앞에 추가한다:

```swift

    @Test func 되쓰기_타수가0이면_파도지워_기록없는홀로_되돌린다() {
        let round = GolfRound()
        round.holeScores = [4, 3, 5]
        round.holePars = [4, 3, 5]
        round.puttCounts = [2, 1, 2]
        var model = RoundEditViewModel(par: 3, score: 3, putts: 0)

        model.decrementScore()
        model.decrementScore()
        model.decrementScore()
        model.apply(to: round, holeIndex: 1)

        #expect(model.score == 0)
        // 타수를 0까지 내린 것은 "이 홀은 사실 안 쳤다"는 뜻이다 (spec §5.4).
        #expect(round.holeScores == [4, 0, 5])
        #expect(round.holePars == [4, 0, 5])
        #expect(round.recordedHoleCount == 2)
    }

    @Test func 되쓰기_건너뛴홀에_파만넣으면_여전히_기록없는홀이다() {
        let round = GolfRound()
        round.holeScores = [4, 0, 3]
        round.holePars = [4, 0, 3]
        round.puttCounts = [2, 0, 1]
        var model = RoundEditViewModel(par: 0, score: 0, putts: 0)

        model.setPar(4)
        model.apply(to: round, holeIndex: 1)

        // 파만 고르고 타수를 안 넣었으므로 par-only 홀이 만들어지지 않는다 (spec §4.4).
        #expect(round.holePars == [4, 0, 3])
        #expect(round.holeScores == [4, 0, 3])
        #expect(round.recordedHoleCount == 2)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 새 테스트 2건 FAIL — `holePars`가 각각 `[4, 3, 5]`·`[4, 4, 3]`으로 par-only 홀이 남는다

- [ ] **Step 3: `apply(to:holeIndex:)` 교체**

`iOSApp/Features/History/Detail/RoundEditViewModel.swift`에서 아래 코드를 doc comment째로 교체한다.

교체 대상:

```swift
    /// 편집 결과를 라운드의 병렬 배열에 되쓴다.
    /// `holeScores`에 없는 홀은 존재하지 않는 홀이므로 무시하고, 나머지 두 배열이 짧으면 0으로 채운다.
    func apply(to round: GolfRound, holeIndex: Int) {
        guard holeIndex >= 0, holeIndex < round.holeScores.count else { return }
        let count = round.holeScores.count

        var pars = Self.padded(round.holePars, to: count)
        var putts = Self.padded(round.puttCounts, to: count)
        pars[holeIndex] = par
        putts[holeIndex] = self.putts

        round.holeScores[holeIndex] = score
        round.holePars = pars
        round.puttCounts = putts
    }
```

새 내용:

```swift
    /// 편집 결과를 라운드의 병렬 배열에 되쓴다.
    /// `holeScores`에 없는 홀은 존재하지 않는 홀이므로 무시하고, 나머지 두 배열이 짧으면 0으로 채운다.
    ///
    /// 타수가 0이면 파도 0으로 쓴다 — 저장 경계에서의 정규화다 (spec §5.4). 파만 있고
    /// 타수가 없는 홀은 오버파에서도 기록 홀 수에서도 빠지므로 화면마다 어긋나 보인다.
    /// 이 규칙 덕분에 타수를 0까지 내리는 것이 "이 홀은 사실 안 쳤다"를 되돌리는
    /// 구제 경로가 된다 — 라운드가 끝난 뒤 워치 오기록을 고칠 수 있는 유일한 지점이다.
    func apply(to round: GolfRound, holeIndex: Int) {
        guard holeIndex >= 0, holeIndex < round.holeScores.count else { return }
        let count = round.holeScores.count

        var pars = Self.padded(round.holePars, to: count)
        var putts = Self.padded(round.puttCounts, to: count)
        pars[holeIndex] = score > 0 ? par : 0
        putts[holeIndex] = self.putts

        round.holeScores[holeIndex] = score
        round.holePars = pars
        round.puttCounts = putts
    }
```

`putts`는 손대지 않는다. 타수가 0이면 불변식(`score >= putts`)에 의해 `putts`도 이미 0이다.

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` — 새 테스트 2건 포함 iOS 타깃 전부 PASS

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add iOSApp/Features/History/Detail/RoundEditViewModel.swift \
        iosTests/Features/History/Detail/RoundEditViewModelTests.swift
git commit -m "✨ feat: iOS 홀 편집 저장 시 미타구 홀 정규화"
```

---

### Task 5: 표시 방어 — 두 뷰의 행 게이트

**Files:**
- Modify: `iOSApp/Features/History/Detail/Components/HoleRow.swift`
- Modify: `WatchApp/Features/Round/Scorecard/ScorecardView.swift`

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (뷰 내부 분기만 바뀐다)

**View는 테스트하지 않는다**(CLAUDE.md). 이 태스크의 검증은 두 타깃 빌드 성공과 기존 테스트 무회귀다.

Task 3·4의 정규화가 서면 새 데이터는 이 분기에 걸리지 않는다. 이 방어는 **이미 저장된 레거시 라운드**와 미래의 누수를 위한 것이다 (spec §6).

- [ ] **Step 1: `HoleRow` 게이트 좁히기**

`iOSApp/Features/History/Detail/Components/HoleRow.swift`에서 파일 상단 doc comment와 `isRecorded`를 교체한다.

교체 대상:

```swift
/// 상세 스코어카드의 한 홀.
/// 워치에서 건너뛴 홀(par == 0)은 오버파를 계산할 수 없으므로 "기록 없음"으로 표시한다 (spec §4).
struct HoleRow: View {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int

    private var isRecorded: Bool {
        par > 0
    }
```

새 내용:

```swift
/// 상세 스코어카드의 한 홀.
/// 기록 없는 홀은 오버파를 계산할 수 없으므로 "기록 없음"으로 표시한다 (spec §6).
///
/// 두 종류를 같이 다룬다 — 워치에서 건너뛴 홀(`par == 0`)과, 파만 고르고 한 타도 치지
/// 않은 홀(`par > 0 && score == 0`). 후자는 저장 경계에서 정규화되므로 새 데이터에는
/// 없지만, 이미 저장된 라운드에는 남아 있을 수 있다. 행을 탭하면 편집 시트가 저장된 파를
/// 그대로 보여주므로 이 분기가 수정 경로를 막지는 않는다.
struct HoleRow: View {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int

    private var isRecorded: Bool {
        par > 0 && score > 0
    }
```

`body`는 손대지 않는다 — `isRecorded`가 이미 Par 칸·타수 칸·오버파 칸을 전부 가른다.

- [ ] **Step 2: `ScorecardView` 게이트 좁히기**

`WatchApp/Features/Round/Scorecard/ScorecardView.swift`에서 행을 그리는 두 줄을 교체한다.

교체 대상:

```swift
                    Text(row.par > 0 ? "Par\(row.par)" : "—")
                        .frame(width: 38, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text("\(row.score)타(\(row.putts)p)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.par > 0 ? ScoreFormat.relativeToPar(row.score - row.par) : "")
```

새 내용:

```swift
                    Text(row.isRecorded ? "Par\(row.par)" : "—")
                        .frame(width: 38, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text("\(row.score)타(\(row.putts)p)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.isRecorded ? ScoreFormat.relativeToPar(row.score - row.par) : "")
```

타수 칸(`\(row.score)타(\(row.putts)p)`)은 그대로 둔다 — 기록 없는 홀은 `0타(0p)`로 보이는데, 이는 `par == 0` 홀의 기존 표시와 같다.

같은 파일 아래쪽의 `ScorecardRow`에 `isRecorded`를 추가한다.

교체 대상:

```swift
private struct ScorecardRow {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int
}
```

새 내용:

```swift
private struct ScorecardRow {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int

    /// 기록된 홀 = 파와 타수가 모두 있는 홀. `HoleRow`(iOS)와 같은 규칙이다 (spec §6).
    var isRecorded: Bool {
        par > 0 && score > 0
    }
}
```

- [ ] **Step 3: 세 타깃 빌드·테스트 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: 워치·iOS `** TEST SUCCEEDED **`, 컴플리케이션 `** BUILD SUCCEEDED **`. 기존 테스트가 하나도 안 깨져야 한다 — View는 테스트 대상이 아니므로 이 변경은 테스트에 보이지 않는다.

- [ ] **Step 4: 커밋**

```bash
make lint && make format
git add iOSApp/Features/History/Detail/Components/HoleRow.swift \
        WatchApp/Features/Round/Scorecard/ScorecardView.swift
git commit -m "🐛 fix: 미타구 홀을 스코어카드에서도 기록 없음으로 표시"
```

---

### Task 6: 스펙 §3 정정

**Files:**
- Modify: `docs/superpowers/specs/2026-08-13-ios-history-stats-design.md` (§3 용어와 공통 계산 규칙)

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (문서만)

코드 변경이 없으므로 테스트 단계가 없다. 이 태스크의 검증은 §3을 다시 읽었을 때 Task 1~5의 코드와 어긋나는 문장이 없는지다.

- [ ] **Step 1: §3의 용어 항목 교체**

`docs/superpowers/specs/2026-08-13-ios-history-stats-design.md`에서 아래 세 줄을 교체한다 (75~77행).

교체 대상:

```markdown
- **유효 홀**: `holePars[i] > 0` 인 홀. 워치에서 파를 고르지 않은 홀(`par == 0`)은 배열 중간에 남아 있을 수 있다 — 사용자가 의도적으로 건너뛴 홀이며 카운터에 접근한 적이 없으므로 `score`·`putts`도 0이다(스펙 §3).
- **집계 대상 홀**: 유효 홀 중 `holeScores[i] > 0` 인 홀. 파는 골랐지만 한 타도 치지 않고 넘어간 홀을 제외한다 — 이 홀을 넣으면 `score − par`가 음수가 되어 버디로 잘못 집계된다.
- **기록 홀 수**: 유효 홀의 개수. 리스트 뱃지에 `N홀`로 그대로 표시한다. `GolfRound.recordedHoleCount`로 파생한다.
```

새 내용:

```markdown
- **홀 기록 불변식**: **저장·전송되는** 모든 홀은 `par > 0 && score > 0`이거나 `par == 0 && score == 0`이다. 즉 `(par > 0) == (score > 0)`. 라운드 진행 중에는 파만 고른 홀이 정상 상태이므로(파 선택 화면이 카운터보다 먼저 온다) 입력을 막지 않고 **경계에서 정규화한다** — 워치 홀 이동(`skipCurrentHole()`), 워치 라운드 종료(`HoleProgress.clearUnplayedHoles()`), iOS 편집 저장(`RoundEditViewModel.apply(to:holeIndex:)`) 세 곳이다 (2026-08-16 추가, spec `2026-08-16-hole-record-invariant-design.md`).
- **유효 홀**: `holePars[i] > 0` 인 홀. 워치에서 파를 고르지 않은 홀(`par == 0`)은 배열 중간에 남아 있을 수 있다 — 사용자가 의도적으로 건너뛴 홀이며 카운터에 접근한 적이 없으므로 `score`·`putts`도 0이다(스펙 §3).
- **집계 대상 홀**: 유효 홀 중 `holeScores[i] > 0` 인 홀. 파는 골랐지만 한 타도 치지 않고 넘어간 홀을 제외한다 — 이 홀을 넣으면 `score − par`가 음수가 되어 버디로 잘못 집계된다.
	- 위 불변식이 서면 **유효 홀과 집계 대상 홀은 같은 집합이다.** 두 용어를 남겨 두는 이유는 불변식 이전에 저장된 레거시 라운드를 설명할 때 여전히 필요하기 때문이며, **지표 계산에는 집계 대상 홀만 쓴다.**
- **기록 홀 수**: 집계 대상 홀의 개수. 리스트 뱃지에 `N홀`로 그대로 표시한다. `ScoreAggregate.recordedHoleCount(holeScores:holePars:)` 한 곳에서 계산하고 `GolfRound`·`RoundSnapshot`이 그것을 부른다 — 오버파와 **같은 필터**라 두 지표가 항상 같은 홀 집합을 본다. 초판은 "유효 홀의 개수"로 적었고, 그러면 파만 고른 홀이 홀 수에는 잡히고 오버파에서는 빠져 "18홀인데 17홀치 스코어"가 된다 (2026-08-16 정정).
```

- [ ] **Step 2: `18홀 라운드` 항목 보강**

교체 대상 (78행):

```markdown
- **18홀 라운드**: 기록 홀 수가 정확히 18인 라운드(`GolfRound.isFullRound`). 9홀을 골랐거나 18홀을 고르고 중단한 라운드는 여기 포함되지 않는다.
```

새 내용:

```markdown
- **18홀 라운드**: 기록 홀 수가 정확히 18인 라운드(`GolfRound.isFullRound`). 9홀을 골랐거나 18홀을 고르고 중단한 라운드는 여기 포함되지 않는다. 기록 홀 수 정정(위)에 따라 **18홀 전부에 실제 점수가 있는 라운드**만 해당한다 — 점수가 빠진 홀이 있으면 총타수 기반 통계가 왜곡되므로 이쪽이 맞다.
```

- [ ] **Step 3: §3을 통독하며 코드와 대조**

`Shared/Models/ScoreAggregate.swift`를 옆에 두고 §3 전체를 다시 읽는다. 오버파 항목(79~81행)은 PR #20이 이미 정정했으므로 **그대로 둔다.** 새로 어긋나는 문장이 발견되면 고치고, 판단이 서지 않으면 보고한다.

- [ ] **Step 4: 커밋**

```bash
git add docs/superpowers/specs/2026-08-13-ios-history-stats-design.md
git commit -m "📝 docs: 홀 기록 불변식 반영해 spec §3 정정"
```

---

## 완료 조건

- 파만 고르고 한 타도 치지 않은 홀이 **저장·전송을 넘어가지 못한다** — 워치 종료(현재 홀·이전 버튼으로 두고 온 홀 모두)와 iOS 편집 저장 양쪽에서
- 그런 홀이 이미 저장된 라운드에 있어도 워치 스코어카드·iOS 상세 어디에서도 `-par`로 보이지 않는다
- `recordedHoleCount`가 오버파와 같은 홀 집합을 센다 — 워치 종료 다이얼로그, 워치 요약, iOS `N홀` 뱃지, `isFullRound` 전부
- 오버파·기록 홀 수 계산이 `ScoreAggregate` 한 곳에만 존재한다
- 세 타깃(`GolfCounter` / `GolfCounter Watch App` / `ComplicationAppExtension`) 전부 빌드 성공, iOS·워치 테스트 전부 통과
- `make lint`·`make format` 위반 0
- 스펙 §3이 새 규칙과 일치한다

## 검증 시 눈으로 확인할 것 (선택)

워치 시뮬레이터에서 1번 홀을 치고 2번 홀에서 **파만 고른 뒤 종료**한다. 종료 확인 다이얼로그가 `2홀이 기록됩니다`가 아니라 **`1홀이 기록됩니다`**로 떠야 하고, 요약과 스코어카드에도 2번 홀이 남지 않아야 한다. 다이얼로그에서 **취소**를 눌렀을 때 파 선택 화면이 아니라 **2번 홀 카운터로 돌아오는지**도 함께 확인한다 (spec §5.1의 기각 사유).
