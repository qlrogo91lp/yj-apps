# RalliKit Plan 3: PersistenceCore 앱 마이그레이션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이미 ralli-kit에 구현된 `PersistenceCore`(컨테이너 팩토리 + 제너릭 CRUD)를 테니스 iOS 타겟이 실제로 소비하도록 마이그레이션한다.

**Architecture:** Plan 2의 `MatchConnectivity` 패턴을 그대로 따른다 — 코어는 도메인을 모르고(제너릭 `PersistenceService<Model>`), 앱 레이어 `MatchPersistenceService`가 테니스 도메인 지식(`workoutSessionId` 중복 제거 predicate, `startedAt` 정렬)을 소유하며 기존 `.shared` 표면을 그대로 유지한다. 따라서 호출부(ViewModel 2곳)는 **한 줄도 바뀌지 않는다**. 앱 루트의 컨테이너 생성 do/catch는 `PersistenceContainerFactory.make`로 대체한다.

**Tech Stack:** SwiftData(+CloudKit), Swift Testing, XCLocalSwiftPackageReference, Xcode 16 `PBXFileSystemSynchronizedRootGroup`.

**연관 문서:** `docs/superpowers/ideas/workout-kit-spm-feasibility.md`(설계 확정본 — PersistenceCore 절), `docs/superpowers/plans/2026-07-13-ralli-kit-workout-core.md`(Plan 1), `docs/superpowers/plans/2026-07-14-ralli-kit-connectivity-core.md`(Plan 2), `docs/superpowers/logs/2026-07-16-rallikit-spm-extraction-status.md`(진행 현황 — 이 계획이 갱신 대상).

---

## 착수 전 현황 (2026-07-30 확인)

**패키지 쪽은 이미 완료되어 있다.** Plan 1·2와 달리 이 계획은 추출 작업이 아니라 **소비 전환 작업**이다.

| 항목 | 상태 |
|---|---|
| `Sources/PersistenceCore/PersistenceContainerFactory.swift` | ✅ 구현됨 (ralli-kit `64d720b`) |
| `Sources/PersistenceCore/PersistenceService.swift` | ✅ 구현됨 (ralli-kit `7cf5064`) |
| `Tests/PersistenceCoreTests/` | ✅ 9개 테스트, `swift test` 29/29 그린 |
| ralli-kit README PersistenceCore 섹션 | ✅ 작성됨 (사용법 + CloudKit 체크리스트) |
| 테니스 pbxproj에 `PersistenceCore` 링크 | ⬜ **없음** (`ConnectivityCore` 양 타겟 + `WorkoutCore` Watch만 링크됨) |
| 테니스 앱이 PersistenceCore 소비 | ⬜ **없음** (`MatchPersistenceService`가 자체 구현, `iOSApp.swift`가 컨테이너 직접 생성) |

즉 잔여 작업은 **Task 1~5 (앱 링크 + 래퍼 전환 + 컨테이너 전환 + 문서 + 실기기)** 뿐이다.

### 코어 API (호출부가 참조할 시그니처 — 변경 금지)

```swift
public enum PersistenceContainerFactory {
    public static func make(for types: [any PersistentModel.Type],
                            cloudKit: Bool = true,
                            inMemory: Bool = false) -> ModelContainer
}

@MainActor
public final class PersistenceService<Model: PersistentModel> {
    public init(context: ModelContext)
    public func fetchAll(sortBy: [SortDescriptor<Model>] = []) throws -> [Model]
    public func fetch(matching predicate: Predicate<Model>,
                      sortBy: [SortDescriptor<Model>] = []) throws -> [Model]
    public func upsert(_ model: Model, replacing predicate: Predicate<Model>? = nil) throws
    public func delete(_ model: Model) throws
}
```

## Global Constraints

