# ④ watch: 홀 수 선택 + 종료 요약 + 라운드 전송 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 라운드 시작 시 9/18홀을 고르게 하고, 종료 시 확인 → 요약 화면 → `.reliable` 전송까지 이어 붙여 워치에서 만든 라운드가 iOS로 넘어갈 수 있게 한다.

**Architecture:** 전송 페이로드는 `Shared/Services/ConnectivityMessages.swift`의 `RoundCompletedMessage`(ConnectivityCore `ConnectivityMessage` 채택)이고, 발신은 `RoundTransmitting` 프로토콜 뒤에 두어 ViewModel 테스트가 WatchConnectivity 없이 돈다 — plan ③의 `RoundSnapshotPublishing`과 같은 방식이다. 홀 수 상한과 미기록 홀 트림은 전부 `RoundViewModel`·`RoundSnapshot`의 순수 로직으로 넣고 `watchosTests`에서 검증한다. 종료 요약은 새 화면을 push하지 않고 `RoundSessionView` 안에서 `phase == .summary`일 때 3페이지 TabView를 통째로 대체한다.

**Tech Stack:** Swift 5(language mode) / SwiftUI / WidgetKit / ralli-kit(`ConnectivityCore`·`WorkoutCore`, 로컬 SPM `../ralli-kit`) / Swift Testing

**참조 spec:** `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` (§3 홀 수 선택·미기록 홀 트림·`RoundSnapshot`, §4 홀 수 선택 화면·종료 요약, §5 전송)

**선행 plan:** ③ `docs/superpowers/plans/2026-08-04-watch-counter-core.md` (PR #7 머지 완료). 이 plan은 ③이 만든 `RoundViewModel`·`RoundSnapshot`·`HomeView`·`RoundSessionView`를 **수정**한다.

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0** (ralli-kit 최소 요구)
- `DEVELOPMENT_TEAM = P2TU28W32L`, App Group `group.com.yj.GolfCounter`
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `🐛 fix:` / `♻️ refactor:` / `✅ test:` / `📝 docs:` …), **main 직접 커밋 금지** — 브랜치 + PR, 머지는 `gh pr merge <n> --merge --delete-branch`
- 빌드 검증 시뮬레이터: iPhone은 `iPhone 17 Pro`, 워치는 `Apple Watch Series 11 (46mm)` (`xcrun simctl list devices available`로 존재 확인)
- 파일 네이밍·폴더 규칙: `CLAUDE.md` 컨벤션 (View suffix는 독립 화면만, 한 파일 = 한 타입, 계층화 Components, ViewModel은 UI 프레임워크 import 금지)
- 테스트: Swift Testing(`@Test`/`#expect`), 테스트명 `대상_행위_예상결과`, ViewModel 테스트는 `@MainActor`, **View는 테스트하지 않는다**
- 사용자 노출 문자열은 이 plan에서도 **한국어 하드코딩**으로 둔다 (로컬라이즈는 plan ⑦). 단 "Par"/"H"/"bpm" 등 plan ③에서 관용 표기로 유지하기로 한 영문은 그대로 둔다
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`

## 타깃 링크 제약 (이 plan에서 가장 중요한 함정)

`Shared/`는 `PBXFileSystemSynchronizedRootGroup`으로 **세 타깃 모두**(iOS `GolfCounter` / `GolfCounter Watch App` / `ComplicationAppExtension`)에 동기화되어 있다. 그런데 SPM 링크는 타깃마다 다르다:

| 타깃 | 링크된 ralli-kit 제품 |
|------|---------------------|
| `GolfCounter` (iOS) | `ConnectivityCore`, `PersistenceCore` |
| `GolfCounter Watch App` | `ConnectivityCore`, `WorkoutCore` |
| `ComplicationAppExtension` | **없음** (SwiftUI + WidgetKit만) |

따라서:

1. **`Shared/`에 `import ConnectivityCore`를 하는 파일을 두면 컴플리케이션 타깃 빌드가 깨진다.** → Task 4에서 `PBXFileSystemSynchronizedBuildFileExceptionSet`으로 그 파일들을 컴플리케이션 타깃에서 제외한다. **이 plan은 pbxproj를 손대는 첫 plan이다** (plan ①의 "파일 추가만으로 반영" 전제가 처음으로 깨지는 지점).
2. **`Shared/`에 `import WorkoutCore`를 하는 파일을 두면 iOS 타깃 빌드가 깨진다.** → 워크아웃 메트릭은 `Shared/Models/RoundMetrics.swift`(Foundation만 쓰는 순수 struct)로 옮겨 담고, `WorkoutResult` → `RoundMetrics` 변환은 **워치 타깃 안**(`WatchApp/`)에 둔다.

---

## 이 plan에서 확정한 설계 결정 (brainstorming 결과)

1. **홀 수 선택 UI를 도입한다** — spec 초안의 "9홀/18홀 선택 UI 자체가 없다"를 뒤집었다. "다음"에 상한이 없어 마지막 홀에서 한 번 더 누르면 빈 홀이 생기는 문제 때문. 선택값은 고정이며 **연장 없음**(9홀을 골랐으면 9홀로 끝). 대가로 전반/후반 이어치기가 다시 엣지케이스가 된다 — 새 라운드로 처리한다.
2. **미기록 홀은 전송 직전에 트림한다** — 배열 말단에서부터 `par == 0`인 홀을 제거. `par == 0`이면 파 선택 화면이 떠 카운터에 접근할 수 없으므로 `score`·`putts`도 반드시 0 → **무손실**이다. 홀 수 선택만으로는 "18홀 골라 3홀만 치고 중단" 케이스가 안 막히므로 둘 다 필요하다.
3. **라운드 id는 라운드 시작 시 생성해 `RoundSnapshot`에 싣는다** — 복구 후에도 같은 id가 유지되어 "전송했으나 스냅샷 삭제 전 크래시 → 복구 후 재전송"까지 iOS 중복 검사가 걸러낸다.
4. **"라운드 종료"에 확인 다이얼로그를 둔다** — 오터치로 워크아웃이 끊기는 것을 막고, 트림 후 실제로 몇 홀이 기록되는지 문구에 명시한다.
5. **요약 화면은 push가 아니라 `RoundSessionView` 내부 phase 전환** — 화면 스택이 안 깊어지고 plan ③의 `didFinish`/`onDisappear` 방어 로직을 그대로 재사용한다.
6. **전송 없이 요약을 벗어나면 스냅샷을 남긴다** — 라운드 데이터가 조용히 사라지는 경로를 만들지 않는다. 단 복구는 **앱 실행당 1회**만 시도한다(아래 7).
7. **홈의 복구 시도는 앱 실행당 1회로 제한한다** — plan ③의 `resumeIfNeeded()`는 `HomeView.onAppear`마다 도는데, 이 plan에서 "전송 없이 요약 이탈 → 홈"이 가능해지면서 **홈에 도착하자마자 다시 라운드로 튕겨 들어가 빠져나올 수 없는 루프**가 된다. `@State` 플래그로 1회 제한한다.
8. **요약 화면은 spec대로 최소 구성** — 총타수·총퍼트(+골프장명은 값이 있을 때만). 워크아웃 메트릭은 화면에 안 띄우고 전송 페이로드에만 싣는다.
9. **"저장 & 전송" 버튼은 항상 활성** — `stopWorkout()`이 async라 메트릭 수집에 1~3초 걸리는데, 버튼을 죽이는 대신 탭 후 "전송 중…"을 표시하고 도착하는 대로 보낸다.
10. **기록된 홀이 0개면 전송하지 않는다** — 시작하자마자 종료한 경우. 버튼 문구가 "저장 없이 종료"로 바뀌고 스냅샷만 지운다. iOS에 빈 라운드를 만들지 않는다.

## 범위 밖

- iOS 수신·저장·기록 화면 (plan ⑤) — 이 plan은 **발신까지만**. 전송한 메시지를 받는 쪽은 아직 없다
- 문자열 로컬라이즈 (plan ⑦), MapKit 골프장 감지 (plan ⑧ — `courseName`은 이 plan 시점에도 항상 nil)
- 워치의 완료 라운드 로컬 보관 (spec §14에서 명시적 제외)

---

### Task 0: 작업 브랜치 생성

**Files:** 없음 (git만)

- [ ] **Step 1: main 최신화 후 브랜치 생성**

```bash
git -C /Users/yj/Workspace/golf_counter checkout main && git -C /Users/yj/Workspace/golf_counter pull
git -C /Users/yj/Workspace/golf_counter checkout -b feat/watch-round-transmission
```

- [ ] **Step 2: 베이스라인 테스트 수치 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: watchosTests **49건** PASS. 이 숫자가 이 plan의 출발점이다.

---

### Task 1: `RoundSnapshot`에 `id`·`holeCount` 추가 (TDD)

라운드 식별자와 선택한 홀 수를 스냅샷에 싣는다. 기존 호출부 9곳이 그대로 컴파일되도록 두 필드 모두 **기본값 있는 파라미터**로 넣는다.

**Files:**
- Modify: `Shared/Models/RoundSnapshot.swift`
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`
- Test: `watchosTests/Shared/RoundSnapshotTests.swift`

