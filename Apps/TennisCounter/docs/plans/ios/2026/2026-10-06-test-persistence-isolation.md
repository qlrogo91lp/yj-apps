# iOS 테스트 저장소 격리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 테스트(`RalliTests`)가 앱 저장소 싱글턴을 건드리지 않게 해서, 기본 병렬 설정에서도 테스트 호스트가 `No eligible connection available` 로 죽지 않게 한다.

**Architecture:** 테스트마다 고유 이름·CloudKit 끔·보관되는 인메모리 컨테이너를 만들고, 거기에 묶인 **서비스 인스턴스**를 주입한다(`TestPersistence`).
프로덕션은 그대로 `.shared` 를 쓴다 — `MatchPersistenceService` 의 `init` 을 열고 `HistoryViewModel` 이 두 저장소를 주입받게 하는 것이 프로덕션 변경의 전부다.
`WorkoutSessionViewModel` 은 이미 `matchStore:` 로 주입을 받는다(`1f766f1`).

**Tech Stack:** Swift Testing, SwiftData, Xcode 워크스페이스 `YJApps.xcworkspace`

**Spec:** 별도 스펙 없음. 근거 — [작업 기록 2026-09-21 §4](../../../logs/2026/2026-09-21-session-record-integration-gaps.md) · 루트 `TODO.md` "`saveFromWatchPersistsMatch` 테스트 오염 수정" 항목

## 원인 (실행 전에 읽는다)

크래시는 iOS 테스트 실행 중 **테스트 호스트(=Ralli 앱 프로세스)** 에서 난다. 경로가 `XCTestDevices` 인 크래시 리포트가 그것이다.

```
NSInternalInconsistencyException: "No eligible connection available"
  NSManagedObjectContext.executeFetchRequest
  ← PersistenceCore.fetch(matching:sortBy:)
  ← MatchPersistenceService.fetchByWorkoutSession
```

세 요인이 겹친다. **어느 것이 결정적인지는 확정되지 않았다** — 작업 기록(09-21)은 ①, TODO(09-29)는 ② 를 지목한다.
이 플랜은 셋을 모두 없애므로 결론이 어느 쪽이든 결과는 같다. Task 1 Step 1 의 기준선 측정과 Task 3 의 최종 측정이 증거로 남는다.

1. **싱글턴 교체 + 컨테이너 수명** — 테스트가 `MatchPersistenceService.shared.configure(with: ModelContext(container))` 로 싱글턴을 갈아끼우고, `container` 는 테스트 함수의 지역 변수다. 다른 테스트가 그 사이 싱글턴으로 조회한다
2. **이름 없는 인메모리 설정** — `ModelConfiguration(isStoredInMemoryOnly: true)` 는 전부 `default` 저장소를 가리키고, `cloudKitDatabase` 기본값이 자동이라 iCloud 권한이 있는 앱에서는 미러링이 붙는다
3. **두 겹의 병렬** — 스킴 `parallelizable = "YES"`(시뮬레이터 복제본) + Swift Testing 의 프로세스 내 동시 실행

**싱글턴을 직접 쓰지 않는 테스트도 오염된다.** `HistoryViewModel` 이 `rebuildSessions()`·`delete(_:)` 에서 `.shared` 를 직접 읽기 때문에,
`HistoryViewModel()` 을 만드는 모든 테스트가 그 순간 싱글턴이 가리키는 저장소(다른 테스트의 것이거나 앱 `init` 이 꽂은 시뮬레이터 실제 저장소)를 읽는다.

## Global Constraints

