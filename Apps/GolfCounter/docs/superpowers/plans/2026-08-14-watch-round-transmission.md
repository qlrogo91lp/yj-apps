# ④ watch: 홀 수 선택 + 종료 요약 + 라운드 전송 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 라운드 시작 시 9/18홀을 고르게 하고, 종료 시 확인 → 요약 화면 → `.reliable` 전송까지 이어 붙여 워치에서 만든 라운드가 iOS로 넘어갈 수 있게 한다.

**Architecture:** 홀 수 상한은 `HoleProgress`가 소유해 `advanceToNextHole()`이 스스로 상한을 넘지 못한다. 종료 요약은 새 화면을 push하지 않고 `phase == .summary`일 때 `RoundSessionView`가 3페이지 TabView를 통째로 `SummaryView`로 교체한다. 발신은 `RoundTransmitting` 프로토콜 뒤에 두어 ViewModel 테스트가 WatchConnectivity 없이 돈다 — 기존 `RoundSnapshotPublishing`과 같은 방식이다. 홀 수 선택은 별도 화면 대신 홈 화면의 라벨+값 버튼이다.

**Tech Stack:** Swift / SwiftUI / Swift Testing / ralli-kit(`ConnectivityCore`·`WorkoutCore`·`WorkoutUI`, 원격 SPM branch `main`)

**참조 spec:** `docs/superpowers/specs/2026-08-14-watch-round-transmission-design.md`

**선행:** ③-c(PR #10)·③-d(PR #12) 머지 완료. 이 plan은 그 위에서 시작한다.

## Global Constraints

- **브랜치 `feature/watch-round-transmission`에서 작업.** `main` 직접 push 금지 — PR + `gh pr merge <n> --merge --delete-branch`
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `♻️ refactor:` / `✅ test:` / `🔧 chore:`). 본문 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- 테스트: Swift Testing(`@Test`/`#expect`), 테스트명은 한국어 `대상_행위_예상결과`, ViewModel 테스트는 `@MainActor`. **View는 테스트하지 않는다**
- 사용자 노출 문자열은 **한국어 하드코딩** (로컬라이즈는 plan ⑦). "Par"/"H"/"bpm" 등 관용 영문은 유지
- ViewModel은 UI 프레임워크를 import하지 않는다. `Shared/` 순수 타입은 `Foundation`만
- 파일 네이밍: View suffix는 독립 화면만, `Components/` 안 순수 컴포넌트는 suffix 없음, 한 파일 = 한 타입
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`
- **빌드 로그를 저장소 안에 저장하지 않는다.** `/tmp` 등 저장소 밖에 쓰고, `git add` 전에 `git status`로 스테이징 목록을 확인한다
- watch 테스트 명령 (이하 "**watch test**", `test`를 `build`로 바꾸면 "**watch build**"):
  ```bash
  xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
  ```
  기기명이 없으면 `xcrun simctl list devices available`로 확인해 대체한다
- **베이스라인: watch 타깃 93건 PASS.** 이 숫자가 출발점이다

## 기본값에 관한 판단 (spec에 없어 이 plan에서 정함)

- `HoleProgress.init(holeCount:)`에는 **기본값을 두지 않는다.** 상한 없는 `HoleProgress`는 의미가 없다. 기존 `HoleProgressTests` 17건은 Task 3에서 기계적으로 치환한다
- `RoundViewModel.init(holeCount: Int = 18)`에는 **기본값 18을 둔다.** 프리뷰 3곳과 기존 ViewModel 테스트 4파일이 홀 수와 무관하게 계속 컴파일된다. 실제 진입점(`RoundSessionView`)은 항상 명시적으로 넘긴다
- `RoundSnapshot`의 `id`·`holeCount`도 **프로퍼티 기본값을 둔다.** 멤버와이즈 init에서 생략 가능해져 기존 생성 호출부 10곳이 그대로 컴파일된다. **단 `RoundViewModel.snapshot`은 반드시 `id:`를 명시해야 한다** — 생략하면 발행할 때마다 새 UUID가 생겨 복구를 넘어 유지되지 않는다

---

### Task 1: `RoundSnapshot`에 `id`·`holeCount` 추가 + 하위호환 디코딩 (TDD)

`RoundSnapshotStore.load()`가 `try?`로 디코딩하므로, 필드를 그냥 추가하면 구버전 스냅샷이 조용히 `nil`이 되어 진행 중 라운드가 사라진다 (spec §3.5).

**Files:**
- Modify: `Shared/Models/RoundSnapshot.swift`
- Test: `watchosTests/Shared/RoundSnapshotTests.swift`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: `RoundSnapshot.id: UUID`(기본값 `UUID()`), `RoundSnapshot.holeCount: Int`(기본값 18). 멤버와이즈 init은 `RoundSnapshot(id:holeCount:startedAt:courseName:currentHoleIndex:holeScores:holePars:puttCounts:)` — 앞 둘은 생략 가능

- [ ] **Step 1: 브랜치 생성**

```bash
git checkout main && git pull
git checkout -b feature/watch-round-transmission
```

- [ ] **Step 2: 실패하는 테스트 추가**

`watchosTests/Shared/RoundSnapshotTests.swift`의 `struct RoundSnapshotTests { ... }` 안, 마지막 `@Test` 뒤에 추가:

```swift
    @Test func id와_holeCount가_코더블_왕복에서_유지된다() throws {
        let id = UUID()
        let snapshot = RoundSnapshot(id: id,
                                     holeCount: 9,
                                     startedAt: Date(timeIntervalSince1970: 1000),
                                     courseName: "테스트CC",
                                     currentHoleIndex: 2,
                                     holeScores: [4, 3, 5],
                                     holePars: [4, 3, 4],
                                     puttCounts: [2, 1, 2])

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.holeCount == 9)
        #expect(decoded == snapshot)
    }

    @Test func 구버전_스냅샷은_id가_새로_발급되고_holeCount가_18로_채워진다() throws {
        let data = try Self.legacySnapshotJSON(currentHoleIndex: 2,
                                               holeScores: [4, 3, 5],
                                               holePars: [4, 3, 4],
                                               puttCounts: [2, 1, 2])

        let snapshot = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(snapshot.holeCount == 18)
        #expect(snapshot.currentHoleIndex == 2)
        #expect(snapshot.holeScores == [4, 3, 5])
    }

    @Test func 구버전_스냅샷이_18홀을_넘겼어도_기록이_잘리지_않는다() throws {
        // 상한이 없던 시절에는 "다음"을 계속 눌러 20홀까지 갈 수 있었다.
        let data = try Self.legacySnapshotJSON(currentHoleIndex: 19,
                                               holeScores: Array(repeating: 4, count: 20),
                                               holePars: Array(repeating: 4, count: 20),
                                               puttCounts: Array(repeating: 2, count: 20))

        let snapshot = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(snapshot.holeCount == 20)
        #expect(snapshot.holeScores.count == 20)
    }

    /// `id`·`holeCount`가 없던 시절의 와이어 포맷.
    private static func legacySnapshotJSON(currentHoleIndex: Int,
                                           holeScores: [Int],
                                           holePars: [Int],
                                           puttCounts: [Int]) throws -> Data
    {
        let dictionary: [String: Any] = [
            "startedAt": 0,
            "currentHoleIndex": currentHoleIndex,
            "holeScores": holeScores,
            "holePars": holePars,
            "puttCounts": puttCounts,
        ]
        return try JSONSerialization.data(withJSONObject: dictionary)
    }
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `extra arguments 'id', 'holeCount'`

- [ ] **Step 4: `RoundSnapshot` 교체**

`Shared/Models/RoundSnapshot.swift` 전체를 교체:

```swift
import Foundation

/// 라운드 진행 중 상태 스냅샷.
/// 워치 크래시/강제종료 복구와 컴플리케이션 표시 데이터원을 겸한다 (spec §3).
struct RoundSnapshot: Equatable {
    /// 라운드 시작 시 생성해 복구를 넘어 유지한다. iOS가 이 값으로 중복 수신을 거른다.
    ///
    /// 기본값이 있어 멤버와이즈 init에서 생략할 수 있지만, 생략하면 **호출할 때마다 새 UUID가
    /// 생긴다.** `RoundViewModel.snapshot`처럼 라운드 정체성을 실어야 하는 자리는 반드시 명시한다.
    var id: UUID = UUID()
    /// 선택한 홀 수 상한 (9 또는 18).
    var holeCount: Int = 18
    var startedAt: Date
    var courseName: String?
    var currentHoleIndex: Int // 0-based, 인덱스 = 홀 번호 - 1
    var holeScores: [Int]
    var holePars: [Int]
    var puttCounts: [Int]

    var currentHoleNumber: Int {
        currentHoleIndex + 1
    }

    var totalStrokes: Int {
        holeScores.reduce(0, +)
    }

    var totalPutts: Int {
        puttCounts.reduce(0, +)
    }

    /// holePars/puttCounts는 holeScores와 같은 개수만 유효 — 아직 파가 없는 홀의 배열 길이 불일치를 자동으로 무시한다
    var relativeToPar: Int {
        zip(holeScores, holePars).reduce(0) { $0 + $1.0 - $1.1 }
    }
}

/// Codable을 확장에 두는 이유: 본문에 init을 선언하면 멤버와이즈 init이 사라져
/// 기존 생성 호출부 10곳이 전부 깨진다.
extension RoundSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, holeCount, startedAt, courseName, currentHoleIndex, holeScores, holePars, puttCounts
    }

    /// `id`·`holeCount`가 없던 구버전 스냅샷도 살려낸다 (spec §3.5).
    /// `RoundSnapshotStore.load()`가 `try?`로 디코딩하므로 여기서 던지면
    /// 진행 중 라운드가 조용히 사라진다.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName)
        currentHoleIndex = try container.decode(Int.self, forKey: .currentHoleIndex)
        holeScores = try container.decode([Int].self, forKey: .holeScores)
        holePars = try container.decode([Int].self, forKey: .holePars)
        puttCounts = try container.decode([Int].self, forKey: .puttCounts)

        // 스냅샷에 남아 있다는 것은 아직 전송되지 않았다는 뜻이므로(전송 성공 시 스냅샷을 지운다)
        // 새 id를 발급해도 iOS에 중복이 생기지 않는다.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()

        // 상한이 없던 시절 라운드는 18홀을 넘겼을 수 있다. 그냥 18로 채우면 currentHoleIndex가
        // 상한 밖에 놓여 이미 친 홀이 잘린다 — 실제 기록 길이를 하한으로 잡는다.
        holeCount = try container.decodeIfPresent(Int.self, forKey: .holeCount) ?? max(18, holeScores.count)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(holeCount, forKey: .holeCount)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(courseName, forKey: .courseName)
        try container.encode(currentHoleIndex, forKey: .currentHoleIndex)
        try container.encode(holeScores, forKey: .holeScores)
        try container.encode(holePars, forKey: .holePars)
        try container.encode(puttCounts, forKey: .puttCounts)
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: watch test
Expected: 96건 PASS (기존 93 + 신규 3). 기존 `RoundSnapshot` 생성 호출부 10곳은 기본값 덕에 무변경으로 컴파일된다.

- [ ] **Step 6: 커밋**

```bash
git add Shared/Models/RoundSnapshot.swift watchosTests/Shared/RoundSnapshotTests.swift
git commit -m "✨ feat: RoundSnapshot에 id·holeCount 추가, 구버전 하위호환 디코딩

