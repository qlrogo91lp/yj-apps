# common: 오버파 집계에서 미타구 홀 제외 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 파는 골랐지만 한 타도 치지 않은 홀이 오버파 합계에 `0 − par`(언더파)로 새어 드는 버그를 워치·iOS·컴플리케이션에서 한꺼번에 없앤다.

**Architecture:** 현재 `GolfRound`와 `RoundSnapshot`이 **같은 zip 합산 로직을 각자 중복 정의**하고 있다. 계산을 `ScoreAggregate` 한 곳으로 뽑아 두 타입이 그것을 호출하게 바꾼다 — 그래야 규칙이 한 곳에만 존재하고, 앞으로 plan ⑥(통계 탭)의 평균 오버파도 같은 규칙을 재사용할 수 있다. 새 규칙은 spec §3이 이미 정의해 둔 **집계 대상 홀**(`par > 0 && score > 0`)이며, 이 plan은 그 정의를 코드에 반영하는 것이 전부다.

**Tech Stack:** Swift 5(language mode) / SwiftData / Swift Testing. 새 의존성 없음.

**참조 spec:** `docs/superpowers/specs/2026-08-13-ios-history-stats-design.md` §3 (용어와 공통 계산 규칙 — 유효 홀 / 집계 대상 홀 / 오버파). §3의 오버파 항목은 이 plan과 함께 정정되었다.

**선행 조건:** [PR #15](https://github.com/qlrogo91lp/golf_counter/pull/15)(plan ⑤)가 **먼저 머지되어야 한다.** 이 plan이 고치는 `Shared/Persistence/GolfRound.swift`를 PR #15도 수정했으므로, 머지 전에 브랜치를 따면 충돌한다.

**후속 plan:** ⑥ `2026-08-13-ios-stats.md` (통계 탭) — 평균 오버파가 이 규칙을 그대로 물려받는다. 이 plan을 ⑥보다 **먼저** 끝내야 ⑥의 통계 계산·테스트를 두 번 쓰지 않는다.

## 배경: 이 홀이 어떻게 생기나

두 경로 모두 실제로 도달 가능하다.

1. **워치** — 새 홀에 들어가면 파 선택 화면이 먼저 뜨고, 파를 고르면 카운터가 열린다. 그런데 `HoleProgress.canGoToNextHole`은 홀 수 상한만 보고 타수 기록 여부는 보지 않는다. 그래서 파만 고르고 다음 홀로 넘기거나, **파만 고른 상태에서 라운드를 종료**하면 그 홀이 `score = 0, par = N`으로 남는다. `RoundSnapshot.trimmed()`는 `par == 0`인 말단 홀만 잘라내므로 이 홀은 살아남아 iOS로 전송된다.
2. **iOS 홀 편집 시트** — 기록 없는 홀을 탭해 파만 고르고 타수를 그대로 둔 채 저장하면 같은 상태가 된다.

`RoundSnapshot.relativeToPar`는 워치 카운터 헤더·스코어카드 합계·종료 요약·**컴플리케이션**이 함께 쓰므로, 이 버그는 현재 워치 메인 화면에 상시 노출된다 — 홀마다 파를 고르는 순간 누적 오버파가 `-par`만큼 떨어졌다가 타수를 칠 때마다 회복된다.

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0** (ralli-kit 최소 요구)
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `🐛 fix:` / `♻️ refactor:` / `✅ test:` / `📝 docs:`), **main 직접 커밋 금지** — 브랜치 + PR, 머지는 `gh pr merge <n> --merge --delete-branch`
- 빌드 검증 시뮬레이터: iOS는 `iPhone 17 Pro`, watch/complication은 `Apple Watch Series 11 (46mm)` (`xcrun simctl list devices available`로 존재 확인)
- 파일 네이밍·폴더 규칙: `CLAUDE.md` 컨벤션 — **한 파일 = 한 타입**, `Shared/Models/`에는 플랫폼 독립 순수 struct/enum만
- 테스트: Swift Testing(`@Test`/`#expect`), 테스트명은 한국어 `대상_행위_예상결과`
- `Shared/`는 `PBXFileSystemSynchronizedRootGroup`이라 **파일 생성만으로 세 타깃 전부에 반영된다.** 이 plan은 pbxproj를 손대지 않는다 — 새 파일이 `import Foundation`만 쓰므로 컴플리케이션 타깃(ralli-kit 미링크)에서도 안전하다
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`
- **기존 동작 중 바꾸지 않는 것**: `totalStrokes`·`totalPutts`·`totalPar`는 필터를 걸지 않는다(원시 합계). `recordedHoleCount`도 그대로 — 유효 홀(파가 있는 홀) 개수이지 집계 대상 홀 개수가 아니다

## 파일 구조

| 파일 | 책임 |
|------|------|
| `Shared/Models/ScoreAggregate.swift` (신규) | 홀 배열 → 오버파 집계. 규칙이 존재하는 유일한 장소 |
| `Shared/Models/RoundSnapshot.swift` (수정) | `relativeToPar`가 `ScoreAggregate` 호출로 교체 — 워치 3화면 + 컴플리케이션에 영향 |
| `Shared/Persistence/GolfRound.swift` (수정) | `relativeToPar`가 `ScoreAggregate` 호출로 교체 — iOS 기록 리스트·상세에 영향 |
| `watchosTests/Shared/ScoreAggregateTests.swift` (신규) | 집계 규칙 자체의 단위 테스트 |
| `watchosTests/Shared/RoundSnapshotTests.swift` (수정) | 워치 회귀 테스트 1건 추가 |
| `iosTests/Shared/GolfRoundTests.swift` (수정) | iOS 회귀 테스트 1건 추가 |

`Shared/Models/`의 테스트는 기존 관례대로 `watchosTests/Shared/`에 둔다(`ScoreFormatTests`·`RoundSnapshotTests`·`ComplicationStateTests`가 모두 거기 있다). `GolfRound`만 `iosTests/Shared/`에 있으므로 그것만 예외적으로 iOS 쪽에 추가한다.

**기존 테스트는 하나도 깨지지 않는다** — 확인 결과 모든 기존 픽스처가 파가 있는 홀에는 타수도 넣어 두었다(`RoundSnapshotTests`의 7홀 픽스처, `ComplicationStateTests`의 3홀 픽스처, `RoundViewModelHoleFlowTests`는 항상 파 선택 후 타수를 친다). 즉 버그 상태를 고정해 둔 테스트가 없다. 만약 어떤 테스트가 깨진다면 그 테스트가 버그를 encode하고 있었다는 뜻이므로, 고치기 전에 **보고할 것.**

---

### Task 1: `ScoreAggregate` 신설

**Files:**
- Create: `Shared/Models/ScoreAggregate.swift`
- Test: `watchosTests/Shared/ScoreAggregateTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: `enum ScoreAggregate`, `static func relativeToPar(holeScores: [Int], holePars: [Int]) -> Int`