- 빌드·테스트는 워크스페이스 기준: `xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test`
- 시뮬레이터는 UDID 로: `IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')`
- 테스트 프레임워크 Swift Testing (`@Test`, `#expect`). ViewModel 테스트는 `@MainActor`
- 테스트 폴더는 소스 구조를 미러링한다. 공용 테스트 헬퍼는 `iosTests/Support/`
- 파일 추가는 파일시스템만으로 — `project.pbxproj` 를 고치지 않는다
- ViewModel 은 SwiftUI 를 import 하지 않는다
- 커밋 메시지 gitmoji: ✅ test / ♻️ refactor / 📝 docs
- **이 체크아웃(`main`)에서 다른 세션이 작업 중이다.** 워크트리 `../yj-apps-worktrees/ralli-test-persistence-isolation`, 브랜치 `fix/ralli-test-persistence-isolation` 에서 실행한다

## Review Focus

1. **기본 `matchStore` 를 쓰는 `WorkoutSessionViewModel()` 이 공유 연결로 들어온 저장 메시지를 받는 경우** — VM 은 모두 `MatchConnectivity.shared` 를 구독한다. 다른 스위트가 흘린 `matchSave` 를 받으면 앱 싱글턴(테스트 호스트의 실제 저장소)에 쓴다. 이번 범위에서는 고치지 않고, Task 3 Step 2 에서 그런 경로가 있는지 grep 으로 확인해 결과를 기록한다
2. **주입하지 않은 `HistoryViewModel()` 이 테스트에 남는 경우** — 시뮬레이터 실제 저장소의 레코드가 세션 묶음에 섞인다. Task 2 Step 6 에서 `HistoryViewModel()` 이 `iosTests` 에 0건임을 확인한다
3. **삭제가 다른 컨텍스트에서 다시 열어도 반영되는가** — 서비스와 화면이 같은 컨테이너의 다른 컨텍스트를 쓰는 프로덕션 모양을 `TestPersistence.relaunched()` 로 유지한다. 기존 `delete_removesSessionMatchesAndRecordAfterReload` 가 지킨다
4. **병렬 실행 안정성** — 한 번 통과는 운일 수 있다. Task 3 에서 기본 병렬로 전체를 **두 번** 돌린다
5. **`CalendarView` 는 여전히 `.shared` 를 직접 읽는다** — View 는 테스트하지 않으므로 이번 범위 밖. 프로덕션 동작은 바뀌지 않는다

---

### Task 1: `TestPersistence` 헬퍼 + 서비스·워크아웃 테스트를 싱글턴에서 떼기

**Files:**
- Create: `Apps/TennisCounter/iosTests/Support/TestPersistence.swift`
- Modify: `Apps/TennisCounter/iOSApp/Services/MatchPersistenceService.swift` (`private init() {}`)
- Modify: `Apps/TennisCounter/iosTests/Services/MatchPersistenceServiceTests.swift:6-17`
- Modify: `Apps/TennisCounter/iosTests/Services/SessionPersistenceServiceTests.swift:8-14`
- Modify: `Apps/TennisCounter/iosTests/WorkoutSession/SessionRecordSavingTests.swift:14-20`
- Modify: `Apps/TennisCounter/iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift:125-130, 424-446`

**Interfaces:**
- Produces: `@MainActor struct TestPersistence` — `static func make() throws -> TestPersistence`, `let container: ModelContainer`, `let matches: MatchPersistenceService`, `let sessions: SessionPersistenceService`, `func newContext() -> ModelContext`, `func relaunched() -> TestPersistence`
- Produces: `MatchPersistenceService.init()` 가 `internal`

- [x] **Step 1: 워크트리 생성 + 기준선 측정**

```bash
cd /Users/yj/Workspace/Projects/yj-apps
git worktree add ../yj-apps-worktrees/ralli-test-persistence-isolation -b fix/ralli-test-persistence-isolation main
cd ../yj-apps-worktrees/ralli-test-persistence-isolation
cp ../../yj-apps/Apps/TennisCounter/iOSApp/GoogleService-Info.plist Apps/TennisCounter/iOSApp/ 2>/dev/null || true
cp ../../yj-apps/Apps/TennisCounter/WatchApp/GoogleService-Info.plist Apps/TennisCounter/WatchApp/ 2>/dev/null || true
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test 2>&1 | tee /tmp/baseline.log | grep -E "Test run with|failed|No eligible" | tail -20
```