라운드 id는 복구를 넘어 유지되어 iOS 중복 수신을 막고, holeCount는 선택한 상한을
싣는다. RoundSnapshotStore.load()가 try?로 디코딩하므로 필드를 그냥 추가하면
구버전 스냅샷이 조용히 nil이 되어 진행 중 라운드가 사라진다 — init(from:)을 직접
써서 없는 필드를 채운다. 18홀을 넘긴 구버전 라운드는 실제 기록 길이를 하한으로 보존.

Codable을 확장에 둔 이유: 본문에 init을 선언하면 멤버와이즈 init이 사라져
기존 생성 호출부 10곳이 깨진다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: `RoundSnapshot.trimmed()` — 미기록 홀 트림 (TDD)

전송 직전 배열 말단에서부터 `par == 0`인 홀을 제거한다. `par == 0`이면 파 선택 화면이 떠 카운터에 접근할 수 없으므로 `score`·`putts`도 0 — 무손실이다 (spec §2 결정 2).

**Files:**
- Modify: `Shared/Models/RoundSnapshot.swift`
- Test: `watchosTests/Shared/RoundSnapshotTrimTests.swift`

**Interfaces:**
- Consumes: Task 1의 `RoundSnapshot`
- Produces: `RoundSnapshot.trimmed() -> RoundSnapshot`, `RoundSnapshot.recordedHoleCount: Int`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Shared/RoundSnapshotTrimTests.swift` 신규 생성:

```swift
@testable import GolfCounter_Watch_App
import Foundation
import Testing

struct RoundSnapshotTrimTests {
    private func snapshot(currentHoleIndex: Int,
                          holeScores: [Int],
                          holePars: [Int],
                          puttCounts: [Int]) -> RoundSnapshot
    {
        RoundSnapshot(holeCount: 18,
                      startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: nil,
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: puttCounts)
    }

    @Test func 말단의_미기록_홀이_제거된다() {
        let trimmed = snapshot(currentHoleIndex: 4,
                               holeScores: [4, 5, 0, 0, 0],
                               holePars: [4, 5, 0, 0, 0],
                               puttCounts: [2, 2, 0, 0, 0]).trimmed()

        #expect(trimmed.holeScores == [4, 5])
        #expect(trimmed.holePars == [4, 5])
        #expect(trimmed.puttCounts == [2, 2])
    }

    @Test func 중간에_낀_미기록_홀은_보존된다() {
        // 사용자가 의도적으로 건너뛴 홀일 수 있다.
        let trimmed = snapshot(currentHoleIndex: 3,
                               holeScores: [4, 0, 5, 0],
                               holePars: [4, 0, 5, 0],
                               puttCounts: [2, 0, 2, 0]).trimmed()

        #expect(trimmed.holePars == [4, 0, 5])
    }

    @Test func 전부_미기록이면_빈_배열이_된다() {
        let trimmed = snapshot(currentHoleIndex: 2,
                               holeScores: [0, 0, 0],
                               holePars: [0, 0, 0],
                               puttCounts: [0, 0, 0]).trimmed()

        #expect(trimmed.holeScores.isEmpty)
        #expect(trimmed.holePars.isEmpty)
        #expect(trimmed.puttCounts.isEmpty)
        #expect(trimmed.currentHoleIndex == 0)
    }

    @Test func 트림하면_현재홀_인덱스가_남은_범위로_클램프된다() {
        let trimmed = snapshot(currentHoleIndex: 4,
                               holeScores: [4, 5, 0, 0, 0],
                               holePars: [4, 5, 0, 0, 0],
                               puttCounts: [2, 2, 0, 0, 0]).trimmed()

        #expect(trimmed.currentHoleIndex == 1)
    }

    @Test func 트림할게_없으면_그대로다() {
        let original = snapshot(currentHoleIndex: 1,
                                holeScores: [4, 5],
                                holePars: [4, 5],
                                puttCounts: [2, 2])

        #expect(original.trimmed() == original)
    }

    @Test func 기록홀수는_트림후_홀_개수다() {
        let value = snapshot(currentHoleIndex: 4,
                             holeScores: [4, 5, 0, 0, 0],
                             holePars: [4, 5, 0, 0, 0],
                             puttCounts: [2, 2, 0, 0, 0])

        #expect(value.recordedHoleCount == 2)
    }