이 태스크는 호출부를 바꾸지 않는다. 순수 계산 타입만 만들고 테스트로 규칙을 고정한다 — Task 2·3이 각각 워치와 iOS를 이 함수로 갈아끼운다.

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Shared/ScoreAggregateTests.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct ScoreAggregateTests {
    @Test func 파와타수가_모두있는홀만_합산한다() {
        let value = ScoreAggregate.relativeToPar(holeScores: [4, 3, 6],
                                                holePars: [4, 3, 5])

        #expect(value == 1)
    }

    @Test func 파는골랐지만_타수가0인홀은_제외한다() {
        // 파만 고르고 한 타도 치지 않고 넘어간 홀. 옛 공식이라면 0 − 4 = −4가 새어 든다.
        let value = ScoreAggregate.relativeToPar(holeScores: [4, 0],
                                                 holePars: [4, 4])

        #expect(value == 0)
    }

    @Test func 파가0인홀은_제외한다() {
        // 파 선택 화면을 넘기지 않은 홀. 원래도 0으로 기여했지만 규칙으로 명시한다.
        let value = ScoreAggregate.relativeToPar(holeScores: [4, 0, 5],
                                                 holePars: [4, 0, 4])

        #expect(value == 1)
    }

    @Test func 배열길이가_다르면_짧은쪽까지만_본다() {
        // 타수는 쳤지만 파가 아직 배열에 없는 말단 홀을 자동으로 무시한다.
        let value = ScoreAggregate.relativeToPar(holeScores: [4, 3, 6, 5],
                                                 holePars: [4, 3, 5])

        #expect(value == 1)
    }

    @Test func 빈배열은_0이다() {
        #expect(ScoreAggregate.relativeToPar(holeScores: [], holePars: []) == 0)
    }
}
```

위 import 3줄은 같은 폴더의 `watchosTests/Shared/ScoreFormatTests.swift`와 동일하다 (확인 완료). `swiftformat`의 `--importgrouping alpha` 규칙이 적용되어 있으니 순서를 임의로 바꾸지 말 것.

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'ScoreAggregate' in scope`

- [ ] **Step 3: `ScoreAggregate` 작성**

`Shared/Models/ScoreAggregate.swift` 신규 생성:

```swift
import Foundation

/// 홀 배열에서 라운드 지표를 집계한다.
/// iOS(`GolfRound`)와 워치(`RoundSnapshot`)가 같은 규칙을 쓰도록 계산을 한 곳에 모아 둔다 (spec §3).
enum ScoreAggregate {
    /// 집계 대상 홀(`par > 0 && score > 0`)에 대해서만 `Σ(score − par)`.
    ///
    /// 두 종류의 홀을 뺀다 (spec §3):
    /// - `par == 0` — 파 선택 화면을 넘기지 않은 홀. 양쪽 합에 0으로 기여해 원래도 무해했다.
    /// - `score == 0` — 파는 골랐지만 한 타도 치지 않고 넘어간 홀. 넣으면 `0 − par`가
    ///   그대로 언더파로 새어 들어가 버디로 잘못 집계된다.
    ///
    /// 배열 길이가 다르면 짧은 쪽까지만 본다 — 파를 아직 안 고른 말단 홀을 자동으로 무시한다.
    static func relativeToPar(holeScores: [Int], holePars: [Int]) -> Int {
        zip(holeScores, holePars)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .reduce(0) { $0 + $1.0 - $1.1 }
    }
}
```

튜플 요소 이름이 없어 `$0.0`(타수)·`$0.1`(파)로 읽는다. `zip`이 만드는 것은 `(holeScores[i], holePars[i])` 순서다 — 뒤집으면 부호가 반대가 되니 주의할 것.

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: `ScoreAggregateTests` 5개 PASS, 기존 워치 테스트 전부 PASS

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add Shared/Models/ScoreAggregate.swift watchosTests/Shared/ScoreAggregateTests.swift
git commit -m "✨ feat: 오버파 집계 규칙을 담은 ScoreAggregate"
```

---

### Task 2: `RoundSnapshot`이 `ScoreAggregate`를 쓰게 교체 (워치·컴플리케이션)

**Files:**
- Modify: `Shared/Models/RoundSnapshot.swift` (`relativeToPar` 계산 프로퍼티)
- Test: `watchosTests/Shared/RoundSnapshotTests.swift` (회귀 테스트 추가)

**Interfaces:**
- Consumes: `ScoreAggregate.relativeToPar(holeScores:holePars:)` (Task 1)
- Produces: 없음 (기존 `RoundSnapshot.relativeToPar` 시그니처 그대로, 동작만 교정)

이 태스크가 **사용자 눈에 보이는 워치 동작을 바꾼다** — 카운터 헤더, 스코어카드 합계, 종료 요약, 컴플리케이션이 모두 이 값을 쓴다.

- [ ] **Step 1: 실패하는 회귀 테스트 작성**

`watchosTests/Shared/RoundSnapshotTests.swift`의 마지막 `}` 앞에 추가한다. 기존 `makeSnapshot()` 헬퍼(7홀, 오버파 0)를 재사용한다:

```swift
    @Test func 파만고르고_한타도치지않은홀은_오버파에_반영되지않는다() {
        var snapshot = makeSnapshot()
        // 8번째 홀에 파만 고르고 넘어간 상태 — 워치에서 실제로 만들 수 있다.
        snapshot.holeScores.append(0)
        snapshot.holePars.append(4)
        snapshot.puttCounts.append(0)

        // 옛 공식이라면 0 − 4 = −4가 새어 들어가 4언더파로 잘못 집계된다.
        #expect(snapshot.relativeToPar == 0)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 새 테스트만 FAIL — `Expectation failed: (snapshot.relativeToPar → -4) == 0`

이 실패가 바로 이 plan이 고치려는 버그다. 다른 실패가 함께 뜨면 **멈추고 보고할 것.**

- [ ] **Step 3: `relativeToPar` 교체**

`Shared/Models/RoundSnapshot.swift`에서 기존 `relativeToPar` 계산 프로퍼티와 그 doc comment를 통째로 아래로 교체한다:

```swift
    /// 집계 대상 홀(파와 타수가 모두 있는 홀)만 더한다. 규칙은 `ScoreAggregate` 참조 (spec §3).
    var relativeToPar: Int {
        ScoreAggregate.relativeToPar(holeScores: holeScores, holePars: holePars)
    }
```

교체 대상인 기존 코드는 다음과 같다 (doc comment 포함해 지운다):

```swift
    /// holePars/puttCounts는 holeScores와 같은 개수만 유효 — 아직 파가 없는 홀의 배열 길이 불일치를 자동으로 무시한다
    var relativeToPar: Int {
        zip(holeScores, holePars).reduce(0) { $0 + $1.0 - $1.1 }
    }
```

- [ ] **Step 4: 워치 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: 새 테스트 포함 워치 타깃 전부 PASS

- [ ] **Step 5: 컴플리케이션 타깃 빌드 확인**

`ComplicationState`가 `RoundSnapshot.relativeToPar`를 쓰므로 별도 타깃 빌드가 필요하다:

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 커밋**

```bash
make lint && make format
git add Shared/Models/RoundSnapshot.swift watchosTests/Shared/RoundSnapshotTests.swift
git commit -m "🐛 fix: 워치 오버파에서 미타구 홀 제외"
```

---

### Task 3: `GolfRound`가 `ScoreAggregate`를 쓰게 교체 (iOS)

**Files:**
- Modify: `Shared/Persistence/GolfRound.swift` (`relativeToPar` 계산 프로퍼티)
- Test: `iosTests/Shared/GolfRoundTests.swift` (회귀 테스트 추가)

**Interfaces:**
- Consumes: `ScoreAggregate.relativeToPar(holeScores:holePars:)` (Task 1)
- Produces: 없음 (기존 `GolfRound.relativeToPar` 시그니처 그대로, 동작만 교정)

- [ ] **Step 1: 실패하는 회귀 테스트 작성**

`iosTests/Shared/GolfRoundTests.swift`의 마지막 `}` 앞에 추가한다:

```swift
    @Test func 파만고르고_한타도치지않은홀은_오버파에_반영되지않는다() {
        let round = GolfRound()
        // 3번 홀은 파만 고르고 넘어간 홀 — 워치 종료 직전이나 iOS 홀 편집으로 만들 수 있다.
        round.holeScores = [4, 3, 0]
        round.holePars = [4, 3, 4]
        round.puttCounts = [2, 1, 0]

        // 옛 공식이라면 0 − 4 = −4가 새어 들어간다.
        #expect(round.relativeToPar == 0)
        // 파가 있는 홀이므로 기록 홀 수에는 그대로 들어간다 — 유효 홀 ≠ 집계 대상 홀 (spec §3).
        #expect(round.recordedHoleCount == 3)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 새 테스트만 FAIL — `Expectation failed: (round.relativeToPar → -4) == 0`

- [ ] **Step 3: `relativeToPar` 교체**

`Shared/Persistence/GolfRound.swift`에서 기존 `relativeToPar` 계산 프로퍼티와 그 doc comment를 통째로 아래로 교체한다:

```swift
    /// 집계 대상 홀(파와 타수가 모두 있는 홀)만 더한다. 규칙은 `ScoreAggregate` 참조 (spec §3).
    var relativeToPar: Int {
        ScoreAggregate.relativeToPar(holeScores: holeScores, holePars: holePars)
    }
```

교체 대상인 기존 코드는 다음과 같다 (doc comment 포함해 지운다):

```swift
    /// holePars/puttCounts는 holeScores와 같은 개수만 유효 — 아직 파가 없는 홀의 배열 길이 불일치를 자동으로 무시한다
    var relativeToPar: Int {
        zip(holeScores, holePars).reduce(0) { $0 + $1.0 - $1.1 }
    }
```

- [ ] **Step 4: iOS 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 새 테스트 포함 iOS 타깃 전부 PASS (PR #15 기준 21건 + 1건 = 22건)

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add Shared/Persistence/GolfRound.swift iosTests/Shared/GolfRoundTests.swift
git commit -m "🐛 fix: iOS 오버파에서 미타구 홀 제외"
```

---

## 완료 조건

- 파를 고르고 한 타도 치지 않은 홀이 워치 카운터·스코어카드·요약, 컴플리케이션, iOS 기록 리스트·상세 어디에서도 오버파에 반영되지 않는다
- 오버파 계산 로직이 `ScoreAggregate` 한 곳에만 존재한다 (중복 정의 제거)
- 세 타깃(`GolfCounter` / `GolfCounter Watch App` / `ComplicationAppExtension`) 전부 빌드 성공, iOS·워치 테스트 전부 통과
- `make lint`·`make format` 위반 0
- spec §3의 오버파 항목이 새 규칙과 일치한다 (이 plan과 함께 정정 완료)

## 검증 시 눈으로 확인할 것 (선택)

워치 시뮬레이터에서 라운드를 시작해 **파를 고른 직후** 카운터 헤더의 누적 오버파를 본다. 수정 전에는 `-4`(고른 파만큼 음수)로 떨어졌다가 타수를 칠 때마다 회복되고, 수정 후에는 첫 타를 치기 전까지 이전 홀까지의 누적값을 그대로 유지해야 한다.