plist 는 git 밖이라 워크트리에 없다(없어도 테스트는 통과한다 — Noop). 결과(통과/실패 수, `No eligible` 등장 여부)를 이 문서 끝 "실행 기록" 에 적는다.

- [x] **Step 2: 실패하는 테스트 작성** — `MatchPersistenceServiceTests` 에 추가

```swift
    /// 인스턴스마다 자기 컨테이너를 쓴다 — 테스트가 싱글턴을 갈아끼울 필요가 없다.
    @Test func instancesDoNotShareStore() throws {
        let first = try TestPersistence.make()
        let second = try TestPersistence.make()
        let match = Match()
        match.matchId = UUID()

        try first.matches.upsert(match)

        #expect(try first.matches.fetchAll().count == 1)
        #expect(try second.matches.fetchAll().isEmpty)
    }
```

- [x] **Step 3: 실패 확인**

Run: `xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test -only-testing:RalliTests/MatchPersistenceServiceTests`
Expected: 컴파일 실패 — `cannot find 'TestPersistence' in scope`

- [x] **Step 4: `MatchPersistenceService.init` 열기**

`iOSApp/Services/MatchPersistenceService.swift`:

```swift
    // 변경 전
    private init() {}

    // 변경 후
    /// 앱 코드는 `.shared` 만 쓴다. 테스트는 자기 컨테이너에 묶인 인스턴스를 만든다 —
    /// 싱글턴을 갈아끼우면 병렬로 도는 다른 테스트가 해제된 컨텍스트를 건드린다.
    init() {}
```

- [x] **Step 5: `TestPersistence` 작성** — `iosTests/Support/TestPersistence.swift`

```swift
import Foundation
import SwiftData
@testable import TennisCounter

/// 테스트 하나가 쓰는 저장소 묶음. 앱 싱글턴(`MatchPersistenceService.shared` 등)은 건드리지 않는다.
///
/// - 이름을 매번 새로 준다 — 이름 없는 설정은 모두 `default` 저장소를 가리켜 테스트끼리 섞인다
/// - `cloudKitDatabase: .none` — 앱에 iCloud 권한이 있어 기본값이면 인메모리 저장소에도 미러링이 붙는다
/// - 컨테이너를 정적 배열에 보관한다 — 테스트 함수가 끝나도 서비스가 든 컨텍스트가 죽지 않게
/// - 서비스와 화면은 프로덕션처럼 같은 컨테이너의 **서로 다른** 컨텍스트를 쓴다
@MainActor
struct TestPersistence {
    private static var retainedContainers: [ModelContainer] = []

    let container: ModelContainer
    let matches: MatchPersistenceService
    let sessions: SessionPersistenceService

    static func make() throws -> TestPersistence {
        let configuration = ModelConfiguration(
            UUID().uuidString,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: Match.self,
            SetRecord.self,
            WorkoutSessionRecord.self,
            configurations: configuration
        )
        retainedContainers.append(container)
        return TestPersistence(container: container)
    }

    /// 화면이 `@Environment(\.modelContext)` 로 받는 컨텍스트에 해당한다.
    func newContext() -> ModelContext {
        ModelContext(container)
    }

    /// 같은 저장소를 새 서비스·컨텍스트로 다시 연다 — 앱 재실행 흉내.
    func relaunched() -> TestPersistence {
        TestPersistence(container: container)
    }

    private init(container: ModelContainer) {
        self.container = container
        matches = MatchPersistenceService()
        matches.configure(with: ModelContext(container))
        sessions = SessionPersistenceService()
        sessions.configure(with: ModelContext(container))
    }
}
```

- [x] **Step 6: 서비스 테스트 픽스처 교체**

`MatchPersistenceServiceTests.swift` — 6~7행 주석을 지우고 `makeService()` 를 바꾼다. `@Suite(.serialized)` 는 남긴다(이번 범위 밖).