- **ralli-kit 로컬 클론 위치**: pbxproj가 `XCLocalSwiftPackageReference "../ralli-kit"`로 참조하므로 클론은 **테니스 레포의 형제 폴더**여야 한다. 이 머신에서는 `/Users/yj/Workspace/ralli-kit` (2026-07-30 클론 완료). Plan 1·2 문서에 적힌 `~/Workspace/Projects/ralli-kit`는 **이전 머신 경로로 이제 유효하지 않다** — Task 4에서 문서를 고친다.
- **⚠️ destination은 실행 머신 기준으로 다시 확인한다.** CLAUDE.md와 Plan 1·2에 적힌 `iPhone 17 Pro` / watch UDID `8502B1AE-...`는 이전 머신 값이라 이 머신에서 매칭되지 않는다. Task 1 Step 1에서 실제 값을 확인해 기록하고, 이 계획의 모든 `xcodebuild` 명령에서 치환해 쓴다.
- 패키지 코드는 **수정하지 않는다.** 이 계획은 앱 쪽만 바꾼다. 패키지 변경이 필요해 보이면 멈추고 사용자에게 보고한다.
- **`MatchPersistenceService`의 외부 표면(`shared`/`configure`/`fetchAll`/`upsert`/`fetchByWorkoutSession`/`PersistenceError`)은 불변.** 호출부 2곳(`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:215,270`)은 수정하지 않는다.
- **Persistence는 iOS 전용이다.** Watch·Complication 타겟은 `MatchPersistenceService`·`SwiftData`를 전혀 참조하지 않는다(확인 완료). 따라서 `PersistenceCore`는 **iOS 타겟에만 링크**하고, `MatchPersistenceService.swift`를 `Shared/Services/` → `iOSApp/Services/`로 옮긴다 (`Shared/`는 Watch 타겟에도 컴파일되므로, 그 자리에서 `import PersistenceCore`하면 Watch 빌드가 깨진다).
- `Shared/Persistence/Match.swift`·`SetRecord.swift`(`@Model`)는 **제자리 유지** — `SwiftData`만 import하고 `PersistenceCore`는 참조하지 않으므로 Watch 컴파일에 문제없다. 이동은 이 계획의 스코프가 아니다.
- 테스트 파일은 소스 구조를 미러링한다(CLAUDE.md) — 소스가 `iOSApp/Services/`로 가므로 테스트도 `iosTests/Shared/` → `iosTests/Services/`로 옮긴다.
- 테스트 프레임워크: Swift Testing. ViewModel/Service 테스트는 `@MainActor`.
- Xcode GUI가 필요한 지점(패키지 product를 타겟 Frameworks에 추가)은 **항상 사용자가 직접 수행**한다. `project.pbxproj` 자동 편집 도구 사용 금지.
- 각 태스크 종료 시 관련 타겟 빌드+테스트 그린 유지. **Task 2·3(스왑 태스크)은 Release 구성 빌드까지 확인** (Plan 1 교훈 — Debug 전용 검증이 아카이브 실패를 숨겼다).
- 커밋: gitmoji + 한국어. 이 계획 문서 자체는 **사용자 검토 전까지 커밋하지 않는다** (CLAUDE.md Docs Conventions).
- 린트/포맷: 각 코드 태스크 마지막에 `make fix && make lint` 위반 0건.

**의도된 동작 변경 3가지 (이외 동작 변화 금지):**

1. **CloudKit 폴백이 진짜 로컬로 떨어진다.** 현 `iOSApp.swift`는 1차 시도 `ModelConfiguration(schema:, cloudKitDatabase: .automatic)`, 폴백 `ModelConfiguration(schema:)`인데 후자의 `cloudKitDatabase` 기본값도 `.automatic`이라 **같은 설정을 두 번 시도**하는 셈이다. 팩토리는 폴백에서 `.none`을 명시하므로, CloudKit 초기화가 진짜 실패하는 환경에서 이전에는 `fatalError`였던 것이 이제 로컬 스토어로 살아난다. 개선이므로 수용.
2. **`upsert` 내부 fetch 실패도 `PersistenceError.saveFailed`로 감싸진다.** 원본은 save 실패만 `saveFailed`로 감싸고 중복 조회(fetch) 실패는 raw로 던졌다. 호출부 2곳 모두 `catch { success = false }` 형태로 에러 종류를 구분하지 않아 실질 영향 없음.
3. **rollback 주체가 코어로 이동.** save 실패 시 `context.rollback()`은 이제 `PersistenceService.upsert` 안에서 수행된다(동작 동일, 위치만 이동).

**스코프 밖 (명시적으로 건드리지 않음):**

- `iOSApp/Features/History/HistoryViewModel.swift` — 페이지네이션(`fetchOffset`/`fetchLimit`)을 쓰는데 `PersistenceService`는 offset/limit을 지원하지 않는다. 코어 API를 늘리지 않고 raw `ModelContext` 사용을 유지한다 (YAGNI).
- `iOSApp/Features/Summary/SummaryView.swift:6` — SwiftUI `@Query`. 프레임워크 매크로라 서비스 레이어와 무관.