**Interfaces:**
- Produces: `RoundSnapshot.id: UUID`, `RoundSnapshot.holeCount: Int`, `RoundSnapshot.defaultHoleCount: Int` (= 18), 명시적 `init(id:startedAt:courseName:holeCount:currentHoleIndex:holeScores:holePars:puttCounts:)` (`id`·`courseName`·`holeCount`에 기본값), 하위호환 `init(from:)`
- Produces: `RoundViewModel.id: UUID`, `RoundViewModel.holeCount: Int`, `init(id:startedAt:courseName:holeCount:publisher:)`
- Consumes: 없음

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Shared/RoundSnapshotTests.swift`의 `makeSnapshot()`에 `holeCount`·`id`를 넣고, 파일 맨 끝(`}` 직전)에 테스트 2개를 추가한다.

`makeSnapshot()`을 아래로 교체:

```swift
    private static let fixedID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private func makeSnapshot() -> RoundSnapshot {
        RoundSnapshot(id: Self.fixedID,
                      startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: "테스트CC",
                      holeCount: 18,
                      currentHoleIndex: 6,
                      holeScores: [4, 3, 6, 5, 4, 3, 2],
                      holePars: [4, 3, 5, 4, 4, 3, 4],
                      puttCounts: [2, 1, 2, 2, 1, 1, 1])
    }
```

파일 끝에 추가:

```swift
    @Test func id와_홀수가_코더블_왕복에서_보존된다() throws {
        let snapshot = makeSnapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(decoded.id == Self.fixedID)
        #expect(decoded.holeCount == 18)
    }

    // plan ④ 이전 빌드가 App Group에 남긴 스냅샷에는 id·holeCount 키가 없다.
    // 디코딩이 실패하면 진행 중이던 라운드가 조용히 사라지므로 기본값으로 채운다.
    @Test func 구버전_스냅샷도_디코딩되고_기본값이_채워진다() throws {
        let legacy = Data("""
        {"startedAt":1000,"courseName":"테스트CC","currentHoleIndex":2,\
        "holeScores":[4,5,3],"holePars":[4,4,3],"puttCounts":[2,2,1]}
        """.utf8)

        let decoded = try JSONDecoder().decode(RoundSnapshot.self, from: legacy)

        #expect(decoded.holeCount == RoundSnapshot.defaultHoleCount)
        #expect(decoded.holeScores == [4, 5, 3])
        #expect(decoded.courseName == "테스트CC")
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -30
```

Expected: 컴파일 실패 — `extra argument 'id' in call`, `value of type 'RoundSnapshot' has no member 'holeCount'`

- [ ] **Step 3: `RoundSnapshot`에 필드 추가**

`Shared/Models/RoundSnapshot.swift` 전체를 교체:

```swift
import Foundation

/// 라운드 진행 중 상태 스냅샷.
/// 워치 크래시/강제종료 복구와 컴플리케이션 표시 데이터원을 겸한다 (spec §3).
struct RoundSnapshot: Codable, Equatable {
    /// 홀 수를 고르기 전에 만들어진 구버전 스냅샷을 복원할 때 쓰는 값.
    static let defaultHoleCount = 18

    /// 라운드 시작 시 1회 생성되어 복구를 넘어 유지된다.
    /// `GolfRound.id`가 이 값을 물려받아 iOS의 중복 수신 검사가 성립한다 (spec §5).
    var id: UUID
    var startedAt: Date
    var courseName: String?
    /// 라운드 시작 시 고른 상한(9 또는 18). 진행 중 바뀌지 않는다 (spec §3).
    var holeCount: Int
    var currentHoleIndex: Int // 0-based, 인덱스 = 홀 번호 - 1
    var holeScores: [Int]
    var holePars: [Int]
    var puttCounts: [Int]

    init(id: UUID = UUID(),
         startedAt: Date,
         courseName: String? = nil,
         holeCount: Int = RoundSnapshot.defaultHoleCount,
         currentHoleIndex: Int,
         holeScores: [Int],
         holePars: [Int],
         puttCounts: [Int])
    {
        self.id = id
        self.startedAt = startedAt
        self.courseName = courseName
        self.holeCount = holeCount
        self.currentHoleIndex = currentHoleIndex
        self.holeScores = holeScores
        self.holePars = holePars
        self.puttCounts = puttCounts
    }

    /// plan ④ 이전 빌드가 남긴 스냅샷에는 `id`·`holeCount` 키가 없다.
    /// 기본 합성 디코딩이면 그 스냅샷은 통째로 디코딩에 실패해 진행 중 라운드가 사라지므로,
    /// 두 키만 없어도 되도록 직접 디코딩한다. (Encodable은 합성된 것을 그대로 쓴다)
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName)
        holeCount = try container.decodeIfPresent(Int.self, forKey: .holeCount) ?? Self.defaultHoleCount
        currentHoleIndex = try container.decode(Int.self, forKey: .currentHoleIndex)
        holeScores = try container.decode([Int].self, forKey: .holeScores)
        holePars = try container.decode([Int].self, forKey: .holePars)
        puttCounts = try container.decode([Int].self, forKey: .puttCounts)
    }

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
```

- [ ] **Step 4: `RoundViewModel`이 두 값을 갖고 스냅샷에 싣게 수정**

`WatchApp/Features/Round/RoundViewModel.swift`에서 저장 프로퍼티·두 init·`snapshot` 세 곳을 수정한다.

`let startedAt: Date` 윗줄에 추가:

```swift
    let id: UUID
    /// 라운드 시작 시 고른 홀 수 상한. 진행 중 바뀌지 않는다 (spec §3).
    let holeCount: Int
```

지정 init을 교체:

```swift
    init(id: UUID = UUID(),
         startedAt: Date = Date(),
         courseName: String? = nil,
         holeCount: Int = RoundSnapshot.defaultHoleCount,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher())
    {
        self.id = id
        self.startedAt = startedAt
        self.courseName = courseName
        self.holeCount = holeCount
        self.publisher = publisher
        holeScores = [0]
        holePars = [0]
        puttCounts = [0]
        currentHoleIndex = 0
    }
```

복구 init에서 `startedAt = snapshot.startedAt` 윗줄에 추가:

```swift
        id = snapshot.id
        holeCount = snapshot.holeCount
```

`snapshot` 계산 프로퍼티를 교체:

```swift
    var snapshot: RoundSnapshot {
        RoundSnapshot(id: id,
                      startedAt: startedAt,
                      courseName: courseName,
                      holeCount: holeCount,
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: puttCounts)
    }
