# ⑤ ios: 라운드 수신 + 기록 탭 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워치가 보낸 `RoundCompletedMessage`를 iOS가 받아 SwiftData에 저장하고, 기록 탭에서 라운드를 열람·정정·삭제할 수 있게 한다.

**Architecture:** 수신은 두 겹으로 나눈다 — `RoundReceiveService`가 `ConnectivityService` 등록만 맡고, 실제 적재·중복 검사는 WatchConnectivity를 모르는 `RoundImporter`가 하므로 인메모리 컨테이너로 테스트할 수 있다. 화면은 `@Query` 직결이고 페이징이 없다(골프는 연 수십 라운드 규모). 홀 편집의 불변식은 `RoundEditViewModel`(UI 프레임워크 import 없음)에 모아 두고 시트는 그 상태를 그리기만 한다.

**Tech Stack:** Swift 5(language mode) / SwiftUI / SwiftData / ralli-kit(`ConnectivityCore`·`PersistenceCore`, 원격 SPM `https://github.com/qlrogo91lp/ralli-kit.git` branch `main`) / Swift Testing

**참조 spec:** `docs/superpowers/specs/2026-08-13-ios-history-stats-design.md` (§2 화면 구조, §3 용어·집계 규칙, §4 기록 탭, §6 데이터 흐름, §7 파일 구조, §8 에러 처리, §9 테스트)

**선행 plan:** ④ `docs/superpowers/plans/2026-08-05-watch-round-transmission.md` — **반드시 먼저 머지되어 있어야 한다.** 이 plan은 ④가 만드는 `RoundCompletedMessage`·`RoundMetrics`·`RoundSnapshot.id/holeCount`를 그대로 쓴다. ④가 없으면 Task 2부터 컴파일되지 않는다.

**후속 plan:** ⑥ `2026-08-13-ios-stats.md` (통계 탭) — 이 plan이 만드는 `GolfRound.isFullRound`·`StatCard`·`EmptyRoundsView`·`ScorePalette`를 재사용한다.

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0** (ralli-kit 최소 요구)
- `DEVELOPMENT_TEAM = P2TU28W32L`, App Group `group.com.yj.GolfCounter`
- 커밋 메시지는 gitmoji prefix (`✨ feat:` / `🐛 fix:` / `♻️ refactor:` / `✅ test:` / `📝 docs:`), **main 직접 커밋 금지** — 브랜치 + PR, 머지는 `gh pr merge <n> --merge --delete-branch`
- 빌드 검증 시뮬레이터: `iPhone 17 Pro` (`xcrun simctl list devices available`로 존재 확인)
- 파일 네이밍·폴더 규칙: `CLAUDE.md` 컨벤션 — View suffix는 독립 화면만, **한 파일 = 한 타입**(private helper는 예외), 계층화 Components(앱 루트 → Feature → 화면), **ViewModel은 UI 프레임워크 import 금지**
- 테스트: Swift Testing(`@Test`/`#expect`), 테스트명은 한국어 `대상_행위_예상결과`, ViewModel 테스트는 `@MainActor`, **View는 테스트하지 않는다**
- 사용자 노출 문자열은 **한국어 하드코딩**으로 둔다 (로컬라이즈는 plan ⑦에서 세 타깃 일괄). 단 `Par`·`H`·`bpm`·`kcal`·`km`는 관용 표기로 영문 유지
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0. 자동 수정은 `make fix`
- `iOSApp/`·`iosTests/`는 `PBXFileSystemSynchronizedRootGroup`이라 **파일 생성만으로 타깃에 반영된다.** 이 plan은 pbxproj를 손대지 않는다 — iOS 타깃은 이미 `ConnectivityCore`·`PersistenceCore`를 링크하고 있고, `iOSApp/`은 iOS 전용이라 plan ④가 겪은 타깃별 링크 충돌이 없다

## 파일 구조

| 파일 | 책임 |
|------|------|
| `Shared/Persistence/GolfRound.swift` (수정) | `recordedHoleCount`·`isFullRound` 파생값 추가 |
| `iOSApp/Components/ScorePalette.swift` | 오버파 3상태(언더/이븐/오버) 색 매핑 — 디자인 확정 시 여기만 고친다 |
| `iOSApp/Components/EmptyRoundsView.swift` | "라운드 없음" 안내 — 기록·통계 두 탭이 공유 |
| `iOSApp/Components/StatCard.swift` | 제목+값 카드 — 상세 워크아웃 섹션과 통계 탭이 공유 |
| `iOSApp/Services/RoundImporter.swift` | 메시지 → `GolfRound` 적재 + id 중복 검사 (WatchConnectivity 무관, 테스트 대상) |
| `iOSApp/Services/RoundReceiveService.swift` | `ConnectivityService` 수신 등록 (얇은 배선, 테스트 안 함) |
| `iOSApp/Features/History/HistoryView.swift` | 리스트 화면 + 삭제 + 상세 push |
| `iOSApp/Features/History/Components/RoundCard.swift` | 리스트 한 행 |
| `iOSApp/Features/History/Detail/RoundDetailView.swift` | 상세 4섹션 + 골프장명 편집 + 편집 시트 표시 |
| `iOSApp/Features/History/Detail/RoundEditViewModel.swift` | 홀 편집 불변식 + 배열 되쓰기 (테스트 대상) |
| `iOSApp/Features/History/Detail/Components/HoleRow.swift` | 스코어카드 한 홀 |
| `iOSApp/Features/History/Detail/Components/HoleEditSheet.swift` | 홀 편집 시트 |
| `iOSApp/Features/History/Detail/Components/WorkoutMetricsGrid.swift` | 워크아웃 메트릭 그리드 |
| `iOSApp/iOSApp.swift` (수정) | placeholder 제거, 수신 서비스 기동 + `HistoryView` 표시 |