```swift
@Suite(.serialized)
@MainActor
struct MatchPersistenceServiceTests {
    private func makeService() throws -> MatchPersistenceService {
        try TestPersistence.make().matches
    }
```

`SessionPersistenceServiceTests.swift`:

```swift
    private func makeService() throws -> SessionPersistenceService {
        try TestPersistence.make().sessions
    }
```

`SessionRecordSavingTests.swift`:

```swift
    private func makePersistence() throws -> SessionPersistenceService {
        try TestPersistence.make().sessions
    }
```

- [x] **Step 7: `WorkoutSessionViewModelTests` 의 싱글턴 사용 2곳 교체**

125~130행 `saveCurrentMatchReturnsMatchOnSuccess`:

```swift
    @Test @MainActor func saveCurrentMatchReturnsMatchOnSuccess() throws {
        let persistence = try TestPersistence.make()

        let vm = WorkoutSessionViewModel(matchStore: persistence.matches)
        vm.startSession()
```

424~446행 `saveFromWatchPersistsMatch`:

```swift
    @Test @MainActor func saveFromWatchPersistsMatch() throws {
        let persistence = try TestPersistence.make()

        let sid = UUID()
        let msg = MatchEndMessage(
            // … 기존 인자 그대로 …
        )

        let vm = WorkoutSessionViewModel(matchStore: persistence.matches)
        vm.saveFromWatchForTest(msg)

        let saved = try persistence.matches.fetchByWorkoutSession(sid)
        #expect(saved.count == 1)
    }
```

- [x] **Step 8: 대상 스위트 통과 확인**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test \
  -only-testing:RalliTests/MatchPersistenceServiceTests \
  -only-testing:RalliTests/SessionPersistenceServiceTests \
  -only-testing:RalliTests/SessionRecordSavingTests \
  -only-testing:RalliTests/WorkoutSessionViewModelTests
```

Expected: 전부 PASS (`instancesDoNotShareStore` 포함)

- [x] **Step 9: 남은 싱글턴 사용 확인**

Run: `grep -rn "MatchPersistenceService.shared\|SessionPersistenceService.shared" Apps/TennisCounter/iosTests/Services Apps/TennisCounter/iosTests/WorkoutSession`
Expected: 출력 없음

- [x] **Step 10: 커밋**

```bash
git add Apps/TennisCounter/iosTests/Support/TestPersistence.swift \
        Apps/TennisCounter/iOSApp/Services/MatchPersistenceService.swift \
        Apps/TennisCounter/iosTests/Services \
        Apps/TennisCounter/iosTests/WorkoutSession
git commit -m "✅ 서비스·워크아웃 테스트가 저장소 싱글턴 대신 자기 컨테이너의 인스턴스를 쓴다"
```

---

### Task 2: `HistoryViewModel` 저장소 주입 + 기록 테스트 3개를 싱글턴에서 떼기

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/History/HistoryViewModel.swift:24-31, 134, 136, 161, 167`
- Create: `Apps/TennisCounter/iosTests/Support/HistoryViewModel+TestPersistence.swift`
- Modify: `Apps/TennisCounter/iosTests/History/HistoryViewModelTests.swift`
- Modify: `Apps/TennisCounter/iosTests/History/HistorySelectionTests.swift`
- Modify: `Apps/TennisCounter/iosTests/History/HealthKitDeletionTests.swift`

**Interfaces:**
- Consumes: `TestPersistence` (Task 1)
- Produces: `HistoryViewModel.init(workoutDeleter:matchStore:sessionStore:)` — 뒤 두 인자는 기본값 `.shared`
- Produces: 테스트 전용 `HistoryViewModel.init(persistence: TestPersistence, workoutDeleter: any WorkoutDeleting = WorkoutDeletionService())`

- [x] **Step 1: 실패하는 테스트 작성** — `HistoryViewModelTests` 에 추가