```

- [ ] **Step 5: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: watchosTests **51건** PASS (49 + 2). 나머지 8개 `RoundSnapshot(` 호출부는 기본값 덕분에 수정 없이 컴파일된다.

- [ ] **Step 6: 커밋**

```bash
git add Shared/Models/RoundSnapshot.swift WatchApp/Features/Round/RoundViewModel.swift watchosTests/Shared/RoundSnapshotTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: RoundSnapshot에 라운드 id와 선택 홀 수 추가

전송 시 iOS 중복 검사에 쓸 id를 라운드 시작 시 만들어 스냅샷에 싣고,
복구를 넘어 유지되게 한다. 홀 수 상한도 함께 저장해 복구 시 선택 화면을 건너뛴다.
두 키가 없는 구버전 스냅샷도 기본값으로 디코딩된다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: 미기록 홀 트림 (TDD)

전송 직전 배열 말단의 `par == 0` 홀을 제거하는 순수 함수. 유령 홀("다음"을 한 번 더)과 조기 종료(18홀 골라 3홀만) 두 케이스를 한 규칙으로 처리한다.

**Files:**
- Modify: `Shared/Models/RoundSnapshot.swift`
- Test: `watchosTests/Shared/RoundSnapshotTrimTests.swift`

**Interfaces:**
- Consumes: Task 1의 `RoundSnapshot` (id·holeCount 포함)
- Produces: `RoundSnapshot.trimmingUnrecordedTrailingHoles() -> RoundSnapshot`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Shared/RoundSnapshotTrimTests.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct RoundSnapshotTrimTests {
    private func makeSnapshot(currentHoleIndex: Int,
                              holeScores: [Int],
                              holePars: [Int],
                              puttCounts: [Int]) -> RoundSnapshot
    {
        RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                      holeCount: 18,
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: puttCounts)
    }

    @Test func 트림_말단의_미기록홀을_제거한다() {
        // 3홀까지 치고 "다음"을 눌러 만들어진 4번째 유령 홀
        let snapshot = makeSnapshot(currentHoleIndex: 3,
                                    holeScores: [4, 5, 3, 0],
                                    holePars: [4, 4, 3, 0],
                                    puttCounts: [2, 2, 1, 0])

        let trimmed = snapshot.trimmingUnrecordedTrailingHoles()

        #expect(trimmed.holeScores == [4, 5, 3])
        #expect(trimmed.holePars == [4, 4, 3])
        #expect(trimmed.puttCounts == [2, 2, 1])
    }

    @Test func 트림_말단의_미기록홀이_여러개면_모두_제거한다() {
        // 18홀을 골라 3홀만 치고 중단한 경우를 축약한 형태
        let snapshot = makeSnapshot(currentHoleIndex: 5,
                                    holeScores: [4, 5, 3, 0, 0, 0],
                                    holePars: [4, 4, 3, 0, 0, 0],
                                    puttCounts: [2, 2, 1, 0, 0, 0])

        let trimmed = snapshot.trimmingUnrecordedTrailingHoles()

        #expect(trimmed.holeScores.count == 3)
        #expect(trimmed.holePars.count == 3)
        #expect(trimmed.puttCounts.count == 3)
    }

    @Test func 트림_중간의_미기록홀은_남긴다() {
        // 2번 홀을 건너뛴 것은 사용자 의도일 수 있으므로 건드리지 않는다
        let snapshot = makeSnapshot(currentHoleIndex: 2,
                                    holeScores: [4, 0, 3],
                                    holePars: [4, 0, 3],
                                    puttCounts: [2, 0, 1])

        let trimmed = snapshot.trimmingUnrecordedTrailingHoles()

        #expect(trimmed.holePars == [4, 0, 3])
    }

    @Test func 트림_모든홀이_기록되어_있으면_그대로다() {
        let snapshot = makeSnapshot(currentHoleIndex: 2,
                                    holeScores: [4, 5, 3],
                                    holePars: [4, 4, 3],
                                    puttCounts: [2, 2, 1])

        #expect(snapshot.trimmingUnrecordedTrailingHoles() == snapshot)
    }

    @Test func 트림_현재홀인덱스를_남은홀_범위로_줄인다() {
        let snapshot = makeSnapshot(currentHoleIndex: 3,
                                    holeScores: [4, 5, 3, 0],
                                    holePars: [4, 4, 3, 0],
                                    puttCounts: [2, 2, 1, 0])

        let trimmed = snapshot.trimmingUnrecordedTrailingHoles()

        #expect(trimmed.currentHoleIndex == 2)
    }

    @Test func 트림_기록된홀이_하나도_없으면_배열이_비고_인덱스는_0이다() {
        // 라운드 시작 직후 바로 종료한 경우
        let snapshot = makeSnapshot(currentHoleIndex: 0,
                                    holeScores: [0],
                                    holePars: [0],
                                    puttCounts: [0])

        let trimmed = snapshot.trimmingUnrecordedTrailingHoles()

        #expect(trimmed.holeScores.isEmpty)
        #expect(trimmed.currentHoleIndex == 0)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -30
```

Expected: 컴파일 실패 — `value of type 'RoundSnapshot' has no member 'trimmingUnrecordedTrailingHoles'`

- [ ] **Step 3: 트림 구현**

`Shared/Models/RoundSnapshot.swift`의 `relativeToPar` 아래(구조체 닫는 `}` 직전)에 추가:

```swift
    /// 말단의 "파를 고르지 않은" 홀을 전부 잘라낸 사본을 돌려준다 (spec §3 미기록 홀 트림).
    ///
    /// `par == 0`인 홀은 파 선택 화면이 떠 있어 카운터 화면에 접근할 수 없으므로
    /// `score`·`putts`도 반드시 0이다 — 따라서 이 트림은 무손실이다.
    /// 중간에 끼어 있는 `par == 0` 홀은 사용자가 의도적으로 건너뛴 것일 수 있어 건드리지 않는다.
    func trimmingUnrecordedTrailingHoles() -> RoundSnapshot {
        var trimmed = self
        while trimmed.holePars.last == 0,
              !trimmed.holeScores.isEmpty,
              !trimmed.puttCounts.isEmpty
        {
            trimmed.holeScores.removeLast()
            trimmed.holePars.removeLast()
            trimmed.puttCounts.removeLast()
        }
        trimmed.currentHoleIndex = min(currentHoleIndex, max(trimmed.holeScores.count - 1, 0))
        return trimmed
    }
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: watchosTests **57건** PASS (51 + 6)

- [ ] **Step 5: 커밋**

```bash
git add Shared/Models/RoundSnapshot.swift watchosTests/Shared/RoundSnapshotTrimTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: 말단 미기록 홀 트림 추가

전송 직전 배열 끝에서부터 par가 0인 홀을 제거한다. par가 0이면
파 선택 화면이 떠 카운터에 접근할 수 없어 타수·퍼팅도 반드시 0이므로 무손실이다.
"다음"을 한 번 더 눌러 생긴 유령 홀과 조기 종료로 남은 빈 홀을 한 규칙으로 처리한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 홀 수 상한 — 마지막 홀에서 "다음" 차단 (TDD)

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`
- Modify: `WatchApp/Features/Round/Counter/Components/HoleNavigation.swift`
- Modify: `WatchApp/Features/Round/Counter/CounterView.swift`
- Test: `watchosTests/Round/RoundViewModelHoleCapTests.swift`

**Interfaces:**
- Consumes: Task 1의 `RoundViewModel.holeCount`
- Produces: `RoundViewModel.canGoToNextHole: Bool`, `HoleNavigation(canGoToPrevious:canGoToNext:onPrevious:onNext:)`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Round/RoundViewModelHoleCapTests.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelHoleCapTests {
    private func makeViewModel(holeCount: Int) -> RoundViewModel {
        RoundViewModel(startedAt: Date(timeIntervalSince1970: 1000),
                       holeCount: holeCount,
                       publisher: RoundSnapshotPublisherSpy())
    }

    /// 홀을 끝까지 진행시킨다. 각 홀에 파를 골라야 다음 홀로 넘어갈 수 있는 흐름을 흉내낸다.
    /// `canGoToNextHole`도 조건에 넣어, 상한에 막히면 무한 루프 대신 그 자리에서 멈추게 한다.
    private func advance(_ viewModel: RoundViewModel, toHoleNumber holeNumber: Int) {
        while viewModel.currentHoleNumber < holeNumber, viewModel.canGoToNextHole {
            viewModel.selectPar(4)
            viewModel.goToNextHole()
        }
    }

    @Test func 홀수상한_9홀이면_9번홀에서_다음이_막힌다() {
        let viewModel = makeViewModel(holeCount: 9)
        advance(viewModel, toHoleNumber: 9)

        #expect(viewModel.currentHoleNumber == 9)
        #expect(!viewModel.canGoToNextHole)
    }

    @Test func 홀수상한_9홀이면_8번홀까지는_다음이_열려있다() {
        let viewModel = makeViewModel(holeCount: 9)
        advance(viewModel, toHoleNumber: 8)

        #expect(viewModel.canGoToNextHole)
    }

    @Test func 홀수상한_마지막홀에서_다음을_눌러도_홀이_늘지_않는다() {
        let viewModel = makeViewModel(holeCount: 9)
        advance(viewModel, toHoleNumber: 9)

        viewModel.goToNextHole()

        #expect(viewModel.currentHoleNumber == 9)
        #expect(viewModel.snapshot.holeScores.count == 9)
    }

    @Test func 홀수상한_18홀이면_18번홀에서_막힌다() {
        let viewModel = makeViewModel(holeCount: 18)
        advance(viewModel, toHoleNumber: 18)

        #expect(!viewModel.canGoToNextHole)
    }

    @Test func 홀수상한_복구시_스냅샷의_홀수를_따른다() {
        let snapshot = RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                                     holeCount: 9,
                                     currentHoleIndex: 8,
                                     holeScores: [4, 5, 3, 4, 4, 5, 3, 4, 4],
                                     holePars: [4, 4, 3, 4, 4, 5, 3, 4, 4],
                                     puttCounts: [2, 2, 1, 2, 2, 2, 1, 2, 2])

        let viewModel = RoundViewModel(resuming: snapshot, publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.holeCount == 9)
        #expect(!viewModel.canGoToNextHole)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -30
```

Expected: 컴파일 실패 — `value of type 'RoundViewModel' has no member 'canGoToNextHole'`

- [ ] **Step 3: `RoundViewModel`에 상한 추가**

`canGoToPreviousHole` 아래에 추가:

```swift
    /// 마지막 홀에서는 다음으로 넘어갈 수 없다 — 상한을 넘는 빈 홀이 애초에 생기지 않게 한다 (spec §3).
    var canGoToNextHole: Bool {
        currentHoleIndex + 1 < holeCount
    }
```

`goToNextHole()`에 가드 추가:

```swift
    func goToNextHole() {
        guard canGoToNextHole else { return }
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
        resetHoleLocalState()
        publishSnapshot()
    }
```

- [ ] **Step 4: `HoleNavigation`이 상한을 반영하게 수정**

`WatchApp/Features/Round/Counter/Components/HoleNavigation.swift` 전체를 교체:

```swift
import SwiftUI

struct HoleNavigation: View {
    let canGoToPrevious: Bool
    let canGoToNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            navButton(title: "이전", systemName: "chevron.left", action: onPrevious)
                .disabled(!canGoToPrevious)
                .opacity(canGoToPrevious ? 1 : 0.35)
            navButton(title: "다음", systemName: "chevron.right", action: onNext)
                .disabled(!canGoToNext)
                .opacity(canGoToNext ? 1 : 0.35)
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

- [ ] **Step 5: `CounterView` 호출부 수정**

`WatchApp/Features/Round/Counter/CounterView.swift`의 `HoleNavigation(...)` 호출을 교체:

```swift
                HoleNavigation(canGoToPrevious: viewModel.canGoToPreviousHole,
                               canGoToNext: viewModel.canGoToNextHole,
                               onPrevious: viewModel.goToPreviousHole,
                               onNext: viewModel.goToNextHole)
```

- [ ] **Step 6: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: watchosTests **62건** PASS (57 + 5)

- [ ] **Step 7: 커밋**

```bash
git add WatchApp/Features/Round/RoundViewModel.swift \
  WatchApp/Features/Round/Counter/Components/HoleNavigation.swift \
  WatchApp/Features/Round/Counter/CounterView.swift \
  watchosTests/Round/RoundViewModelHoleCapTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: 홀 수 상한 적용 — 마지막 홀에서 다음 이동 차단

선택한 홀 수를 상한으로 삼아 마지막 홀에서 "다음" 버튼을 비활성화하고
goToNextHole()도 가드한다. 상한을 넘는 빈 홀이 애초에 생기지 않는다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: 전송 메시지·발신 서비스 + pbxproj 타깃 예외 (TDD)

**"타깃 링크 제약" 절을 먼저 읽을 것.** 이 Task가 `Shared/`에 `import ConnectivityCore`를 처음 들여오므로 pbxproj 수정이 함께 필요하다.

**Files:**
- Create: `Shared/Models/RoundMetrics.swift`
- Create: `Shared/Services/ConnectivityMessages.swift`
- Create: `Shared/Services/RoundTransmitter.swift`
- Create: `WatchApp/Features/Round/RoundMetrics+WorkoutResult.swift`
- Modify: `GolfCounter.xcodeproj/project.pbxproj`
- Test: `watchosTests/Shared/ConnectivityMessagesTests.swift`

**Interfaces:**
- Consumes: Task 1·2의 `RoundSnapshot`(`id`, `trimmingUnrecordedTrailingHoles()`)
- Produces: `RoundMetrics(calories:avgHeartRate:distanceMeters:steps:)` (전부 기본값 0), `RoundMetrics.init(_ result: WorkoutResult?)` (워치 전용)
- Produces: `RoundCompletedMessage(snapshot:endedAt:metrics:)`, `RoundCompletedMessage.messageType == "roundCompleted"`
- Produces: `protocol RoundTransmitting { func send(_ message: RoundCompletedMessage) }`, `RoundTransmitter.shared`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/Shared/ConnectivityMessagesTests.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct ConnectivityMessagesTests {
    private static let fixedID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let endedAt = Date(timeIntervalSince1970: 5000)

    private func makeSnapshot(courseName: String? = "테스트CC") -> RoundSnapshot {
        RoundSnapshot(id: Self.fixedID,
                      startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: courseName,
                      holeCount: 9,
                      currentHoleIndex: 2,
                      holeScores: [4, 5, 3],
                      holePars: [4, 4, 3],
                      puttCounts: [2, 2, 1])
    }

    private let metrics = RoundMetrics(calories: 210.5,
                                       avgHeartRate: 98.25,
                                       distanceMeters: 4200.75,
                                       steps: 6300)

    @Test func 스냅샷으로_만든_메시지가_필드를_그대로_옮긴다() {
        let message = RoundCompletedMessage(snapshot: makeSnapshot(), endedAt: endedAt, metrics: metrics)

        #expect(message.id == Self.fixedID)
        #expect(message.startedAt == Date(timeIntervalSince1970: 1000))
        #expect(message.endedAt == endedAt)
        #expect(message.courseName == "테스트CC")
        #expect(message.holeScores == [4, 5, 3])
        #expect(message.holePars == [4, 4, 3])
        #expect(message.puttCounts == [2, 2, 1])
        #expect(message.metrics == metrics)
    }

    @Test func 딕셔너리_왕복시_동일하다() throws {
        let message = RoundCompletedMessage(snapshot: makeSnapshot(), endedAt: endedAt, metrics: metrics)

        let restored = try #require(RoundCompletedMessage(from: message.toDictionary()))

        #expect(restored == message)
    }

    @Test func 골프장명이_nil이면_키가_빠지고_복원도_nil이다() throws {
        let message = RoundCompletedMessage(snapshot: makeSnapshot(courseName: nil), endedAt: endedAt, metrics: metrics)
        let dict = message.toDictionary()

        #expect(dict["courseName"] == nil)
        #expect(try #require(RoundCompletedMessage(from: dict)).courseName == nil)
    }

    @Test func 타입키가_다르면_복원에_실패한다() {
        var dict = RoundCompletedMessage(snapshot: makeSnapshot(), endedAt: endedAt, metrics: metrics).toDictionary()
        dict["type"] = "somethingElse"

        #expect(RoundCompletedMessage(from: dict) == nil)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -30
```

Expected: 컴파일 실패 — `cannot find 'RoundCompletedMessage' in scope`, `cannot find 'RoundMetrics' in scope`

- [ ] **Step 3: `RoundMetrics` 작성**

`Shared/Models/RoundMetrics.swift` 신규 생성:

```swift
import Foundation

/// 라운드의 워크아웃 메트릭. `GolfRound`의 대응 필드와 1:1이다.
///
/// WorkoutCore의 `WorkoutResult`를 그대로 쓰지 않는 이유: 이 타입은 `Shared/`에 있어
/// iOS 타깃에도 컴파일되는데, WorkoutCore는 워치 타깃에만 링크되어 있다.
/// `WorkoutResult` → `RoundMetrics` 변환은 워치 전용 코드에 둔다.
struct RoundMetrics: Equatable {
    var calories: Double
    var avgHeartRate: Double
    var distanceMeters: Double
    var steps: Int

    init(calories: Double = 0,
         avgHeartRate: Double = 0,
         distanceMeters: Double = 0,
         steps: Int = 0)
    {
        self.calories = calories
        self.avgHeartRate = avgHeartRate
        self.distanceMeters = distanceMeters
        self.steps = steps
    }
}
```

- [ ] **Step 4: `RoundCompletedMessage` 작성**

`Shared/Services/ConnectivityMessages.swift` 신규 생성:

```swift
import ConnectivityCore
import Foundation

/// 라운드 종료 시 워치 → iOS 단방향 전송 페이로드 (spec §5).
/// 필드는 `GolfRound`와 1:1이다 — iOS 수신부(plan ⑤)가 이 값들로 `GolfRound`를 만든다.
///
/// `WorkoutResult`의 `durationSeconds`·`totalCaloriesBurned`는 `GolfRound`에 대응 필드가 없어 싣지 않는다
/// (소요 시간은 `endedAt - startedAt`으로 파생된다).
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

    /// 전송 대상은 **트림된** 스냅샷이어야 한다 (호출부 책임 — spec §3).
    init(snapshot: RoundSnapshot, endedAt: Date, metrics: RoundMetrics) {
        id = snapshot.id
        startedAt = snapshot.startedAt
        self.endedAt = endedAt
        courseName = snapshot.courseName
        holeScores = snapshot.holeScores
        holePars = snapshot.holePars
        puttCounts = snapshot.puttCounts
        self.metrics = metrics
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": Self.messageType,
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
        if let courseName { dict["courseName"] = courseName }
        return dict
    }

    init?(from dictionary: [String: Any]) {
        guard dictionary["type"] as? String == Self.messageType,
              let idString = dictionary["id"] as? String,
              let id = UUID(uuidString: idString),
              let startedTimestamp = dictionary["startedAt"] as? Double,
              let endedTimestamp = dictionary["endedAt"] as? Double else { return nil }
        self.id = id
        startedAt = Date(timeIntervalSince1970: startedTimestamp)
        endedAt = Date(timeIntervalSince1970: endedTimestamp)
        courseName = dictionary["courseName"] as? String
        holeScores = dictionary["holeScores"] as? [Int] ?? []
        holePars = dictionary["holePars"] as? [Int] ?? []
        puttCounts = dictionary["puttCounts"] as? [Int] ?? []
        metrics = RoundMetrics(calories: dictionary["calories"] as? Double ?? 0,
                               avgHeartRate: dictionary["avgHeartRate"] as? Double ?? 0,
                               distanceMeters: dictionary["distanceMeters"] as? Double ?? 0,
                               steps: dictionary["steps"] as? Int ?? 0)
    }
}
```

- [ ] **Step 5: 발신 서비스 작성**

`Shared/Services/RoundTransmitter.swift` 신규 생성:

```swift
import ConnectivityCore
import Foundation

/// 완료 라운드 발신 표면. ViewModel은 이 프로토콜에만 의존해
/// 테스트에서 WatchConnectivity 없이 전송 호출을 검증한다 (plan ③의 `RoundSnapshotPublishing`과 같은 방식).
@MainActor
protocol RoundTransmitting {
    func send(_ message: RoundCompletedMessage)
}

/// `ConnectivityService`를 감싼 유일한 구현체.
/// WCSession은 프로세스당 하나이므로 싱글턴으로 두고, 라운드마다 새로 만들지 않는다.
@MainActor
final class RoundTransmitter: RoundTransmitting {
    static let shared = RoundTransmitter()

    /// `lazy`인 이유: `RoundViewModel`의 기본 인자가 `.shared`라, 스파이를 주입하지 않는
    /// 기존 ViewModel 테스트들도 이 싱글턴을 건드리게 된다. 즉시 초기화하면 그때마다
    /// 테스트 프로세스에서 실제 `WCSession`이 활성화된다 — 실제로 보낼 때까지 미룬다.
    /// (워치는 발신 전용이라 미리 살아 있을 이유가 없다. iOS 수신부는 콜드런치 컨텍스트를
    /// 놓치지 않으려면 즉시 등록해야 하므로, plan ⑤에서 별도 타입으로 만든다.)
    private lazy var service = ConnectivityService()

    private init() {}

    /// `.reliable` — 미도달 시 transferUserInfo 큐가 도달 시점까지 배달을 보장하므로
    /// 워치 쪽 재시도 로직은 만들지 않는다 (spec §5).
    func send(_ message: RoundCompletedMessage) {
        service.send(message, via: .reliable)
    }
}
```

- [ ] **Step 6: `WorkoutResult` → `RoundMetrics` 변환 (워치 전용)**

`WatchApp/Features/Round/RoundMetrics+WorkoutResult.swift` 신규 생성:

```swift
import Foundation
import WorkoutCore

/// WorkoutCore 의존을 워치 타깃 안에 가둔다 — `RoundMetrics` 자체는 iOS·컴플리케이션에도 컴파일되므로
/// 이 변환을 `Shared/`에 두면 iOS 빌드가 깨진다 (WorkoutCore는 워치에만 링크되어 있다).
extension RoundMetrics {
    /// `stopWorkout()`이 nil을 주면(세션이 없었던 경우) 전부 0인 메트릭이 된다.
    init(_ result: WorkoutResult?) {
        guard let result else {
            self.init()
            return
        }
        self.init(calories: result.caloriesBurned,
                  avgHeartRate: result.averageHeartRate ?? 0,
                  distanceMeters: result.distanceMeters,
                  steps: result.steps)
    }
}
```

- [ ] **Step 7: pbxproj에 컴플리케이션 타깃 예외 추가**

`GolfCounter.xcodeproj/project.pbxproj`를 두 군데 수정한다.

**(a)** `/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */` 블록 안, 기존 `3974B9042EBCDFA6002D0EA7` 항목 **바로 뒤**에 새 항목을 추가한다 (들여쓰기는 탭 2개):

```
		39C7D1A030200001000000A1 /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				"Services/ConnectivityMessages.swift",
				"Services/RoundTransmitter.swift",
			);
			target = 3974B8F32EBCDFA5002D0EA7 /* ComplicationAppExtension */;
		};
```

**(b)** `Shared` 동기화 그룹 정의(한 줄짜리)에 `exceptions`를 끼워 넣는다. 아래 줄을

```
		39928A012EB95F0D005F1856 /* Shared */ = {isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {}; explicitFolders = (); path = Shared; sourceTree = "<group>"; };
```

이렇게 바꾼다:

```
		39928A012EB95F0D005F1856 /* Shared */ = {isa = PBXFileSystemSynchronizedRootGroup; exceptions = (39C7D1A030200001000000A1 /* PBXFileSystemSynchronizedBuildFileExceptionSet */, ); explicitFileTypes = {}; explicitFolders = (); path = Shared; sourceTree = "<group>"; };
```

> `39C7D1A030200001000000A1`은 파일 안에서 유일하기만 하면 되는 24자리 hex ID다. 충돌하면(`grep -c` 로 확인) 다른 값을 쓴다.
> `membershipExceptions`의 경로는 `Shared/` 그룹 루트 기준 상대 경로다 (기존 `ComplicationApp` 그룹의 `Info.plist`와 같은 규칙).

- [ ] **Step 8: 세 타깃이 모두 빌드되는지 확인 (이 Task의 핵심 검증)**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: 둘 다 `** BUILD SUCCEEDED **`

컴플리케이션이 `No such module 'ConnectivityCore'`로 깨지면 Step 7(a)/(b)가 제대로 반영되지 않은 것이고, iOS가 `No such module 'WorkoutCore'`로 깨지면 `RoundMetrics+WorkoutResult.swift`가 `Shared/`에 잘못 놓인 것이다.

- [ ] **Step 9: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: watchosTests **66건** PASS (62 + 4)

- [ ] **Step 10: 커밋**

```bash
git add Shared/Models/RoundMetrics.swift Shared/Services/ConnectivityMessages.swift \
  Shared/Services/RoundTransmitter.swift WatchApp/Features/Round/RoundMetrics+WorkoutResult.swift \
  GolfCounter.xcodeproj/project.pbxproj watchosTests/Shared/ConnectivityMessagesTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: RoundCompletedMessage와 발신 서비스 추가

GolfRound와 1:1인 전송 페이로드를 정의하고 .reliable 발신을 프로토콜 뒤에 둔다.
Shared/는 세 타깃에 모두 동기화되는데 ConnectivityCore는 컴플리케이션에 링크되어
있지 않으므로, 두 파일을 그 타깃에서 제외하는 예외를 pbxproj에 추가했다.
WorkoutCore 의존은 iOS 빌드가 깨지지 않도록 워치 타깃 안에 가둔다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `RoundViewModel` — 종료·요약·전송 (TDD)

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`
- Create: `watchosTests/Support/RoundTransmitterSpy.swift`
- Test: `watchosTests/Round/RoundViewModelFinishTests.swift`

**Interfaces:**
- Consumes: Task 2의 `trimmingUnrecordedTrailingHoles()`, Task 4의 `RoundCompletedMessage`·`RoundMetrics`·`RoundTransmitting`
- Produces: `RoundViewModel.Phase.summary`, `finishRound()`, `save(endedAt:metrics:)`, `trimmedSnapshot`, `recordedHoleCount`, `recordedTotalStrokes`, `recordedTotalPutts`
- Produces: `RoundTransmitterSpy.sent: [RoundCompletedMessage]`
- **제거**: 기존 `finish()` — 스냅샷을 즉시 지우던 plan ③의 중간 구현. `finishRound()`가 대체하며 스냅샷은 `save()`에서만 지운다

- [ ] **Step 1: 테스트 더블 작성**

`watchosTests/Support/RoundTransmitterSpy.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter_Watch_App

/// 전송 호출을 기록만 하는 테스트 더블. WatchConnectivity를 건드리지 않는다.
@MainActor
final class RoundTransmitterSpy: RoundTransmitting {
    private(set) var sent: [RoundCompletedMessage] = []

    func send(_ message: RoundCompletedMessage) {
        sent.append(message)
    }
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`watchosTests/Round/RoundViewModelFinishTests.swift` 신규 생성:

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelFinishTests {
    private let startedAt = Date(timeIntervalSince1970: 1000)
    private let endedAt = Date(timeIntervalSince1970: 5000)
    private let metrics = RoundMetrics(calories: 210, avgHeartRate: 98, distanceMeters: 4200, steps: 6300)

    private func makeViewModel(publisher: RoundSnapshotPublisherSpy,
                               transmitter: RoundTransmitterSpy) -> RoundViewModel
    {
        RoundViewModel(startedAt: startedAt,
                       holeCount: 18,
                       publisher: publisher,
                       transmitter: transmitter)
    }

    /// 3홀을 기록한 뒤 "다음"을 한 번 더 눌러 말단에 유령 홀이 생긴 상태를 만든다.
    private func playThreeHolesThenAdvance(_ viewModel: RoundViewModel) {
        for _ in 0 ..< 3 {
            viewModel.selectPar(4)
            viewModel.incrementStroke()
            viewModel.goToNextHole()
        }
    }

    @Test func 종료하면_요약단계가_된다() {
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: RoundTransmitterSpy())
        viewModel.selectPar(4)

        viewModel.finishRound()

        #expect(viewModel.phase == .summary)
    }

    @Test func 종료만으로는_스냅샷을_지우지_않는다() {
        let publisher = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: RoundTransmitterSpy())
        viewModel.selectPar(4)

        viewModel.finishRound()

        #expect(publisher.clearCallCount == 0)
    }

    @Test func 저장하면_트림된_라운드를_전송한다() {
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: transmitter)
        playThreeHolesThenAdvance(viewModel)
        viewModel.finishRound()

        viewModel.save(endedAt: endedAt, metrics: metrics)

        #expect(transmitter.sent.count == 1)
        // 유령 홀이 빠져 3홀만 전송된다
        #expect(transmitter.sent.last?.holeScores == [1, 1, 1])
        #expect(transmitter.sent.last?.holePars == [4, 4, 4])
        #expect(transmitter.sent.last?.endedAt == endedAt)
        #expect(transmitter.sent.last?.metrics == metrics)
    }

    @Test func 저장하면_스냅샷을_지운다() {
        let publisher = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: RoundTransmitterSpy())
        playThreeHolesThenAdvance(viewModel)
        viewModel.finishRound()

        viewModel.save(endedAt: endedAt, metrics: metrics)

        #expect(publisher.clearCallCount == 1)
    }

    @Test func 기록된홀이_없으면_전송하지_않고_스냅샷만_지운다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        viewModel.finishRound() // 파를 한 번도 고르지 않은 채 종료

        viewModel.save(endedAt: endedAt, metrics: metrics)

        #expect(transmitter.sent.isEmpty)
        #expect(publisher.clearCallCount == 1)
    }

    @Test func 복구한_라운드는_원래_id로_전송된다() {
        let originalID = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        let snapshot = RoundSnapshot(id: originalID,
                                     startedAt: startedAt,
                                     holeCount: 9,
                                     currentHoleIndex: 1,
                                     holeScores: [4, 5],
                                     holePars: [4, 4],
                                     puttCounts: [2, 2])
        let transmitter = RoundTransmitterSpy()
        let viewModel = RoundViewModel(resuming: snapshot,
                                       publisher: RoundSnapshotPublisherSpy(),
                                       transmitter: transmitter)
        viewModel.finishRound()

        viewModel.save(endedAt: endedAt, metrics: metrics)

        #expect(transmitter.sent.last?.id == originalID)
    }

    @Test func 요약단계에서는_파선택_조건보다_요약이_우선한다() {
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: RoundTransmitterSpy())
        // 파를 고르지 않아 평소라면 .parSelection인 상태

        viewModel.finishRound()

        #expect(viewModel.phase == .summary)
    }

    @Test func 요약_표시값은_트림된_라운드_기준이다() {
        let viewModel = makeViewModel(publisher: RoundSnapshotPublisherSpy(), transmitter: RoundTransmitterSpy())
        playThreeHolesThenAdvance(viewModel)

        viewModel.finishRound()

        #expect(viewModel.recordedHoleCount == 3)
        #expect(viewModel.recordedTotalStrokes == 3)
        #expect(viewModel.recordedTotalPutts == 0)
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -30
```

Expected: 컴파일 실패 — `extra argument 'transmitter' in call`, `value of type 'RoundViewModel' has no member 'finishRound'`

- [ ] **Step 4: `RoundViewModel` 수정**

`Phase`에 `summary`를 추가:

```swift
    enum Phase: Equatable {
        case parSelection
        case counting
        case summary
    }
```

`@Published private(set) var isEditingPar = false` 아래에 추가:

```swift
    /// 종료 확인을 마쳤는지. true가 되면 화면이 요약으로 바뀐다.
    @Published private(set) var isFinished = false
```

`private let publisher: RoundSnapshotPublishing` 아래에 추가:

```swift
    private let transmitter: RoundTransmitting
```

두 init의 시그니처와 본문에 `transmitter`를 추가한다. 지정 init:

```swift
    init(id: UUID = UUID(),
         startedAt: Date = Date(),
         courseName: String? = nil,
         holeCount: Int = RoundSnapshot.defaultHoleCount,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher(),
         transmitter: RoundTransmitting = RoundTransmitter.shared)
    {
        self.id = id
        self.startedAt = startedAt
        self.courseName = courseName
        self.holeCount = holeCount
        self.publisher = publisher
        self.transmitter = transmitter
        holeScores = [0]
        holePars = [0]
        puttCounts = [0]
        currentHoleIndex = 0
    }
```

복구 init:

```swift
    init(resuming snapshot: RoundSnapshot,
         publisher: RoundSnapshotPublishing = RoundSnapshotPublisher(),
         transmitter: RoundTransmitting = RoundTransmitter.shared)
    {
        id = snapshot.id
        holeCount = snapshot.holeCount
        startedAt = snapshot.startedAt
        courseName = snapshot.courseName
        self.publisher = publisher
        self.transmitter = transmitter
        holeScores = snapshot.holeScores
        holePars = snapshot.holePars
        puttCounts = snapshot.puttCounts
        currentHoleIndex = max(snapshot.currentHoleIndex, 0)
        ensureCapacityForCurrentHole()
    }
```

`phase`를 교체:

```swift
    /// 화면 분기 조건은 "홀 이동 방향"이 아니라 "이 홀에 파가 있는가" 하나다 (spec §4).
    /// 단 종료 후에는 무엇보다 요약이 우선한다.
    var phase: Phase {
        if isFinished { return .summary }
        if isEditingPar { return .parSelection }
        return currentPar == 0 ? .parSelection : .counting
    }
```

기존 `finish()`를 아래 블록으로 **교체**한다 (`// MARK: - 라이프사이클` 절 안, `start()` 아래):

```swift
    /// 종료 확인을 마쳤을 때 호출. 화면만 요약으로 바꾼다.
    /// 스냅샷은 지우지 않는다 — 전송 없이 요약을 벗어나도 다음 실행 시 라운드가 복구되어야 한다 (spec §4).
    func finishRound() {
        isFinished = true
    }

    /// 요약 화면의 "저장 & 전송". 트림된 라운드를 발신하고 스냅샷을 지운다.
    /// 기록된 홀이 하나도 없으면 보낼 것이 없으므로 스냅샷만 지운다 — iOS에 빈 라운드를 만들지 않는다.
    func save(endedAt: Date, metrics: RoundMetrics) {
        let trimmed = trimmedSnapshot
        if !trimmed.holeScores.isEmpty {
            transmitter.send(RoundCompletedMessage(snapshot: trimmed, endedAt: endedAt, metrics: metrics))
        }
        publisher.clear()
    }
```

`snapshot` 계산 프로퍼티 아래에 요약용 파생값을 추가:

```swift
    /// 전송·요약 표시의 기준. 말단 미기록 홀이 잘린 스냅샷이다 (spec §3).
    var trimmedSnapshot: RoundSnapshot {
        snapshot.trimmingUnrecordedTrailingHoles()
    }

    /// 종료 확인 문구와 요약 화면이 쓰는 "실제로 기록될 홀 수".
    var recordedHoleCount: Int {
        trimmedSnapshot.holeScores.count
    }

    var recordedTotalStrokes: Int {
        trimmedSnapshot.totalStrokes
    }

    var recordedTotalPutts: Int {
        trimmedSnapshot.totalPutts
    }
```

- [ ] **Step 5: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -30
```

Expected: 컴파일 실패 — `RoundSessionView.swift`가 없어진 `viewModel.finish()`를 호출한다. Task 7에서 고치므로, **지금은 그 한 줄만 임시로 `viewModel.finishRound()`로 바꿔** 컴파일을 통과시킨다 (전체 종료 흐름은 Task 7에서 완성).

`WatchApp/Features/Round/RoundSessionView.swift`의 `endRound()` 안:

```swift
        viewModel.finishRound()
```

다시 실행:

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: watchosTests **74건** PASS (66 + 8)

- [ ] **Step 6: 커밋**

```bash
git add WatchApp/Features/Round/RoundViewModel.swift WatchApp/Features/Round/RoundSessionView.swift \
  watchosTests/Support/RoundTransmitterSpy.swift watchosTests/Round/RoundViewModelFinishTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: 라운드 종료·요약·전송 로직 구현

finishRound()는 화면만 요약으로 바꾸고, save()가 트림된 라운드를 .reliable로
발신한 뒤 스냅샷을 지운다. 전송 없이 요약을 벗어나면 스냅샷이 남아 복구된다.
기록된 홀이 없으면 빈 라운드를 만들지 않고 스냅샷만 정리한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 홀 수 선택 화면 + 홈 라우팅

**Files:**
- Create: `WatchApp/Features/Home/HoleCountSelection/HoleCountSelectionView.swift`
- Modify: `WatchApp/Features/Home/HomeView.swift`
- Modify: `WatchApp/Features/Round/RoundSessionView.swift`

**Interfaces:**
- Consumes: Task 1의 `RoundViewModel(holeCount:)`
- Produces: `HoleCountSelectionView(onSelect: (Int) -> Void)`
- Produces: `RoundSessionView(holeCount:onExit:)`, `RoundSessionView(resuming:onExit:)` — `@Environment(\.dismiss)` 대신 `onExit` 클로저를 쓴다

> **왜 `dismiss()`를 버리는가:** 홈 → 홀 수 선택 → 라운드로 스택이 2단이 되면서 `dismiss()`는 홈이 아니라 **홀 수 선택 화면으로** 돌아가 버린다. 라운드가 끝나면 스택 전체를 비워야 하므로 홈이 소유한 경로를 클로저로 넘긴다.

- [ ] **Step 1: 홀 수 선택 화면 작성**

`WatchApp/Features/Home/HoleCountSelection/HoleCountSelectionView.swift` 신규 생성:

```swift
import SwiftUI

/// 라운드 시작 직전 9/18홀을 고르는 화면 (spec §4).
/// 이 화면에서는 아직 라운드가 시작되지 않는다 — 스냅샷도 워크아웃도 만들지 않으므로
/// 뒤로 나가면 아무 흔적 없이 홈으로 돌아간다.
struct HoleCountSelectionView: View {
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("홀 수")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach([9, 18], id: \.self) { holeCount in
                Button {
                    onSelect(holeCount)
                } label: {
                    Text("\(holeCount)홀")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.plain)
                .background(Color.green.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    HoleCountSelectionView { _ in }
}
```

- [ ] **Step 2: `RoundSessionView`의 종료 경로를 클로저로 교체**

`WatchApp/Features/Round/RoundSessionView.swift`에서:

`@Environment(\.dismiss) private var dismiss` 줄을 **삭제**하고, `@StateObject private var healthKit ...` 아래에 추가:

```swift
    /// 라운드를 마치고 홈으로 돌아가는 경로. 홈이 내비게이션 스택 전체를 비운다.
    let onExit: () -> Void
```

init을 교체:

```swift
    /// 새 라운드. 홀 수는 선택 화면에서 받는다.
    init(holeCount: Int, onExit: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RoundViewModel(holeCount: holeCount))
        self.onExit = onExit
    }

    /// 진행 중 스냅샷으로 라운드를 이어서 시작한다 (홀 수도 스냅샷을 따른다).
    init(resuming snapshot: RoundSnapshot, onExit: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RoundViewModel(resuming: snapshot))
        self.onExit = onExit
    }
```

`endRound()`의 `dismiss()`를 `onExit()`으로 바꾼다 (이 메서드 전체는 Task 7에서 다시 손본다).

- [ ] **Step 3: `HomeView`를 경로 기반 내비게이션으로 교체**

`WatchApp/Features/Home/HomeView.swift` 전체를 교체:

```swift
import SwiftUI

struct HomeView: View {
    /// 홈에서 갈 수 있는 목적지. 라운드가 끝나면 이 배열을 통째로 비워 홈으로 돌아온다.
    private enum Route: Hashable {
        case holeCountSelection
        case round(holeCount: Int)
        case resume
    }

    @State private var path: [Route] = []
    @State private var resumingSnapshot: RoundSnapshot?
    /// 복구 시도는 앱 실행당 1회. onAppear마다 돌면 전송 없이 요약을 벗어났을 때
    /// 홈에 닿자마자 라운드로 다시 튕겨 들어가 빠져나올 수 없게 된다.
    @State private var didAttemptResume = false

    private let publisher = RoundSnapshotPublisher()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 14) {
                Spacer()

                Text("GolfCounter")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.green)

                Button {
                    path.append(.holeCountSelection)
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
            .navigationDestination(for: Route.self, destination: destination)
        }
        .onAppear(perform: resumeIfNeeded)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .holeCountSelection:
            HoleCountSelectionView { holeCount in
                path.append(.round(holeCount: holeCount))
            }
        case let .round(holeCount):
            RoundSessionView(holeCount: holeCount, onExit: exitToHome)
        case .resume:
            if let resumingSnapshot {
                RoundSessionView(resuming: resumingSnapshot, onExit: exitToHome)
            }
        }
    }

    private func exitToHome() {
        path.removeAll()
        resumingSnapshot = nil
    }

    /// 크래시·강제종료 후, 또는 전송 없이 앱이 종료된 뒤 실행되면 진행 중 스냅샷으로 라운드를 이어간다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 RoundSessionView가 새로 시작한다.
    private func resumeIfNeeded() {
        guard !didAttemptResume else { return }
        didAttemptResume = true
        guard let snapshot = publisher.loadCurrent() else { return }
        resumingSnapshot = snapshot
        path = [.resume]
    }
}

#Preview {
    HomeView()
}
```

- [ ] **Step 4: 빌드·테스트 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, watchosTests **74건** PASS (View는 테스트하지 않으므로 건수 변화 없음)

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/Home/ WatchApp/Features/Round/RoundSessionView.swift
git commit -m "$(cat <<'EOF'
✨ feat: 홀 수 선택 화면과 경로 기반 홈 내비게이션

라운드 시작 시 9/18홀을 고르게 하고, 홈이 내비게이션 경로를 소유해
라운드 종료 시 스택 전체를 비운다. dismiss()는 스택이 2단이 되면서
홈이 아니라 선택 화면으로 돌아가므로 onExit 클로저로 대체했다.
복구 시도는 앱 실행당 1회로 제한해 홈↔라운드 왕복 루프를 막는다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 종료 확인 다이얼로그 + 요약 화면 + 세션 화면 연결

**Files:**
- Create: `WatchApp/Features/Round/Summary/SummaryView.swift`
- Modify: `WatchApp/Features/Round/RoundSessionView.swift`

**Interfaces:**
- Consumes: Task 5의 `finishRound()`·`save(endedAt:metrics:)`·`recordedHoleCount`·`recordedTotalStrokes`·`recordedTotalPutts`, Task 4의 `RoundMetrics(_ result:)`
- Produces: `SummaryView(viewModel:isSaving:onSave:)`

- [ ] **Step 1: 요약 화면 작성**

`WatchApp/Features/Round/Summary/SummaryView.swift` 신규 생성:

```swift
import SwiftUI

/// 라운드 종료 요약 (spec §4). 총타수·총퍼트만 보여주는 최소 구성이며,
/// 워크아웃 메트릭은 화면에 띄우지 않고 전송 페이로드에만 싣는다.
struct SummaryView: View {
    @ObservedObject var viewModel: RoundViewModel
    let isSaving: Bool
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("라운드 종료")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let courseName = viewModel.courseName {
                    Text(courseName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text("\(viewModel.recordedTotalStrokes)타")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("\(viewModel.recordedTotalPutts)퍼트 · \(viewModel.recordedHoleCount)홀")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Button(action: onSave) {
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
                .background(Color.green.opacity(0.85), in: Capsule())
                .foregroundStyle(.white)
                .disabled(isSaving)
                .opacity(isSaving ? 0.6 : 1)
                .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
    }

    /// 기록된 홀이 없으면 보낼 것이 없으므로 "저장 없이 종료"가 된다 (spec §4).
    private var buttonTitle: String {
        if isSaving { return "전송 중…" }
        return viewModel.recordedHoleCount > 0 ? "저장 & 전송" : "저장 없이 종료"
    }
}
```

- [ ] **Step 2: `RoundSessionView`를 요약 흐름까지 연결**

`WatchApp/Features/Round/RoundSessionView.swift` 전체를 교체:

```swift
import SwiftUI
import WorkoutCore

struct RoundSessionView: View {
    @StateObject private var viewModel: RoundViewModel
    @StateObject private var healthKit = WorkoutSessionService(configuration: .golf)
    /// 라운드를 마치고 홈으로 돌아가는 경로. 홈이 내비게이션 스택 전체를 비운다.
    let onExit: () -> Void

    @State private var selectedTab = 1
    @State private var startTask: Task<Void, Never>?
    /// 종료 확인 후 시작되는 워크아웃 정리 작업. 메트릭 수집이 끝나면 값을 내놓는다.
    @State private var stopTask: Task<RoundMetrics, Never>?
    @State private var isConfirmingFinish = false
    @State private var isSaving = false
    /// beginFinish()가 정상적으로 워크아웃을 끝냈는지 표시한다.
    /// false인 채로 뷰가 사라지면(edge-swipe 등) onDisappear에서 방어적으로 정리한다.
    @State private var didFinish = false

    /// 새 라운드. 홀 수는 선택 화면에서 받는다.
    init(holeCount: Int, onExit: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RoundViewModel(holeCount: holeCount))
        self.onExit = onExit
    }

    /// 진행 중 스냅샷으로 라운드를 이어서 시작한다 (홀 수도 스냅샷을 따른다).
    init(resuming snapshot: RoundSnapshot, onExit: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RoundViewModel(resuming: snapshot))
        self.onExit = onExit
    }

    var body: some View {
        Group {
            if viewModel.phase == .summary {
                SummaryView(viewModel: viewModel, isSaving: isSaving, onSave: save)
            } else {
                sessionTabs
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear(perform: startRound)
        .onDisappear(perform: stopWorkoutIfNotFinished)
        .confirmationDialog("라운드 종료", isPresented: $isConfirmingFinish) {
            Button("종료", role: .destructive, action: beginFinish)
            Button("취소", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }

    /// 트림 후 실제로 몇 홀이 저장되는지 알려준다 — 말단의 미기록 홀은 빠진다 (spec §3).
    private var confirmationMessage: String {
        viewModel.recordedHoleCount > 0
            ? "\(viewModel.recordedHoleCount)홀까지 기록됩니다."
            : "기록된 홀이 없습니다."
    }

    private var sessionTabs: some View {
        TabView(selection: $selectedTab) {
            ControlsView(healthKit: healthKit, onEndRound: { isConfirmingFinish = true })
                .tag(0)
            centerPage
                .tag(1)
            MetricsView(healthKit: healthKit)
                .tag(2)
        }
        .tabViewStyle(.page)
    }

    @ViewBuilder
    private var centerPage: some View {
        switch viewModel.phase {
        case .parSelection:
            ParSelectionView(viewModel: viewModel)
        case .counting:
            CounterView(viewModel: viewModel)
        case .summary:
            EmptyView() // 요약은 TabView 바깥에서 그린다
        }
    }

    private func startRound() {
        guard !didFinish else { return }
        viewModel.start()
        startTask = Task {
            await healthKit.requestAuthorization()
            guard !Task.isCancelled else { return }
            healthKit.startWorkout()
        }
    }

    /// 종료 확인 직후. 워크아웃을 끝내며 메트릭 수집을 시작하고 화면을 요약으로 바꾼다.
    /// 스냅샷은 여기서 지우지 않는다 — 전송 없이 이탈해도 라운드가 복구되어야 한다 (spec §4).
    /// 인증 대기 중이던 시작 Task를 먼저 취소해, 뒤늦게 startWorkout()이 불려
    /// 고아 HKWorkoutSession이 남는 경쟁 상태를 막는다.
    private func beginFinish() {
        startTask?.cancel()
        didFinish = true
        viewModel.finishRound()
        let service = healthKit
        stopTask = Task { RoundMetrics(await service.stopWorkout()) }
    }

    /// 요약 화면의 "저장 & 전송". 메트릭 수집이 아직이면 끝날 때까지 기다렸다 보낸다 (spec §4).
    /// dismiss 이후 @StateObject를 읽지 않도록 Task 생성 전에 로컬로 캡처한다.
    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let model = viewModel
        let pendingStop = stopTask
        let exit = onExit
        Task {
            let metrics = await pendingStop?.value ?? RoundMetrics()
            model.save(endedAt: Date(), metrics: metrics)
            exit()
        }
    }

    /// beginFinish()를 거치지 않고 뷰가 사라지면(예: 엣지 스와이프) 워크아웃 세션이 고아로 남는다.
    /// 스냅샷/App Group 상태는 건드리지 않는다 — 크래시 복구는 HomeView의 resumeIfNeeded()가 계속 담당한다.
    private func stopWorkoutIfNotFinished() {
        guard !didFinish else { return }
        let service = healthKit
        Task { _ = await service.stopWorkout() }
    }
}
```

- [ ] **Step 3: 빌드·테스트 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, watchosTests **74건** PASS

- [ ] **Step 4: 커밋**

```bash
git add WatchApp/Features/Round/Summary/SummaryView.swift WatchApp/Features/Round/RoundSessionView.swift
git commit -m "$(cat <<'EOF'
✨ feat: 종료 확인 다이얼로그와 요약 화면 연결

"라운드 종료"는 확인 후에만 진행하며, 트림 결과 몇 홀이 기록되는지 문구에 밝힌다.
확인하면 워크아웃 종료와 메트릭 수집을 시작하고 화면을 요약으로 바꾼다.
"저장 & 전송"은 항상 누를 수 있고 메트릭이 늦으면 "전송 중…"을 표시한 뒤 보낸다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: 전체 검증 + 육안 확인 + PR

**Files:** 없음 (검증만)

- [ ] **Step 1: 포맷·린트**

```bash
make fix && make lint && make format
```

Expected: 위반 0. `make fix`가 파일을 바꿨으면 `🎨 style: make fix 결과 반영`으로 커밋한다.

- [ ] **Step 2: 세 스킴 빌드**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -3
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -3
```

Expected: 셋 다 `** BUILD SUCCEEDED **`

- [ ] **Step 3: 전체 테스트**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: watchosTests **74건**, iosTests **3건** PASS.

> plan ③에서 요약 건수가 실제와 어긋난 전례가 있다. **각 Task의 코드 블록이 원본이고 이 숫자는 파생**이다 — 어긋나면 실제로 회귀가 있는지부터 확인하고, 없으면 이 숫자를 정정한다.

- [ ] **Step 4: 워치 시뮬레이터 육안 확인**

Xcode에서 워치 앱을 실행해 아래를 순서대로 확인한다.

1. 홈 "라운드 시작" → **홀 수 선택 화면**(9홀/18홀)이 뜬다
2. 홀 수 선택 화면에서 뒤로 나가면 홈으로 돌아가고, 컴플리케이션은 평상시 그대로다 (라운드가 시작되지 않았으므로)
3. "9홀" 선택 → 파 선택 화면 → 파를 고르면 카운터 화면
4. 9번 홀까지 진행하면 **"다음" 버튼이 흐려지고 눌리지 않는다**
5. 1번 홀로 돌아가면 "이전"이 흐려지고 "다음"은 다시 눌린다
6. 컨트롤 페이지 "라운드 종료" → **확인 다이얼로그**가 뜨고 "N홀까지 기록됩니다"가 맞는 숫자다
7. "취소"를 누르면 라운드가 그대로 이어진다 (워크아웃도 계속)
8. 3홀만 치고 "다음"을 한 번 더 눌러 파 선택 화면에 둔 채 종료 → 확인 문구가 **"3홀까지 기록됩니다"** (4홀 아님)
9. 확인 → **요약 화면**으로 바뀌고 총타수·총퍼트·홀 수가 맞다
10. "저장 & 전송" → 홈으로 돌아오고 **컴플리케이션이 평상시로** 바뀐다
11. 라운드 중 앱을 강제종료 후 재실행 → **홀 수 선택을 건너뛰고** 라운드가 복구되며, 복구된 라운드의 홀 상한이 원래 선택값과 같다
12. 요약 화면에서 전송하지 않고 엣지 스와이프로 빠져나오면 홈에 머무르고 **다시 라운드로 튕겨 들어가지 않는다**
13. 그 상태로 앱을 껐다 다시 켜면 라운드가 복구된다
14. 라운드 시작 직후 바로 종료 → 확인 문구가 "기록된 홀이 없습니다", 요약 버튼이 **"저장 없이 종료"**

> 10·11번의 실제 iOS 수신 확인은 plan ⑤ 전까지 불가능하다. 이 plan에서는 **전송 호출까지가 검증 범위**이고, 수신 측이 없으므로 메시지는 큐에 남거나 조용히 버려진다 — 정상이다.

- [ ] **Step 5: PR 생성**

```bash
git push -u origin feat/watch-round-transmission
gh pr create --base main --title "✨ feat: 홀 수 선택과 라운드 종료 전송 구현 (plan ④)" --body "$(cat <<'EOF'
## 요약
- **홀 수 선택** — 라운드 시작 시 9/18홀을 고르고 그 값을 상한으로 고정. 마지막 홀에서 "다음" 비활성화
- **미기록 홀 트림** — 전송 직전 말단의 `par == 0` 홀 제거. 유령 홀과 조기 종료를 한 규칙으로 처리
- **종료 확인 + 요약 화면** — 오터치 방지 확인 후 요약으로 전환, "저장 & 전송"으로 발신
- **`RoundCompletedMessage`** — `GolfRound`와 1:1인 페이로드를 `.reliable`로 발신 (수신은 plan ⑤)
- **라운드 id** — 시작 시 생성해 스냅샷에 실어 복구를 넘어 유지 → iOS 중복 검사의 기준

## spec 개정
초안의 "9홀/18홀 선택 UI 자체가 없다"(§3)를 뒤집었다. "다음"에 상한이 없어 마지막 홀에서 한 번 더 누르면 빈 홀이 생기는 문제 때문. 대가로 전반/후반 이어치기가 다시 엣지케이스가 되며, 새 라운드로 처리한다.

## pbxproj 변경 (plan ① 이후 처음)
`Shared/`는 세 타깃 모두에 동기화되는데 `ConnectivityCore`는 컴플리케이션에 링크되어 있지 않다. `ConnectivityMessages.swift`·`RoundTransmitter.swift`를 그 타깃에서 제외하는 `PBXFileSystemSynchronizedBuildFileExceptionSet`을 추가했다. `WorkoutCore`는 iOS에 없으므로 메트릭 변환은 워치 타깃 안에 가뒀다.

## 테스트
- watchosTests 74건, iosTests 3건 PASS
- 세 스킴 BUILD SUCCEEDED, `make lint`/`make format` 위반 0
- 시뮬레이터 육안 확인: 홀 수 상한, 트림된 확인 문구, 요약·전송, 복구, 요약 이탈 후 루프 없음

## 범위 밖
iOS 수신·저장 (plan ⑤), 로컬라이즈 (plan ⑦), MapKit 골프장 감지 (plan ⑧ — `courseName`은 여전히 항상 nil)

참조: `docs/superpowers/plans/2026-08-05-watch-round-transmission.md`
EOF
)"
```

---

## 완료 기준

- [ ] `watchosTests` 74건 PASS, `iosTests` 3건 PASS
- [ ] 세 스킴(`GolfCounter`, `GolfCounter Watch App`, `ComplicationAppExtension`) BUILD SUCCEEDED — 특히 **컴플리케이션**이 pbxproj 예외 덕분에 깨지지 않는지
- [ ] `make lint`·`make format` 위반 0
- [ ] 시뮬레이터에서 Task 8 Step 4의 14개 항목 전부 확인
- [ ] 9홀을 골랐을 때 10번 홀로 넘어갈 수 없다
- [ ] 3홀만 치고 "다음"을 누른 채 종료해도 4번째 빈 홀이 전송 페이로드에 없다
- [ ] 요약에서 전송하지 않고 나오면 홈에 머무르고, 앱 재실행 시 그 라운드가 복구된다
- [ ] 복구된 라운드를 전송하면 최초 시작 시 만든 id가 그대로 실린다