`MainTabView`는 이 plan에서 만들지 않는다. 통계 탭이 없는 동안 탭이 하나뿐인 `TabView`를 두는 것보다, 앱 루트가 `HistoryView`를 바로 띄우고 plan ⑥에서 탭 구조를 도입하는 편이 깔끔하다.

---

### Task 1: `GolfRound`에 홀 수 파생값 추가

**Files:**
- Modify: `Shared/Persistence/GolfRound.swift`
- Test: `iosTests/Shared/GolfRoundTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: `GolfRound.recordedHoleCount: Int` (파가 기록된 홀 수), `GolfRound.isFullRound: Bool` (`recordedHoleCount == 18`)

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Shared/GolfRoundTests.swift`의 마지막 `}` 앞에 테스트 3개를 추가한다.

```swift
    @Test func recordedHoleCount_파가있는홀만_센다() {
        let round = GolfRound()
        round.holeScores = [4, 3, 0, 5]
        // 3번째 홀은 워치에서 건너뛴 홀 — par 0이라 세지 않는다.
        round.holePars = [4, 3, 0, 5]
        round.puttCounts = [2, 1, 0, 2]

        #expect(round.recordedHoleCount == 3)
        #expect(round.isFullRound == false)
    }

    @Test func isFullRound_파가18개면_참이다() {
        let round = GolfRound()
        round.holeScores = Array(repeating: 5, count: 18)
        round.holePars = Array(repeating: 4, count: 18)
        round.puttCounts = Array(repeating: 2, count: 18)

        #expect(round.recordedHoleCount == 18)
        #expect(round.isFullRound == true)
    }

    @Test func isFullRound_18홀중_일부만기록되면_거짓이다() {
        let round = GolfRound()
        round.holeScores = Array(repeating: 5, count: 9)
        round.holePars = Array(repeating: 4, count: 9)
        round.puttCounts = Array(repeating: 2, count: 9)

        #expect(round.recordedHoleCount == 9)
        #expect(round.isFullRound == false)
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 컴파일 실패 — `value of type 'GolfRound' has no member 'recordedHoleCount'`

- [ ] **Step 3: 파생 프로퍼티 추가**

`Shared/Persistence/GolfRound.swift`의 `relativeToPar` 아래(닫는 `}` 앞)에 추가한다.

```swift
    /// 파가 기록된 홀 수. 워치에서 건너뛴 홀(par == 0)은 세지 않는다 (spec §3).
    /// 기록 리스트의 `N홀` 뱃지와 통계의 18홀 판정이 같은 값을 쓴다.
    var recordedHoleCount: Int {
        holePars.filter { $0 > 0 }.count
    }

    /// 18홀을 끝까지 기록한 라운드. 총타수 기반 통계는 이 라운드만 집계한다 (spec §5).
    var isFullRound: Bool {
        recordedHoleCount == 18
    }
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 기존 3개 + 신규 3개 모두 PASS

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add Shared/Persistence/GolfRound.swift iosTests/Shared/GolfRoundTests.swift
git commit -m "✨ feat: GolfRound에 recordedHoleCount·isFullRound 추가"
```

---

### Task 2: `RoundImporter` — 수신 라운드 적재와 중복 검사

**Files:**
- Create: `iOSApp/Services/RoundImporter.swift`
- Test: `iosTests/Services/RoundImporterTests.swift`

**Interfaces:**
- Consumes: plan ④의 `RoundCompletedMessage(snapshot:endedAt:metrics:)`, `RoundMetrics(calories:avgHeartRate:distanceMeters:steps:)`, `RoundSnapshot(id:startedAt:courseName:holeCount:currentHoleIndex:holeScores:holePars:puttCounts:)`
- Produces: `@MainActor struct RoundImporter`, `init(context: ModelContext)`, `@discardableResult func save(_ message: RoundCompletedMessage) -> Bool` (저장했으면 true, 중복이거나 저장 실패면 false)

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Services/RoundImporterTests.swift` 신규 생성:

```swift
import Foundation
import PersistenceCore
import SwiftData
import Testing
@testable import GolfCounter

@MainActor
struct RoundImporterTests {
    private func makeContext() -> ModelContext {
        let container = PersistenceContainerFactory.make(for: [GolfRound.self],
                                                         cloudKit: false,
                                                         inMemory: true)
        return ModelContext(container)
    }

    private func makeMessage(id: UUID = UUID(), courseName: String? = nil) -> RoundCompletedMessage {
        let snapshot = RoundSnapshot(id: id,
                                     startedAt: Date(timeIntervalSince1970: 1000),
                                     courseName: courseName,
                                     holeCount: 18,
                                     currentHoleIndex: 2,
                                     holeScores: [4, 5, 3],
                                     holePars: [4, 4, 3],
                                     puttCounts: [2, 2, 1])
        return RoundCompletedMessage(snapshot: snapshot,
                                     endedAt: Date(timeIntervalSince1970: 5000),
                                     metrics: RoundMetrics(calories: 320,
                                                           avgHeartRate: 108,
                                                           distanceMeters: 6400,
                                                           steps: 9000))
    }

    private func storedRounds(in context: ModelContext) throws -> [GolfRound] {
        try context.fetch(FetchDescriptor<GolfRound>())
    }

    @Test func 새메시지_전필드가_그대로저장된다() throws {
        let context = makeContext()
        let importer = RoundImporter(context: context)
        let id = UUID()

        let didSave = importer.save(makeMessage(id: id, courseName: "레이크사이드"))

        #expect(didSave == true)
        let rounds = try storedRounds(in: context)
        #expect(rounds.count == 1)
        let round = try #require(rounds.first)
        #expect(round.id == id)
        #expect(round.startedAt == Date(timeIntervalSince1970: 1000))
        #expect(round.endedAt == Date(timeIntervalSince1970: 5000))
        #expect(round.courseName == "레이크사이드")
        #expect(round.holeScores == [4, 5, 3])
        #expect(round.holePars == [4, 4, 3])
        #expect(round.puttCounts == [2, 2, 1])
        #expect(round.calories == 320)
        #expect(round.avgHeartRate == 108)
        #expect(round.distanceMeters == 6400)
        #expect(round.steps == 9000)
    }

    @Test func 같은id_재수신되면_저장하지않는다() throws {
        let context = makeContext()
        let importer = RoundImporter(context: context)
        let id = UUID()

        importer.save(makeMessage(id: id))
        let didSaveAgain = importer.save(makeMessage(id: id))

        #expect(didSaveAgain == false)
        #expect(try storedRounds(in: context).count == 1)
    }

    @Test func 다른id_수신되면_추가로저장된다() throws {
        let context = makeContext()
        let importer = RoundImporter(context: context)

        importer.save(makeMessage(id: UUID()))
        importer.save(makeMessage(id: UUID()))

        #expect(try storedRounds(in: context).count == 2)
    }

    @Test func 골프장명이없으면_nil로저장된다() throws {
        let context = makeContext()
        let importer = RoundImporter(context: context)

        importer.save(makeMessage(courseName: nil))

        let round = try #require(try storedRounds(in: context).first)
        #expect(round.courseName == nil)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'RoundImporter' in scope`

- [ ] **Step 3: `RoundImporter` 작성**

`iOSApp/Services/RoundImporter.swift` 신규 생성:

```swift
import Foundation
import SwiftData

/// 워치에서 도착한 완료 라운드를 SwiftData에 적재한다 (spec §6).
///
/// WatchConnectivity를 모르기 때문에 인메모리 컨테이너로 테스트할 수 있다 —
/// 세션 등록은 `RoundReceiveService`가 맡는다.
@MainActor
struct RoundImporter {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// 같은 `id`의 라운드가 이미 있으면 저장하지 않는다.
    /// transferUserInfo 재배달과 "전송 후 스냅샷 삭제 전 크래시 → 복구 후 재전송"을 함께 막는다 (spec §6).
    /// - Returns: 실제로 저장했으면 true. 중복이거나 저장에 실패하면 false.
    @discardableResult
    func save(_ message: RoundCompletedMessage) -> Bool {
        let id = message.id
        let descriptor = FetchDescriptor<GolfRound>(predicate: #Predicate { $0.id == id })
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return false }

        let round = GolfRound()
        round.id = message.id
        round.startedAt = message.startedAt
        round.endedAt = message.endedAt
        round.courseName = message.courseName
        round.holeScores = message.holeScores
        round.holePars = message.holePars
        round.puttCounts = message.puttCounts
        round.calories = message.metrics.calories
        round.avgHeartRate = message.metrics.avgHeartRate
        round.distanceMeters = message.metrics.distanceMeters
        round.steps = message.metrics.steps

        context.insert(round)
        do {
            try context.save()
        } catch {
            // 저장이 깨지면 반쯤 들어간 라운드를 남기지 않는다. 워치는 재전송하지 않으므로
            // 이 라운드는 유실되지만, 잘못된 레코드를 남기는 것보다 낫다 (spec §8).
            context.rollback()
            return false
        }
        return true
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: `RoundImporterTests` 4개 PASS

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add iOSApp/Services/RoundImporter.swift iosTests/Services/RoundImporterTests.swift
git commit -m "✨ feat: 수신 라운드를 SwiftData에 적재하는 RoundImporter"
```

---

### Task 3: 기록 리스트 화면

**Files:**
- Create: `iOSApp/Components/ScorePalette.swift`
- Create: `iOSApp/Components/EmptyRoundsView.swift`
- Create: `iOSApp/Features/History/Components/RoundCard.swift`
- Create: `iOSApp/Features/History/HistoryView.swift`

**Interfaces:**
- Consumes: `GolfRound.recordedHoleCount`(Task 1), `ScoreFormat.relativeToPar(_:)`(기존 `Shared/Models/ScoreFormat.swift`)
- Produces: `ScorePalette.color(for: Int) -> Color`, `EmptyRoundsView()`, `RoundCard(round:)`, `HistoryView()`

이 태스크는 View만 만든다. **View는 테스트하지 않는다**(컨벤션) — 검증은 빌드 성공으로 한다. 상세 화면은 Task 5에서 붙이므로 여기서는 `NavigationLink`를 두지 않는다.

- [ ] **Step 1: `ScorePalette` 작성**

`iOSApp/Components/ScorePalette.swift` 신규 생성:

```swift
import SwiftUI

/// 오버파 세 상태(언더파·이븐·오버파)를 색으로 구분한다 (spec §2).
/// 구체 색값은 디자인 확정 시 이 한 곳만 고치면 된다.
enum ScorePalette {
    static func color(for relativeToPar: Int) -> Color {
        if relativeToPar < 0 {
            return .blue
        }
        if relativeToPar == 0 {
            return .green
        }
        return .orange
    }
}
```

- [ ] **Step 2: `EmptyRoundsView` 작성**

`iOSApp/Components/EmptyRoundsView.swift` 신규 생성:

```swift
import SwiftUI

/// 라운드가 하나도 없을 때의 안내. 기록 탭과 통계 탭이 같은 화면을 쓴다 (spec §4·§5).
struct EmptyRoundsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("기록된 라운드가 없습니다", systemImage: "figure.golf")
        } description: {
            Text("Apple Watch에서 라운드를 시작하세요")
        }
    }
}

#Preview {
    EmptyRoundsView()
}
```

- [ ] **Step 3: `RoundCard` 작성**

`iOSApp/Features/History/Components/RoundCard.swift` 신규 생성:

```swift
import SwiftUI

/// 기록 리스트의 한 행. 오버파를 가장 크게 두고 총타수는 보조로 둔다 (spec §4).
struct RoundCard: View {
    let round: GolfRound

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // 골프장명이 없으면 행 자체를 생략한다 — "미입력" placeholder를 두지 않는다.
                if let courseName = round.courseName, !courseName.isEmpty {
                    Text(courseName)
                        .font(.headline)
                }

                Text("\(round.recordedHoleCount)홀")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ScoreFormat.relativeToPar(round.relativeToPar))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ScorePalette.color(for: round.relativeToPar))
                Text("\(round.totalStrokes)타")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let round = GolfRound()
    round.courseName = "레이크사이드"
    round.holeScores = [4, 5, 3]
    round.holePars = [4, 4, 3]
    round.puttCounts = [2, 2, 1]
    return List {
        RoundCard(round: round)
    }
}
```

- [ ] **Step 4: `HistoryView` 작성**

`iOSApp/Features/History/HistoryView.swift` 신규 생성:

```swift
import SwiftData
import SwiftUI

/// 기록 탭. 최신순 전체 로드 — 골프는 연 수십 라운드 규모라 페이징을 두지 않는다 (spec §4).
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    @State private var pendingDeletion: GolfRound?

    var body: some View {
        NavigationStack {
            Group {
                if rounds.isEmpty {
                    EmptyRoundsView()
                } else {
                    List {
                        ForEach(rounds) { round in
                            RoundCard(round: round)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        pendingDeletion = round
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("기록")
            .confirmationDialog("이 라운드를 삭제할까요?",
                                isPresented: deletionDialogBinding,
                                titleVisibility: .visible,
                                presenting: pendingDeletion)
            { round in
                Button("삭제", role: .destructive) { delete(round) }
                Button("취소", role: .cancel) { pendingDeletion = nil }
            }
        }
    }

    /// 되돌릴 수 없는 동작이라 확인 단계를 생략하지 않는다 (spec §4).
    private var deletionDialogBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { pendingDeletion = nil }
                })
    }

    private func delete(_ round: GolfRound) {
        modelContext.delete(round)
        try? modelContext.save()
        pendingDeletion = nil
    }
}
```

- [ ] **Step 5: 빌드 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 커밋**

```bash
make lint && make format
git add iOSApp/Components/ iOSApp/Features/History/
git commit -m "✨ feat: 기록 탭 리스트 화면과 공용 컴포넌트"
```

---

### Task 4: 수신 서비스 기동 + 앱 진입점 교체

**Files:**
- Create: `iOSApp/Services/RoundReceiveService.swift`
- Modify: `iOSApp/iOSApp.swift`

**Interfaces:**
- Consumes: `RoundImporter(context:)`·`save(_:)`(Task 2), `HistoryView()`(Task 3), plan ④의 `RoundCompletedMessage`
- Produces: `@MainActor final class RoundReceiveService`, `init(context: ModelContext)`

- [ ] **Step 1: `RoundReceiveService` 작성**

`iOSApp/Services/RoundReceiveService.swift` 신규 생성:

```swift
import ConnectivityCore
import Foundation
import SwiftData

/// 워치 → iOS 수신 등록. 앱 시작 시 한 번 만들어 앱이 사는 동안 살려 둔다 (spec §6).
///
/// ⚠️ `ConnectivityService`를 만든 **그 main-queue turn 안에서** `onReceive` 등록을 끝내야 한다.
/// 활성화 콜백(콜드런치 컨텍스트 배달)은 다음 turn에 main으로 들어오므로, 늦게 등록하면
/// 앱이 꺼져 있던 동안 도착한 라운드를 놓친다. 워치의 `RoundTransmitter`가 `lazy`로 미루는 것과
/// 정반대 이유다 — 그쪽은 발신 전용이라 미리 살아 있을 이유가 없다.
@MainActor
final class RoundReceiveService {
    private let service = ConnectivityService()
    private let importer: RoundImporter

    init(context: ModelContext) {
        let importer = RoundImporter(context: context)
        self.importer = importer
        // maxAge를 주지 않는다 — 며칠 뒤에 배달되는 라운드도 그대로 저장해야 한다.
        service.onReceive(RoundCompletedMessage.self) { message in
            importer.save(message)
        }
    }
}
```

- [ ] **Step 2: 앱 진입점 교체**