---

### Task 1: [사용자 수동] PersistenceCore를 iOS 타겟에 링크 + 환경 확인

**⚠️ Xcode GUI 작업 — 사용자가 직접 수행한다. 에이전트는 Step 1·2를 수행하고, Step 3~4 안내 후 대기하고, Step 5만 수행한다.**

**Files:**
- Modify: `TennisCounter.xcodeproj/project.pbxproj` (Xcode가 자동 수정 — `PersistenceCore` productRef 추가. 커밋은 Task 2에서 마이그레이션과 함께)

**Interfaces:**
- Consumes: ralli-kit `main`의 `PersistenceCore` product (이미 구현 완료)
- Produces: "TennisCounter" 타겟에서 `import PersistenceCore` 가능한 상태. Task 2·3이 이를 전제한다.

- [ ] **Step 1: ralli-kit 클론 위치·상태 확인**

```bash
ls /Users/yj/Workspace/ralli-kit/Package.swift
cd /Users/yj/Workspace/ralli-kit && git log --oneline -3 && swift test 2>&1 | tail -3
```

Expected: `Package.swift` 존재, HEAD에 `64d720b ✨ PersistenceContainerFactory...` 포함, `Test run with 29 tests in 5 suites passed`.

클론이 없으면: `cd /Users/yj/Workspace && git clone git@github.com:qlrogo91lp/ralli-kit.git` (형제 폴더여야 pbxproj의 `../ralli-kit`가 해석된다).

- [ ] **Step 2: 이 머신의 destination 확인 후 기록**

```bash
xcrun simctl list devices available | grep -E "iPhone|Apple Watch"
```

출력에서 iPhone 하나와 Apple Watch 하나를 고르고, 아래 두 값을 이 태스크 결과에 기록한다. **이후 모든 태스크의 `xcodebuild` 명령에서 이 값으로 치환한다.**

- `<IOS_DEST>` = `platform=iOS Simulator,name=<고른 iPhone 이름>`
- `<WATCH_DEST>` = `platform=watchOS Simulator,id=<고른 Watch의 UDID>`

(Watch는 이전 머신에서 name 매칭이 실패한 이력이 있어 UDID를 쓴다. iPhone은 name으로 충분하다.)

- [ ] **Step 3: [사용자] iOS 타겟 Frameworks에 PersistenceCore 추가**

RalliKit 패키지는 Plan 1에서 이미 프로젝트에 등록돼 있으므로 File → Add Package가 아니라 **타겟별 Frameworks 추가**만 하면 된다:

1. `TennisCounter.xcodeproj`를 Xcode로 연다.
2. 프로젝트 네비게이터 최상단 파란 **TennisCounter 프로젝트 아이콘** 클릭
3. TARGETS → **"TennisCounter"** → General → **Frameworks, Libraries, and Embedded Content** → `+` → *Workspace → RalliKit* 아래 `PersistenceCore` 선택 → Add
4. **"TennisCounter Watch App" 타겟에는 추가하지 않는다** (Watch는 저장소를 쓰지 않는다 — Global Constraints 참조)

- [ ] **Step 4: [사용자] 완료 알림**

- [ ] **Step 5: 링크 상태 빌드 확인 (에이전트)**

