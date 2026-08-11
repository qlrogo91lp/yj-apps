# 워치 카운터 재설계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카운터 화면을 링 기반 3블록 레이아웃으로 바꾸고, 세로 페이징에 시스템 점 인디케이터를 붙인다.

**Architecture:** 세로 페이징은 `TabView(.tabViewStyle(.verticalPage))` 중첩으로 가고, 페이지 안에 스크롤을 두지 않도록 스코어카드를 9홀씩 나눈다. 카운터 페이지는 상단 정보행(Par 버튼·홀번호+누적타수·취소 버튼) / 링 / 하단 조작행(이전·모드·다음) 세 블록이다. `+`/`−` 두 버튼은 링 안쪽 원반 탭 하나로 합치고, `−`는 여러 단계 취소로 대체한다. 링 세그먼트 계산은 UI와 분리된 순수 타입으로 빼서 테스트한다.

**Tech Stack:** Swift 5 (language mode) / SwiftUI (watchOS 10+) / RalliKit 원격 SPM (`WorkoutCore`·`WorkoutUI`·`ConnectivityCore`·`PersistenceCore`) / Swift Testing

**참조 spec:** `docs/superpowers/specs/2026-08-11-watch-counter-redesign-design.md`

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0**
- **RalliKit 패키지 코드 변경 0.** 이 plan은 `~/Workspace/Projects/ralli-kit`를 건드리지 않는다
- **`Shared/`를 건드리지 않는다.** `RoundSnapshot`·`GolfRound`·서비스 전부 그대로다. `Shared/`는 세 타깃 모두에 동기화되므로 이 plan의 신규 코드는 전부 `WatchApp/` 아래에만 둔다
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `🐛 fix:` / `♻️ refactor:` / `🎨 style:` / `📝 docs:` / `✅ test:` / `🔥 remove:`)
- **`main` 직접 push 금지** — 브랜치 + PR, 머지는 `gh pr merge <n> --merge --delete-branch`. 예외는 Task 6의 스펙 문서 커밋
- 브랜치: `feature/watch-counter-redesign`
- 파일 네이밍·폴더 규칙은 `CLAUDE.md` — View suffix는 독립 화면만, **한 파일 = 한 타입**(private helper는 예외), 계층화 Components, ViewModel은 UI 프레임워크 import 금지
- 테스트는 Swift Testing(`@Test`/`#expect`), 테스트명은 **한국어 `대상_행위_예상결과`**, `@testable import GolfCounter_Watch_App`, **View는 테스트하지 않는다**
- 사용자 노출 문자열은 한국어 하드코딩 유지 (로컬라이즈는 plan ⑦)
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`
- pbxproj는 `PBXFileSystemSynchronizedRootGroup` — 파일 생성·삭제는 파일시스템 조작만으로 빌드에 반영된다. **pbxproj를 손으로 편집하지 않는다**

### 시작 상태

| 항목 | 값 |
|---|---|
| 저장소 | `/Users/yj/Workspace/Projects/golf-counter` |
| 브랜치 | `main` @ `0e7368b` (스펙 커밋 직후) |
| watchosTests | **51건** |

이 plan은 최종적으로 watchosTests를 **70건**으로 만든다 (+25 신규, −6 삭제).

| 태스크 | 변화 | 누계 |
|---|---|---|
| 시작 | — | 51 |
| Task 1 `ScorecardChunksTests` | +4 | 55 |
| Task 2 `RingSegmentsTests` | +7 | 62 |
| Task 3 `RoundViewModelUndoTests` | +11 | 73 |
| Task 5 감소 테스트 제거 | −6 | 67 |
| Task 5 `CounterSizingTests` 확장 (2 → 5) | +3 | **70** |

### 검증 명령

시뮬레이터 UDID·기기명은 머신마다 다르다. 세션 시작 시 확인할 것:

```bash
xcrun simctl list devices available | grep "Apple Watch"
```

작성 시점 기준 사용 가능 기기: `Apple Watch Series 11 (46mm)`, `Apple Watch Series 11 (42mm)`, `Apple Watch Ultra 3 (49mm)`, `Apple Watch SE 3 (44mm)`, `Apple Watch SE 3 (40mm)`.

빌드:

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

테스트:

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test
```

린트:

```bash
make lint && make format
```

## File Structure

| 파일 | 책임 | 태스크 |
|---|---|---|
| `WatchApp/Features/Round/Counter/Components/ScorecardChunks.swift` | 홀 수 → 9홀 단위 페이지 범위 배열. 순수 계산 | 1 |
| `WatchApp/Features/Round/Counter/CounterView.swift` | 세로 페이지 컨테이너. 카운터 1페이지 + 스코어카드 N페이지 | 1, 5 |
| `WatchApp/Features/Round/Counter/Components/Scorecard.swift` | 홀 범위 하나를 표로 그린다. 합계는 마지막 청크만 | 1 |
| `WatchApp/Features/Round/Counter/Components/RingSegments.swift` | 파·타수·퍼트 → 링 세그먼트 배열. 순수 계산, UI 미import | 2 |
| `WatchApp/Features/Round/RoundViewModel.swift` | 라운드 상태 + 취소 스택 | 3, 5 |
| `WatchApp/Features/Round/Counter/Components/CounterSizing.swift` | 세 크기 세트 | 4, 5 |
| `WatchApp/Features/Round/Counter/Components/StrokeRing.swift` | `RingSegments`를 원호로 그린다 | 4 |
| `WatchApp/Features/Round/Counter/Components/UndoButton.swift` | 원형 아이콘 취소 버튼 | 4 |
| `WatchApp/Features/Round/Counter/Components/ModeButton.swift` | 모드 버튼. 폭에 따라 알약/원형 | 4 |
| `WatchApp/Features/Round/Counter/Components/CounterHeader.swift` | 상단 정보행 | 4 |
| `WatchApp/Features/Round/Counter/Components/CounterControls.swift` | 하단 조작행 | 4 |
| `WatchApp/Features/Round/Counter/Components/CounterPage.swift` | 세 블록 조립 + 햅틱 + 애니메이션 | 5 |

삭제: `StrokeButton.swift` · `HoleNavigation.swift` · `ModeToggle.swift` (Task 5)

---

### Task 1: 세로 페이징 컨테이너 + 스코어카드 9홀 청킹

가장 불확실한 것(가로 `TabView` 안에 세로 `TabView`를 중첩했을 때 제스처 간섭)을 먼저 끝낸다. 이 태스크는 기존 `CounterPage`를 그대로 쓰므로 레이아웃 재설계와 독립적이다.

**Files:**
- Create: `WatchApp/Features/Round/Counter/Components/ScorecardChunks.swift`
- Create: `watchosTests/Round/ScorecardChunksTests.swift`
- Modify: `WatchApp/Features/Round/Counter/CounterView.swift` (전체 교체)
- Modify: `WatchApp/Features/Round/Counter/Components/Scorecard.swift`

**Interfaces:**
- Consumes: `RoundViewModel.snapshot` → `RoundSnapshot` (기존), `CounterPage(viewModel:sizing:)` (기존 시그니처 그대로)
- Produces:
  - `ScorecardChunks.ranges(holeCount: Int) -> [Range<Int>]` — 9홀 단위 0-based 인덱스 범위
  - `Scorecard(snapshot: RoundSnapshot, holeRange: Range<Int>, showsTotal: Bool)`

- [ ] **Step 1: 브랜치 생성**

```bash
git checkout main && git pull
git checkout -b feature/watch-counter-redesign
```

- [ ] **Step 2: `ScorecardChunks` 실패 테스트 작성**

`watchosTests/Round/ScorecardChunksTests.swift`:

```swift
@testable import GolfCounter_Watch_App
import Testing

struct ScorecardChunksTests {
    @Test func 홀이_없으면_페이지가_없다() {
        #expect(ScorecardChunks.ranges(holeCount: 0).isEmpty)
    }

    @Test func 아홉홀_이하는_한_페이지다() {
        #expect(ScorecardChunks.ranges(holeCount: 1) == [0 ..< 1])
        #expect(ScorecardChunks.ranges(holeCount: 9) == [0 ..< 9])
    }

    @Test func 열홀부터_두_페이지로_나뉜다() {
        #expect(ScorecardChunks.ranges(holeCount: 10) == [0 ..< 9, 9 ..< 10])
        #expect(ScorecardChunks.ranges(holeCount: 18) == [0 ..< 9, 9 ..< 18])
    }

    @Test func 음수가_들어와도_빈_배열을_돌려준다() {
        #expect(ScorecardChunks.ranges(holeCount: -3).isEmpty)
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

Run:
```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -30
```
Expected: 컴파일 실패 — `cannot find 'ScorecardChunks' in scope`

- [ ] **Step 4: `ScorecardChunks` 구현**

`WatchApp/Features/Round/Counter/Components/ScorecardChunks.swift`:

```swift
/// 스코어카드를 세로 페이지로 나누는 규칙 (spec §4).
///
/// 페이지 안에 스크롤을 두지 않기 위해 9홀씩 끊는다. 9홀은 골프가 원래 쓰는
/// 전반/후반 단위라 기술적 타협이 아니라 도메인에 맞는 분할이다.
/// UI 프레임워크를 import하지 않는다 — 순수 계산이다.
enum ScorecardChunks {
    static let holesPerPage = 9