```swift
    /// 주입한 저장소의 레코드로 세션을 묶는다 — 앱 싱글턴이 무엇을 가리키든 상관없다.
    @Test func groupsSessionsWithInjectedSessionStore() throws {
        let persistence = try TestPersistence.make()
        let context = persistence.newContext()
        let sessionId = UUID()
        _ = insertMatch(session: sessionId, startedAt: Date(), in: context)
        try context.save()
        let record = WorkoutSessionRecord()
        record.workoutSessionId = sessionId
        record.elapsedSeconds = 1234
        try persistence.sessions.upsert(record)

        let vm = HistoryViewModel(persistence: persistence)
        vm.configure(modelContext: context)
        vm.loadInitial()

        let session = try #require(vm.listSessions.first { $0.id == sessionId })
        #expect(session.record?.elapsedSeconds == 1234)
    }
```

- [x] **Step 2: 실패 확인**

Run: `xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test -only-testing:RalliTests/HistoryViewModelTests`
Expected: 컴파일 실패 — `extra argument 'persistence' in call`

- [x] **Step 3: `HistoryViewModel` 에 저장소 주입**

```swift
    private var modelContext: ModelContext?
    private let workoutDeleter: any WorkoutDeleting
    private let matchStore: MatchPersistenceService
    private let sessionStore: SessionPersistenceService
    // … 나머지 프로퍼티 그대로 …

    /// 저장소 기본값은 앱 싱글턴이다. 테스트는 자기 컨테이너에 묶인 인스턴스를 넣는다 —
    /// 싱글턴을 갈아끼우면 병렬로 도는 다른 테스트가 해제된 컨텍스트를 건드린다.
    init(workoutDeleter: any WorkoutDeleting = WorkoutDeletionService(),
         matchStore: MatchPersistenceService = .shared,
         sessionStore: SessionPersistenceService = .shared)
    {
        self.workoutDeleter = workoutDeleter
        self.matchStore = matchStore
        self.sessionStore = sessionStore
    }
```

본문 4곳을 바꾼다.

| 행 | 변경 전 | 변경 후 |
|---|---|---|
| 134 | `try? MatchPersistenceService.shared.delete(match)` | `try? matchStore.delete(match)` |
| 136 | `try? SessionPersistenceService.shared.delete(sessionId: session.id)` | `try? sessionStore.delete(sessionId: session.id)` |
| 161 | `try? MatchPersistenceService.shared.fetchByWorkoutSession(session.id)` | `try? matchStore.fetchByWorkoutSession(session.id)` |
| 167 | `try? SessionPersistenceService.shared.fetchAll()` | `try? sessionStore.fetchAll()` |

- [x] **Step 4: 테스트 전용 이니셜라이저** — `iosTests/Support/HistoryViewModel+TestPersistence.swift`

```swift
@testable import TennisCounter
import WorkoutCore

extension HistoryViewModel {
    /// 기록 테스트용. 앱 싱글턴 대신 테스트 컨테이너에 묶인 저장소를 쓴다.
    convenience init(
        persistence: TestPersistence,
        workoutDeleter: any WorkoutDeleting = WorkoutDeletionService()
    ) {
        self.init(
            workoutDeleter: workoutDeleter,
            matchStore: persistence.matches,
            sessionStore: persistence.sessions
        )
    }
}
```

`HistoryViewModel` 은 `final class` 이고 지정 이니셜라이저가 하나라 확장의 `convenience init` 이 가능하다.

- [x] **Step 5: 기록 테스트 3개 픽스처 교체**

**`HistoryViewModelTests.swift`**

- 6행 주석을 지운다. `@Suite(.serialized)` 는 남긴다
- 12~38행의 `makeContainer()`·`makeContext()`·`makeSharedContainer()`·`makeSharedContainerContext()` 를 지우고 하나로 바꾼다

```swift
    /// 프로덕션과 같은 모양 — 서비스와 VM 이 같은 컨테이너의 서로 다른 컨텍스트를 쓴다.
    private func makeFixture() throws -> (persistence: TestPersistence, context: ModelContext) {
        let persistence = try TestPersistence.make()
        return (persistence, persistence.newContext())
    }
```