아직 `import PersistenceCore`가 없으므로, 링크가 빌드를 깨지 않는지만 확인한다.

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' build
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' build
```

Expected: 둘 다 BUILD SUCCEEDED

---

### Task 2: MatchPersistenceService를 PersistenceCore 래퍼로 전환

**리팩터링 태스크이므로 TDD 순서가 뒤집힌다:** 표면이 불변이라 "실패하는 테스트"를 쓸 수 없다. 대신 **특성화 테스트(characterization test)를 먼저 추가해 구 구현에서 통과시키고**(안전망 확보), 구현을 갈아끼운 뒤 **같은 테스트가 계속 통과**하는지로 동등성을 검증한다.

**Files:**
- Move: `Shared/Services/MatchPersistenceService.swift` → `iOSApp/Services/MatchPersistenceService.swift` (내용도 교체)
- Move: `iosTests/Shared/MatchPersistenceServiceTests.swift` → `iosTests/Services/MatchPersistenceServiceTests.swift` (테스트 추가)
- Commit 포함: `TennisCounter.xcodeproj/project.pbxproj` (Task 1에서 Xcode가 수정)
- 수정하지 않음: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (표면 불변이라 무변경)

**Interfaces:**
- Consumes: Task 1의 링크된 `PersistenceCore` — `PersistenceService<Match>(context:)`, `fetchAll(sortBy:)`, `fetch(matching:sortBy:)`, `upsert(_:replacing:)`
- Produces: 표면이 **완전히 동일한** `MatchPersistenceService` — `static let shared`, `configure(with: ModelContext)`, `fetchAll() throws -> [Match]`, `upsert(_ match: Match) throws`, `fetchByWorkoutSession(_ sessionId: UUID) throws -> [Match]`, `enum PersistenceError { case notConfigured, saveFailed(Error) }`. Task 3의 `iOSApp.swift`가 `configure(with:)`를 호출한다.

- [ ] **Step 1: 특성화 테스트로 교체 (구 구현에서 통과해야 함)**

기존 파일을 폴더 규약에 맞게 옮기고 내용을 확장한다.

```bash
cd /Users/yj/Workspace/tennis_counter
mkdir -p iosTests/Services
git mv iosTests/Shared/MatchPersistenceServiceTests.swift iosTests/Services/MatchPersistenceServiceTests.swift
```

`iosTests/Services/MatchPersistenceServiceTests.swift` 전체를 다음으로 교체:

```swift
import Foundation
import SwiftData
@testable import TennisCounter
import Testing

@MainActor
struct MatchPersistenceServiceTests {
    private func makeService() throws -> MatchPersistenceService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        let service = MatchPersistenceService.shared
        service.configure(with: ModelContext(container))
        return service
    }

    @Test func upsertSameSessionKeepsSingleRecord() throws {
        let service = try makeService()
        let sid = UUID()

        let m1 = Match(); m1.workoutSessionId = sid; m1.myTotalSets = 1
        try service.upsert(m1)

        let m2 = Match(); m2.workoutSessionId = sid; m2.myTotalSets = 2
        try service.upsert(m2)

        let all = try service.fetchByWorkoutSession(sid)
        #expect(all.count == 1)
        #expect(all.first?.myTotalSets == 2) // 최신으로 갱신
    }

    @Test func upsertWithoutSessionIdKeepsEveryRecord() throws {
        let service = try makeService()

        let m1 = Match(); m1.myTotalSets = 1
        try service.upsert(m1)
        let m2 = Match(); m2.myTotalSets = 2
        try service.upsert(m2)

        // workoutSessionId가 없으면 중복 제거 대상이 아니다
        #expect(try service.fetchAll().count == 2)
    }

    @Test func upsertReplacesOnlyMatchingSession() throws {
        let service = try makeService()
        let untouched = UUID()
        let replaced = UUID()

        let other = Match(); other.workoutSessionId = untouched; other.myTotalSets = 9
        try service.upsert(other)

        let first = Match(); first.workoutSessionId = replaced; first.myTotalSets = 1
        try service.upsert(first)
        let second = Match(); second.workoutSessionId = replaced; second.myTotalSets = 2
        try service.upsert(second)

        #expect(try service.fetchAll().count == 2)
        #expect(try service.fetchByWorkoutSession(untouched).first?.myTotalSets == 9)
        #expect(try service.fetchByWorkoutSession(replaced).first?.myTotalSets == 2)
    }

    @Test func fetchAllSortsByStartedAtDescending() throws {
        let service = try makeService()

        let older = Match(); older.startedAt = Date(timeIntervalSince1970: 1000)
        try service.upsert(older)
        let newer = Match(); newer.startedAt = Date(timeIntervalSince1970: 2000)
        try service.upsert(newer)

        let all = try service.fetchAll()
        #expect(all.map(\.startedAt) == [newer.startedAt, older.startedAt])
    }

    @Test func fetchByWorkoutSessionIgnoresOtherSessions() throws {
        let service = try makeService()
        let target = UUID()

        let mine = Match(); mine.workoutSessionId = target
        try service.upsert(mine)
        let others = Match(); others.workoutSessionId = UUID()
        try service.upsert(others)

        #expect(try service.fetchByWorkoutSession(target).count == 1)
        #expect(try service.fetchByWorkoutSession(UUID()).isEmpty)
    }
}
```

- [ ] **Step 2: 구 구현에서 테스트 통과 확인 (안전망 확보)**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>'`
Expected: TEST SUCCEEDED — 5개 모두 PASS (아직 구 구현 = 이 테스트들이 현재 동작을 고정한 것)