`iOSApp/iOSApp.swift` 전체를 교체:

```swift
import PersistenceCore
import SwiftData
import SwiftUI

@main
struct GolfCounterApp: App {
    private let container: ModelContainer
    /// 참조를 잡아 두기만 하면 된다 — 살아 있는 동안 WCSession 수신 등록이 유지된다.
    private let receiver: RoundReceiveService

    init() {
        let container = PersistenceContainerFactory.make(for: [GolfRound.self])
        self.container = container
        // App.init은 main에서 돌지만 Swift 5 모드에서는 그 사실이 타입에 드러나지 않는다.
        // 수신 등록은 콜드런치 컨텍스트를 놓치지 않도록 여기서 즉시 끝내야 한다 (RoundReceiveService 주석).
        receiver = MainActor.assumeIsolated {
            RoundReceiveService(context: ModelContext(container))
        }
    }

    var body: some Scene {
        WindowGroup {
            HistoryView()
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 3: 빌드하고 시뮬레이터에서 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

시뮬레이터에서 앱을 실행해 **빈 상태 화면**("기록된 라운드가 없습니다")이 뜨는지 확인한다. 네비게이션 타이틀은 "기록"이어야 한다.

- [ ] **Step 4: 커밋**

```bash
make lint && make format
git add iOSApp/Services/RoundReceiveService.swift iOSApp/iOSApp.swift
git commit -m "✨ feat: 라운드 수신 등록과 앱 진입점 교체"
```

---

### Task 5: 라운드 상세 화면 (읽기 전용 + 골프장명 편집)

**Files:**
- Create: `iOSApp/Components/StatCard.swift`
- Create: `iOSApp/Features/History/Detail/Components/HoleRow.swift`
- Create: `iOSApp/Features/History/Detail/Components/WorkoutMetricsGrid.swift`
- Create: `iOSApp/Features/History/Detail/RoundDetailView.swift`
- Modify: `iOSApp/Features/History/HistoryView.swift`

**Interfaces:**
- Consumes: `ScorePalette.color(for:)`·`RoundCard`(Task 3), `ScoreFormat.relativeToPar(_:)`
- Produces: `StatCard(title:value:caption:)` (`caption` 기본값 nil), `HoleRow(holeNumber:par:score:putts:)`, `WorkoutMetricsGrid(round:)`, `RoundDetailView(round:)`

- [ ] **Step 1: `StatCard` 작성**

`iOSApp/Components/StatCard.swift` 신규 생성:

```swift
import SwiftUI

/// 제목 + 값 카드. 라운드 상세의 워크아웃 섹션과 통계 탭 요약이 함께 쓴다 (spec §7).
struct StatCard: View {
    let title: String
    let value: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    StatCard(title: "평균 타수", value: "92.4", caption: "18홀 라운드 6개 기준")
        .padding()
}
```

- [ ] **Step 2: `HoleRow` 작성**

`iOSApp/Features/History/Detail/Components/HoleRow.swift` 신규 생성:

```swift
import SwiftUI

/// 상세 스코어카드의 한 홀.
/// 워치에서 건너뛴 홀(par == 0)은 오버파를 계산할 수 없으므로 "기록 없음"으로 표시한다 (spec §4).
struct HoleRow: View {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int

    private var isRecorded: Bool { par > 0 }