    @Test func 아무것도_치지_않았으면_기록홀수가_0이다() {
        let value = snapshot(currentHoleIndex: 0,
                             holeScores: [0],
                             holePars: [0],
                             puttCounts: [0])

        #expect(value.recordedHoleCount == 0)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `value of type 'RoundSnapshot' has no member 'trimmed'`

- [ ] **Step 3: `trimmed()` 구현**

`Shared/Models/RoundSnapshot.swift`의 `extension RoundSnapshot: Codable { ... }` **앞에** 새 확장을 추가:

```swift
extension RoundSnapshot {
    /// 전송 직전, 배열 말단에서부터 `par == 0`인 미기록 홀을 제거한다 (spec §2 결정 2).
    ///
    /// `par == 0`이면 파 선택 화면이 떠 카운터에 접근할 수 없으므로 `score`·`putts`도 반드시
    /// 0이다 — 이 트림은 무손실이다. 중간에 낀 `par == 0` 홀은 건드리지 않는다(사용자가
    /// 의도적으로 건너뛴 홀일 수 있다).
    func trimmed() -> RoundSnapshot {
        var end = holePars.count
        while end > 0, holePars[end - 1] == 0 {
            end -= 1
        }

        var copy = self
        copy.holeScores = Array(holeScores.prefix(end))
        copy.holePars = Array(holePars.prefix(end))
        copy.puttCounts = Array(puttCounts.prefix(end))
        copy.currentHoleIndex = max(0, min(currentHoleIndex, end - 1))
        return copy
    }

    /// 트림 후 실제로 기록된 홀 수. 종료 확인 문구와 요약 헤더가 쓴다.
    var recordedHoleCount: Int {
        trimmed().holePars.count
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: watch test
Expected: 103건 PASS (96 + 신규 7)

- [ ] **Step 5: 커밋**

```bash
git add Shared/Models/RoundSnapshot.swift watchosTests/Shared/RoundSnapshotTrimTests.swift
git commit -m "✨ feat: RoundSnapshot.trimmed()로 미기록 홀 트림

말단부터 par == 0인 홀을 제거한다. par == 0이면 파 선택 화면이 떠 카운터에
접근할 수 없어 score·putts도 0이므로 무손실이다. 중간에 낀 미기록 홀은
의도적으로 건너뛴 홀일 수 있어 건드리지 않는다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: `HoleProgress`에 홀 수 상한 (TDD)

배열 길이·인덱스 관리가 이미 이 타입 책임이므로 상한도 같이 둔다. 호출부가 가드를 빠뜨려도 타입이 스스로 막는다 (spec §3.1).

**Files:**
- Modify: `WatchApp/Features/Round/HoleProgress.swift`
- Modify: `WatchApp/Features/Round/RoundViewModel.swift` (컴파일 유지용 최소 수정)
- Test: `watchosTests/Round/HoleProgressTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: `HoleProgress.init(holeCount:)`, `HoleProgress.init(holeCount:holeScores:holePars:puttCounts:currentHoleIndex:)`, `HoleProgress.holeCount: Int`, `HoleProgress.canGoToNextHole: Bool`. `advanceToNextHole()`이 상한에서 no-op이 된다

- [ ] **Step 1: 기존 17건을 새 시그니처로 치환**

`watchosTests/Round/HoleProgressTests.swift`에서 두 가지 치환:

```bash
perl -pi -e 's/HoleProgress\(\)/HoleProgress(holeCount: 18)/g' watchosTests/Round/HoleProgressTests.swift
perl -pi -e 's/HoleProgress\(holeScores:/HoleProgress(holeCount: 18, holeScores:/g' watchosTests/Round/HoleProgressTests.swift
```

치환 확인:

```bash
grep -c "HoleProgress(holeCount: 18)" watchosTests/Round/HoleProgressTests.swift
grep -c "HoleProgress(holeCount: 18, holeScores:" watchosTests/Round/HoleProgressTests.swift
```
Expected: 각각 15, 2 (합 17)

- [ ] **Step 2: 상한 테스트 3건 추가**

`watchosTests/Round/HoleProgressTests.swift`의 `struct HoleProgressTests { ... }` 안, 마지막 `@Test` 뒤에 추가:

```swift
    @Test func 마지막_홀에서는_다음홀로_갈_수_없다() {
        var progress = HoleProgress(holeCount: 18)
        for _ in 1 ..< 18 {
            progress.advanceToNextHole()
        }

        #expect(progress.currentHoleNumber == 18)
        #expect(progress.canGoToNextHole == false)
    }

    @Test func 상한에_도달하면_다음홀_이동이_아무것도_바꾸지_않는다() {
        var progress = HoleProgress(holeCount: 9)
        for _ in 1 ..< 9 {
            progress.advanceToNextHole()
        }

        progress.advanceToNextHole()

        #expect(progress.currentHoleIndex == 8)
        #expect(progress.holeScores.count == 9)
    }

    @Test func 아홉홀_라운드는_아홉번째_홀이_마지막이다() {
        var progress = HoleProgress(holeCount: 9)
        progress.advanceToNextHole()

        #expect(progress.canGoToNextHole)
        #expect(progress.holeCount == 9)
    }
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `extra argument 'holeCount' in call`

- [ ] **Step 4: `HoleProgress` 수정**

`WatchApp/Features/Round/HoleProgress.swift`에서 세 곳을 수정한다.

(1) 저장 프로퍼티 블록과 두 init을 교체:

```swift
struct HoleProgress: Equatable {
    /// 이 라운드의 홀 수 상한 (9 또는 18). 중간 변경·연장은 없다 (spec §3.1).
    /// 기본값을 두지 않는 이유: 상한 없는 HoleProgress는 의미가 없다.
    let holeCount: Int
    private(set) var holeScores: [Int]
    private(set) var holePars: [Int]
    private(set) var puttCounts: [Int]
    private(set) var currentHoleIndex: Int

    init(holeCount: Int) {
        self.holeCount = holeCount
        holeScores = [0]
        holePars = [0]
        puttCounts = [0]
        currentHoleIndex = 0
    }

    /// 스냅샷 복구용 (spec §12). 길이가 어긋난 값이 들어와도 현재 홀까지 용량을 맞춘다.
    init(holeCount: Int, holeScores: [Int], holePars: [Int], puttCounts: [Int], currentHoleIndex: Int) {
        self.holeCount = holeCount
        self.holeScores = holeScores
        self.holePars = holePars
        self.puttCounts = puttCounts
        self.currentHoleIndex = max(currentHoleIndex, 0)
        ensureCapacityForCurrentHole()
    }
```

(2) `canGoToPreviousHole` 바로 아래에 추가:

```swift
    var canGoToNextHole: Bool {
        currentHoleIndex + 1 < holeCount
    }
```

(3) `advanceToNextHole()`에 가드 추가:

```swift
    mutating func advanceToNextHole() {
        guard canGoToNextHole else { return }
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
    }
```

- [ ] **Step 5: `RoundViewModel`을 컴파일 가능하게 최소 수정**

`WatchApp/Features/Round/RoundViewModel.swift`에서 두 곳만 고친다 (전체 개편은 Task 6).

저장 프로퍼티 선언:

```swift
    @Published private var progress: HoleProgress
```

지정 init에 `holeCount` 파라미터를 넣고 `progress`를 초기화:

```swift
    init(holeCount: Int = 18,
         startedAt: Date = Date(),
         courseName: String? = nil,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        self.startedAt = startedAt
        self.courseName = courseName
        self.publisher = publisher
        progress = HoleProgress(holeCount: holeCount)
    }
```

복구 init의 `progress` 대입에 `holeCount:`를 추가:

```swift
        progress = HoleProgress(holeCount: snapshot.holeCount,
                                holeScores: snapshot.holeScores,
                                holePars: snapshot.holePars,
                                puttCounts: snapshot.puttCounts,
                                currentHoleIndex: snapshot.currentHoleIndex)
```

- [ ] **Step 6: 테스트 통과 확인**

Run: watch test
Expected: 106건 PASS (103 + 신규 3). `RoundViewModel` 테스트 4파일과 프리뷰 3곳은 `holeCount` 기본값 18 덕에 무변경으로 통과한다.

- [ ] **Step 7: 커밋**

```bash
git add WatchApp/Features/Round/HoleProgress.swift WatchApp/Features/Round/RoundViewModel.swift \
  watchosTests/Round/HoleProgressTests.swift
git commit -m "✨ feat: HoleProgress가 홀 수 상한을 소유

배열 길이·인덱스 관리가 이미 이 타입 책임이므로 상한도 같이 둔다.
advanceToNextHole()이 스스로 상한을 막아, 호출부가 가드를 빠뜨려도 빈 홀이
생기지 않는다 — ④가 종료·전송 경로를 얹어 호출부가 늘어나는 시점이라 특히 중요하다.

RoundViewModel.init에는 기본값 18을 둬 프리뷰·기존 테스트가 무변경으로 돈다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: `RoundMetrics` + `WorkoutResult` 변환 (TDD)

`Shared/`에 `import WorkoutCore`를 두면 iOS 타깃 빌드가 깨진다(iOS는 WorkoutCore를 링크하지 않는다). 순수 struct는 `Shared/`에, 변환은 워치 타깃에 둔다 (spec §5).

**Files:**
- Create: `Shared/Models/RoundMetrics.swift`
- Create: `WatchApp/Services/RoundMetrics+WorkoutResult.swift`
- Test: `watchosTests/Services/RoundMetricsConversionTests.swift`

**Interfaces:**
- Consumes: `WorkoutCore.WorkoutResult`(`durationSeconds`·`caloriesBurned`·`totalCaloriesBurned`·`averageHeartRate: Double?`·`distanceMeters`·`steps`)
- Produces: `RoundMetrics(calories:avgHeartRate:distanceMeters:steps:)` 전 파라미터 기본값 보유, `RoundMetrics.empty`, `RoundMetrics.init(_ result: WorkoutResult)`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Services/RoundMetricsConversionTests.swift` 신규 생성:

```swift
@testable import GolfCounter_Watch_App
import Testing
import WorkoutCore

struct RoundMetricsConversionTests {
    @Test func 워크아웃_결과의_네_값이_옮겨진다() {
        let result = WorkoutResult(durationSeconds: 12345,
                                   caloriesBurned: 412,
                                   averageHeartRate: 118,
                                   totalCaloriesBurned: 500,
                                   distanceMeters: 6200,
                                   steps: 9100)

        let metrics = RoundMetrics(result)

        #expect(metrics.calories == 412)
        #expect(metrics.avgHeartRate == 118)
        #expect(metrics.distanceMeters == 6200)
        #expect(metrics.steps == 9100)
    }

    @Test func 심박을_한번도_못받으면_0이_된다() {
        let result = WorkoutResult(durationSeconds: 60,
                                   caloriesBurned: 10,
                                   averageHeartRate: nil)

        let metrics = RoundMetrics(result)

        #expect(metrics.avgHeartRate == 0)
    }

    @Test func empty는_전부_0이다() {
        #expect(RoundMetrics.empty == RoundMetrics(calories: 0, avgHeartRate: 0, distanceMeters: 0, steps: 0))
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `cannot find 'RoundMetrics' in scope`

- [ ] **Step 3: `RoundMetrics` 구현**

`Shared/Models/RoundMetrics.swift` 신규 생성:

```swift
import Foundation

/// 라운드 워크아웃 집계값. `GolfRound`의 대응 필드와 1:1이다 (spec §4).
///
/// `WorkoutResult`(WorkoutCore)를 그대로 쓰지 않는 이유: `Shared/`에 `import WorkoutCore`를
/// 두면 iOS 타깃 빌드가 깨진다 — iOS는 WorkoutCore를 링크하지 않는다 (spec §5).
/// 변환은 워치 타깃의 `RoundMetrics+WorkoutResult.swift`에 있다.
struct RoundMetrics: Equatable {
    var calories: Double = 0
    var avgHeartRate: Double = 0
    var distanceMeters: Double = 0
    var steps: Int = 0

    /// 워크아웃 결과를 못 받은 경우 — HealthKit 거부 · 워크아웃 미시작 · 복구된 라운드.
    /// 복구 라운드는 그 구간에 워크아웃 세션이 없었으므로 이게 정상 경로다 (spec §8).
    static let empty = RoundMetrics()
}
```

- [ ] **Step 4: 변환 구현**

`WatchApp/Services/RoundMetrics+WorkoutResult.swift` 신규 생성:

```swift
import Foundation
import WorkoutCore

extension RoundMetrics {
    /// `WorkoutResult`는 워치 타깃에만 있으므로 변환도 여기 둔다 (spec §5).
    ///
    /// `durationSeconds`·`totalCaloriesBurned`는 `GolfRound`에 대응 필드가 없어 버린다 —
    /// 소요 시간은 iOS가 `endedAt - startedAt`으로 파생한다.
    init(_ result: WorkoutResult) {
        self.init(calories: result.caloriesBurned,
                  avgHeartRate: result.averageHeartRate ?? 0,
                  distanceMeters: result.distanceMeters,
                  steps: result.steps)
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: watch test
Expected: 109건 PASS (106 + 신규 3)

- [ ] **Step 6: iOS 빌드로 Shared 오염 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED. 실패하면 `import WorkoutCore`가 `Shared/`로 샌 것이다.

- [ ] **Step 7: 커밋**

```bash
git add Shared/Models/RoundMetrics.swift WatchApp/Services/RoundMetrics+WorkoutResult.swift \
  watchosTests/Services/RoundMetricsConversionTests.swift
git commit -m "✨ feat: RoundMetrics 신설 + WorkoutResult 변환

Shared에 import WorkoutCore를 두면 iOS 타깃 빌드가 깨지므로(iOS는 WorkoutCore를
링크하지 않는다) 순수 struct는 Shared에, 변환은 워치 타깃에 둔다.
심박은 옵셔널이라 한 번도 못 받으면 0으로 싣는다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: 전송 계층 — 메시지 · 발신 프로토콜 · pbxproj 예외 (TDD)

**이 plan에서 유일하게 pbxproj를 손대는 태스크다.** `Shared/`는 컴플리케이션 타깃에도 동기화되는데 그 타깃은 ralli-kit을 하나도 링크하지 않아, `import ConnectivityCore`를 하는 파일을 그대로 두면 빌드가 깨진다 (spec §5).

**Files:**
- Create: `Shared/Services/ConnectivityMessages.swift`
- Create: `WatchApp/Services/RoundTransmitter.swift`
- Modify: `GolfCounter.xcodeproj/project.pbxproj`
- Test: `watchosTests/Shared/ConnectivityMessagesTests.swift`

**Interfaces:**
- Consumes: Task 4의 `RoundMetrics`, `ConnectivityCore`의 `ConnectivityMessage`·`ConnectivityService.send(_:via:)`·`Delivery.reliable`
- Produces: `RoundCompletedMessage(id:startedAt:endedAt:courseName:holeScores:holePars:puttCounts:metrics:)`, `protocol RoundTransmitting { func send(_ message: RoundCompletedMessage) }`, `struct RoundTransmitter: RoundTransmitting`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Shared/ConnectivityMessagesTests.swift` 신규 생성:

```swift
@testable import GolfCounter_Watch_App
import Foundation
import Testing

struct ConnectivityMessagesTests {
    private func sample(courseName: String?) -> RoundCompletedMessage {
        RoundCompletedMessage(id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                              startedAt: Date(timeIntervalSince1970: 1000),
                              endedAt: Date(timeIntervalSince1970: 5000),
                              courseName: courseName,
                              holeScores: [4, 5, 3],
                              holePars: [4, 5, 3],
                              puttCounts: [2, 2, 1],
                              metrics: RoundMetrics(calories: 412,
                                                    avgHeartRate: 118,
                                                    distanceMeters: 6200,
                                                    steps: 9100))
    }

    @Test func 딕셔너리_왕복에서_전_필드가_유지된다() throws {
        let original = sample(courseName: "테스트CC")

        let restored = try #require(RoundCompletedMessage(from: original.toDictionary()))

        #expect(restored.id == original.id)
        #expect(restored.startedAt == original.startedAt)
        #expect(restored.endedAt == original.endedAt)
        #expect(restored.courseName == "테스트CC")
        #expect(restored.holeScores == [4, 5, 3])
        #expect(restored.holePars == [4, 5, 3])
        #expect(restored.puttCounts == [2, 2, 1])
        #expect(restored.metrics == original.metrics)
    }

    @Test func 골프장명이_없으면_키_자체가_빠진다() {
        let dictionary = sample(courseName: nil).toDictionary()

        #expect(dictionary["courseName"] == nil)
    }

    @Test func 골프장명이_없어도_복원된다() throws {
        let original = sample(courseName: nil)

        let restored = try #require(RoundCompletedMessage(from: original.toDictionary()))

        #expect(restored.courseName == nil)
    }

    @Test func 필수_필드가_빠지면_복원에_실패한다() {
        var dictionary = sample(courseName: nil).toDictionary()
        dictionary.removeValue(forKey: "holeScores")

        #expect(RoundCompletedMessage(from: dictionary) == nil)
    }

    @Test func 메시지_타입은_roundCompleted다() {
        #expect(RoundCompletedMessage.messageType == "roundCompleted")
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `cannot find 'RoundCompletedMessage' in scope`

- [ ] **Step 3: 메시지 구현**

`Shared/Services/ConnectivityMessages.swift` 신규 생성:

```swift
import ConnectivityCore
import Foundation

/// 라운드 완료 시 워치 → iOS 단방향 전송 페이로드 (spec §4).
///
/// 필드는 `GolfRound`와 1:1이다 — iOS(plan ⑤)는 이걸 그대로 옮겨 담아 저장한다.
/// `WorkoutResult.durationSeconds`·`totalCaloriesBurned`는 `GolfRound`에 대응 필드가 없어
/// 싣지 않는다(소요 시간은 `endedAt - startedAt`으로 파생).
///
/// **이 파일은 `import ConnectivityCore` 때문에 컴플리케이션 타깃에서 제외되어 있다**
/// (pbxproj의 `PBXFileSystemSynchronizedBuildFileExceptionSet`). 컴플리케이션은
/// ralli-kit을 하나도 링크하지 않는다.
struct RoundCompletedMessage: ConnectivityMessage, Equatable {
    static let messageType = "roundCompleted"

    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let courseName: String?
    let holeScores: [Int]
    let holePars: [Int]
    let puttCounts: [Int]
    let metrics: RoundMetrics

    init(id: UUID,
         startedAt: Date,
         endedAt: Date,
         courseName: String?,
         holeScores: [Int],
         holePars: [Int],
         puttCounts: [Int],
         metrics: RoundMetrics)
    {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.courseName = courseName
        self.holeScores = holeScores
        self.holePars = holePars
        self.puttCounts = puttCounts
        self.metrics = metrics
    }

    init?(from dictionary: [String: Any]) {
        guard let idString = dictionary["id"] as? String,
              let id = UUID(uuidString: idString),
              let startedAt = dictionary["startedAt"] as? TimeInterval,
              let endedAt = dictionary["endedAt"] as? TimeInterval,
              let holeScores = dictionary["holeScores"] as? [Int],
              let holePars = dictionary["holePars"] as? [Int],
              let puttCounts = dictionary["puttCounts"] as? [Int]
        else { return nil }

        self.init(id: id,
                  startedAt: Date(timeIntervalSince1970: startedAt),
                  endedAt: Date(timeIntervalSince1970: endedAt),
                  courseName: dictionary["courseName"] as? String,
                  holeScores: holeScores,
                  holePars: holePars,
                  puttCounts: puttCounts,
                  metrics: RoundMetrics(calories: dictionary["calories"] as? Double ?? 0,
                                        avgHeartRate: dictionary["avgHeartRate"] as? Double ?? 0,
                                        distanceMeters: dictionary["distanceMeters"] as? Double ?? 0,
                                        steps: dictionary["steps"] as? Int ?? 0))
    }

    func toDictionary() -> [String: Any] {
        var dictionary: [String: Any] = [
            "id": id.uuidString,
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "holeScores": holeScores,
            "holePars": holePars,
            "puttCounts": puttCounts,
            "calories": metrics.calories,
            "avgHeartRate": metrics.avgHeartRate,
            "distanceMeters": metrics.distanceMeters,
            "steps": metrics.steps,
        ]
        // nil을 키로 남기면 WCSession 직렬화에서 NSNull이 되어 수신측 캐스팅이 어긋난다.
        if let courseName {
            dictionary["courseName"] = courseName
        }
        return dictionary
    }
}
```

- [ ] **Step 4: pbxproj 예외 추가**

먼저 새 오브젝트 ID가 안 쓰이는지 확인:

```bash
grep -c "39D4A1002FBD0001005FBA12" GolfCounter.xcodeproj/project.pbxproj
```
Expected: `0`

`GolfCounter.xcodeproj/project.pbxproj`에서 기존 예외 세트 블록 바로 뒤(`/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */` **앞**)에 추가:

```
		39D4A1002FBD0001005FBA12 /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				Services/ConnectivityMessages.swift,
			);
			target = 3974B8F32EBCDFA5002D0EA7 /* ComplicationAppExtension */;
		};
```

그리고 `Shared` 동기화 그룹 줄에 `exceptions`를 끼워 넣는다. 이 줄을:

```
		39928A012EB95F0D005F1856 /* Shared */ = {isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {}; explicitFolders = (); path = Shared; sourceTree = "<group>"; };
```

다음으로 교체:

```
		39928A012EB95F0D005F1856 /* Shared */ = {isa = PBXFileSystemSynchronizedRootGroup; exceptions = (39D4A1002FBD0001005FBA12 /* PBXFileSystemSynchronizedBuildFileExceptionSet */, ); explicitFileTypes = {}; explicitFolders = (); path = Shared; sourceTree = "<group>"; };
```

- [ ] **Step 5: 세 타깃 전부 빌드해 예외가 먹었는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: 둘 다 BUILD SUCCEEDED. 컴플리케이션이 `no such module 'ConnectivityCore'`로 깨지면 예외가 안 먹은 것이니 Step 4를 다시 확인한다.

- [ ] **Step 6: 발신 프로토콜과 구현**

`WatchApp/Services/RoundTransmitter.swift` 신규 생성:

```swift
import ConnectivityCore
import Foundation

/// 완료 라운드 발신. ViewModel이 WatchConnectivity를 직접 모르게 프로토콜 뒤에 둔다
/// (`RoundSnapshotPublishing`과 같은 방식, spec §7).
protocol RoundTransmitting {
    func send(_ message: RoundCompletedMessage)
}

struct RoundTransmitter: RoundTransmitting {
    private let service: ConnectivityService

    init(service: ConnectivityService = ConnectivityService()) {
        self.service = service
    }

    /// `.reliable`은 sendMessage 실패 시 transferUserInfo로 큐잉되고 시스템이 배달을
    /// 보장한다 — 워치 쪽 재시도 로직은 만들지 않는다 (spec §7).
    func send(_ message: RoundCompletedMessage) {
        service.send(message, via: .reliable)
    }
}
```

- [ ] **Step 7: 테스트 통과 확인**

Run: watch test
Expected: 114건 PASS (109 + 신규 5)

- [ ] **Step 8: 커밋**

```bash
git status --short
git add Shared/Services/ConnectivityMessages.swift WatchApp/Services/RoundTransmitter.swift \
  GolfCounter.xcodeproj/project.pbxproj watchosTests/Shared/ConnectivityMessagesTests.swift
git commit -m "✨ feat: 전송 계층 — RoundCompletedMessage · RoundTransmitting

페이로드는 GolfRound와 1:1. 발신은 프로토콜 뒤에 둬 ViewModel 테스트가
WatchConnectivity 없이 돈다. .reliable이 미도달 시 transferUserInfo로 큐잉하고
시스템이 배달을 보장하므로 워치 재시도 로직은 없다.

pbxproj: Shared는 컴플리케이션 타깃에도 동기화되는데 그 타깃은 ralli-kit을 하나도
링크하지 않아, import ConnectivityCore를 하는 ConnectivityMessages.swift를
PBXFileSystemSynchronizedBuildFileExceptionSet으로 제외했다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: `RoundViewModel` — 종료 · 요약 · 전송 (TDD)

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`
- Create: `watchosTests/Support/RoundTransmitterSpy.swift`
- Test: `watchosTests/Round/RoundViewModelTransmissionTests.swift`

**Interfaces:**
- Consumes: Task 1·2의 `RoundSnapshot`(`id`·`holeCount`·`trimmed()`·`recordedHoleCount`·`totalPutts`), Task 3의 `HoleProgress.canGoToNextHole`, Task 4의 `RoundMetrics`, Task 5의 `RoundTransmitting`·`RoundCompletedMessage`
- Produces: `Phase.summary`, `RoundViewModel.id`, `.canGoToNextHole`, `.recordedHoleCount`, `.trimmedTotalStrokes`, `.trimmedTotalPutts`, `.trimmedRelativeToPar`, `.isTransmitting`, `.didComplete`, `finishRound()`, `applyMetrics(_:)`, `saveAndTransmit()`. init 시그니처는 `init(id:holeCount:startedAt:courseName:publisher:transmitter:)`와 `init(resuming:publisher:transmitter:)`

- [ ] **Step 1: 테스트 더블 작성**

`watchosTests/Support/RoundTransmitterSpy.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter_Watch_App

/// 발신 호출을 기록만 하는 테스트 더블. WatchConnectivity를 건드리지 않는다.
final class RoundTransmitterSpy: RoundTransmitting {
    private(set) var sent: [RoundCompletedMessage] = []

    func send(_ message: RoundCompletedMessage) {
        sent.append(message)
    }
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`watchosTests/Round/RoundViewModelTransmissionTests.swift` 신규 생성:

```swift
@testable import GolfCounter_Watch_App
import Foundation
import Testing

@MainActor
struct RoundViewModelTransmissionTests {
    private func makeViewModel(holeCount: Int = 18,
                               publisher: RoundSnapshotPublisherSpy,
                               transmitter: RoundTransmitterSpy) -> RoundViewModel
    {
        RoundViewModel(holeCount: holeCount,
                       startedAt: Date(timeIntervalSince1970: 1000),
                       publisher: publisher,
                       transmitter: transmitter)
    }

    /// 한 홀을 파 선택 → 타수 입력까지 채운다.
    private func playHole(_ viewModel: RoundViewModel, par: Int, strokes: Int) {
        viewModel.selectPar(par)
        for _ in 0 ..< strokes {
            viewModel.incrementStroke()
        }
    }

    @Test func 종료하면_요약_단계가_되고_종료시각이_기록된다() {
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(),
                                      transmitter: RoundTransmitterSpy())
        playHole(viewModel, par: 4, strokes: 5)

        viewModel.finishRound()

        #expect(viewModel.phase == .summary)
        #expect(viewModel.endedAt != nil)
    }

    @Test func 메트릭이_이미_있으면_즉시_전송한다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        viewModel.applyMetrics(RoundMetrics(calories: 412, avgHeartRate: 118, distanceMeters: 6200, steps: 9100))

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.count == 1)
        #expect(transmitter.sent.first?.metrics.calories == 412)
        #expect(viewModel.didComplete)
    }

    @Test func 메트릭이_아직_없으면_전송_대기_상태가_된다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.isEmpty)
        #expect(viewModel.isTransmitting)
        #expect(viewModel.didComplete == false)
    }

    @Test func 대기_중_메트릭이_도착하면_이어서_전송한다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        viewModel.saveAndTransmit()

        viewModel.applyMetrics(RoundMetrics(calories: 300, avgHeartRate: 100, distanceMeters: 1000, steps: 500))

        #expect(transmitter.sent.count == 1)
        #expect(viewModel.isTransmitting == false)
        #expect(viewModel.didComplete)
    }

    @Test func 워크아웃_결과를_못받으면_0값으로_전송한다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        viewModel.applyMetrics(nil)

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.first?.metrics == .empty)
    }

    @Test func 기록홀이_없으면_전송하지_않고_스냅샷만_지운다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        viewModel.finishRound()
        viewModel.applyMetrics(nil)

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.isEmpty)
        #expect(publisher.clearCallCount == 1)
        #expect(viewModel.didComplete)
    }

    @Test func 전송_페이로드는_트림된_배열이다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole() // 파를 안 고른 채 남겨 말단 미기록 홀을 만든다
        viewModel.finishRound()
        viewModel.applyMetrics(nil)

        viewModel.saveAndTransmit()

        #expect(transmitter.sent.first?.holeScores == [5])
        #expect(transmitter.sent.first?.holePars == [4])
    }

    @Test func 전송하면_스냅샷을_지운다() {
        let publisher = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: RoundTransmitterSpy())
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.finishRound()
        viewModel.applyMetrics(nil)

        viewModel.saveAndTransmit()

        #expect(publisher.clearCallCount == 1)
    }

    @Test func 라운드_id는_발행을_거듭해도_바뀌지_않는다() {
        let publisher = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: RoundTransmitterSpy())

        viewModel.start()
        playHole(viewModel, par: 4, strokes: 2)

        let ids = Set(publisher.published.map(\.id))
        #expect(ids.count == 1)
        #expect(ids.first == viewModel.id)
    }

    @Test func 복구한_라운드는_스냅샷의_id와_홀수를_잇는다() {
        let id = UUID()
        let snapshot = RoundSnapshot(id: id,
                                     holeCount: 9,
                                     startedAt: Date(timeIntervalSince1970: 1000),
                                     courseName: nil,
                                     currentHoleIndex: 0,
                                     holeScores: [3],
                                     holePars: [3],
                                     puttCounts: [1])

        let viewModel = RoundViewModel(resuming: snapshot,
                                       publisher: RoundSnapshotPublisherSpy(),
                                       transmitter: RoundTransmitterSpy())

        #expect(viewModel.id == id)
        #expect(viewModel.snapshot.holeCount == 9)
    }

    @Test func 마지막_홀에서는_다음홀로_갈_수_없다() {
        let viewModel = makeViewModel(holeCount: 9,
                                      publisher: RoundSnapshotPublisherSpy(),
                                      transmitter: RoundTransmitterSpy())
        for _ in 1 ..< 9 {
            viewModel.selectPar(4)
            viewModel.goToNextHole()
        }

        #expect(viewModel.canGoToNextHole == false)

        viewModel.goToNextHole()

        #expect(viewModel.currentHoleNumber == 9)
    }

    @Test func 요약_표시값은_트림_기준이다() {
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(),
                                      transmitter: RoundTransmitterSpy())
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole() // 미기록 홀

        #expect(viewModel.recordedHoleCount == 1)
        #expect(viewModel.trimmedTotalStrokes == 5)
        #expect(viewModel.trimmedRelativeToPar == 1)
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `extra argument 'transmitter' in call`

- [ ] **Step 4: `Phase`와 저장 프로퍼티 확장**

`WatchApp/Features/Round/RoundViewModel.swift`에서 `enum Phase`를 교체:

```swift
    enum Phase: Equatable {
        case parSelection
        case counting
        case summary
    }
```

저장 프로퍼티 블록 끝(`@Published private var undoStack = StrokeUndo()` 다음 줄)에 추가:

```swift
    /// 종료 확인을 거쳤는지. `phase`가 이 값에서 `.summary`로 갈린다.
    @Published private var isFinished = false
    /// 워크아웃 집계값. `stopWorkout()`이 1~3초 걸려 뒤늦게 도착한다 (spec §2 결정 9).
    @Published private(set) var metrics: RoundMetrics?
    /// "저장 & 전송"을 눌렀지만 메트릭이 아직 안 와 대기 중인 상태. 요약이 "전송 중…"을 띄운다.
    @Published private(set) var isTransmitting = false
    /// 전송(또는 0홀 폐기)이 끝나 홈으로 돌아가도 되는 상태. View가 이걸 보고 dismiss한다.
    @Published private(set) var didComplete = false
```

`let startedAt: Date` 위에 추가:

```swift
    /// 라운드 식별자. 스냅샷에 실려 복구를 넘어 유지되고, iOS가 이 값으로 재전송을 거른다.
    let id: UUID
    /// 종료 확인을 누른 시점. 요약 체류 시간이나 전송 지연이 라운드 길이에 섞이지 않는다 (spec §4).
    private(set) var endedAt: Date?
```

`private let publisher: RoundSnapshotPublishing` 다음 줄에 추가:

```swift
    private let transmitter: RoundTransmitting
```

- [ ] **Step 5: 두 init 교체**

지정 init:

```swift
    init(id: UUID = UUID(),
         holeCount: Int = 18,
         startedAt: Date = Date(),
         courseName: String? = nil,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher(),
         transmitter: RoundTransmitting = RoundTransmitter())
    {
        self.id = id
        self.startedAt = startedAt
        self.courseName = courseName
        self.publisher = publisher
        self.transmitter = transmitter
        progress = HoleProgress(holeCount: holeCount)
    }
```

복구 init:

```swift
    /// App Group 스냅샷으로 라운드를 되살린다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 새로 시작하므로, 여기서는 스코어 상태만 복원한다.
    /// `id`를 이어받아야 "전송 후 스냅샷 삭제 전 크래시 → 복구 후 재전송"을 iOS가 걸러낸다.
    init(resuming snapshot: RoundSnapshot,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher(),
         transmitter: RoundTransmitting = RoundTransmitter())
    {
        id = snapshot.id
        startedAt = snapshot.startedAt
        courseName = snapshot.courseName
        self.publisher = publisher
        self.transmitter = transmitter
        progress = HoleProgress(holeCount: snapshot.holeCount,
                                holeScores: snapshot.holeScores,
                                holePars: snapshot.holePars,
                                puttCounts: snapshot.puttCounts,
                                currentHoleIndex: snapshot.currentHoleIndex)
    }
```

- [ ] **Step 6: 표시값 확장과 `snapshot` 수정**

`phase`를 교체:

```swift
    /// 화면 분기 조건은 "홀 이동 방향"이 아니라 "이 홀에 파가 있는가" 하나다 (spec §4).
    /// 종료 확인을 거치면 그 위에 요약이 덮인다.
    var phase: Phase {
        if isFinished { return .summary }
        if isEditingPar { return .parSelection }
        return currentPar == 0 ? .parSelection : .counting
    }
```

`canGoToPreviousHole` 아래에 추가:

```swift
    var canGoToNextHole: Bool {
        progress.canGoToNextHole
    }
```

`snapshot`을 교체 — **`id:`와 `holeCount:`를 반드시 명시한다.** 생략하면 발행할 때마다 새 UUID가 생겨 복구를 넘어 유지되지 않는다:

```swift
    var snapshot: RoundSnapshot {
        RoundSnapshot(id: id,
                      holeCount: progress.holeCount,
                      startedAt: startedAt,
                      courseName: courseName,
                      currentHoleIndex: progress.currentHoleIndex,
                      holeScores: progress.holeScores,
                      holePars: progress.holePars,
                      puttCounts: progress.puttCounts)
    }

    // MARK: - 요약 표시값 (전부 트림 후 기준)

    /// 트림 후 실제로 전송될 홀 수. 종료 확인 문구와 요약 헤더가 쓴다.
    var recordedHoleCount: Int {
        snapshot.recordedHoleCount
    }

    var trimmedTotalStrokes: Int {
        snapshot.trimmed().totalStrokes
    }

    var trimmedTotalPutts: Int {
        snapshot.trimmed().totalPutts
    }

    var trimmedRelativeToPar: Int {
        snapshot.trimmed().relativeToPar
    }
```

- [ ] **Step 7: 종료·전송 로직 추가**

`func finish()` 블록 전체를 다음으로 교체:

```swift
    /// 종료 확인에서 호출한다. 워크아웃 종료는 View가 async로 진행하고,
    /// 도착한 결과는 `applyMetrics(_:)`로 들어온다 (spec §7).
    func finishRound() {
        endedAt = Date()
        isFinished = true
    }

    /// 워크아웃 종료 결과가 도착했을 때 View가 부른다.
    /// `nil`이면 0으로 채운다 — HealthKit 거부·워크아웃 미시작·복구 라운드에서 정상 경로다 (spec §8).
    func applyMetrics(_ result: RoundMetrics?) {
        metrics = result ?? .empty
        guard isTransmitting, let metrics else { return }
        transmit(with: metrics)
    }

    /// 요약의 "저장 & 전송". 메트릭이 아직 안 왔으면 대기만 하고, 도착하면 이어서 보낸다
    /// (버튼을 죽이지 않는다 — spec §2 결정 9).
    func saveAndTransmit() {
        // 시작하자마자 종료한 경우. iOS에 빈 라운드를 만들지 않는다 (spec §2 결정 10).
        guard recordedHoleCount > 0 else {
            publisher.clear()
            didComplete = true
            return
        }
        guard let metrics else {
            isTransmitting = true
            return
        }
        transmit(with: metrics)
    }

    private func transmit(with metrics: RoundMetrics) {
        let trimmed = snapshot.trimmed()
        transmitter.send(RoundCompletedMessage(id: id,
                                               startedAt: startedAt,
                                               endedAt: endedAt ?? Date(),
                                               courseName: courseName,
                                               holeScores: trimmed.holeScores,
                                               holePars: trimmed.holePars,
                                               puttCounts: trimmed.puttCounts,
                                               metrics: metrics))
        publisher.clear()
        isTransmitting = false
        didComplete = true
    }
```

- [ ] **Step 8: `RoundSessionView`의 호출부 최소 수정**

`finish()`를 `finishRound()`로 바꿨으므로 호출부를 먼저 맞춰야 컴파일된다.
`WatchApp/Features/Round/RoundSessionView.swift`의 `endRound()`에서 `viewModel.finish()`를
`viewModel.finishRound()`로 바꾼다. 나머지 연결(요약 전환·확인 다이얼로그)은 Task 9에서 한다.

- [ ] **Step 9: 테스트 통과 확인**

Run: watch test
Expected: 126건 PASS (114 + 신규 12)

- [ ] **Step 10: 커밋**

```bash
git status --short
git add WatchApp/Features/Round/RoundViewModel.swift WatchApp/Features/Round/RoundSessionView.swift \
  watchosTests/Support/RoundTransmitterSpy.swift watchosTests/Round/RoundViewModelTransmissionTests.swift
git commit -m "✨ feat: RoundViewModel에 종료·요약·전송

phase에 .summary를 더하고 라운드 id·endedAt·metrics·transmitter를 얹는다.
endedAt은 종료 확인 시점이라 요약 체류나 전송 지연이 라운드 길이에 안 섞인다.
메트릭이 늦게 와도 버튼을 죽이지 않고, 도착하면 이어서 보낸다(결정 9).
기록 홀 0개면 전송하지 않고 스냅샷만 지운다(결정 10).

snapshot이 id를 명시적으로 싣는다 — 생략하면 발행마다 새 UUID가 생겨
복구를 넘어 유지되지 않는다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: `HomeViewModel` (TDD)

복구 판단을 View 밖으로 빼 테스트 가능하게 한다. 1회 가드가 없으면 요약에서 전송 없이 나왔을 때 홈에 도착하자마자 다시 라운드로 끌려 들어가 빠져나올 수 없다 (spec §6).

**Files:**
- Create: `WatchApp/Features/Home/HomeViewModel.swift`
- Test: `watchosTests/Home/HomeViewModelTests.swift`

**Interfaces:**
- Consumes: `RoundSnapshotPublishing`
- Produces: `HomeViewModel(publisher:)`, `.holeCount`, `.resumingSnapshot`, `.isRoundActive`, `.startButtonLabel`, `.hasPendingRound`, `resumeIfNeeded()`, `toggleHoleCount()`, `startNewRound()`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Home/HomeViewModelTests.swift` 신규 생성:

```swift
@testable import GolfCounter_Watch_App
import Foundation
import Testing

@MainActor
struct HomeViewModelTests {
    private func snapshot() -> RoundSnapshot {
        RoundSnapshot(holeCount: 9,
                      startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: nil,
                      currentHoleIndex: 1,
                      holeScores: [4, 0],
                      holePars: [4, 0],
                      puttCounts: [2, 0])
    }

    @Test func 스냅샷이_있으면_그_라운드로_복구한다() {
        let publisher = RoundSnapshotPublisherSpy()
        publisher.stored = snapshot()
        let viewModel = HomeViewModel(publisher: publisher)

        viewModel.resumeIfNeeded()

        #expect(viewModel.isRoundActive)
        #expect(viewModel.resumingSnapshot?.holeCount == 9)
    }

    @Test func 스냅샷이_없으면_아무것도_하지_않는다() {
        let viewModel = HomeViewModel(publisher: RoundSnapshotPublisherSpy())

        viewModel.resumeIfNeeded()

        #expect(viewModel.isRoundActive == false)
        #expect(viewModel.resumingSnapshot == nil)
    }

    @Test func 복구_시도는_앱_실행당_한_번뿐이다() {
        // 요약에서 전송 없이 나오면 스냅샷이 남는다. 가드가 없으면 홈에 도착하자마자
        // 다시 라운드로 끌려 들어가 빠져나올 수 없다.
        let publisher = RoundSnapshotPublisherSpy()
        publisher.stored = snapshot()
        let viewModel = HomeViewModel(publisher: publisher)
        viewModel.resumeIfNeeded()
        viewModel.isRoundActive = false

        viewModel.resumeIfNeeded()

        #expect(viewModel.isRoundActive == false)
    }

    @Test func 홀수_토글은_18과_9를_오간다() {
        let viewModel = HomeViewModel(publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.holeCount == 18)

        viewModel.toggleHoleCount()
        #expect(viewModel.holeCount == 9)

        viewModel.toggleHoleCount()
        #expect(viewModel.holeCount == 18)
    }

    @Test func 시작_버튼_문구가_홀수를_말한다() {
        let viewModel = HomeViewModel(publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.startButtonLabel == "18홀 시작")

        viewModel.toggleHoleCount()
        #expect(viewModel.startButtonLabel == "9홀 시작")
    }

    @Test func 새_라운드를_시작하면_복구_스냅샷을_비운다() {
        let publisher = RoundSnapshotPublisherSpy()
        publisher.stored = snapshot()
        let viewModel = HomeViewModel(publisher: publisher)
        viewModel.resumeIfNeeded()

        viewModel.startNewRound()

        #expect(viewModel.resumingSnapshot == nil)
        #expect(viewModel.isRoundActive)
    }

    @Test func 진행중_라운드가_남아있는지_알려준다() {
        let publisher = RoundSnapshotPublisherSpy()
        let viewModel = HomeViewModel(publisher: publisher)

        #expect(viewModel.hasPendingRound == false)

        publisher.stored = snapshot()
        #expect(viewModel.hasPendingRound)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: watch test
Expected: 컴파일 실패 — `cannot find 'HomeViewModel' in scope`

- [ ] **Step 3: `HomeViewModel` 구현**

`WatchApp/Features/Home/HomeViewModel.swift` 신규 생성:

```swift
import Combine
import Foundation

/// 홈 화면의 상태. 복구 판단을 View 밖으로 빼 테스트 가능하게 한다 (spec §6).
/// UI 프레임워크를 import하지 않는다.
@MainActor
final class HomeViewModel: ObservableObject {
    /// 라운드 시작 시 쓸 홀 수. 앱을 열 때마다 18로 시작하며 영속 저장하지 않는다 (spec §3.4).
    @Published private(set) var holeCount = 18
    /// 복구할 스냅샷. nil이 아니면 그 라운드를 이어서 연다.
    @Published private(set) var resumingSnapshot: RoundSnapshot?
    @Published var isRoundActive = false

    private let publisher: RoundSnapshotPublishing

    /// 복구 시도는 앱 실행당 1회다 (spec §2 결정 7). 없으면 요약에서 전송 없이 나왔을 때
    /// 홈에 도착하자마자 다시 라운드로 끌려 들어가 빠져나올 수 없다.
    private var hasAttemptedResume = false

    init(publisher: RoundSnapshotPublishing = RoundSnapshotPublisher()) {
        self.publisher = publisher
    }

    var startButtonLabel: String {
        "\(holeCount)홀 시작"
    }

    /// 진행 중 스냅샷이 남아 있는지. 새 라운드 시작 전 확인 다이얼로그를 띄울지 판단한다 (spec §3.6).
    var hasPendingRound: Bool {
        publisher.loadCurrent() != nil
    }

    func resumeIfNeeded() {
        guard !hasAttemptedResume else { return }
        hasAttemptedResume = true
        guard let snapshot = publisher.loadCurrent() else { return }
        resumingSnapshot = snapshot
        isRoundActive = true
    }

    func toggleHoleCount() {
        holeCount = holeCount == 18 ? 9 : 18
    }

    func startNewRound() {
        resumingSnapshot = nil
        isRoundActive = true
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: watch test
Expected: 133건 PASS (126 + 신규 7)

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/Home/HomeViewModel.swift watchosTests/Home/HomeViewModelTests.swift
git commit -m "✨ feat: HomeViewModel — 복구 판단과 홀 수 선택

복구 시도를 앱 실행당 1회로 제한한다. 가드가 없으면 요약에서 전송 없이 나왔을 때
홈에 도착하자마자 다시 라운드로 끌려 들어가 빠져나올 수 없다.
홀 수는 앱을 열 때마다 18로 시작하며 영속 저장하지 않는다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: 홈 화면 — 홀 수 선택 + 새 라운드 확인

**Files:**
- Create: `WatchApp/Features/Home/Components/HoleCountSelector.swift`
- Modify: `WatchApp/Features/Home/HomeView.swift`

**Interfaces:**
- Consumes: Task 7의 `HomeViewModel`
- Produces: `HoleCountSelector(holeCount:onToggle:)`. `RoundSessionView(resuming:holeCount:)` 시그니처를 요구한다 — Task 9에서 맞춘다

- [ ] **Step 1: 컴포넌트 생성**

`WatchApp/Features/Home/Components/HoleCountSelector.swift` 신규 생성:

```swift
import SwiftUI

/// 홀 수 선택 행 — 라벨 + 값 버튼 (spec §3.4).
///
/// tennis_counter `ModeView`의 게임 수(4→5→6) 컨트롤과 같은 모양이다. 홀 수는 불리언이
/// 아니라 값이라 스위치보다 성격이 맞고, 9와 18 중 무엇인지가 숫자로 항상 보인다.
struct HoleCountSelector: View {
    let holeCount: Int
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Text("홀 수")
                .font(.system(size: 14))
            Spacer()
            Button(action: onToggle) {
                Text("\(holeCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    HoleCountSelector(holeCount: 18, onToggle: {})
}
```

- [ ] **Step 2: `HomeView` 교체**

`WatchApp/Features/Home/HomeView.swift` 전체를 교체:

```swift
import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var isConfirmingNewRound = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Spacer()

                Text("Golf Counter")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.green)

                Button(action: startTapped) {
                    Text(viewModel.startButtonLabel)
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                HoleCountSelector(holeCount: viewModel.holeCount,
                                  onToggle: viewModel.toggleHoleCount)

                Spacer()
            }
            .padding(.horizontal, 8)
            .navigationDestination(isPresented: $viewModel.isRoundActive) {
                RoundSessionView(resuming: viewModel.resumingSnapshot,
                                 holeCount: viewModel.holeCount)
            }
            .confirmationDialog("진행 중인 라운드가 있습니다",
                                isPresented: $isConfirmingNewRound,
                                titleVisibility: .visible)
            {
                Button("새로 시작", role: .destructive, action: viewModel.startNewRound)
                Button("취소", role: .cancel) {}
            } message: {
                Text("새로 시작하면 지워집니다.")
            }
        }
        .onAppear(perform: viewModel.resumeIfNeeded)
    }

    /// 전송 없이 요약을 벗어나면 스냅샷이 남는다(결정 6). 그대로 새 라운드를 시작하면
    /// start()가 곧바로 새 스냅샷을 발행해 이전 라운드를 덮어쓰므로 먼저 확인한다 (spec §3.6).
    private func startTapped() {
        if viewModel.hasPendingRound {
            isConfirmingNewRound = true
        } else {
            viewModel.startNewRound()
        }
    }
}

#Preview {
    HomeView()
}
```

- [ ] **Step 3: `RoundSessionView.init`에 `holeCount` 받기**

`HomeView`가 `holeCount:`를 넘기므로 시그니처를 먼저 맞춰야 빌드가 유지된다.
`WatchApp/Features/Round/RoundSessionView.swift`의 init을 교체:

```swift
    /// 진행 중 스냅샷이 있으면 그 라운드를 이어서, 없으면 고른 홀 수로 새 라운드를 시작한다.
    /// 복구 라운드는 홈의 선택값을 무시하고 스냅샷의 `holeCount`를 쓴다.
    init(resuming snapshot: RoundSnapshot? = nil, holeCount: Int = 18) {
        if let snapshot {
            _viewModel = StateObject(wrappedValue: RoundViewModel(resuming: snapshot))
        } else {
            _viewModel = StateObject(wrappedValue: RoundViewModel(holeCount: holeCount))
        }
    }
```

- [ ] **Step 4: watch build로 검증**

Run: watch build
Expected: BUILD SUCCEEDED

- [ ] **Step 5: 커밋**

```bash
git status --short
git add WatchApp/Features/Home/ WatchApp/Features/Round/RoundSessionView.swift
git commit -m "✨ feat: 홈에서 홀 수를 고르고 새 라운드를 확인한다

별도 화면 대신 라벨+값 버튼을 홈에 둔다 — 지금 담을 게 9/18 하나뿐이라
화면값을 못 한다. 골프장 입력(⑧)이 생기면 '라운드 준비' 화면으로 승격한다.
시작 버튼이 'N홀 시작'으로 무엇을 시작하는지 직접 말한다.

진행 중 스냅샷이 남은 채 새 라운드를 시작하면 이전 라운드를 덮어쓰므로
확인 다이얼로그를 둔다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: 요약 화면 + 세션 화면 연결

**Files:**
- Create: `WatchApp/Features/Round/Summary/SummaryView.swift`
- Modify: `WatchApp/Features/Round/RoundSessionView.swift`

**Interfaces:**
- Consumes: Task 6의 `RoundViewModel`(`phase`·`recordedHoleCount`·`trimmed*`·`isTransmitting`·`didComplete`·`finishRound()`·`applyMetrics(_:)`·`saveAndTransmit()`), Task 4의 `RoundMetrics.init(_:)`
- Produces: `SummaryView(viewModel:)`, `RoundSessionView(resuming:holeCount:)`

- [ ] **Step 1: `SummaryView` 생성**

`WatchApp/Features/Round/Summary/SummaryView.swift` 신규 생성:

```swift
import SwiftUI

/// 종료 요약 — 기록 홀 수 · 오버파 · 총타수/총퍼트 · 저장&전송 (spec §3.3).
///
/// 표시값은 전부 **트림 후** 기준이다. 상단의 "N홀 완료"가 실제로 전송될 홀 수를
/// 발신 직전에 다시 확인시킨다.
///
/// 워크아웃 메트릭(칼로리·심박·거리·시간)은 여기 띄우지 않고 전송 페이로드에만 싣는다 —
/// `stopWorkout()`이 1~3초 걸려 대기·도착·미도착 세 상태를 설계해야 하는데, 같은 정보를
/// iOS 상세 화면이 보여줄 예정이라 값에 비해 비용이 크다.
struct SummaryView: View {
    @ObservedObject var viewModel: RoundViewModel

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            Text(headline)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(ScoreFormat.relativeToPar(viewModel.trimmedRelativeToPar))
                .font(.system(size: 42, weight: .bold, design: .rounded))

            Text("\(viewModel.trimmedTotalStrokes)타 · \(viewModel.trimmedTotalPutts)퍼트")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            if let courseName = viewModel.courseName {
                Text(courseName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: viewModel.saveAndTransmit) {
                Text(buttonLabel)
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 8)
    }

    private var headline: String {
        viewModel.recordedHoleCount > 0
            ? "\(viewModel.recordedHoleCount)홀 완료"
            : "기록된 홀 없음"
    }

    /// 메트릭 대기 중에도 버튼은 살아 있다 — 문구만 바뀐다 (spec §2 결정 9).
    private var buttonLabel: String {
        if viewModel.isTransmitting { return "전송 중…" }
        return viewModel.recordedHoleCount > 0 ? "저장 & 전송" : "저장 없이 종료"
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    viewModel.finishRound()
    return SummaryView(viewModel: viewModel)
}
```

- [ ] **Step 2: `RoundSessionView` 교체**

`WatchApp/Features/Round/RoundSessionView.swift` 전체를 교체:

```swift
import SwiftUI
import WorkoutCore

struct RoundSessionView: View {
    @StateObject private var viewModel: RoundViewModel
    @StateObject private var healthKit = WorkoutSessionService(configuration: .golf)
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1
    @State private var startTask: Task<Void, Never>?
    @State private var isConfirmingEnd = false
    /// endRound()가 정상적으로 워크아웃을 끝냈는지 표시한다.
    /// false인 채로 뷰가 사라지면(edge-swipe 등 endRound() 밖의 경로) onDisappear에서 방어적으로 정리한다.
    @State private var didFinish = false

    /// 진행 중 스냅샷이 있으면 그 라운드를 이어서, 없으면 고른 홀 수로 새 라운드를 시작한다.
    /// 복구 라운드는 홈의 선택값을 무시하고 스냅샷의 `holeCount`를 쓴다.
    init(resuming snapshot: RoundSnapshot? = nil, holeCount: Int = 18) {
        if let snapshot {
            _viewModel = StateObject(wrappedValue: RoundViewModel(resuming: snapshot))
        } else {
            _viewModel = StateObject(wrappedValue: RoundViewModel(holeCount: holeCount))
        }
    }

    /// 요약이면 3페이지 TabView를 통째로 대체한다 — 종료 후에는 컨트롤·메트릭 페이지가
    /// 의미를 잃으므로 그쪽으로 스와이프할 수 없어야 한다 (spec §3.2).
    ///
    /// `Group`이 아니라 `ZStack`인 이유: `Group`은 modifier를 분기마다 개별 적용해
    /// 전환 시 `onAppear`가 재발화하고 `startRound()`가 다시 돈다.
    var body: some View {
        ZStack {
            if viewModel.phase == .summary {
                SummaryView(viewModel: viewModel)
            } else {
                sessionTabs
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear(perform: startRound)
        .onDisappear(perform: stopWorkoutIfNotFinished)
        .onChange(of: viewModel.didComplete) { _, completed in
            if completed { dismiss() }
        }
        .confirmationDialog(endDialogTitle,
                            isPresented: $isConfirmingEnd,
                            titleVisibility: .visible)
        {
            Button(endDialogConfirmLabel, role: .destructive, action: endRound)
            Button("취소", role: .cancel) {}
        }
    }

    private var sessionTabs: some View {
        TabView(selection: $selectedTab) {
            SessionControlsView(isPaused: healthKit.isPaused,
                                onPauseResume: togglePause,
                                onEnd: { isConfirmingEnd = true })
                .tag(0)
            centerPage
                .tag(1)
            SessionMetricsView(healthKit: healthKit)
                .tag(2)
        }
        .tabViewStyle(.page)
    }

    /// 트림 후 실제로 몇 홀이 기록되는지를 문구에 명시한다 (spec §2 결정 4).
    private var endDialogTitle: String {
        viewModel.recordedHoleCount > 0
            ? "\(viewModel.recordedHoleCount)홀이 기록됩니다"
            : "기록된 홀이 없습니다"
    }

    private var endDialogConfirmLabel: String {
        viewModel.recordedHoleCount > 0 ? "종료" : "저장 없이 종료"
    }

    private func togglePause() {
        if healthKit.isPaused {
            healthKit.resumeWorkout()
        } else {
            healthKit.pauseWorkout()
        }
    }

    @ViewBuilder
    private var centerPage: some View {
        switch viewModel.phase {
        case .parSelection:
            ParSelectionView(viewModel: viewModel)
        case .counting, .summary:
            ScoringView(viewModel: viewModel)
        }
    }

    private func startRound() {
        viewModel.start()
        startTask = Task {
            await healthKit.requestAuthorization()
            guard !Task.isCancelled else { return }
            healthKit.startWorkout()
        }
    }

    /// 종료 확인을 거친 뒤 호출된다. 워크아웃을 끝내고 요약으로 전환하며,
    /// 집계값은 도착하는 대로 ViewModel에 넘긴다 — 화면은 기다리지 않는다 (spec §7).
    ///
    /// 인증 대기 중이던 시작 Task를 먼저 취소해, 라운드 종료 후 뒤늦게 startWorkout()이
    /// 불려 고아 HKWorkoutSession이 남는 경쟁 상태를 막는다.
    private func endRound() {
        startTask?.cancel()
        didFinish = true
        viewModel.finishRound()
        let service = healthKit
        Task {
            let result = await service.stopWorkout()
            viewModel.applyMetrics(result.map(RoundMetrics.init))
        }
    }

    /// endRound()를 거치지 않고 뷰가 사라지면(예: edge-swipe 뒤로가기) 워크아웃 세션이 고아로 남는다.
    /// 스냅샷/App Group 상태는 건드리지 않는다 — 전송 없이 요약을 벗어난 라운드는 스냅샷이
    /// 남아 다음 실행 때 복구된다 (spec §2 결정 6).
    private func stopWorkoutIfNotFinished() {
        guard !didFinish else { return }
        let service = healthKit
        Task { _ = await service.stopWorkout() }
    }
}
```

- [ ] **Step 3: watch test로 검증**

Run: watch test
Expected: 133건 PASS. 신규 테스트는 없다 — View는 테스트하지 않는다.

- [ ] **Step 4: 커밋**

```bash
git status --short
git add WatchApp/Features/Round/Summary/SummaryView.swift WatchApp/Features/Round/RoundSessionView.swift
git commit -m "✨ feat: 종료 확인 다이얼로그 + 요약 화면 연결

요약이면 3페이지 TabView를 통째로 대체한다 — 종료 후에는 컨트롤의 일시정지·종료와
메트릭의 실시간 수치가 의미를 잃으므로 그쪽으로 스와이프할 수 없어야 한다.
Group이 아니라 ZStack인 이유: Group은 modifier를 분기마다 개별 적용해 전환 시
onAppear가 재발화하고 startRound()가 다시 돈다.

확인 다이얼로그는 트림 후 실제 기록 홀 수를 문구에 넣는다.
요약은 오버파를 중심에 두고 워크아웃 메트릭은 페이로드에만 싣는다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: 최종 검증 + PR

**Files:** 없음 (검증·PR만)

**Interfaces:**
- Consumes: Task 1~9 전체
- Produces: 3개 타깃 그린 + lint/format 통과 + PR

- [ ] **Step 1: 3개 타깃 빌드/테스트**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```
Expected: 전부 SUCCEEDED, watchosTests 133건 PASS.

컴플리케이션이 `no such module 'ConnectivityCore'`로 깨지면 Task 5의 pbxproj 예외가 안 먹은 것이다. iOS가 `no such module 'WorkoutCore'`로 깨지면 `import WorkoutCore`가 `Shared/`로 샌 것이다.

- [ ] **Step 2: lint/format**

```bash
make lint && make format
```
Expected: 위반 0. 실패하면 `make fix` 후 재실행하고 결과를 커밋한다.

- [ ] **Step 3: 시뮬레이터 육안 확인**

워치 시뮬레이터에서 다음 5가지를 확인한다. 자동화 테스트가 없는 부분이다.

1. 홈에서 `홀 수 [18]`을 탭하면 `[9]`가 되고 시작 버튼이 `9홀 시작`으로 바뀐다
2. 9홀을 골라 시작하면 9번째 홀에서 "다음" 화살표가 더 이상 홀을 늘리지 않는다
3. 컨트롤 페이지의 "라운드 종료" → `N홀이 기록됩니다` 다이얼로그 → 확인하면 요약 화면이 뜨고 **옆으로 스와이프가 안 된다**
4. 요약에서 "저장 & 전송"을 누르면 홈으로 돌아간다
5. 요약에서 크라운/스와이프로 나온 뒤 `18홀 시작`을 누르면 `진행 중인 라운드가 있습니다` 확인이 뜬다

- [ ] **Step 4: push + PR 생성**

```bash
git push -u origin feature/watch-round-transmission
gh pr create --title "✨ 워치 라운드 종료·전송 — 홀 수 선택 + 요약 + 발신" --body "$(cat <<'EOF'
## Summary
- 스펙: docs/superpowers/specs/2026-08-14-watch-round-transmission-design.md
- 홀 수 선택(9/18) — 상한을 `HoleProgress`가 소유해 `advanceToNextHole()`이 스스로 막는다
- 종료 확인 다이얼로그 → 요약 화면 → `.reliable` 발신
- 요약은 3페이지 TabView를 통째로 교체 (종료 후 컨트롤·메트릭은 의미를 잃는다)
- 홀 수 선택은 별도 화면 대신 홈의 라벨+값 버튼 — 골프장 입력(⑧) 때 "라운드 준비" 화면으로 승격
- `RoundSnapshot`에 `id`·`holeCount` 추가 + 구버전 하위호환 디코딩
- `Shared/`의 `ConnectivityMessages.swift`를 컴플리케이션 타깃에서 제외 (pbxproj 예외)

받는 쪽(iOS 수신·저장)은 plan ⑤ 범위다 — 이 PR은 발신까지.

## 이 PR에서 새로 막은 것
- 구버전 스냅샷 디코딩 실패로 진행 중 라운드가 조용히 사라지는 경로
- 요약 이탈 후 새 라운드를 시작하면 이전 스냅샷을 덮어쓰는 경로

## Test plan
- [ ] GolfCounter Watch App: 133건 PASS
- [ ] GolfCounter (iOS)·ComplicationAppExtension: build 통과
- [ ] make lint / make format 통과
- [ ] 시뮬레이터 육안 확인 5가지 (홀 수 토글 · 상한 · 요약 전환 · 전송 후 복귀 · 새 라운드 확인)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

머지는 사용자 확인 후 `gh pr merge <n> --merge --delete-branch`.

---

## 후속 작업 (이 plan 범위 밖)

1. **plan ⑤ iOS 수신 + 기록 탭** — `2026-08-13-ios-receive-and-history.md`. `RoundCompletedMessage`를 받아 `GolfRound`로 저장하고, 같은 `id`가 이미 있으면 무시한다
2. **plan ⑥ iOS 통계 탭** — `2026-08-13-ios-stats.md`
3. **plan ⑧ MapKit 골프장 감지** — 그때 홀 수와 골프장을 함께 담는 "라운드 준비" 화면으로 승격하고 `HoleCountSelector`를 그대로 옮긴다