**만약 여기서 실패하면** 테스트가 현재 동작을 잘못 기술한 것이다. 구현을 바꾸기 전에 테스트를 고쳐 그린을 만든다.

- [ ] **Step 3: 서비스 파일을 iOS 전용 위치로 이동**

```bash
cd /Users/yj/Workspace/tennis_counter
mkdir -p iOSApp/Services
git mv Shared/Services/MatchPersistenceService.swift iOSApp/Services/MatchPersistenceService.swift
```

(`PBXFileSystemSynchronizedRootGroup`이라 pbxproj 수동 편집 불필요 — Xcode가 폴더를 스캔해 iOS 타겟에 포함하고 Watch 타겟에서 제외한다.)

- [ ] **Step 4: 코어 위임 구현으로 교체**

`iOSApp/Services/MatchPersistenceService.swift` 전체를 다음으로 교체:

```swift
import Foundation
import PersistenceCore
import SwiftData

enum PersistenceError: Error {
    case notConfigured
    case saveFailed(Error)
}

/// PersistenceCore 위의 앱 레이어. 코어는 도메인을 모르므로(제너릭 CRUD),
/// 테니스 규칙 — workoutSessionId 기준 중복 제거, startedAt 정렬 — 은 여기가 소유한다.
/// iOS 전용: Watch·Complication 타겟은 저장소를 쓰지 않는다.
@MainActor
final class MatchPersistenceService {
    static let shared = MatchPersistenceService()

    private var store: PersistenceService<Match>?

    private init() {}

    func configure(with context: ModelContext) {
        store = PersistenceService(context: context)
    }

    func fetchAll() throws -> [Match] {
        guard let store else { return [] }
        return try store.fetchAll(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
    }

    /// 같은 워크아웃 세션의 기존 기록을 지우고 삽입한다 — 워치·폰 양쪽 저장 요청이
    /// 중복 레코드를 만들지 않게 하는 규칙. sessionId가 없으면 그냥 삽입한다.
    func upsert(_ match: Match) throws {
        guard let store else { throw PersistenceError.notConfigured }
        do {
            if let sid = match.workoutSessionId {
                try store.upsert(match, replacing: #Predicate<Match> { $0.workoutSessionId == sid })
            } else {
                try store.upsert(match)
            }
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    func fetchByWorkoutSession(_ sessionId: UUID) throws -> [Match] {
        guard let store else { return [] }
        let id = sessionId
        return try store.fetch(
            matching: #Predicate<Match> { $0.workoutSessionId == id },
            sortBy: [SortDescriptor(\.startedAt)]
        )
    }
}
```

원본과의 대응: `guard let context else { return [] }` → `guard let store else { return [] }`(동일), 중복 제거 루프 → 코어의 `replacing:` predicate, `context.save()`+`rollback()` → 코어 `upsert` 내부.

- [ ] **Step 5: 같은 테스트가 계속 통과하는지 확인 (동등성 검증)**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>'`
Expected: TEST SUCCEEDED — Step 2와 동일한 5개 PASS + 기존 iOS 스위트 전체 그린 (`WorkoutSessionViewModelTests`의 저장 경로 테스트 포함)

- [ ] **Step 6: Watch 타겟 회귀 확인 (파일 이동 영향)**

`Shared/`에서 파일이 빠졌으니 Watch 컴파일이 영향을 받지 않았는지 확인한다.

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>'`
Expected: TEST SUCCEEDED