- 각 테스트를 같은 규칙으로 바꾼다

| 변경 전 | 변경 후 |
|---|---|
| `let context = try makeContext()` | `let (persistence, context) = try makeFixture()` |
| `let context = try makeSharedContainerContext()` | `let (persistence, context) = try makeFixture()` |
| `let container = try makeSharedContainer()` + `let context = ModelContext(container)` | `let (persistence, context) = try makeFixture()` |
| `let vm = HistoryViewModel()` | `let vm = HistoryViewModel(persistence: persistence)` |
| `try SessionPersistenceService.shared.upsert(…)` | `try persistence.sessions.upsert(…)` |

대상 행: `makeContext` 63·75·88·100·114·144·160·174·192·215·451·472·485 / `makeSharedContainerContext` 338·390·412·430 / `makeSharedContainer` 259·292·358 / `HistoryViewModel()` 66·78·91·103·128·151·166·182·202·238·273·318·344·371·397·419·434·462·476·486 / `SessionPersistenceService.shared.upsert` 271·313·316·365·369

- **재실행을 흉내 내는 3개 테스트** (`delete_removesSessionMatchesAndRecordAfterReload` 와 292·358행에서 시작하는 두 테스트) 는 끝부분을 이렇게 바꾼다

```swift
        vm.delete(session)

        let relaunched = persistence.relaunched()
        let remainingMatches = try relaunched.newContext().fetch(FetchDescriptor<Match>())
        #expect(remainingMatches.map(\.workoutSessionId) == [otherSessionId])
        #expect(try relaunched.sessions.fetchAll().isEmpty)
```

(292·358행 테스트의 기대값은 원래대로 `== [otherSessionId]` 를 `relaunched.sessions.fetchAll().map(\.workoutSessionId)` 에 건다. 281~282행의 싱글턴 재구성 두 줄은 삭제)

**`HistorySelectionTests.swift`** — `makeContext()` 를 바꾸고 `HistoryViewModel()` 10곳(43·69·96·114·131·154·172·193·225행)을 `HistoryViewModel(persistence: persistence)` 로

```swift
    private func makeFixture() throws -> (persistence: TestPersistence, context: ModelContext) {
        let persistence = try TestPersistence.make()
        return (persistence, persistence.newContext())
    }
```

`let context = try makeContext()` → `let (persistence, context) = try makeFixture()`. 154행처럼 VM 을 컨텍스트보다 먼저 만드는 테스트는 두 줄 순서를 바꾼다.

**`HealthKitDeletionTests.swift`**

- 25~27행 `HealthKitDeletionTestStorage` 를 지운다 (`TestPersistence` 가 보관한다)
- `Fixture` 의 `let container: ModelContainer` → `let persistence: TestPersistence`
- `makeFixture` 의 41~54행을 바꾼다

```swift
        let persistence = try TestPersistence.make()
        let context = persistence.newContext()
```

- 69행 `try SessionPersistenceService.shared.upsert(record)` → `try persistence.sessions.upsert(record)`
- 71행 `HistoryViewModel(workoutDeleter: workoutDeleter)` → `HistoryViewModel(persistence: persistence, workoutDeleter: workoutDeleter)`
- 반환 `Fixture(container: container, …)` → `Fixture(persistence: persistence, …)`
- 118~120행

```swift
        let reloaded = fixture.persistence.relaunched()
        #expect(try reloaded.newContext().fetch(FetchDescriptor<Match>()).isEmpty)
        #expect(try reloaded.sessions.fetchAll().isEmpty)
```

- [x] **Step 6: 남은 싱글턴·기본 VM 확인**

```bash
grep -rn "PersistenceService.shared\|HistoryViewModel()\|ModelConfiguration(isStoredInMemoryOnly" Apps/TennisCounter/iosTests
```

Expected: 출력 없음