    /// 0-based 홀 인덱스를 `holesPerPage` 단위로 끊은 범위 배열.
    static func ranges(holeCount: Int) -> [Range<Int>] {
        guard holeCount > 0 else { return [] }
        return stride(from: 0, to: holeCount, by: holesPerPage).map { start in
            start ..< min(start + holesPerPage, holeCount)
        }
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: 위 test 명령
Expected: PASS. watchosTests 51 → 55건

- [ ] **Step 6: `Scorecard`에 홀 범위 파라미터 추가**

`WatchApp/Features/Round/Counter/Components/Scorecard.swift` 전체 교체:

```swift
import SwiftUI

/// 스코어카드 한 페이지. 홀 범위 하나만 그린다 (spec §4).
/// 합계 줄은 마지막 청크에만 붙이고, 값은 라운드 전체 합계다.
struct Scorecard: View {
    let snapshot: RoundSnapshot
    let holeRange: Range<Int>
    let showsTotal: Bool

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows, id: \.holeNumber) { row in
                HStack(spacing: 4) {
                    Text("H\(row.holeNumber)")
                        .frame(width: 26, alignment: .leading)
                    Text(row.par > 0 ? "Par\(row.par)" : "—")
                        .frame(width: 38, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text("\(row.score)타(\(row.putts)p)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.par > 0 ? ScoreFormat.relativeToPar(row.score - row.par) : "")
                        .frame(width: 26, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }

            if showsTotal {
                Divider()

                Text("합계 \(snapshot.totalStrokes)타 · \(totalPutts)퍼트 · \(ScoreFormat.relativeToPar(snapshot.relativeToPar))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
    }

    private var totalPutts: Int {
        snapshot.puttCounts.reduce(0, +)
    }

    /// 세 배열의 길이가 어긋난 값이 들어와도 인덱스를 벗어나지 않도록 가장 짧은 길이에 맞춘다.
    private var rows: [ScorecardRow] {
        let available = min(snapshot.holeScores.count, snapshot.holePars.count, snapshot.puttCounts.count)
        let safeRange = holeRange.clamped(to: 0 ..< available)
        return safeRange.map { index in
            ScorecardRow(holeNumber: index + 1,
                         par: snapshot.holePars[index],
                         score: snapshot.holeScores[index],
                         putts: snapshot.puttCounts[index])
        }
    }
}

private struct ScorecardRow {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int
}

#Preview {
    Scorecard(snapshot: RoundSnapshot(startedAt: Date(),
                                      courseName: "테스트CC",
                                      currentHoleIndex: 2,
                                      holeScores: [4, 3, 6],
                                      holePars: [4, 3, 5],
                                      puttCounts: [2, 1, 2]),
              holeRange: 0 ..< 3,
              showsTotal: true)
}
```

- [ ] **Step 7: `CounterView`를 세로 `TabView`로 교체**

`WatchApp/Features/Round/Counter/CounterView.swift` 전체 교체:

```swift
import SwiftUI

/// 카운터 화면 — 크라운으로 넘기는 세로 페이지 (spec §4).
///
/// 1페이지가 카운터, 그 뒤로 스코어카드가 9홀씩 이어진다. 시스템이 세로 점
/// 인디케이터를 그려주므로 아래에 내용이 더 있다는 사실이 발견된다.
///
/// 이 화면은 `RoundSessionView`의 **가로** TabView 안에 들어 있다. 크라운(세로)과
/// 스와이프(가로)는 입력 채널이 달라 충돌하지 않는다. 페이지 안에 `ScrollView`를
/// 두지 않으므로 크라운을 쓰는 주체가 페이지 전환 하나뿐이고, 다툴 상대가 없다.
struct CounterView: View {
    @ObservedObject var viewModel: RoundViewModel

    var body: some View {
        TabView {
            ViewThatFits(in: .vertical) {
                CounterPage(viewModel: viewModel, sizing: .regular)
                CounterPage(viewModel: viewModel, sizing: .compact)
                CounterPage(viewModel: viewModel, sizing: .tight)
            }

            ForEach(chunks, id: \.lowerBound) { range in
                Scorecard(snapshot: viewModel.snapshot,
                          holeRange: range,
                          showsTotal: range.upperBound == holeCount)
                    .padding(.horizontal, 4)
            }
        }
        .tabViewStyle(.verticalPage)
    }

    private var holeCount: Int {
        viewModel.snapshot.holeScores.count
    }

    private var chunks: [Range<Int>] {
        ScorecardChunks.ranges(holeCount: holeCount)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CounterView(viewModel: viewModel)
}
```

- [ ] **Step 8: 빌드 확인**

Run:
```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 9: 시뮬레이터에서 제스처 간섭 검증 (이 태스크의 핵심)**

46mm에서 앱을 실행하고 다음 네 가지를 **직접 확인한다**:

```bash
xcrun simctl boot "Apple Watch Series 11 (46mm)"
open -a Simulator
```

Xcode에서 `GolfCounter Watch App` 스킴을 Run한 뒤:

| 확인 항목 | 기대 |
|---|---|
| 라운드 시작 → 파 4 선택 → 타수 몇 번 입력 | 카운터가 정상 표시됨 |
| 크라운을 아래로 돌림 | 스코어카드 페이지로 넘어가고 **세로 점 인디케이터가 보임** |
| 크라운을 위로 돌림 | 카운터로 돌아옴 |
| 좌우로 스와이프 | 워크아웃 컨트롤/메트릭 탭으로 전환됨 (세로 페이징에 갇히지 않음) |

**네 가지가 모두 통과하면 다음 스텝으로 간다.**

**하나라도 실패하면 폴백으로 전환한다** (spec §4 "폴백"). `CounterView`의 `TabView`/`.tabViewStyle(.verticalPage)`를 아래로 바꾸고, `ScorecardChunks`·`Scorecard` 변경은 그대로 유지한다:

```swift
ScrollView {
    VStack(spacing: 0) {
        ViewThatFits(in: .vertical) {
            CounterPage(viewModel: viewModel, sizing: .regular)
            CounterPage(viewModel: viewModel, sizing: .compact)
            CounterPage(viewModel: viewModel, sizing: .tight)
        }
        .containerRelativeFrame(.vertical)

        ForEach(chunks, id: \.lowerBound) { range in
            Scorecard(snapshot: viewModel.snapshot,
                      holeRange: range,
                      showsTotal: range.upperBound == holeCount)
                .padding(.horizontal, 4)
                .containerRelativeFrame(.vertical)
        }
    }
}
.scrollTargetBehavior(.paging)
```

이 경우 세로 점 인디케이터를 직접 그려야 하므로, **폴백을 택했다면 그 사실과 실패한 항목을 커밋 메시지에 적고 사용자에게 보고한 뒤 지시를 기다린다.** 이 plan의 나머지 태스크는 폴백이든 아니든 그대로 진행된다.

- [ ] **Step 10: 전체 테스트 통과 확인**

Run: 위 test 명령
Expected: PASS, 55건

- [ ] **Step 11: 린트**

```bash
make fix && make lint && make format
```
Expected: 위반 0

- [ ] **Step 12: 커밋**

```bash
git add WatchApp/Features/Round/Counter/ watchosTests/Round/ScorecardChunksTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: 카운터 세로 페이징을 TabView(.verticalPage)로 전환

시스템 세로 점 인디케이터를 얻고, 페이지 안에 스크롤이 생기지 않도록
스코어카드를 9홀씩 나눈다.

- ScorecardChunks: 홀 수 → 9홀 단위 범위 배열 (순수 계산 + 테스트)
- Scorecard: holeRange·showsTotal 파라미터 추가, 합계는 마지막 청크만
- CounterView: ScrollView + .paging → TabView + .verticalPage

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: RingSegments — 링 세그먼트 계산

링을 그리기 전에 "무엇을 그릴지"를 순수 계산으로 확정한다. 뷰가 아니라 로직이므로 테스트한다.

**Files:**
- Create: `WatchApp/Features/Round/Counter/Components/RingSegments.swift`
- Create: `watchosTests/Round/RingSegmentsTests.swift`

**Interfaces:**
- Consumes: 없음 (순수 타입)
- Produces:
  - `RingSegments(par: Int, strokes: Int, putts: Int)`
  - `RingSegments.Kind` — `.swing` / `.putt` / `.empty`
  - `RingSegments.slots: [Kind]` — 주 링. 길이는 항상 `par`
  - `RingSegments.overflow: [Kind]` — 바깥 초과 링. 길이는 0 이상 `par` 이하

- [ ] **Step 1: 실패 테스트 작성**

`watchosTests/Round/RingSegmentsTests.swift`:

```swift
@testable import GolfCounter_Watch_App
import Testing

struct RingSegmentsTests {
    @Test func 아직_안_쳤으면_전_슬롯이_비어있다() {
        let segments = RingSegments(par: 4, strokes: 0, putts: 0)

        #expect(segments.slots == [.empty, .empty, .empty, .empty])
        #expect(segments.overflow.isEmpty)
    }

    @Test func 파_이내면_친_만큼만_채워진다() {
        let segments = RingSegments(par: 4, strokes: 3, putts: 0)

        #expect(segments.slots == [.swing, .swing, .swing, .empty])
        #expect(segments.overflow.isEmpty)
    }

    @Test func 정확히_파면_꽉_차고_초과링이_없다() {
        let segments = RingSegments(par: 4, strokes: 4, putts: 0)

        #expect(segments.slots == [.swing, .swing, .swing, .swing])
        #expect(segments.overflow.isEmpty)
    }

    /// 모델은 입력 순서를 저장하지 않으므로 스윙을 먼저 그린다 (spec §6 알려진 한계).
    @Test func 퍼팅은_스윙_뒤에_그려진다() {
        let segments = RingSegments(par: 4, strokes: 5, putts: 2)

        #expect(segments.slots == [.swing, .swing, .swing, .putt])
        #expect(segments.overflow == [.putt])
    }

    /// 초과가 한 바퀴를 또 넘으면 바깥 링은 파 칸수에서 멈춘다. 정확한 값은 가운데 숫자가 담당한다.
    @Test func 초과가_한바퀴를_넘으면_바깥링은_파_칸수에서_멈춘다() {
        let segments = RingSegments(par: 3, strokes: 10, putts: 4)

        #expect(segments.slots.count == 3)
        #expect(segments.overflow.count == 3)
    }

    /// 퍼트가 타수보다 많은 값은 정상 경로로는 안 생기지만, 들어와도 인덱스를 벗어나면 안 된다.
    @Test func 퍼트가_타수보다_많아도_타수까지만_센다() {
        let segments = RingSegments(par: 4, strokes: 2, putts: 5)

        #expect(segments.slots == [.putt, .putt, .empty, .empty])
        #expect(segments.overflow.isEmpty)
    }

    /// 파 선택 화면이 파를 강제하므로 카운터에서 par 0은 안 생기지만, 나눗셈 방어는 필요하다.
    @Test func 파가_0이면_슬롯이_없다() {
        let segments = RingSegments(par: 0, strokes: 3, putts: 1)

        #expect(segments.slots.isEmpty)
        #expect(segments.overflow.isEmpty)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: 위 test 명령
Expected: 컴파일 실패 — `cannot find 'RingSegments' in scope`

- [ ] **Step 3: `RingSegments` 구현**

`WatchApp/Features/Round/Counter/Components/RingSegments.swift`:

```swift
/// 링에 그릴 세그먼트 구성 (spec §6).
///
/// 링 한 바퀴가 파고, 타수 하나가 한 칸이다. 파를 넘긴 타수는 바깥 링으로 넘어간다.
/// 뷰가 아니라 계산이므로 UI 프레임워크를 import하지 않는다 — 색도 `Color`가 아니라
/// 자체 enum으로 표현하고, 실제 색 매핑은 `StrokeRing`이 한다.
struct RingSegments: Equatable {
    enum Kind: Equatable {
        case swing
        case putt
        case empty
    }

    /// 주 링. 길이는 항상 `par`다.
    let slots: [Kind]
    /// 바깥 초과 링. 비어 있으면 그리지 않는다. 길이는 최대 `par`다.
    let overflow: [Kind]

    init(par: Int, strokes: Int, putts: Int) {
        guard par > 0 else {
            slots = []
            overflow = []
            return
        }

        // 퍼트는 타수에 포함되는 개념이므로 타수를 넘을 수 없다.
        // 정상 경로로는 안 생기지만, 어긋난 값이 들어와도 인덱스를 벗어나지 않게 클램프한다.
        let totalStrokes = max(strokes, 0)
        let totalPutts = min(max(putts, 0), totalStrokes)
        let swingCount = totalStrokes - totalPutts

        /// 0-based 타수 순번에 해당하는 종류. 스윙을 먼저, 퍼팅을 나중에 배치한다.
        func kind(atStrokeIndex index: Int) -> Kind {
            index < swingCount ? .swing : .putt
        }

        slots = (0 ..< par).map { index in
            index < min(totalStrokes, par) ? kind(atStrokeIndex: index) : .empty
        }

        // 초과가 파를 또 넘으면 바깥 링은 한 바퀴에서 멈춘다.
        let overflowCount = min(max(totalStrokes - par, 0), par)
        overflow = (0 ..< overflowCount).map { index in
            kind(atStrokeIndex: par + index)
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: 위 test 명령
Expected: PASS, 55 → 62건

- [ ] **Step 5: 린트 + 커밋**

```bash
make fix && make lint && make format
git add WatchApp/Features/Round/Counter/Components/RingSegments.swift watchosTests/Round/RingSegmentsTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: RingSegments — 파·타수·퍼트를 링 세그먼트로 계산

링 한 바퀴가 파고 타수 하나가 한 칸이다. 파를 넘긴 타수는 바깥 링으로
넘어가되 한 바퀴에서 멈춘다.

모델이 입력 순서를 저장하지 않으므로 스윙을 먼저 그린다 (spec §6 한계).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: RoundViewModel 취소 스택

`decrementStroke()`는 이 태스크에서 **삭제하지 않는다** — 아직 `CounterPage`가 쓰고 있어 빌드가 깨진다. Task 5에서 뷰를 갈아끼울 때 함께 지운다.

**Files:**
- Modify: `WatchApp/Features/Round/RoundViewModel.swift`
- Create: `watchosTests/Round/RoundViewModelUndoTests.swift`

**Interfaces:**
- Consumes: `StrokeInputMode` (기존, `Shared/Models/`), `RoundSnapshotPublishing` (기존)
- Produces:
  - `RoundViewModel.canUndo: Bool`
  - `RoundViewModel.undo()`

- [ ] **Step 1: 실패 테스트 작성**

`watchosTests/Round/RoundViewModelUndoTests.swift`:

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

@MainActor
struct RoundViewModelUndoTests {
    private func makeViewModel(spy: RoundSnapshotPublisherSpy = RoundSnapshotPublisherSpy()) -> RoundViewModel {
        RoundViewModel(startedAt: Date(timeIntervalSince1970: 1000), publisher: spy)
    }

    @Test func 시작하면_되돌릴게_없다() {
        let viewModel = makeViewModel()

        #expect(viewModel.canUndo == false)
    }

    @Test func 타수를_입력하면_되돌릴게_생긴다() {
        let viewModel = makeViewModel()

        viewModel.incrementStroke()

        #expect(viewModel.canUndo)
    }

    @Test func 스윙_입력을_되돌리면_타수만_내려간다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke()
        viewModel.incrementStroke()

        viewModel.undo()

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 0)
    }

    @Test func 퍼팅_입력을_되돌리면_타수와_퍼팅이_함께_내려간다() {
        let viewModel = makeViewModel()
        viewModel.inputMode = .putt
        viewModel.incrementStroke()

        viewModel.undo()

        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
    }

    /// 되돌리기는 입력의 정확한 역연산이다 — 모드가 바뀌어도 그때 친 종류대로 되돌린다.
    @Test func 연속_되돌리기는_입력의_역순으로_돌아간다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke() // 스윙
        viewModel.inputMode = .putt
        viewModel.incrementStroke() // 퍼팅
        viewModel.inputMode = .swing

        viewModel.undo() // 퍼팅이 되돌아가야 한다

        #expect(viewModel.currentScore == 1)
        #expect(viewModel.currentPutts == 0)

        viewModel.undo() // 스윙이 되돌아가야 한다

        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
        #expect(viewModel.canUndo == false)
    }

    @Test func 되돌릴게_없으면_되돌리기는_아무것도_바꾸지_않는다() {
        let viewModel = makeViewModel()

        viewModel.undo()

        #expect(viewModel.currentScore == 0)
        #expect(viewModel.currentPutts == 0)
    }

    /// 홀을 넘긴 뒤 되돌리면 화면이 통째로 이전 홀로 돌아가 예측이 안 된다.
    /// "지금 보고 있는 홀의 마지막 입력을 되돌린다"가 유일하게 예측 가능한 의미다 (spec §7).
    @Test func 다음홀로_이동하면_되돌릴게_없다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.goToNextHole()

        #expect(viewModel.canUndo == false)
    }

    @Test func 이전홀로_이동하면_되돌릴게_없다() {
        let viewModel = makeViewModel()
        viewModel.selectPar(4)
        viewModel.goToNextHole()
        viewModel.selectPar(3)
        viewModel.incrementStroke()

        viewModel.goToPreviousHole()

        #expect(viewModel.canUndo == false)
    }

    /// 복구 시점에는 되돌릴 대상을 모른다. 모르는 상태에서 되돌리는 것보다 안 뜨는 게 안전하다.
    @Test func 복구로_시작하면_되돌릴게_없다() {
        let snapshot = RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                                     courseName: nil,
                                     currentHoleIndex: 0,
                                     holeScores: [3],
                                     holePars: [4],
                                     puttCounts: [1])
        let viewModel = RoundViewModel(resuming: snapshot, publisher: RoundSnapshotPublisherSpy())

        #expect(viewModel.canUndo == false)
    }

    /// 파는 Par 버튼으로 언제든 고칠 수 있으므로 되돌리기 대상이 아니고,
    /// 파를 바꿔도 이미 친 타는 유효하므로 스택을 비우지도 않는다.
    @Test func 파를_고르는것은_되돌리기에_영향이_없다() {
        let viewModel = makeViewModel()
        viewModel.incrementStroke()

        viewModel.selectPar(5)

        #expect(viewModel.canUndo)
    }

    @Test func 되돌리면_스냅샷을_발행한다() {
        let spy = RoundSnapshotPublisherSpy()
        let viewModel = makeViewModel(spy: spy)
        viewModel.selectPar(4)
        viewModel.incrementStroke()

        viewModel.undo()

        #expect(spy.published.last?.holeScores == [0])
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: 위 test 명령
Expected: 컴파일 실패 — `value of type 'RoundViewModel' has no member 'canUndo'`

- [ ] **Step 3: `strokeHistory`와 `canUndo` 추가**

`WatchApp/Features/Round/RoundViewModel.swift` — `@Published private(set) var isEditingPar = false` 바로 아래에 추가:

```swift
    /// 현재 홀에서 친 타의 종류 순서. 되돌리기의 유일한 상태다 (spec §7).
    ///
    /// `incrementStroke()`가 하는 일이 모드에 따라 (타수 +1) 또는 (타수 +1, 퍼트 +1)
    /// 두 가지뿐이므로, 어느 쪽이었는지만 알면 정확히 되돌릴 수 있다. 배열 전체를
    /// 복사할 필요가 없다.
    ///
    /// `@Published`인 이유: `canUndo`가 이 값에서 파생되므로, 뷰가 취소 버튼의
    /// 등장·퇴장을 관찰하려면 변경이 발행되어야 한다.
    @Published private var strokeHistory: [StrokeInputMode] = []
```

그리고 `// MARK: - 표시값` 블록의 `canGoToPreviousHole` 아래에 추가:

```swift
    var canUndo: Bool {
        !strokeHistory.isEmpty
    }
```

- [ ] **Step 4: `incrementStroke()`에 기록 추가**

`incrementStroke()`의 첫 줄에 `strokeHistory.append(inputMode)`를 넣는다:

```swift
    func incrementStroke() {
        strokeHistory.append(inputMode)
        switch inputMode {
        case .swing:
            holeScores[currentHoleIndex] += 1
        case .putt:
            holeScores[currentHoleIndex] += 1
            puttCounts[currentHoleIndex] += 1
        }
        publishSnapshot()
    }
```

- [ ] **Step 5: `undo()` 추가**

`decrementStroke()` 바로 아래에 추가:

```swift
    /// 현재 홀의 마지막 입력을 되돌린다. 입력의 정확한 역연산이다.
    /// 상태를 바꾸는 모든 경로가 스냅샷을 발행한다는 규칙을 따라 마지막에 발행한다.
    func undo() {
        guard let mode = strokeHistory.popLast() else { return }
        holeScores[currentHoleIndex] -= 1
        if mode == .putt {
            puttCounts[currentHoleIndex] -= 1
        }
        publishSnapshot()
    }
```

- [ ] **Step 6: 홀 이동 시 기록 비우기**

`resetHoleLocalState()`에 한 줄 추가:

```swift
    /// 홀을 옮기면 입력 모드는 스윙으로 리셋되고(spec §3), 진행 중이던 파 편집은 취소된다.
    /// 되돌리기 기록도 함께 비운다 — 되돌리기 스코프는 현재 홀이다 (spec §7).
    private func resetHoleLocalState() {
        inputMode = .swing
        isEditingPar = false
        strokeHistory.removeAll()
    }
```

- [ ] **Step 7: 테스트 통과 확인**

Run: 위 test 명령
Expected: PASS, 62 → 73건

- [ ] **Step 8: 린트 + 커밋**

```bash
make fix && make lint && make format
git add WatchApp/Features/Round/RoundViewModel.swift watchosTests/Round/RoundViewModelUndoTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: RoundViewModel에 여러 단계 취소 추가

입력한 타의 종류만 쌓아 정확한 역연산으로 되돌린다. 상태 전체를
스냅샷하지 않는다.

스코프는 현재 홀 — 홀을 옮기면 기록을 비운다. 홀을 넘긴 뒤 되돌렸을 때
화면이 통째로 이전 홀로 돌아가면 예측할 수 없기 때문이다.

decrementStroke()는 CounterPage가 아직 쓰고 있어 다음 커밋에서 지운다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: 뷰 컴포넌트 5개 + CounterSizing 새 필드

아직 아무도 쓰지 않는 컴포넌트를 먼저 만든다. 빌드가 계속 통과하므로 리뷰어가 컴포넌트만 따로 볼 수 있다. `CounterSizing`은 **새 필드를 추가**하고 구 필드는 남겨둔다 (Task 5에서 제거).

**Files:**
- Create: `WatchApp/Features/Round/Counter/Components/StrokeRing.swift`
- Create: `WatchApp/Features/Round/Counter/Components/UndoButton.swift`
- Create: `WatchApp/Features/Round/Counter/Components/ModeButton.swift`
- Create: `WatchApp/Features/Round/Counter/Components/CounterHeader.swift`
- Create: `WatchApp/Features/Round/Counter/Components/CounterControls.swift`
- Modify: `WatchApp/Features/Round/Counter/Components/CounterSizing.swift`

**Interfaces:**
- Consumes: `RingSegments` (Task 2), `StrokeInputMode` (기존)
- Produces:
  - `CounterSizing` 새 필드: `headerHeight` `ringDiameter` `ringStroke` `overflowStroke` `overflowGap` `relativeFont` `parButtonSize` `undoSize` `arrowSize` `modeHeight` `modeWideWidth` `usesShortHoleLabel` (`headerFont` `scoreFont` `spacing`은 기존 이름 유지, 값만 변경)
  - `StrokeRing(segments: RingSegments, sizing: CounterSizing)`
  - `UndoButton(size: CGFloat, action: () -> Void)`
  - `ModeButton(mode: Binding<StrokeInputMode>, sizing: CounterSizing)`
  - `CounterHeader(holeNumber:par:totalStrokes:canUndo:sizing:onEditPar:onUndo:)`
  - `CounterControls(mode:canGoToPrevious:sizing:onPrevious:onNext:)`

- [ ] **Step 1: `CounterSizing`에 새 필드 추가**

`WatchApp/Features/Round/Counter/Components/CounterSizing.swift` 전체 교체. 구 필드(`strokeButton` `strokeIcon` `controlHeight` `navHeight`)는 `CounterPage`가 아직 쓰므로 남긴다:

```swift
import CoreGraphics

/// 카운터 세로 1페이지를 워치 화면 높이에 맞추기 위한 크기 세트 (spec §10).
///
/// `CounterView`의 `ViewThatFits`가 regular → compact → tight 순으로 시도해
/// 실제로 들어가는 첫 세트를 고른다. **기기 모델을 분기하지 않는다** — 측정은 SwiftUI가 하므로
/// 여기에 화면 높이나 기기 이름이 등장할 이유가 없다.
///
/// 세로 합계 = headerHeight + spacing + ringDiameter + spacing + modeHeight.
/// 취소와 Par가 둘 다 헤더 안에 들어가므로 세로 예산에서 이 둘의 몫은 headerHeight 하나뿐이다.
struct CounterSizing {
    // MARK: 상단 정보행

    let headerHeight: CGFloat
    let headerFont: CGFloat
    let parButtonSize: CGFloat
    let undoSize: CGFloat
    /// 참이면 헤더 가운데를 "7번 홀 · 41타" 대신 "H7 · 41타"로 축약한다.
    /// 40mm에서 양끝 원형 버튼을 뺀 가운데 폭이 전체 표기보다 좁기 때문이다.
    let usesShortHoleLabel: Bool

    // MARK: 링

    let ringDiameter: CGFloat
    let ringStroke: CGFloat
    let overflowStroke: CGFloat
    /// 주 링 바깥면과 초과 링 안쪽면 사이 간격.
    let overflowGap: CGFloat
    let scoreFont: CGFloat
    let relativeFont: CGFloat

    // MARK: 하단 조작행

    let arrowSize: CGFloat
    let modeHeight: CGFloat
    /// 알약 변형의 고정 폭. `ViewThatFits`가 이 폭으로 먼저 시도하고 안 들어가면 원형으로 떨어진다.
    let modeWideWidth: CGFloat

    let spacing: CGFloat

    // MARK: 구 레이아웃 필드 (CounterPage 재작성 시 제거)

    let strokeButton: CGFloat
    let strokeIcon: CGFloat
    let controlHeight: CGFloat
    let navHeight: CGFloat

    /// 초과 링까지 포함한 실제 반지름. 화면 폭 안에 들어가는지 판단하는 값이다.
    var outerRadius: CGFloat {
        ringDiameter / 2 + ringStroke / 2 + overflowGap + overflowStroke
    }

    /// 링 안쪽 원반 지름 — 스트로크 입력 탭 타깃이다.
    var innerDiameter: CGFloat {
        ringDiameter - ringStroke
    }

    /// 46mm 이상.
    static let regular = CounterSizing(headerHeight: 36,
                                       headerFont: 14,
                                       parButtonSize: 36,
                                       undoSize: 36,
                                       usesShortHoleLabel: false,
                                       ringDiameter: 132,
                                       ringStroke: 11,
                                       overflowStroke: 5,
                                       overflowGap: 4,
                                       scoreFont: 40,
                                       relativeFont: 13,
                                       arrowSize: 40,
                                       modeHeight: 48,
                                       modeWideWidth: 100,
                                       spacing: 6,
                                       strokeButton: 62,
                                       strokeIcon: 26,
                                       controlHeight: 28,
                                       navHeight: 30)

    /// 42~44mm.
    static let compact = CounterSizing(headerHeight: 32,
                                       headerFont: 13,
                                       parButtonSize: 32,
                                       undoSize: 32,
                                       usesShortHoleLabel: false,
                                       ringDiameter: 110,
                                       ringStroke: 10,
                                       overflowStroke: 4.5,
                                       overflowGap: 3.5,
                                       scoreFont: 33,
                                       relativeFont: 12,
                                       arrowSize: 36,
                                       modeHeight: 44,
                                       modeWideWidth: 92,
                                       spacing: 5,
                                       strokeButton: 54,
                                       strokeIcon: 23,
                                       controlHeight: 26,
                                       navHeight: 28)

    /// 40mm. `ViewThatFits`가 시도하는 마지막 후보라 이 아래로는 fallback이 없다 —
    /// 더 작은 기기가 나오거나 고정 pt 대신 Dynamic Type으로 바꿔서 이 세트도 안 맞게 되면
    /// graceful degradation 없이 콘텐츠가 잘린다. 그런 변경이 생기면 다시 실측해야 한다.
    static let tight = CounterSizing(headerHeight: 28,
                                     headerFont: 12,
                                     parButtonSize: 28,
                                     undoSize: 28,
                                     usesShortHoleLabel: true,
                                     ringDiameter: 92,
                                     ringStroke: 8,
                                     overflowStroke: 4,
                                     overflowGap: 3,
                                     scoreFont: 28,
                                     relativeFont: 11,
                                     arrowSize: 32,
                                     modeHeight: 38,
                                     modeWideWidth: 84,
                                     spacing: 4,
                                     strokeButton: 46,
                                     strokeIcon: 20,
                                     controlHeight: 24,
                                     navHeight: 26)
}
```

- [ ] **Step 2: `StrokeRing` 생성**

`WatchApp/Features/Round/Counter/Components/StrokeRing.swift`:

```swift
import SwiftUI

/// 파 칸수만큼 나뉜 링 (spec §6).
///
/// 회색 트랙 위에 채워진 칸을 덧그린다. 채워진 칸은 `trim`의 끝값을 시작값에서
/// 끝값으로 움직여 호가 그려지듯 차오른다 — 애니메이션은 호출부가 건다.
/// 파를 넘긴 타수는 바깥에 얇은 링으로 덧그린다.
struct StrokeRing: View {
    let segments: RingSegments
    let sizing: CounterSizing

    var body: some View {
        ZStack {
            arcs(kinds: segments.slots,
                 diameter: sizing.ringDiameter,
                 lineWidth: sizing.ringStroke,
                 drawsTrack: true)

            if !segments.overflow.isEmpty {
                arcs(kinds: paddedOverflow,
                     diameter: overflowDiameter,
                     lineWidth: sizing.overflowStroke,
                     drawsTrack: false)
            }
        }
        .frame(width: sizing.outerRadius * 2, height: sizing.outerRadius * 2)
    }

    private var overflowDiameter: CGFloat {
        sizing.ringDiameter + sizing.ringStroke + sizing.overflowGap * 2 + sizing.overflowStroke
    }

    /// 바깥 링도 주 링과 같은 칸수로 나눈다 — 채워지지 않은 칸은 그리지 않는다.
    private var paddedOverflow: [RingSegments.Kind] {
        let slotCount = segments.slots.count
        guard slotCount > 0 else { return [] }
        return (0 ..< slotCount).map { index in
            index < segments.overflow.count ? segments.overflow[index] : .empty
        }
    }

    private func arcs(kinds: [RingSegments.Kind],
                      diameter: CGFloat,
                      lineWidth: CGFloat,
                      drawsTrack: Bool) -> some View
    {
        let count = max(kinds.count, 1)
        // 칸 사이 간격. 둘레 대비 비율이라 칸이 많아져도 비례해서 줄어든다.
        let gap = 0.5 / CGFloat(count) * 0.16

        return ZStack {
            ForEach(Array(kinds.enumerated()), id: \.offset) { index, kind in
                let start = CGFloat(index) / CGFloat(count) + gap
                let end = CGFloat(index + 1) / CGFloat(count) - gap

                if drawsTrack {
                    arc(from: start, to: end, color: .gray.opacity(0.25), lineWidth: lineWidth)
                }

                // 빈 칸은 길이 0으로 그려둔다. 채워질 때 끝값이 움직이므로 애니메이션이 붙는다.
                arc(from: start,
                    to: kind == .empty ? start : end,
                    color: color(for: kind),
                    lineWidth: lineWidth)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func arc(from start: CGFloat, to end: CGFloat, color: Color, lineWidth: CGFloat) -> some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            // Circle().trim은 3시 방향에서 시작한다. 12시로 옮긴다.
            .rotationEffect(.degrees(-90))
    }

    private func color(for kind: RingSegments.Kind) -> Color {
        switch kind {
        case .swing: .green
        case .putt: .orange
        case .empty: .clear
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StrokeRing(segments: RingSegments(par: 4, strokes: 3, putts: 0), sizing: .regular)
        StrokeRing(segments: RingSegments(par: 4, strokes: 5, putts: 2), sizing: .tight)
    }
}
```

- [ ] **Step 3: `UndoButton` 생성**

`WatchApp/Features/Round/Counter/Components/UndoButton.swift`:

```swift
import SwiftUI

/// 상단 정보행 오른쪽 끝의 취소 버튼 (spec §5).
///
/// tennis-counter는 아이콘 + "취소" 텍스트가 든 캡슐 필을 쓰지만, 골프는 아이콘만 있는
/// 원형이다. 링이 이 화면의 시각적 핵심이라 필의 폭(약 73pt)이 링을 가리기 때문이며,
/// 헤더로 올리면서 모양도 헤더의 다른 원형 버튼(Par)과 맞췄다.
/// 등장·퇴장 트랜지션은 tennis와 같은 것을 쓴다.
struct UndoButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: size, height: size)
                .background(Color.gray.opacity(0.3), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    UndoButton(size: 36) {}
}
```

- [ ] **Step 4: `ModeButton` 생성**

`WatchApp/Features/Round/Counter/Components/ModeButton.swift`:

```swift
import SwiftUI

/// 스윙/퍼팅 전환 버튼 (spec §5).
///
/// 폭이 넉넉하면 알약("스윙 모드"), 좁으면 원형("스윙")으로 떨어진다.
/// 알약 변형에 `maxWidth: .infinity`를 주면 `ViewThatFits`가 언제나 "들어간다"고
/// 판정해 좁은 화면에서 라벨이 잘리므로, 고정 폭을 준다.
///
/// 글자·테두리 색이 링 세그먼트 색과 같다. 색이 "모드"라는 단어 역할을 대신하므로
/// 두 글자로 줄어도 의미가 유지되고, 단일 토글 버튼의 모호함
/// ("현재 상태인가 누르면 갈 곳인가")이 해소된다.
struct ModeButton: View {
    @Binding var mode: StrokeInputMode
    let sizing: CounterSizing

    var body: some View {
        Button(action: toggle) {
            ViewThatFits(in: .horizontal) {
                label(text: wideTitle, width: sizing.modeWideWidth)
                label(text: compactTitle, width: sizing.modeHeight)
            }
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        mode == .swing ? .green : .orange
    }

    private var wideTitle: String {
        mode == .swing ? "스윙 모드" : "퍼팅 모드"
    }

    private var compactTitle: String {
        mode == .swing ? "스윙" : "퍼팅"
    }

    private func toggle() {
        mode = mode == .swing ? .putt : .swing
    }

    /// width == modeHeight이면 Capsule이 정확히 원이 된다.
    private func label(text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: sizing.headerFont, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .frame(width: width, height: sizing.modeHeight)
            .background(tint.opacity(0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.7), lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 12) {
        ModeButton(mode: .constant(.swing), sizing: .regular)
        ModeButton(mode: .constant(.putt), sizing: .tight)
    }
}
```

- [ ] **Step 5: `CounterHeader` 생성**

`WatchApp/Features/Round/Counter/Components/CounterHeader.swift`:

```swift
import SwiftUI

/// 상단 정보행 — 양끝이 원형 버튼(Par·취소), 가운데가 텍스트다 (spec §5).
///
/// 취소가 사라져도 가운데 텍스트가 밀리면 안 되므로, 취소가 없을 때는 같은 크기의
/// 투명 자리채움을 둔다. `RoundSessionView`가 워크아웃 탭에서 쓰는 방식과 같다.
///
/// 누적 타수에 `+`를 붙이지 않는다. 골프에서 `+`는 오버파를 뜻하므로 `+41`은
/// "41 오버"로 읽히고, 링 안의 파 대비 표시와 부호가 겹친다.
struct CounterHeader: View {
    let holeNumber: Int
    let par: Int
    let totalStrokes: Int
    let canUndo: Bool
    let sizing: CounterSizing
    let onEditPar: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: sizing.spacing) {
            parButton
            Spacer(minLength: 0)
            Text(centerTitle)
                .font(.system(size: sizing.headerFont, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            undoSlot
        }
        .frame(height: sizing.headerHeight)
    }

    private var centerTitle: String {
        let hole = sizing.usesShortHoleLabel ? "H\(holeNumber)" : "\(holeNumber)번 홀"
        return "\(hole) · \(totalStrokes)타"
    }

    private var parButton: some View {
        Button(action: onEditPar) {
            VStack(spacing: 0) {
                Text("Par")
                    .font(.system(size: sizing.headerFont * 0.6, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(par)")
                    .font(.system(size: sizing.headerFont, weight: .semibold))
            }
            .frame(width: sizing.parButtonSize, height: sizing.parButtonSize)
            .background(Color.gray.opacity(0.25), in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var undoSlot: some View {
        if canUndo {
            UndoButton(size: sizing.undoSize, action: onUndo)
        } else {
            Color.clear
                .frame(width: sizing.undoSize, height: sizing.undoSize)
        }
    }
}

#Preview {
    VStack {
        CounterHeader(holeNumber: 7, par: 4, totalStrokes: 41, canUndo: true,
                      sizing: .regular, onEditPar: {}, onUndo: {})
        CounterHeader(holeNumber: 7, par: 4, totalStrokes: 41, canUndo: false,
                      sizing: .tight, onEditPar: {}, onUndo: {})
    }
}
```

- [ ] **Step 6: `CounterControls` 생성**

`WatchApp/Features/Round/Counter/Components/CounterControls.swift`:

```swift
import SwiftUI

/// 하단 조작행 — 이전 홀 · 모드 · 다음 홀 (spec §5).
/// 하단 중앙이 엄지가 가장 닿기 쉬운 자리라 가장 자주 쓰는 모드 전환을 거기 둔다.
struct CounterControls: View {
    @Binding var mode: StrokeInputMode
    let canGoToPrevious: Bool
    let sizing: CounterSizing
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: sizing.spacing) {
            arrow(systemName: "chevron.left", action: onPrevious)
                .disabled(!canGoToPrevious)
                .opacity(canGoToPrevious ? 1 : 0.35)

            ModeButton(mode: $mode, sizing: sizing)

            arrow(systemName: "chevron.right", action: onNext)
        }
        .frame(height: sizing.modeHeight)
    }

    private func arrow(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: sizing.arrowSize * 0.4, weight: .semibold))
                .frame(width: sizing.arrowSize, height: sizing.arrowSize)
                .background(Color.gray.opacity(0.25), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CounterControls(mode: .constant(.swing), canGoToPrevious: false,
                    sizing: .regular, onPrevious: {}, onNext: {})
}
```

- [ ] **Step 7: 빌드 + 테스트 확인**

Run:
```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`, 테스트 73건 PASS (신규 컴포넌트는 아직 아무도 안 쓰므로 동작 변화 없음)

- [ ] **Step 8: Xcode Preview로 컴포넌트 눈으로 확인**

Xcode에서 다음 파일을 열고 Canvas를 켠다:

| 파일 | 확인할 것 |
|---|---|
| `StrokeRing.swift` | regular는 4칸 중 3칸 초록 / tight는 4칸 채움 + 바깥에 주황 1칸 |
| `ModeButton.swift` | 알약이고 초록. 눌러서 주황 "퍼팅 모드"로 바뀌는지 |
| `CounterHeader.swift` | 위는 취소 있음 / 아래(tight)는 취소 없이도 가운데 "H7 · 41타"가 중앙 유지 |
| `CounterControls.swift` | 이전 화살표가 흐림(첫 홀), 모드가 알약 |

- [ ] **Step 9: 린트 + 커밋**

```bash
make fix && make lint && make format
git add WatchApp/Features/Round/Counter/Components/
git commit -m "$(cat <<'EOF'
✨ feat: 링 카운터 뷰 컴포넌트 5개 추가

아직 CounterPage가 쓰지 않는 상태로 먼저 넣는다 — 빌드가 계속 통과한다.

- StrokeRing: 파 칸수로 나뉜 링, 초과분은 바깥 얇은 링
- UndoButton: 원형 아이콘 (tennis 캡슐 필은 링을 가려서 채택 안 함)
- ModeButton: ViewThatFits로 알약/원형 전환, 색이 링 세그먼트와 동일
- CounterHeader: 양끝 원형 버튼 + 가운데 텍스트, 취소 없을 때 자리 예약
- CounterControls: 이전 · 모드 · 다음
- CounterSizing: 새 필드 추가 (구 필드는 CounterPage 재작성까지 유지)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: CounterPage 재작성 + 구 코드 정리

새 컴포넌트로 갈아끼우고 대체된 것들을 한꺼번에 지운다. 여기서 빌드가 한 번 깨졌다가 복구되므로 스텝 순서를 지킨다.

**Files:**
- Modify: `WatchApp/Features/Round/Counter/Components/CounterPage.swift` (전체 교체)
- Delete: `WatchApp/Features/Round/Counter/Components/StrokeButton.swift`
- Delete: `WatchApp/Features/Round/Counter/Components/HoleNavigation.swift`
- Delete: `WatchApp/Features/Round/Counter/Components/ModeToggle.swift`
- Modify: `WatchApp/Features/Round/Counter/Components/CounterSizing.swift` (구 필드 제거)
- Modify: `WatchApp/Features/Round/RoundViewModel.swift` (`decrementStroke()` 제거)
- Modify: `watchosTests/Round/RoundViewModelTests.swift` (감소 테스트 5건 제거)
- Modify: `watchosTests/Round/RoundViewModelSnapshotTests.swift` (감소 스냅샷 테스트 1건 제거)
- Modify: `watchosTests/Round/CounterSizingTests.swift` (전체 교체)

**Interfaces:**
- Consumes: `CounterHeader` · `StrokeRing` · `CounterControls` (Task 4), `RingSegments` (Task 2), `RoundViewModel.canUndo`/`.undo()` (Task 3)
- Produces: `CounterPage(viewModel: RoundViewModel, sizing: CounterSizing)` — 시그니처는 기존과 동일하므로 `CounterView`는 안 바뀐다

- [ ] **Step 1: `CounterPage` 전체 교체**

`WatchApp/Features/Round/Counter/Components/CounterPage.swift`:

```swift
import SwiftUI
import WatchKit

/// 카운터의 세로 1페이지 — 상단 정보행 · 링 · 하단 조작행 세 블록이다 (spec §5).
///
/// 어떤 크기 세트를 쓸지는 이 뷰가 정하지 않는다. `CounterView`의 `ViewThatFits`가
/// 화면에 실제로 들어가는 세트를 골라 `sizing`으로 넘겨준다.
struct CounterPage: View {
    @ObservedObject var viewModel: RoundViewModel
    let sizing: CounterSizing

    /// Always-On(손목 내림) 상태에서는 애니메이션을 돌리지 않는다.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        VStack(spacing: sizing.spacing) {
            CounterHeader(holeNumber: viewModel.currentHoleNumber,
                          par: viewModel.currentPar,
                          totalStrokes: viewModel.totalStrokes,
                          canUndo: viewModel.canUndo,
                          sizing: sizing,
                          onEditPar: viewModel.beginParEditing,
                          onUndo: undo)

            ringArea

            CounterControls(mode: $viewModel.inputMode,
                            canGoToPrevious: viewModel.canGoToPreviousHole,
                            sizing: sizing,
                            onPrevious: viewModel.goToPreviousHole,
                            onNext: viewModel.goToNextHole)
        }
        .padding(.horizontal, 4)
        .animation(fillAnimation, value: viewModel.currentScore)
        .animation(fillAnimation, value: viewModel.canUndo)
    }

    /// 한 홀에 연속으로 여러 번 누를 수 있어 길면 다음 탭에서 애니메이션이 겹쳐 밀린다.
    /// 값 기반이라 진행 중 새 값이 들어오면 그쪽으로 바로 따라간다.
    private var fillAnimation: Animation? {
        isLuminanceReduced ? nil : .easeOut(duration: 0.18)
    }

    /// 링 · 가운데 숫자 · 탭 타깃을 겹쳐 놓는다.
    /// 탭 타깃은 맨 위에 두되 링 안쪽 원반으로 한정한다 — 링 호와 그 바깥은 탭 영역이 아니다.
    private var ringArea: some View {
        ZStack {
            StrokeRing(segments: segments, sizing: sizing)

            VStack(spacing: 0) {
                Text("\(viewModel.currentScore)")
                    .font(.system(size: sizing.scoreFont, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text(ScoreFormat.relativeToPar(viewModel.relativeToPar))
                    .font(.system(size: sizing.relativeFont, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Circle()
                .fill(.clear)
                .contentShape(Circle())
                .frame(width: sizing.innerDiameter, height: sizing.innerDiameter)
                .onTapGesture(perform: addStroke)
        }
    }

    private var segments: RingSegments {
        RingSegments(par: viewModel.currentPar,
                     strokes: viewModel.currentScore,
                     putts: viewModel.currentPutts)
    }

    private func addStroke() {
        viewModel.incrementStroke()
        WKInterfaceDevice.current().play(.click)
    }

    private func undo() {
        viewModel.undo()
        WKInterfaceDevice.current().play(.directionDown)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CounterPage(viewModel: viewModel, sizing: .regular)
}
```

- [ ] **Step 2: 대체된 컴포넌트 3개 삭제**

```bash
rm WatchApp/Features/Round/Counter/Components/StrokeButton.swift
rm WatchApp/Features/Round/Counter/Components/HoleNavigation.swift
rm WatchApp/Features/Round/Counter/Components/ModeToggle.swift
```

- [ ] **Step 3: `CounterSizing`에서 구 필드 제거**

`CounterSizing.swift`에서 다음을 지운다:
- `// MARK: 구 레이아웃 필드 (CounterPage 재작성 시 제거)` 블록의 `strokeButton` · `strokeIcon` · `controlHeight` · `navHeight` 선언 4줄
- `regular` · `compact` · `tight` 각 이니셜라이저의 마지막 인자 4개 (`strokeButton:` `strokeIcon:` `controlHeight:` `navHeight:`)

예를 들어 `regular`는 이렇게 끝난다:

```swift
    static let regular = CounterSizing(headerHeight: 36,
                                       headerFont: 14,
                                       parButtonSize: 36,
                                       undoSize: 36,
                                       usesShortHoleLabel: false,
                                       ringDiameter: 132,
                                       ringStroke: 11,
                                       overflowStroke: 5,
                                       overflowGap: 4,
                                       scoreFont: 40,
                                       relativeFont: 13,
                                       arrowSize: 40,
                                       modeHeight: 48,
                                       modeWideWidth: 100,
                                       spacing: 6)
```

- [ ] **Step 4: `RoundViewModel.decrementStroke()` 제거**

`WatchApp/Features/Round/RoundViewModel.swift`에서 아래 메서드 전체를 지운다:

```swift
    func decrementStroke() {
        switch inputMode {
        case .swing:
            // 퍼팅은 타수에 포함되는 개념이라, 타수가 퍼팅 수 아래로 내려갈 수 없다.
            // puttCounts는 항상 0 이상이므로 하한 0도 이 식이 함께 보장한다.
            holeScores[currentHoleIndex] = max(holeScores[currentHoleIndex] - 1, puttCounts[currentHoleIndex])
        case .putt:
            guard puttCounts[currentHoleIndex] > 0 else { return }
            holeScores[currentHoleIndex] -= 1
            puttCounts[currentHoleIndex] -= 1
        }
        publishSnapshot()
    }
```

- [ ] **Step 5: 감소 테스트 제거**

`watchosTests/Round/RoundViewModelTests.swift`에서 아래 5개 `@Test` 함수를 통째로 지운다:
- `스윙모드_감소는_타수를_내린다`
- `스윙모드_감소는_퍼팅수_아래로_내려가지_않는다`
- `스윙모드_감소는_0아래로_내려가지_않는다`
- `퍼팅모드_감소는_타수와_퍼팅을_함께_내린다`
- `퍼팅이_0이면_퍼팅모드_감소는_아무것도_바꾸지_않는다`

`watchosTests/Round/RoundViewModelSnapshotTests.swift`에서 아래 1개를 지운다:
- `타수를_내리면_스냅샷을_발행한다`

되돌리기 쪽 동등한 케이스는 Task 3의 `RoundViewModelUndoTests`가 이미 덮고 있다.

- [ ] **Step 6: `CounterSizingTests` 전체 교체**

`watchosTests/Round/CounterSizingTests.swift`:

```swift
import CoreGraphics
@testable import GolfCounter_Watch_App
import Testing

struct CounterSizingTests {
    private let sets: [CounterSizing] = [.regular, .compact, .tight]

    /// ViewThatFits는 regular → compact → tight 순으로 시도해 첫 번째로 들어가는 것을 고른다.
    /// 뒤 세트가 앞 세트보다 큰 값이 하나라도 있으면 그 순서가 의미를 잃는다.
    @Test func 크기세트는_regular에서_tight로_갈수록_모든_값이_작아진다() {
        for (larger, smaller) in zip(sets, sets.dropFirst()) {
            #expect(smaller.headerHeight < larger.headerHeight)
            #expect(smaller.headerFont < larger.headerFont)
            #expect(smaller.parButtonSize < larger.parButtonSize)
            #expect(smaller.undoSize < larger.undoSize)
            #expect(smaller.ringDiameter < larger.ringDiameter)
            #expect(smaller.ringStroke < larger.ringStroke)
            #expect(smaller.overflowStroke < larger.overflowStroke)
            #expect(smaller.overflowGap < larger.overflowGap)
            #expect(smaller.scoreFont < larger.scoreFont)
            #expect(smaller.relativeFont < larger.relativeFont)
            #expect(smaller.arrowSize < larger.arrowSize)
            #expect(smaller.modeHeight < larger.modeHeight)
            #expect(smaller.modeWideWidth < larger.modeWideWidth)
            #expect(smaller.spacing < larger.spacing)
        }
    }

    /// 링 안쪽 원반은 라운드 중 가장 많이 눌리는 탭 타깃이다.
    /// 가장 작은 세트에서도 Apple 권장 최소 44pt 아래로 내려가면 안 된다.
    @Test func 가장_작은_크기세트도_링_안쪽_원반이_44pt_이상이다() {
        #expect(CounterSizing.tight.innerDiameter >= 44)
    }

    /// 취소와 Par는 헤더 안에 들어가므로 헤더 높이를 넘으면 행이 삐져나온다.
    @Test func 헤더_버튼은_헤더_높이를_넘지_않는다() {
        for sizing in sets {
            #expect(sizing.parButtonSize <= sizing.headerHeight)
            #expect(sizing.undoSize <= sizing.headerHeight)
        }
    }

    /// 알약 변형이 원형보다 좁으면 ViewThatFits의 두 후보 순서가 뒤집힌다.
    @Test func 알약_모드버튼은_원형보다_넓다() {
        for sizing in sets {
            #expect(sizing.modeWideWidth > sizing.modeHeight)
        }
    }

    /// 40mm에서만 헤더를 축약한다 — 나머지는 전체 표기가 들어간다.
    @Test func 헤더_축약은_가장_작은_세트에서만_켜진다() {
        #expect(CounterSizing.regular.usesShortHoleLabel == false)
        #expect(CounterSizing.compact.usesShortHoleLabel == false)
        #expect(CounterSizing.tight.usesShortHoleLabel)
    }
}
```

- [ ] **Step 7: 빌드 + 테스트 확인**

Run:
```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`, 73 − 6 + 3 = **70건** PASS

(`CounterSizingTests`가 2건 → 5건으로 늘어 +3)

- [ ] **Step 8: 46mm 시뮬레이터에서 눈으로 확인**

Xcode에서 Run(46mm) 후:

| 확인 항목 | 기대 |
|---|---|
| 라운드 시작 → 파 4 선택 | 헤더에 `Par 4` · `1번 홀 · 0타`, 취소 버튼 **없음** |
| 링 안쪽을 탭 | 숫자 1, 링 첫 칸이 초록으로 차오름, 헤더 오른쪽에 취소 등장 |
| 링 호(테두리)를 탭 | 아무 일도 안 일어남 |
| 취소 탭 | 숫자 0, 링 비고, 취소 사라짐 |
| 모드 버튼 탭 | 주황 "퍼팅 모드"로 바뀜 |
| 퍼팅 모드로 탭 | 링 칸이 주황으로 차오름 |
| 파 4에서 5번 탭 | 바깥에 얇은 링 1칸이 생김 |
| Par 버튼 탭 | 파 선택 화면으로 전환 |
| 다음/이전 화살표 | 홀 이동, 이동 후 취소 버튼 사라짐 |

- [ ] **Step 9: 40mm 시뮬레이터에서 tight 세트 확인 (spec §10 실측)**

Xcode 스킴 destination을 `Apple Watch SE 3 (40mm)`으로 바꿔 Run:

| 확인 항목 | 기대 | 안 맞으면 |
|---|---|---|
| 세로로 잘리는 것 없음 | 헤더·링·조작행이 다 보임 | `CounterSizing.tight.ringDiameter`를 줄인다 |
| 헤더 가운데 | `H7 · 41타`로 축약되어 안 잘림 | `headerFont`를 줄이거나 `minimumScaleFactor` 조정 |
| 모드 버튼 | **원형**으로 떨어짐 | `modeWideWidth`를 키운다 |
| 링이 가로로 안 잘림 | 초과 링까지 화면 안 | `ringDiameter` 또는 `overflowGap`을 줄인다 |

조정했다면 `CounterSizingTests`가 여전히 통과하는지 다시 확인한다 (단조 감소·44pt·헤더 높이 제약).

- [ ] **Step 10: 린트 + 커밋**

```bash
make fix && make lint && make format
git add -A WatchApp/Features/Round/ watchosTests/Round/
git commit -m "$(cat <<'EOF'
♻️ refactor: CounterPage를 링 레이아웃으로 재작성

＋/－ 두 버튼을 링 안쪽 원반 탭 하나로 합치고, －를 여러 단계 취소로 대체한다.
블록이 5개에서 3개로 줄어 작은 워치에서 링을 크게 쓸 수 있다.

- CounterPage: 헤더 / 링 / 조작행 3블록, 햅틱·애니메이션 배선
- StrokeButton · HoleNavigation · ModeToggle 삭제
- RoundViewModel.decrementStroke() 삭제 (취소가 대체)
- CounterSizing 구 필드 제거, 테스트를 새 제약으로 교체

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 기존 스펙 문서 개정 + PR

이 plan이 두 개의 기존 설계 문서를 낡게 만들었다. spec §12에 적힌 대로 고친다.

**Files:**
- Modify: `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` (§4)
- Modify: `docs/superpowers/specs/2026-08-09-rallikit-adoption-and-counter-paging-design.md` (§6)

**Interfaces:**
- Consumes: 없음 (문서 작업)
- Produces: 없음

- [ ] **Step 1: `2026-07-31` §4의 카운터 다이어그램 교체**

`## 4. 워치 화면 흐름` → `**페이지 2/3 메인 카운터 (기본 화면)**:` 아래의 ASCII 블록과 그 뒤 설명 문단을 아래로 교체한다:

````markdown
**페이지 2/3 메인 카운터 (기본 화면)**:

```
┌────────────────────────┐
│ (Par 4) 7번 홀·41타 (↩) │  상단 — 양끝이 버튼, 가운데는 정보
│      ╭───────────╮      │
│      │     5     │      │  링 — 파 칸수만큼 분할
│      │    +3     │      │  안쪽 원반 탭 = 스트로크 +1
│      ╰───────────╯      │
│  ( ‹ ) [스윙 모드] ( › ) │  하단 조작행
└────────────────────────┘
```

- 링 한 바퀴가 파고 타수 하나가 한 칸이다. 스윙은 초록, 퍼팅은 주황이며, 파를 넘긴 타수는 바깥 얇은 링으로 덧그린다.
- `＋`/`－` 두 버튼은 링 안쪽 원반 탭 하나로 합쳐졌다. `－`는 **여러 단계 취소**로 대체되었고, 취소 스코프는 현재 홀이다.
- 크라운을 돌리면 세로 페이지가 넘어가며 전체 스코어카드가 나온다 — 모달 아님. `TabView` + `.tabViewStyle(.verticalPage)`이고 스코어카드는 **9홀씩** 나뉘어, 9홀 라운드는 총 2페이지·18홀은 3페이지가 된다. 시스템이 세로 점 인디케이터를 그려준다.
- 작은 워치 대응은 `ViewThatFits`가 세 크기 세트 중 화면에 들어가는 것을 골라 처리한다 (기기 모델 분기 없음).

자세한 레이아웃·링 규칙·취소 모델은 `2026-08-11-watch-counter-redesign-design.md` 참조.

```
H1  Par3  4타(2p)  +1
H2  Par4  3타(1p)  -1
...
합계 41타 · 12퍼트 · +3
```
````

- [ ] **Step 2: `2026-08-09` §6에 번복 사실 명시**

`## 6. 파트 C — 카운터 크라운 페이징` 바로 아래(`### 구조` 앞)에 아래 문단을 삽입한다:

```markdown
> **⚠️ 이 절은 `2026-08-11-watch-counter-redesign-design.md`가 개정했다.**
>
> 아래의 `ScrollView` + `.scrollTargetBehavior(.paging)` 구조와 "세로 `TabView` 중첩 기각" 결정은 **번복되었다.** 현재 구현은 `TabView` + `.tabViewStyle(.verticalPage)` 중첩이며, 스코어카드를 9홀씩 나눠 페이지 안에 스크롤을 두지 않는다.
>
> 번복 근거: 중첩 기각은 *스코어카드가 페이지 안에서 스크롤된다*는 전제 위에 있었는데, 9홀 청킹으로 그 전제가 사라져 크라운을 쓰는 주체가 페이지 전환 하나뿐이 되었다. 자세한 내용은 개정 문서 §4 참조.
>
> 아래 `### 작은 화면 대응`의 `CounterSizing` 표도 개정 문서 §10이 대체한다 — 카운터 레이아웃이 바뀌면서 필드가 전부 교체되었다.
```

- [ ] **Step 3: 문서 커밋**

```bash
git add docs/superpowers/specs/
git commit -m "$(cat <<'EOF'
📝 docs: 카운터 재설계에 맞춰 기존 스펙 두 건 개정

- 2026-07-31 §4: 카운터 다이어그램을 링 레이아웃으로, 세로 페이징을
  TabView(.verticalPage) + 9홀 청킹으로 갱신
- 2026-08-09 §6: 세로 TabView 중첩 기각이 번복되었음과 근거를 명시,
  CounterSizing 표가 대체되었음을 표시

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: 최종 전체 검증**

```bash
make lint && make format
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' test 2>&1 | tail -20
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | tail -5
```

Expected: 린트 위반 0, watchOS 테스트 **70건 PASS**, iOS·컴플리케이션 빌드 성공

iOS와 컴플리케이션까지 확인하는 이유: `Shared/`는 세 타깃 모두에 동기화되므로, 실수로 `Shared/`를 건드렸거나 `WatchApp/`에 둬야 할 것을 잘못 놓으면 여기서 드러난다.

- [ ] **Step 5: PR 생성**

```bash
git push -u origin feature/watch-counter-redesign
gh pr create --title "✨ 워치 카운터 재설계 — 링 카운터 + 세로 페이지 인디케이터" --body "$(cat <<'EOF'
## 요약

카운터 화면을 링 기반 3블록 레이아웃으로 바꾸고, 세로 페이징에 시스템 점 인디케이터를 붙인다.

스펙: `docs/superpowers/specs/2026-08-11-watch-counter-redesign-design.md`

## 무엇이 바뀌나

- **세로 페이징**: `ScrollView` + `.paging` → `TabView` + `.verticalPage`. 스코어카드를 9홀씩 나눠 페이지 안에 스크롤을 두지 않는다
- **입력**: `＋`/`－` 두 버튼 → 링 안쪽 원반 탭 하나. `－`는 여러 단계 취소로 대체
- **링**: 한 바퀴가 파, 타수 하나가 한 칸. 스윙 초록 / 퍼팅 주황, 초과분은 바깥 얇은 링
- **레이아웃**: 블록 5개 → 3개 (상단 정보행 / 링 / 하단 조작행)

## 되돌린 결정

2026-08-09 설계가 세로 `TabView` 중첩을 "크라운 소유권 다툼"을 이유로 기각했으나, 그 판단은 스코어카드가 페이지 안에서 스크롤된다는 전제 위에 있었다. 9홀 청킹으로 전제가 사라져 번복했다. 근거는 스펙 §4에 있고, 기존 문서에도 표시했다.

## 알려진 한계

모델이 입력 순서를 저장하지 않아 링은 항상 스윙을 먼저 그린다. 퍼팅 후 다시 스윙을 넣으면 주황 칸이 한 번 밀린다. `RoundSnapshot`(컴플리케이션 공유)까지 바꿔야 해서 감수했다 — 스펙 §6 참조.

## 검증

- watchosTests 51 → 70건
- 46mm / 40mm 시뮬레이터에서 크라운 페이징·가로 스와이프·링 채움·취소 등장/퇴장 확인
- iOS·컴플리케이션 타깃 빌드 확인 (`Shared/` 미변경 확인용)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review

**1. Spec coverage**

| spec 섹션 | 태스크 |
|---|---|
| §4 세로 페이징 · 9홀 청킹 · 시뮬레이터 검증 · 폴백 | Task 1 |
| §5 상단 정보행 | Task 4 (`CounterHeader`), Task 5 (배선) |
| §5 링 영역 · 탭 타깃 한정 | Task 5 (`ringArea`, `innerDiameter`) |
| §5 취소 버튼 · 레이아웃 안정성 | Task 4 (`UndoButton`, `undoSlot`) |
| §5 하단 조작행 · 모드 반응형 | Task 4 (`CounterControls`, `ModeButton`) |
| §6 링 렌더링 · 초과 처리 · 순수 타입 분리 | Task 2, Task 4 (`StrokeRing`) |
| §7 취소 모델 · 스코프 · 복구 · 파 재선택 | Task 3 |
| §8 애니메이션 · Always-On · 햅틱 | Task 5 (`fillAnimation`, `addStroke`, `undo`) |
| §9 파일 변경 (신규 6 · 재작성 5 · 삭제 3) | Task 1~5 |
| §10 CounterSizing · 링 크기 제약 · 헤더 축약 | Task 4, Task 5 Step 9 |
| §11 테스트 | Task 1~3, Task 5 |
| §12 기존 스펙 개정 | Task 6 |
| §13 범위 밖 | 해당 없음 |

spec §9가 `RingSegments.swift`만 순수 타입으로 명시했으나, 9홀 청킹도 같은 이유(뷰가 아니라 계산)로 `ScorecardChunks.swift`를 추가했다. spec에 없는 파일이지만 §4의 청킹 요구를 테스트 가능하게 만드는 것이라 범위 안이다.

**2. Placeholder scan** — "TBD"·"적절히"·"비슷하게" 없음. 모든 코드 스텝에 실제 코드가 있다. Task 5 Step 3·5는 삭제 대상을 이름으로 특정했다.

**3. Type consistency**

- `RingSegments(par:strokes:putts:)` — Task 2 정의, Task 4(`StrokeRing` Preview)·Task 5(`segments`)에서 같은 시그니처로 호출 ✓
- `RingSegments.Kind` `.swing`/`.putt`/`.empty` — Task 2·4에서 일치 ✓
- `RingSegments.slots`/`.overflow` — Task 2·4 일치 ✓
- `ScorecardChunks.ranges(holeCount:)` — Task 1 정의·사용 일치 ✓
- `Scorecard(snapshot:holeRange:showsTotal:)` — Task 1 정의·사용 일치 ✓
- `RoundViewModel.canUndo`/`.undo()` — Task 3 정의, Task 5에서 사용 ✓
- `CounterSizing.innerDiameter` — Task 4 정의, Task 5(`ringArea`)·Task 5 Step 6(테스트) 사용 ✓
- `CounterSizing.outerRadius` — Task 4 정의, `StrokeRing.body` 사용 ✓
- `CounterPage(viewModel:sizing:)` — Task 1의 `CounterView`가 쓰는 시그니처와 Task 5 재작성본이 동일 ✓
- `viewModel.totalStrokes`·`.relativeToPar`·`.currentPar`·`.currentPutts` — 모두 `RoundViewModel`에 기존 존재 ✓