- [ ] **Step 7: 양 타겟 Release 빌드 확인 (Plan 1 교훈)**

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' -configuration Release build
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination '<WATCH_DEST>' -configuration Release build
```

Expected: 둘 다 BUILD SUCCEEDED

- [ ] **Step 8: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add iOSApp iosTests Shared TennisCounter.xcodeproj/project.pbxproj
git commit -m "♻️ MatchPersistenceService → RalliKit PersistenceCore 위임

- 로컬 패키지 PersistenceCore 링크 (iOS 타겟만 — 워치는 저장소 미사용)
- 중복 제거·정렬 규칙은 앱 레이어에 유지, CRUD는 제너릭 코어에 위임
- iOS 전용이므로 Shared/Services → iOSApp/Services 로 이동
- 동등성 특성화 테스트 5개 (구 구현에서 통과시킨 뒤 스왑)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: 앱 루트 컨테이너를 PersistenceContainerFactory로 전환

**Files:**
- Modify: `iOSApp/iOSApp.swift:1-28` (import 블록 + `init()`)

**Interfaces:**
- Consumes: `PersistenceCore`의 `PersistenceContainerFactory.make(for:cloudKit:inMemory:)`, Task 2의 `MatchPersistenceService.shared.configure(with:)`
- Produces: 없음 (앱 진입점 — 이 계획의 마지막 코드 변경)

- [ ] **Step 1: iOSApp.swift 교체**

`iOSApp/iOSApp.swift`의 1-2행 import 블록을 교체 (SwiftFormat 알파벳 순):

```swift
import PersistenceCore
import SwiftData
import SwiftUI
```

10-28행 `init()`을 교체:

```swift
    init() {
        // CloudKit 동기화 시도 → iCloud 미로그인·시뮬레이터 등 실패 시 로컬 폴백 (팩토리가 처리)
        container = PersistenceContainerFactory.make(for: [Match.self, SetRecord.self])
        MatchPersistenceService.shared.configure(with: ModelContext(container))
        Task { @MainActor in LiveActivityService.shared.endAll() }
    }
```

`let container: ModelContainer` 선언과 `body`, `MainTabView` 이하는 변경 없음.

삭제되는 것: `Schema([Match.self, SetRecord.self])` 지역 변수, 이중 do/catch, `fatalError("Failed to create ModelContainer:")` — 셋 다 팩토리 안으로 흡수된다 (팩토리도 로컬까지 실패하면 `fatalError`).

- [ ] **Step 2: iOS 테스트 통과 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>'`
Expected: TEST SUCCEEDED

(테스트는 자체 in-memory 컨테이너를 만들므로 이 변경에 직접 영향받지 않는다 — 컴파일 회귀 확인이 목적이다.)

- [ ] **Step 3: iOS Release 빌드 확인**

Run: `cd /Users/yj/Workspace/tennis_counter && xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' -configuration Release build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: 시뮬레이터 스모크 확인 (CloudKit 폴백 경로)**

시뮬레이터는 iCloud 미로그인 = 팩토리의 로컬 폴백 경로다. 앱이 크래시 없이 뜨고 저장이 동작하는지 본다.

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' build
```

빌드 후 시뮬레이터에서 앱 실행 → 경기 하나 진행 → 저장 → History 탭에 기록이 보이는지 확인. (에이전트가 `/run` 스킬이나 시뮬레이터 도구로 수행 가능하면 직접, 아니면 사용자에게 요청.)

Expected: 앱이 정상 실행되고 저장한 경기가 History에 표시된다. 크래시 시 `fatalError("PersistenceContainerFactory: 로컬 ModelContainer 생성 실패")` 여부를 먼저 확인한다.

- [ ] **Step 5: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add iOSApp
git commit -m "♻️ 앱 루트 컨테이너를 PersistenceContainerFactory로 전환

이중 do/catch 폴백을 팩토리에 위임. 기존 폴백은 같은 설정을 두 번
시도하는 셈이었으나(둘 다 cloudKitDatabase 기본값 .automatic),
팩토리는 폴백에서 .none을 명시해 진짜 로컬 스토어로 떨어진다.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: 문서 갱신 — CLAUDE.md 트리 + 진행 현황 로그

**Files:**
- Modify: `CLAUDE.md` (Architecture 트리 2곳)
- Modify: `docs/superpowers/logs/2026-07-16-rallikit-spm-extraction-status.md` (product 표, Plan 3 절, 레포 경로, 릴리즈 체크리스트)

**Interfaces:**
- Consumes: Task 2·3 완료 상태
- Produces: 없음 (문서 태스크 — 다음 세션이 현황을 정확히 읽을 수 있게 하는 것이 목적)

- [ ] **Step 1: CLAUDE.md 트리에서 서비스 위치 갱신**

`Shared/Services/` 블록에서 아래 줄을 **삭제**:

```
    └── MatchPersistenceService.swift   # SwiftData 경기 저장/조회
```

삭제 후 `Shared/Services/`의 마지막 항목이 `MatchConnectivity.swift`가 되므로 트리 문자를 `├──` → `└──`로 고친다.

`iOSApp/Services/` 블록에 아래 줄을 **추가** (알파벳 순으로 `LiveActivityService.swift` 앞):