- [x] **Step 7: 기록 스위트 통과 확인**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test \
  -only-testing:RalliTests/HistoryViewModelTests \
  -only-testing:RalliTests/HistorySelectionTests
```

Expected: 전부 PASS (`groupsSessionsWithInjectedSessionStore` 와 HealthKit 삭제 테스트 포함 — 후자는 `HistoryViewModelTests` 확장이다)

- [x] **Step 8: 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Features/History/HistoryViewModel.swift \
        Apps/TennisCounter/iosTests/Support/HistoryViewModel+TestPersistence.swift \
        Apps/TennisCounter/iosTests/History
git commit -m "♻️ HistoryViewModel 이 저장소를 주입받아 기록 테스트가 싱글턴을 건드리지 않게 한다"
```

---

### Task 3: 전체 검증 + 문서

**Files:**
- Modify: 이 플랜 문서 (실행 기록)
- Modify: `Apps/TennisCounter/docs/logs/2026/2026-09-21-session-record-integration-gaps.md:149` (체크)
- Modify: `TODO.md` ("아무 때나" 의 `saveFromWatchPersistsMatch` 항목 취소선)

- [x] **Step 1: 기본 병렬로 전체 두 번**

```bash
for i in 1 2; do
  xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test 2>&1 \
    | tee /tmp/after-$i.log | grep -E "Test run with|failed|No eligible" | tail -10
done
```

Expected: 두 번 모두 실패 0, `No eligible` 0건. 실패가 남으면 **여기서 멈추고** 로그를 기록한 뒤 보고한다 — 추가 수정을 얹지 않는다

- [x] **Step 2: Review Focus 1 확인 (기록만)**

```bash
grep -rn "receivedMatchSave\|MatchSaveMessage" Apps/TennisCounter/iosTests
```

테스트가 공유 연결에 저장 메시지를 흘리는 곳이 있으면, 그 시점에 살아 있는 기본 `matchStore` VM 이 앱 싱글턴에 쓸 수 있다. 결과를 실행 기록에 적는다

- [x] **Step 3: 워치 테스트·린트**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" test -only-testing:RalliWatchTests
make lint
```

Expected: PASS, 새 경고 없음

- [x] **Step 4: 문서 갱신** — 실행 기록(기준선 vs 수정 후 숫자), 작업 기록 149행 체크, `TODO.md` 항목 취소선 + `완료 (PR #n)`. TODO 의 "`-parallel-testing-enabled NO` 로 돌린다" 문구는 Step 1 이 통과했을 때만 지운다

- [x] **Step 5: 커밋·푸시·PR**

```bash
git add Apps/TennisCounter/docs TODO.md
git commit -m "📝 테스트 저장소 격리 결과를 기록하고 TODO 를 갱신한다"
git push -u origin fix/ralli-test-persistence-isolation
gh pr create --title "♻️ iOS 테스트가 저장소 싱글턴을 건드리지 않게 한다" --body "…"
```

머지는 사용자 확인 뒤 `gh pr merge <n> --merge --delete-branch`. 워크트리 제거 시 `make dd-prune` 로 DerivedData 고아도 지운다.

---

## 실행 기록

- 기준선: 122개 통과, 98개 실패. `No eligible connection available`은 로그·결과 번들 모두 0건이었다. 실패는 테스트 호스트 `TennisCounter` 크래시로 집중됐다.
- 수정 후 1회차(기본 병렬): 224개 통과, 0개 실패, `No eligible` 0건.
- 수정 후 2회차(기본 병렬): 224개 통과, 0개 실패, `No eligible` 0건.
- Review Focus 1 grep: `ConnectivityMessagesTests.swift`의 `MatchSaveMessage` 역직렬화 테스트 2건만 발견됐다. `receivedMatchSave` 수신 경로는 없어, 기본 `matchStore`가 공유 연결의 저장 메시지로 앱 싱글턴에 쓰는 테스트 경로는 확인되지 않았다.
- 워치: `RalliWatchTests` 통과. `make lint` 통과(0 violations).