    var body: some View {
        HStack(spacing: 8) {
            Text("H\(holeNumber)")
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, alignment: .leading)

            Text(isRecorded ? "Par \(par)" : "Par –")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if isRecorded {
                Text("\(score)타 · \(putts)퍼트")
                    .font(.subheadline)
                Text(ScoreFormat.relativeToPar(score - par))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ScorePalette.color(for: score - par))
                    .frame(width: 34, alignment: .trailing)
            } else {
                Text("기록 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 3: `WorkoutMetricsGrid` 작성**

`iOSApp/Features/History/Detail/Components/WorkoutMetricsGrid.swift` 신규 생성:

```swift
import SwiftUI

/// 라운드 상세의 워크아웃 요약. 소요 시간은 `endedAt - startedAt`으로 파생한다 (spec §4).
struct WorkoutMetricsGrid: View {
    let round: GolfRound

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "칼로리", value: "\(Int(round.calories.rounded())) kcal")
            StatCard(title: "평균 심박", value: heartRateText)
            StatCard(title: "거리", value: String(format: "%.2f km", round.distanceMeters / 1000))
            StatCard(title: "걸음", value: "\(round.steps)")
            StatCard(title: "소요 시간", value: durationText)
        }
    }

    private var heartRateText: String {
        round.avgHeartRate > 0 ? "\(Int(round.avgHeartRate.rounded())) bpm" : "–"
    }

    private var durationText: String {
        guard let endedAt = round.endedAt else { return "–" }
        let seconds = Int(endedAt.timeIntervalSince(round.startedAt))
        guard seconds > 0 else { return "–" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)시간 \(minutes)분" : "\(minutes)분"
    }
}
```

- [ ] **Step 4: `RoundDetailView` 작성**

`iOSApp/Features/History/Detail/RoundDetailView.swift` 신규 생성:

```swift
import SwiftData
import SwiftUI

/// 라운드 상세. 시트가 아니라 push로 띄운다 — 스코어카드가 최대 18행이고
/// 그 위에 홀 편집 시트를 또 올려야 하기 때문이다 (spec §4).
struct RoundDetailView: View {
    @Bindable var round: GolfRound
    @Environment(\.modelContext) private var modelContext
    @State private var courseNameDraft = ""

    var body: some View {
        List {
            summarySection
            courseSection
            scorecardSection
            workoutSection
        }
        .navigationTitle("라운드 상세")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { courseNameDraft = round.courseName ?? "" }
        .onDisappear(perform: commitCourseName)
    }

    private var summarySection: some View {
        Section {
            VStack(spacing: 6) {
                Text(ScoreFormat.relativeToPar(round.relativeToPar))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(ScorePalette.color(for: round.relativeToPar))
                Text("\(round.totalStrokes)타 · \(round.totalPutts)퍼트")
                    .font(.headline)
                Text(round.startedAt.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    /// MapKit 자동 감지가 붙기 전(plan ⑧)까지 골프장명을 채우는 유일한 경로다 (spec §1).
    private var courseSection: some View {
        Section("골프장") {
            TextField("골프장명 입력", text: $courseNameDraft)
                .onSubmit(commitCourseName)
        }
    }

    private var scorecardSection: some View {
        Section("스코어카드") {
            ForEach(Array(round.holeScores.indices), id: \.self) { index in
                HoleRow(holeNumber: index + 1,
                        par: value(in: round.holePars, at: index),
                        score: value(in: round.holeScores, at: index),
                        putts: value(in: round.puttCounts, at: index))
            }

            HStack {
                Text("합계").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(round.totalStrokes)타 · \(round.totalPutts)퍼트")
                    .font(.subheadline)
                Text(ScoreFormat.relativeToPar(round.relativeToPar))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ScorePalette.color(for: round.relativeToPar))
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private var workoutSection: some View {
        Section("워크아웃") {
            WorkoutMetricsGrid(round: round)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    /// 배열 세 개는 병렬이지만 길이가 어긋난 과거 데이터가 있을 수 있어 방어적으로 읽는다.
    private func value(in array: [Int], at index: Int) -> Int {
        index < array.count ? array[index] : 0
    }

    /// 공백만 남기면 nil로 되돌린다 — "미입력"과 "공백 한 칸"을 다르게 저장하지 않는다 (spec §4).
    private func commitCourseName() {
        let trimmed = courseNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        round.courseName = trimmed.isEmpty ? nil : trimmed
        courseNameDraft = trimmed
        try? modelContext.save()
    }
}
```

- [ ] **Step 5: `HistoryView`에 push 연결**

`iOSApp/Features/History/HistoryView.swift`에서 `ForEach` 안의 `RoundCard(round: round)`를 `NavigationLink`로 감싼다:

```swift
                        ForEach(rounds) { round in
                            NavigationLink {
                                RoundDetailView(round: round)
                            } label: {
                                RoundCard(round: round)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDeletion = round
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
```

- [ ] **Step 6: 빌드 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 커밋**

```bash
make lint && make format
git add iOSApp/Components/StatCard.swift iOSApp/Features/History/
git commit -m "✨ feat: 라운드 상세 화면과 골프장명 수동 입력"
```

---

### Task 6: `RoundEditViewModel` — 홀 편집 불변식

**Files:**
- Create: `iOSApp/Features/History/Detail/RoundEditViewModel.swift`
- Test: `iosTests/Features/History/Detail/RoundEditViewModelTests.swift`

**Interfaces:**
- Consumes: `GolfRound`(기존)
- Produces: `struct RoundEditViewModel`, `init(par:score:putts:)`, `static let parOptions: [Int]` (= `[3, 4, 5]`), `var par/score/putts: Int` (get-only), `mutating func setPar(_:)`, `mutating func incrementScore()`, `mutating func decrementScore()`, `mutating func incrementPutts()`, `mutating func decrementPutts()`, `var canDecrementScore: Bool`, `var canDecrementPutts: Bool`, `func apply(to: GolfRound, holeIndex: Int)`

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Features/History/Detail/RoundEditViewModelTests.swift` 신규 생성:

```swift
import Foundation
import Testing
@testable import GolfCounter

@MainActor
struct RoundEditViewModelTests {
    @Test func 초기화_타수가퍼팅보다작으면_퍼팅까지올린다() {
        let model = RoundEditViewModel(par: 4, score: 1, putts: 3)

        #expect(model.score == 3)
        #expect(model.putts == 3)
    }

    @Test func 타수감소_퍼팅수아래로는_내려가지않는다() {
        var model = RoundEditViewModel(par: 4, score: 3, putts: 3)

        model.decrementScore()

        #expect(model.score == 3)
        #expect(model.canDecrementScore == false)
    }

    @Test func 타수감소_퍼팅보다크면_내려간다() {
        var model = RoundEditViewModel(par: 4, score: 5, putts: 2)

        model.decrementScore()

        #expect(model.score == 4)
        #expect(model.canDecrementScore == true)
    }

    @Test func 퍼팅증가_타수가모자라면_함께올라간다() {
        var model = RoundEditViewModel(par: 4, score: 2, putts: 2)

        model.incrementPutts()

        #expect(model.putts == 3)
        #expect(model.score == 3)
    }

    @Test func 퍼팅감소_0아래로는_내려가지않는다() {
        var model = RoundEditViewModel(par: 4, score: 3, putts: 0)

        model.decrementPutts()

        #expect(model.putts == 0)
        #expect(model.canDecrementPutts == false)
    }

    @Test func 타수증가_상한이없다() {
        var model = RoundEditViewModel(par: 3, score: 6, putts: 1)

        model.incrementScore()
        model.incrementScore()

        // par×2 제한은 폐기됐다 — 실제 골프는 초과할 수 있다 (spec §4).
        #expect(model.score == 8)
    }

    @Test func 파변경_3과4와5만_받는다() {
        var model = RoundEditViewModel(par: 4, score: 5, putts: 2)

        model.setPar(5)
        #expect(model.par == 5)

        model.setPar(7)
        #expect(model.par == 5)
    }

    @Test func 되쓰기_해당홀의_세배열을_모두갱신한다() {
        let round = GolfRound()
        round.holeScores = [4, 5, 3]
        round.holePars = [4, 4, 3]
        round.puttCounts = [2, 2, 1]
        var model = RoundEditViewModel(par: 5, score: 7, putts: 3)

        model.setPar(5)
        model.apply(to: round, holeIndex: 1)

        #expect(round.holeScores == [4, 7, 3])
        #expect(round.holePars == [4, 5, 3])
        #expect(round.puttCounts == [2, 3, 1])
    }

    @Test func 되쓰기_건너뛴홀에_파를넣으면_정상홀이된다() {
        let round = GolfRound()
        round.holeScores = [4, 0, 3]
        round.holePars = [4, 0, 3]
        round.puttCounts = [2, 0, 1]
        var model = RoundEditViewModel(par: 0, score: 0, putts: 0)

        model.setPar(4)
        model.incrementScore()
        model.apply(to: round, holeIndex: 1)

        #expect(round.holePars == [4, 4, 3])
        #expect(round.holeScores == [4, 1, 3])
        #expect(round.recordedHoleCount == 3)
    }

    @Test func 되쓰기_짧은배열은_0으로채워진다() {
        let round = GolfRound()
        round.holeScores = [4, 5, 3]
        round.holePars = [4]
        round.puttCounts = []
        var model = RoundEditViewModel(par: 3, score: 3, putts: 1)

        model.apply(to: round, holeIndex: 2)

        #expect(round.holePars == [4, 0, 3])
        #expect(round.puttCounts == [0, 0, 1])
    }

    @Test func 되쓰기_범위밖인덱스는_무시한다() {
        let round = GolfRound()
        round.holeScores = [4]
        round.holePars = [4]
        round.puttCounts = [2]
        var model = RoundEditViewModel(par: 5, score: 9, putts: 3)

        model.apply(to: round, holeIndex: 5)

        #expect(round.holeScores == [4])
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'RoundEditViewModel' in scope`

- [ ] **Step 3: `RoundEditViewModel` 작성**

`iOSApp/Features/History/Detail/RoundEditViewModel.swift` 신규 생성:

```swift
import Foundation

/// 홀 편집 시트의 상태. 워치 카운터와 같은 불변식(타수 ≥ 퍼팅 ≥ 0, 상한 없음)을 강제한다 (spec §4).
/// UI 프레임워크를 import하지 않아 시트 없이 테스트할 수 있다.
struct RoundEditViewModel: Equatable {
    /// 파 선택지. 워치 파 선택 화면과 같은 3개다.
    static let parOptions = [3, 4, 5]

    private(set) var par: Int
    private(set) var score: Int
    private(set) var putts: Int

    init(par: Int, score: Int, putts: Int) {
        self.par = max(0, par)
        self.putts = max(0, putts)
        // 깨진 데이터가 들어와도 불변식을 지킨 상태에서 편집을 시작한다.
        self.score = max(self.putts, max(0, score))
    }

    var canDecrementScore: Bool { score > putts }
    var canDecrementPutts: Bool { putts > 0 }

    mutating func setPar(_ newPar: Int) {
        guard Self.parOptions.contains(newPar) else { return }
        par = newPar
    }

    /// 상한을 두지 않는다 — par×2 제한은 폐기됐다 (spec §4).
    mutating func incrementScore() {
        score += 1
    }

    mutating func decrementScore() {
        score = max(putts, score - 1)
    }

    /// 타수가 모자라면 함께 올린다 — 워치 퍼팅 모드 `+`와 같은 동작이다.
    mutating func incrementPutts() {
        putts += 1
        score = max(score, putts)
    }

    mutating func decrementPutts() {
        putts = max(0, putts - 1)
    }

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

    private static func padded(_ array: [Int], to count: Int) -> [Int] {
        guard array.count < count else { return array }
        return array + Array(repeating: 0, count: count - array.count)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: `RoundEditViewModelTests` 11개 PASS

- [ ] **Step 5: 커밋**

```bash
make lint && make format
git add iOSApp/Features/History/Detail/RoundEditViewModel.swift \
        iosTests/Features/History/Detail/RoundEditViewModelTests.swift
git commit -m "✨ feat: 홀 편집 불변식을 담은 RoundEditViewModel"
```

---

### Task 7: 홀 편집 시트 배선

**Files:**
- Create: `iOSApp/Features/History/Detail/Components/HoleEditSheet.swift`
- Modify: `iOSApp/Features/History/Detail/RoundDetailView.swift`

**Interfaces:**
- Consumes: `RoundEditViewModel`(Task 6), `HoleRow`(Task 5)
- Produces: `HoleEditSheet(holeNumber:par:score:putts:onSave:)` — `onSave`는 `(RoundEditViewModel) -> Void`

- [ ] **Step 1: `HoleEditSheet` 작성**

`iOSApp/Features/History/Detail/Components/HoleEditSheet.swift` 신규 생성:

```swift
import SwiftUI

/// 홀 하나를 정정하는 시트. 워치 오입력의 최종 구제 지점이다 (spec §4).
/// 불변식은 전부 `RoundEditViewModel`이 강제하므로 이 뷰는 상태를 그리기만 한다 —
/// 위반 입력을 만들 수 있는 컨트롤 자체가 없다.
struct HoleEditSheet: View {
    let holeNumber: Int
    let onSave: (RoundEditViewModel) -> Void

    @State private var model: RoundEditViewModel
    @Environment(\.dismiss) private var dismiss

    init(holeNumber: Int,
         par: Int,
         score: Int,
         putts: Int,
         onSave: @escaping (RoundEditViewModel) -> Void)
    {
        self.holeNumber = holeNumber
        self.onSave = onSave
        _model = State(initialValue: RoundEditViewModel(par: par, score: score, putts: putts))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Par") {
                    Picker("Par", selection: parBinding) {
                        ForEach(RoundEditViewModel.parOptions, id: \.self) { par in
                            Text("\(par)").tag(par)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("타수") {
                    Stepper("\(model.score)타",
                            onIncrement: { model.incrementScore() },
                            onDecrement: model.canDecrementScore ? { model.decrementScore() } : nil)
                }

                Section("퍼팅") {
                    Stepper("\(model.putts)퍼트",
                            onIncrement: { model.incrementPutts() },
                            onDecrement: model.canDecrementPutts ? { model.decrementPutts() } : nil)
                }
            }
            .navigationTitle("H\(holeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(model)
                        dismiss()
                    }
                }
            }
        }
    }

    private var parBinding: Binding<Int> {
        Binding(get: { model.par },
                set: { model.setPar($0) })
    }
}
```

- [ ] **Step 2: `RoundDetailView`에 시트 연결**

`iOSApp/Features/History/Detail/RoundDetailView.swift`를 세 군데 고친다.

**(a)** 파일 맨 아래(`RoundDetailView`의 닫는 `}` 뒤)에 private 헬퍼 타입을 추가한다. `sheet(item:)`이 `Identifiable`을 요구하는데 `Int`는 그렇지 않기 때문이다.

```swift
/// `sheet(item:)`에 넘길 수 있게 홀 인덱스를 감싼다.
private struct EditingHole: Identifiable {
    let id: Int
}
```

**(b)** `@State private var courseNameDraft = ""` 아래에 상태를 추가한다:

```swift
    @State private var editingHole: EditingHole?
```

**(c)** `scorecardSection`의 `ForEach` 안 `HoleRow(...)` 호출에 탭 제스처를 붙이고, `body`의 `.onDisappear` 아래에 시트를 단다.

`scorecardSection`의 `ForEach` 본문을 교체:

```swift
            ForEach(Array(round.holeScores.indices), id: \.self) { index in
                Button {
                    editingHole = EditingHole(id: index)
                } label: {
                    HoleRow(holeNumber: index + 1,
                            par: value(in: round.holePars, at: index),
                            score: value(in: round.holeScores, at: index),
                            putts: value(in: round.puttCounts, at: index))
                }
                .buttonStyle(.plain)
            }
```

`body`의 modifier 체인에 추가 (`.onDisappear(perform: commitCourseName)` 바로 아래):

```swift
        .sheet(item: $editingHole) { editing in
            HoleEditSheet(holeNumber: editing.id + 1,
                          par: value(in: round.holePars, at: editing.id),
                          score: value(in: round.holeScores, at: editing.id),
                          putts: value(in: round.puttCounts, at: editing.id))
            { model in
                model.apply(to: round, holeIndex: editing.id)
                try? modelContext.save()
            }
        }
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 전체 테스트 통과 확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 기존 테스트 전부 PASS (Task 1·2·6에서 추가한 18개 포함)

- [ ] **Step 5: 실기기 통합 확인 (워치 발신과 연결)**

plan ④가 머지된 워치 앱으로 라운드를 하나 진행해 "저장 & 전송"까지 실행하고, iPhone 앱을 열어 다음을 확인한다:

1. 기록 리스트에 라운드가 나타난다 (오버파·총타수·`N홀` 뱃지)
2. 행을 탭하면 상세로 push되고 홀별 스코어가 워치에서 친 대로 보인다
3. 골프장명을 입력하고 화면을 나갔다 들어오면 값이 유지된다
4. 홀 행을 탭해 타수를 고치면 합계와 오버파가 함께 바뀐다
5. 같은 라운드가 두 번 나타나지 않는다 (중복 검사)

시뮬레이터만 있는 경우 1~4는 확인할 수 없다 — 이때는 이 스텝을 건너뛰지 말고 **실기기 확인이 남았다고 PR 본문에 명시**한다.

- [ ] **Step 6: 커밋**

```bash
make lint && make format
git add iOSApp/Features/History/Detail/
git commit -m "✨ feat: 홀 편집 시트를 상세 화면에 연결"
```

---

## 완료 조건

- 워치가 보낸 라운드가 iOS 기록 리스트에 나타나고, 같은 라운드가 두 번 저장되지 않는다
- 상세 화면에서 홀별 타수·퍼팅·파를 정정할 수 있고 불변식이 깨지지 않는다
- 골프장명을 수동으로 입력·수정할 수 있다
- 라운드를 확인 다이얼로그를 거쳐 삭제할 수 있다
- `iosTests` 전부 통과, `make lint`·`make format` 위반 0