```
├── Services/
│   ├── LiveActivityService.swift  # Live Activity 시작/업데이트/종료
│   └── MatchPersistenceService.swift  # SwiftData 경기 저장/조회 (RalliKit PersistenceCore 위임)
```

(현재는 `└── LiveActivityService.swift` 한 줄이므로 트리 문자도 함께 고친다.)

- [ ] **Step 2: 진행 현황 로그 갱신**

`docs/superpowers/logs/2026-07-16-rallikit-spm-extraction-status.md`를 다음 4곳 수정한다.

① 제목·작업일 (1-3행):

```markdown
# RalliKit SPM 추출 — Plan 1·2·3 완료 현황 및 실기기 회귀 체크리스트

## 작업일: 2026-07-13 ~ 2026-07-30
```

② "레포 구조" 절의 경로 — 절대 경로가 머신마다 달라 오해를 낳았다. 다음으로 교체:

```markdown
- **ralli-kit** (신규): 원격 `git@github.com:qlrogo91lp/ralli-kit.git` (private), `main` 브랜치.
  로컬 클론은 **테니스 레포의 형제 폴더**여야 한다 — pbxproj가 `XCLocalSwiftPackageReference "../ralli-kit"`로
  참조하기 때문. (2026-07-16 머신에서는 `~/Workspace/Projects/ralli-kit`, 2026-07-30 머신에서는
  `~/Workspace/ralli-kit`. 새 머신에서 작업할 때는 테니스 레포 옆에 클론할 것.)
- **tennis-counter**: 기존 레포. RalliKit은 **로컬 패키지 참조**로 연결돼 있음.
  **원격 참조로 아직 전환 안 함** — 릴리즈 전 필수 전환 작업 (아래 "릴리즈 전 체크리스트" 참조).
```

③ product 표의 `PersistenceCore` 행:

```markdown
| `PersistenceCore` | SwiftData+CloudKit 컨테이너 팩토리(`PersistenceContainerFactory`), 제너릭 CRUD(`PersistenceService<Model>`) | ✅ 완료 (Plan 3) |
```

④ "Plan 2 — ConnectivityCore" 절 바로 뒤에 Plan 3 절을 삽입:

```markdown
## Plan 3 — PersistenceCore (완료)

- 계획: `docs/superpowers/plans/2026-07-30-ralli-kit-persistence-core.md`
- **패키지 쪽은 Plan 2 직후 선행 구현되어 있었다** (ralli-kit `7cf5064`·`64d720b`) — Plan 3은 추출이 아니라
  테니스 앱의 **소비 전환** 작업이었다. 2026-07-30 세션에서 이 사실을 확인하고 계획 범위를 축소했다.
- `MatchPersistenceService`는 Plan 2의 `MatchConnectivity`와 같은 구조 — 앱 레이어가 도메인 규칙
  (`workoutSessionId` 중복 제거, `startedAt` 정렬)을 소유하고 CRUD는 제너릭 코어에 위임. 표면이 불변이라
  호출부(ViewModel 2곳)는 무변경.
- **iOS 전용**: Watch·Complication은 저장소를 쓰지 않아 `PersistenceCore`를 iOS 타겟에만 링크하고,
  `MatchPersistenceService.swift`를 `Shared/Services/` → `iOSApp/Services/`로 이동했다
  (`Shared/`에 남기면 Watch 빌드가 없는 모듈을 import하게 된다).
- 의도된 동작 변경: CloudKit 폴백이 실제로 로컬로 떨어진다 — 기존 `iOSApp.swift`의 폴백은 두 설정 모두
  `cloudKitDatabase` 기본값 `.automatic`이라 같은 시도를 반복하는 셈이었고, 진짜 실패 시 `fatalError`였다.
- 스코프 밖: `HistoryViewModel`(페이지네이션 — 코어가 offset/limit 미지원), `SummaryView`의 `@Query`.
```

⑤ "⚠️ 남은 작업" 절 도입 문단에서 `Plan 3(PersistenceCore) 작업까지 마친 뒤 한 번에 모아서 진행해도 무방` 문장을 다음으로 교체:

```markdown
Plan 1·2·3 모두 머지 자체는 안전하지만(와이어 포맷 하위 호환, 롤백 단위 명확), **시뮬레이터로는 재현
불가능한 버그**(콜드런치, WCSession 큐잉, HealthKit 워크아웃 세션, CloudKit 동기화)가 있어
**TestFlight/App Store 릴리즈 전에 실기기 2대(iPhone + Apple Watch)로 반드시 확인**해야 한다.
세 Plan의 코드 변경이 모두 들어간 지금이 회귀를 한 번에 수행할 시점이다.
```

⑥ 실기기 체크리스트에 Plan 3 항목 추가 — "Plan 2 확인" 블록 뒤에 삽입:

```markdown
### Plan 3 확인 (PersistenceCore)
- [ ] **저장·조회 왕복**: 폰에서 경기 종료 → 저장 → History 목록·캘린더·Summary 통계에 모두 반영
- [ ] **중복 제거**: 같은 워크아웃 세션을 워치에서도 저장 → 히스토리에 레코드가 1개만 (중복 아님)
- [ ] **CloudKit 동기화**: iCloud 로그인 상태에서 저장 → 잠시 후 같은 계정의 다른 기기/재설치 후 기록 복원
- [ ] **로컬 폴백**: iCloud 로그아웃 상태로 앱 실행 → 크래시 없이 저장·조회 동작
```

⑦ "다음 단계" 절 전체를 교체:

```markdown
## 다음 단계

세 코어 추출이 모두 끝났다. 남은 것은 릴리즈 준비뿐이다.

1. 위 실기기 회귀 체크리스트 수행 (Plan 1·2·3 한 번에)
2. 테니스의 RalliKit 참조를 로컬 → 원격으로 전환 + semver 태그
3. 2차 소비자 검증: 골프 카운터 업데이트에서 세 코어 재사용
   (타당성 문서의 진행 논리 — 테니스가 1차 검증, 골프가 2차, 헬스 앱은 처음부터 패키지 기반)
```

- [ ] **Step 3: 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
git add CLAUDE.md docs/superpowers/logs/2026-07-16-rallikit-spm-extraction-status.md
git commit -m "📝 Plan 3 완료 반영 — 진행 현황·CLAUDE.md 트리·실기기 체크리스트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: [사용자 수동] 실기기 2대 회귀 — 릴리즈 게이트

**⚠️ 브랜치 머지 게이트가 아니라 릴리즈 게이트다.** Plan 1·2와 동일한 판단: 시뮬레이터로는 HealthKit 워크아웃 세션·WCSession 큐잉·콜드런치·CloudKit 동기화를 재현할 수 없다. Plan 1·2·3 항목을 한 번에 수행한다.

체크리스트는 Task 4에서 갱신한 `docs/superpowers/logs/2026-07-16-rallikit-spm-extraction-status.md`의 "⚠️ 남은 작업" 절을 단일 출처로 쓴다 (Plan 1 3항목 + Plan 2 7항목 + Plan 3 4항목).

- [ ] **Step 1: [사용자] iPhone + Apple Watch 실기기에 설치 후 체크리스트 수행**

- [ ] **Step 2: 결과를 로그 문서에 반영**

통과 항목은 체크박스를 채운다. 실패가 있으면 증상을 기록하고 `superpowers:systematic-debugging`으로 진입한다. 롤백 단위:

| Plan | 롤백 대상 커밋 |
|---|---|
| Plan 1 (WorkoutCore) | `3b4f027` / `a4cb39c` |
| Plan 2 (ConnectivityCore) | `dedc862` / `1cfd30a` |
| Plan 3 (PersistenceCore) | Task 2·3의 커밋 |

---

## 완료 기준 (Plan 3 Definition of Done)

1. ralli-kit `swift test` 29/29 그린 (패키지 무변경 확인 — 이 계획은 패키지를 수정하지 않는다)
2. `grep -rn "PersistenceCore" --include="*.swift" .` → `iOSApp/Services/MatchPersistenceService.swift`와 `iOSApp/iOSApp.swift` 두 파일만 (Watch·Complication·Shared 0건)
3. `iOSApp.swift`에 `ModelConfiguration`·`Schema(` 직접 사용 0건 (`grep -n "ModelConfiguration\|Schema(" iOSApp/iOSApp.swift` → 0건; 팩토리가 대신한다)
4. `Shared/Services/MatchPersistenceService.swift` 부재, `iOSApp/Services/MatchPersistenceService.swift` 존재
5. iOS·Watch 양 타겟: 테스트 스위트 그린 + **Release 빌드 그린**
6. 호출부 무변경 확인: `git diff` 범위에 `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` 없음
7. `make lint` 위반 0건
8. 실기기 회귀 (Task 5) — 릴리즈 전까지 완료
