# 기록·요약 세션 중심 재편 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 세션(한 번의 워크아웃)을 저장·공유·삭제의 단위로 만들고, 기록·요약 화면을 그 단위에 맞춰 다시 짠다.

**Architecture:** 운동 종료 시 버려지던 `stopWorkout()` 의 최종값을 `WorkoutSessionRecord` 로 저장한다. `MatchSessionGroup` 은 레코드가 있으면 그 값을, 없으면 지금처럼 경기 최댓값으로 폴백한다. 화면은 경기 행을 걷어내고 세션 카드 → 세션 상세(push) 흐름으로 바꾸며, 공유 버튼을 세션 상세 한 곳으로 모은다.

**Tech Stack:** SwiftData(+CloudKit) / WatchConnectivity / SwiftUI / Swift Testing

**Spec:** [docs/specs/ios/2026/2026-09-18-session-centric-history.md](../../../specs/ios/2026/2026-09-18-session-centric-history.md)

## Global Constraints

- **CloudKit 요구사항** — `@Model` 의 모든 속성은 optional 이거나 기본값을 갖는다. 관계는 optional + inverse. 기존 `Match` 가 그 규칙을 따르고 있다.
- **워크아웃 동작 계약**(루트 `CLAUDE.md`) — 화면에 넘기는 칼로리는 워크아웃 누적값. 경과시간은 워치가 단일 소스.
- **YJKit 은 고치지 않는다.** `stopWorkout()` 이 이미 `WorkoutResult?` 를 public 으로 돌려준다.
- **경기 저장 흐름은 건드리지 않는다.** 저장 버튼과 세션 레코드는 독립이다.
- 중복 제거 키는 **경기 단위(`matchId`)를 유지**한다 — 워크아웃을 키로 쓰면 같은 워크아웃의 다른 경기까지 지워진다(`66dc9d6`).
- 테스트는 ViewModel · Model · 메시지 직렬화까지. **View 는 테스트하지 않는다**(루트 `CLAUDE.md`).
- SwiftLint: line length 경고 150 / 오류 200. 한 파일 = 한 타입 (private helper 예외).
- 브랜치 **`feat/session-centric-history`**. gitmoji 커밋.

**빌드·테스트 명령** (저장소 루트에서)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build
make lint && make format
```

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `Shared/Persistence/WorkoutSessionRecord.swift` | 생성 | 세션 최종값 `@Model` |
| `Shared/Models/MatchSessionGroup.swift` | 수정 | 레코드 우선 + 폴백, 전적·심박·총칼로리 |
| `Shared/Services/ConnectivityMessages.swift` | 수정 | `WorkoutEndMessage` 에 최종값 |
| `Shared/Services/MatchConnectivity.swift` | 수정 | `sendWorkoutEnd` 시그니처 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 수정 | `stopWorkout()` 결과 수신·전송 |
| `iOSApp/Services/SessionPersistenceService.swift` | 생성 | 세션 레코드 CRUD |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 수정 | 세션 레코드 저장 |
| `iOSApp/iOSApp.swift` | 수정 | 스키마에 `WorkoutSessionRecord` 등록 |
| `iOSApp/Components/SessionCard.swift` | 생성 | 세션 카드 (목록·요약 공용) |
| `iOSApp/Components/SessionHeader.swift` | 삭제 | 카드에 흡수 |
| `iOSApp/Components/MatchRow.swift` | 삭제 | 목록에서 사라짐 |
| `iOSApp/Features/History/Components/SessionList.swift` | 수정 | 세션 카드 목록 |
| `iOSApp/Features/History/SessionDetailView.swift` | 생성 | 세션 상세 (push) |
| `iOSApp/Features/History/Components/MatchDetailSheet.swift` | 삭제 | 세션 상세에 흡수 |
| `iOSApp/Features/History/Components/Scoreboard.swift` | 수정 | 굵기 균일, 나=초록/상대=주황 |
| `iOSApp/Features/Match/Result/MatchResultView.swift` | 수정 | 공유 버튼 제거 |
| `iOSApp/Features/Summary/SummaryViewModel.swift` | 수정 | 기간별 통계 분기 |
| `iOSApp/Features/Summary/Components/RecentTrendChart.swift` | 수정 | 기간별 차트 분기 |
| `iOSApp/Features/Summary/Components/RecentSessionCard.swift` | 삭제 | `SessionCard` 로 대체 |

---

### Task 1: `WorkoutSessionRecord` 모델과 저장 서비스

**Files:**
- Create: `Apps/TennisCounter/Shared/Persistence/WorkoutSessionRecord.swift`
- Create: `Apps/TennisCounter/iOSApp/Services/SessionPersistenceService.swift`
- Modify: `Apps/TennisCounter/iOSApp/iOSApp.swift:15`
- Test: `Apps/TennisCounter/iosTests/Services/SessionPersistenceServiceTests.swift`

**Interfaces:**
- Produces: `WorkoutSessionRecord` (`@Model`), `SessionPersistenceService.shared` with `configure(with:)` · `upsert(_:)` · `fetchAll() -> [WorkoutSessionRecord]` · `delete(sessionId:)`

- [ ] **Step 1: 브랜치를 판다**

```bash
git switch -c feat/session-centric-history
```

- [ ] **Step 2: 실패하는 테스트**

```swift
import SwiftData
import Testing
@testable import TennisCounter

@MainActor
struct SessionPersistenceServiceTests {
    private func makeService() -> SessionPersistenceService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: WorkoutSessionRecord.self, configurations: config)
        let service = SessionPersistenceService()
        service.configure(with: ModelContext(container))
        return service
    }

    @Test func upsertThenFetch() throws {
        let service = makeService()
        let id = UUID()
        let record = WorkoutSessionRecord()
        record.workoutSessionId = id
        record.elapsedSeconds = 1523
        record.averageHeartRate = 142
        try service.upsert(record)

        let all = try service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.elapsedSeconds == 1523)
        #expect(all.first?.averageHeartRate == 142)
    }

    @Test func upsertSameSessionIdReplaces() throws {
        let service = makeService()
        let id = UUID()

        let first = WorkoutSessionRecord()
        first.workoutSessionId = id
        first.elapsedSeconds = 100
        try service.upsert(first)

        let second = WorkoutSessionRecord()
        second.workoutSessionId = id
        second.elapsedSeconds = 200
        try service.upsert(second)

        let all = try service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.elapsedSeconds == 200)
    }

    @Test func deleteBySessionId() throws {
        let service = makeService()
        let id = UUID()
        let record = WorkoutSessionRecord()
        record.workoutSessionId = id
        try service.upsert(record)

        try service.delete(sessionId: id)
        #expect(try service.fetchAll().isEmpty)
    }
}
```

- [ ] **Step 3: 실패 확인**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/SessionPersistenceServiceTests test 2>&1 | grep error: | head -3
```

Expected: `cannot find 'WorkoutSessionRecord' in scope`

- [ ] **Step 4: 모델을 만든다**

`Shared/Persistence/WorkoutSessionRecord.swift`:

```swift
import Foundation
import SwiftData

/// 한 번의 워크아웃이 끝난 시점의 최종값. 경기(`Match`)와 독립으로 저장된다.
///
/// 경기 레코드의 `workout*` 필드는 "그 경기가 끝난 시점까지의 누적값"이라 마지막 경기 이후
/// 구간이 빠진다. 이 레코드는 워크아웃이 실제로 끝난 시점의 값이다.
@Model
final class WorkoutSessionRecord {
    /// `Match.workoutSessionId` 와 잇는 키. CloudKit 요구사항상 optional.
    var workoutSessionId: UUID?
    var startedAt: Date = Date()
    var endedAt: Date?
    var elapsedSeconds: Int?
    var activeCalories: Double?
    var totalCalories: Double?
    /// **워크아웃 전체 평균.** 경기 구간 평균인 `Match.averageHeartRate` 와 성격이 다르다.
    var averageHeartRate: Double?
    /// 건강 앱 기록과 잇는 키.
    var healthKitUUID: UUID?

    init() {}
}
```

- [ ] **Step 5: 저장 서비스를 만든다**

`iOSApp/Services/SessionPersistenceService.swift`:

```swift
import Foundation
import SwiftData

/// 세션 레코드 CRUD. 중복 제거 키는 `workoutSessionId` 다 —
/// 경기와 달리 워크아웃 하나에 레코드도 하나라서 키가 겹치지 않는다.
final class SessionPersistenceService {
    static let shared = SessionPersistenceService()

    private var context: ModelContext?

    func configure(with context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [WorkoutSessionRecord] {
        guard let context else { return [] }
        return try context.fetch(FetchDescriptor<WorkoutSessionRecord>())
    }

    func upsert(_ record: WorkoutSessionRecord) throws {
        guard let context else { return }
        if let id = record.workoutSessionId {
            let existing = try context.fetch(
                FetchDescriptor<WorkoutSessionRecord>(
                    predicate: #Predicate { $0.workoutSessionId == id }
                )
            )
            for old in existing { context.delete(old) }
        }
        context.insert(record)
        try context.save()
    }

    func delete(sessionId: UUID) throws {
        guard let context else { return }
        let matching = try context.fetch(
            FetchDescriptor<WorkoutSessionRecord>(
                predicate: #Predicate { $0.workoutSessionId == sessionId }
            )
        )
        for record in matching { context.delete(record) }
        try context.save()
    }
}
```

- [ ] **Step 6: 스키마에 등록한다**

`iOSApp/iOSApp.swift` 의 `init()`:

```swift
        container = PersistenceContainerFactory.make(
            for: [Match.self, SetRecord.self, WorkoutSessionRecord.self]
        )
        MatchPersistenceService.shared.configure(with: ModelContext(container))
        SessionPersistenceService.shared.configure(with: ModelContext(container))
```

- [ ] **Step 7: 통과 확인 → 커밋**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/SessionPersistenceServiceTests test 2>&1 | tail -5
git add Apps/TennisCounter/Shared/Persistence/WorkoutSessionRecord.swift \
        Apps/TennisCounter/iOSApp/Services/SessionPersistenceService.swift \
        Apps/TennisCounter/iOSApp/iOSApp.swift \
        Apps/TennisCounter/iosTests/Services/SessionPersistenceServiceTests.swift
git commit -m "✨ 세션 최종값을 담는 WorkoutSessionRecord"
```

---

### Task 2: 워크아웃 종료 메시지에 최종값을 싣는다

**Files:**
- Modify: `Apps/TennisCounter/Shared/Services/ConnectivityMessages.swift:274-290`
- Modify: `Apps/TennisCounter/Shared/Services/MatchConnectivity.swift:78-80`
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift:295-302`
- Test: `Apps/TennisCounter/iosTests/Shared/WorkoutEndMessageTests.swift`

**Interfaces:**
- Consumes: Task 1 의 `WorkoutSessionRecord`
- Produces: `WorkoutEndMessage(sessionId:startedAt:endedAt:elapsedSeconds:activeCalories:totalCalories:averageHeartRate:healthKitUUID:)` — 최종값은 전부 optional. `MatchConnectivity.sendWorkoutEnd(sessionId:result:startedAt:)`

- [ ] **Step 1: 실패하는 테스트**

```swift
import Foundation
import Testing
@testable import TennisCounter

struct WorkoutEndMessageTests {
    @Test func roundTripWithFinalValues() throws {
        let sessionId = UUID()
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let ended = started.addingTimeInterval(9351)
        let original = WorkoutEndMessage(
            sessionId: sessionId,
            startedAt: started,
            endedAt: ended,
            elapsedSeconds: 9351,
            activeCalories: 1343,
            totalCalories: 1584,
            averageHeartRate: 136,
            healthKitUUID: nil
        )

        let decoded = try #require(WorkoutEndMessage(from: original.toDictionary()))
        #expect(decoded.sessionId == sessionId)
        #expect(decoded.elapsedSeconds == 9351)
        #expect(decoded.activeCalories == 1343)
        #expect(decoded.totalCalories == 1584)
        #expect(decoded.averageHeartRate == 136)
        #expect(decoded.endedAt?.timeIntervalSince1970 == ended.timeIntervalSince1970)
    }

    /// 구버전 워치가 보내는 sessionId 만 있는 메시지도 계속 읽혀야 한다.
    @Test func decodesLegacyMessageWithoutFinalValues() throws {
        let sessionId = UUID()
        let legacy: [String: Any] = ["sessionId": sessionId.uuidString]

        let decoded = try #require(WorkoutEndMessage(from: legacy))
        #expect(decoded.sessionId == sessionId)
        #expect(decoded.elapsedSeconds == nil)
        #expect(decoded.averageHeartRate == nil)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/WorkoutEndMessageTests test 2>&1 | grep error: | head -3
```

Expected: `extra arguments at positions ...` (기존 생성자는 `sessionId` 하나만 받는다)

- [ ] **Step 3: 메시지를 확장한다**

`ConnectivityMessages.swift` 의 `WorkoutEndMessage` 를 통째로 바꾼다. **기존 필드 이름과 `messageType` 은 유지한다** — 구버전 워치가 보낸 메시지도 읽혀야 한다.

```swift
/// 워크아웃 종료 알림. 최종값이 함께 온다 — 없으면(구버전 워치) 전부 nil 이다.
struct WorkoutEndMessage: ConnectivityMessage {
    static let messageType = "workoutEnd"

    let sessionId: UUID
    let startedAt: Date?
    let endedAt: Date?
    let elapsedSeconds: Int?
    let activeCalories: Double?
    let totalCalories: Double?
    let averageHeartRate: Double?
    let healthKitUUID: UUID?

    init(sessionId: UUID,
         startedAt: Date? = nil,
         endedAt: Date? = nil,
         elapsedSeconds: Int? = nil,
         activeCalories: Double? = nil,
         totalCalories: Double? = nil,
         averageHeartRate: Double? = nil,
         healthKitUUID: UUID? = nil)
    {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = elapsedSeconds
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.healthKitUUID = healthKitUUID
    }

    init?(from dictionary: [String: Any]) {
        guard let idStr = dictionary["sessionId"] as? String,
              let id = UUID(uuidString: idStr) else { return nil }
        sessionId = id
        startedAt = (dictionary["startedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        endedAt = (dictionary["endedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        elapsedSeconds = dictionary["elapsedSeconds"] as? Int
        activeCalories = dictionary["activeCalories"] as? Double
        totalCalories = dictionary["totalCalories"] as? Double
        averageHeartRate = dictionary["averageHeartRate"] as? Double
        healthKitUUID = (dictionary["healthKitUUID"] as? String).flatMap(UUID.init(uuidString:))
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": Self.messageType,
            "sessionId": sessionId.uuidString,
        ]
        if let startedAt { dict["startedAt"] = startedAt.timeIntervalSince1970 }
        if let endedAt { dict["endedAt"] = endedAt.timeIntervalSince1970 }
        if let elapsedSeconds { dict["elapsedSeconds"] = elapsedSeconds }
        if let activeCalories { dict["activeCalories"] = activeCalories }
        if let totalCalories { dict["totalCalories"] = totalCalories }
        if let averageHeartRate { dict["averageHeartRate"] = averageHeartRate }
        if let healthKitUUID { dict["healthKitUUID"] = healthKitUUID.uuidString }
        return dict
    }
}
```

> `toDictionary()` 의 `"type"` 키가 기존 구현과 같은 형태인지 파일 안의 다른 메시지를 보고 맞춘다. 다르면 그 파일의 방식을 따른다.

- [ ] **Step 4: 송신부를 고친다**

`MatchConnectivity.swift`:

```swift
    func sendWorkoutEnd(sessionId: UUID, result: WorkoutResult? = nil, startedAt: Date? = nil) {
        service.send(
            WorkoutEndMessage(
                sessionId: sessionId,
                startedAt: startedAt,
                endedAt: result == nil ? nil : Date(),
                elapsedSeconds: result?.durationSeconds,
                activeCalories: result?.caloriesBurned,
                totalCalories: result?.totalCaloriesBurned,
                averageHeartRate: result?.averageHeartRate,
                healthKitUUID: result?.healthKitUUID
            ),
            via: .reliable
        )
    }
```

`WorkoutCore` import 가 없으면 파일 상단에 추가한다.

- [ ] **Step 5: 워치가 결과를 받아 보내게 한다**

`WatchApp/.../WorkoutSessionViewModel.swift` 의 `endWorkout(notifyRemote:)`:

```swift
    func endWorkout(notifyRemote: Bool = true) {
        let sessionId = activeSessionId
        let startedAt = workoutStartedAt
        _currentSession = nil
        appGroupDefaults?.set(false, forKey: "isWorkoutActive")
        WidgetCenter.shared.reloadTimelines(ofKind: "ComplicationApp")
        connectivity.clearSessionContext()

        Task {
            // stopWorkout() 이 워크아웃 전체 평균 심박과 최종 시간·칼로리를 돌려준다.
            // 예전엔 이 값을 버려서 세션 최종값이 어디에도 남지 않았다.
            let result = await healthKit.stopWorkout()
            if notifyRemote {
                connectivity.sendWorkoutEnd(sessionId: sessionId, result: result, startedAt: startedAt)
            }
        }
    }
```

`workoutStartedAt` 이 없으면 워크아웃을 시작할 때 `private var workoutStartedAt: Date?` 에 `Date()` 를 넣어 둔다 (`startWorkout()` 부근).

- [ ] **Step 6: 테스트와 빌드**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/WorkoutEndMessageTests test 2>&1 | tail -5
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" build 2>&1 | tail -3
```

- [ ] **Step 7: 커밋**

```bash
git add Apps/TennisCounter/Shared/Services Apps/TennisCounter/WatchApp Apps/TennisCounter/iosTests/Shared/WorkoutEndMessageTests.swift
git commit -m "✨ 워크아웃 종료 메시지에 세션 최종값을 싣는다"
```

---

### Task 3: iOS 가 세션 레코드를 저장한다

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `Apps/TennisCounter/iosTests/WorkoutSession/SessionRecordSavingTests.swift`

**Interfaces:**
- Consumes: Task 1 의 `SessionPersistenceService`, Task 2 의 `WorkoutEndMessage`
- Produces: `WorkoutSessionViewModel.saveSessionRecord(from:) -> WorkoutSessionRecord?` — 최종값이 하나도 없으면 nil 을 돌려주고 저장하지 않는다

- [ ] **Step 1: 실패하는 테스트**

```swift
import Foundation
import Testing
@testable import TennisCounter

@MainActor
struct SessionRecordSavingTests {
    @Test func buildsRecordFromMessage() throws {
        let viewModel = WorkoutSessionViewModel()
        let sessionId = UUID()
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let message = WorkoutEndMessage(
            sessionId: sessionId,
            startedAt: started,
            endedAt: started.addingTimeInterval(9351),
            elapsedSeconds: 9351,
            activeCalories: 1343,
            totalCalories: 1584,
            averageHeartRate: 136
        )

        let record = try #require(viewModel.saveSessionRecord(from: message))
        #expect(record.workoutSessionId == sessionId)
        #expect(record.elapsedSeconds == 9351)
        #expect(record.averageHeartRate == 136)
        #expect(record.startedAt == started)
    }

    /// 구버전 워치가 보낸 메시지는 최종값이 없다 — 레코드를 만들지 않는다.
    @Test func skipsWhenNoFinalValues() {
        let viewModel = WorkoutSessionViewModel()
        let message = WorkoutEndMessage(sessionId: UUID())
        #expect(viewModel.saveSessionRecord(from: message) == nil)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `-only-testing:RalliTests/SessionRecordSavingTests`
Expected: `value of type 'WorkoutSessionViewModel' has no member 'saveSessionRecord'`

- [ ] **Step 3: 구현**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` 에 추가한다. 기존 `WorkoutEndMessage` 수신 처리 부근에 둔다.

```swift
    /// 워크아웃 종료 메시지의 최종값을 세션 레코드로 저장한다.
    /// 최종값이 하나도 없으면(구버전 워치) 저장하지 않는다 — 빈 레코드가 폴백을 가로막는다.
    @discardableResult
    func saveSessionRecord(from message: WorkoutEndMessage) -> WorkoutSessionRecord? {
        guard message.elapsedSeconds != nil
            || message.activeCalories != nil
            || message.averageHeartRate != nil
        else { return nil }

        let record = WorkoutSessionRecord()
        record.workoutSessionId = message.sessionId
        record.startedAt = message.startedAt ?? Date()
        record.endedAt = message.endedAt
        record.elapsedSeconds = message.elapsedSeconds
        record.activeCalories = message.activeCalories
        record.totalCalories = message.totalCalories
        record.averageHeartRate = message.averageHeartRate
        record.healthKitUUID = message.healthKitUUID
        try? SessionPersistenceService.shared.upsert(record)
        return record
    }
```

그리고 기존 `WorkoutEndMessage` 수신 지점에서 `saveSessionRecord(from: msg)` 를 부른다.

- [ ] **Step 4: 통과 확인 → 커밋**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/SessionRecordSavingTests test 2>&1 | tail -5
git add Apps/TennisCounter/iOSApp/Features/WorkoutSession Apps/TennisCounter/iosTests/WorkoutSession
git commit -m "✨ 운동 종료 시 세션 레코드를 저장한다"
```

---

### Task 4: `MatchSessionGroup` — 레코드 우선, 폴백, 빈 세션

**Files:**
- Modify: `Apps/TennisCounter/Shared/Models/MatchSessionGroup.swift`
- Test: `Apps/TennisCounter/iosTests/Shared/MatchSessionGroupTests.swift` (기존 파일에 추가)

**Interfaces:**
- Consumes: Task 1 의 `WorkoutSessionRecord`
- Produces: `MatchSessionGroup(id:matches:record:)`, `elapsedSeconds` · `activeCalories` · `totalCalories` · `averageHeartRate` · `wins` · `losses` · `matchCount`, `MatchSessionGroup.group(_ matches: [Match], records: [WorkoutSessionRecord]) -> [MatchSessionGroup]`

- [ ] **Step 1: 실패하는 테스트** (기존 파일 끝에 추가)

```swift
    @Test func recordWinsOverMatchMaximum() {
        let sessionId = UUID()
        let match = Match()
        match.workoutSessionId = sessionId
        match.workoutElapsedSeconds = 1000
        match.workoutCaloriesBurned = 100

        let record = WorkoutSessionRecord()
        record.workoutSessionId = sessionId
        record.elapsedSeconds = 1500      // 마지막 경기 이후 구간까지 포함
        record.activeCalories = 160
        record.averageHeartRate = 142

        let groups = MatchSessionGroup.group([match], records: [record])
        #expect(groups.count == 1)
        #expect(groups[0].elapsedSeconds == 1500)
        #expect(groups[0].activeCalories == 160)
        #expect(groups[0].averageHeartRate == 142)
    }

    @Test func fallsBackToMatchMaximumWhenNoRecord() {
        let sessionId = UUID()
        let first = Match()
        first.workoutSessionId = sessionId
        first.workoutElapsedSeconds = 600
        let second = Match()
        second.workoutSessionId = sessionId
        second.workoutElapsedSeconds = 1000

        let groups = MatchSessionGroup.group([first, second], records: [])
        #expect(groups[0].elapsedSeconds == 1000)
        // 경기 평균은 세션 평균이 아니므로 폴백하지 않는다
        #expect(groups[0].averageHeartRate == nil)
    }

    @Test func recordWithoutMatchesBecomesEmptySession() {
        let record = WorkoutSessionRecord()
        record.workoutSessionId = UUID()
        record.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        record.elapsedSeconds = 2890

        let groups = MatchSessionGroup.group([], records: [record])
        #expect(groups.count == 1)
        #expect(groups[0].matches.isEmpty)
        #expect(groups[0].matchCount == 0)
        #expect(groups[0].elapsedSeconds == 2890)
    }

    @Test func countsWinsAndLosses() {
        let sessionId = UUID()
        let win = Match()
        win.workoutSessionId = sessionId
        win.myTotalSets = 2
        win.yourTotalSets = 0
        let loss = Match()
        loss.workoutSessionId = sessionId
        loss.myTotalSets = 0
        loss.yourTotalSets = 2

        let groups = MatchSessionGroup.group([win, loss], records: [])
        #expect(groups[0].wins == 1)
        #expect(groups[0].losses == 1)
        #expect(groups[0].matchCount == 2)
    }
```

- [ ] **Step 2: 실패 확인**

Run: `-only-testing:RalliTests/MatchSessionGroupTests`
Expected: `extra argument 'records' in call`

- [ ] **Step 3: 구현**

`Shared/Models/MatchSessionGroup.swift` 를 통째로 바꾼다.

```swift
import Foundation

/// 한 워크아웃(`workoutSessionId`)에 속한 경기들과 그 세션의 최종값.
/// 진행 중 경기 상태인 `MatchSession` 과 이름이 겹치지 않게 `~Group` 을 붙였다.
struct MatchSessionGroup: Identifiable {
    /// `workoutSessionId`. nil 기록은 각자 단독 세션이므로 경기의 `id` 를 쓴다.
    let id: UUID
    /// `startedAt` 오름차순. 경기 없이 운동만 한 세션은 빈 배열이다.
    let matches: [Match]
    /// 세션 레코드. 없으면(구버전 기록) 경기들의 최댓값으로 폴백한다.
    let record: WorkoutSessionRecord?

    var matchCount: Int { matches.count }
    var wins: Int { matches.count(where: { $0.myTotalSets > $0.yourTotalSets }) }
    var losses: Int { matchCount - wins }

    /// 세션 정렬 기준. 레코드가 있으면 그 시작 시각, 없으면 마지막 경기의 시작.
    var latestStartedAt: Date {
        record?.startedAt ?? matches.last?.startedAt ?? .distantPast
    }

    var date: Date {
        record?.startedAt ?? matches.first?.startedAt ?? .distantPast
    }

    /// 누적 지표는 레코드가 우선. 폴백은 그룹당 최댓값 하나다 — 같은 워크아웃의 경기들이
    /// 하나의 누적 축을 공유하므로 합산하면 같은 값을 여러 번 세게 된다.
    var elapsedSeconds: Int? {
        record?.elapsedSeconds ?? matches.compactMap(\.workoutElapsedSeconds).max()
    }

    var activeCalories: Double? {
        record?.activeCalories ?? matches.compactMap(\.workoutCaloriesBurned).max()
    }

    var totalCalories: Double? {
        record?.totalCalories ?? matches.compactMap(\.workoutTotalCaloriesBurned).max()
    }

    /// **폴백하지 않는다.** `Match.averageHeartRate` 는 그 경기 구간의 평균이라
    /// 세션 평균이 아니다. 레코드가 없으면 보여줄 값이 없다.
    var averageHeartRate: Double? {
        record?.averageHeartRate
    }

    static func group(_ matches: [Match],
                      records: [WorkoutSessionRecord] = []) -> [MatchSessionGroup]
    {
        var recordsBySession: [UUID: WorkoutSessionRecord] = [:]
        for record in records {
            if let sid = record.workoutSessionId { recordsBySession[sid] = record }
        }

        var bySession: [UUID: [Match]] = [:]
        var solo: [MatchSessionGroup] = []

        for match in matches {
            if let sid = match.workoutSessionId {
                bySession[sid, default: []].append(match)
            } else {
                // 누적값 도입 이전 기록. 서로 묶을 근거가 없어 각자 한 세션으로 둔다.
                solo.append(MatchSessionGroup(id: match.id, matches: [match], record: nil))
            }
        }

        let grouped = bySession.map { sid, list in
            MatchSessionGroup(id: sid,
                              matches: list.sorted { $0.startedAt < $1.startedAt },
                              record: recordsBySession[sid])
        }

        // 경기를 한 판도 저장하지 않고 운동만 한 세션.
        let empty = recordsBySession
            .filter { bySession[$0.key] == nil }
            .map { sid, record in MatchSessionGroup(id: sid, matches: [], record: record) }

        return (grouped + solo + empty).sorted { $0.latestStartedAt > $1.latestStartedAt }
    }
}
```

- [ ] **Step 4: 호출부를 고친다**

`group(...)` 을 부르는 두 곳에 레코드를 넘긴다.

```bash
grep -rn "MatchSessionGroup.group(" Apps/TennisCounter --include="*.swift"
```

`HistoryViewModel` 과 `SummaryViewModel` 에서 `SessionPersistenceService.shared.fetchAll()` 결과를 함께 넘긴다. 실패하면 빈 배열로 둔다 (`(try? ...) ?? []`).

- [ ] **Step 5: 전체 테스트 → 커밋**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test 2>&1 | tail -5
git add Apps/TennisCounter/Shared/Models Apps/TennisCounter/iOSApp/Features Apps/TennisCounter/iosTests/Shared
git commit -m "✨ 세션 지표를 레코드 우선으로 읽고 빈 세션을 만든다"
```

---

### Task 5: 세션 카드와 기록 목록

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Components/SessionCard.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/History/Components/SessionList.swift`
- Delete: `Apps/TennisCounter/iOSApp/Components/SessionHeader.swift`
- Delete: `Apps/TennisCounter/iOSApp/Components/MatchRow.swift`

**Interfaces:**
- Consumes: Task 4 의 `MatchSessionGroup`
- Produces: `SessionCard(session: MatchSessionGroup)` — 탭·삭제는 붙이는 쪽이 건다

- [ ] **Step 1: 세션 카드**

`iOSApp/Components/SessionCard.swift`:

```swift
import SwiftUI

/// 세션 하나를 담는 카드. 기록 목록과 요약이 함께 쓴다.
///
/// 전적을 카드가 직접 보여준다 — 목록에 경기 행이 없어서 세어 볼 수가 없다.
struct SessionCard: View {
    let session: MatchSessionGroup

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.dateText(session.date))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    recordLine
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HStack(spacing: 10) {
                metric(value: durationText, label: String(localized: "session_metric_duration"), color: .brand)
                metric(value: caloriesText, label: String(localized: "session_metric_calories"), color: Color(red: 1, green: 0.702, blue: 0.251))
                metric(value: heartRateText, label: String(localized: "session_metric_heart_rate"), color: Color(red: 1, green: 0.42, blue: 0.341))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var recordLine: some View {
        if session.matchCount == 0 {
            Text(String(localized: "session_no_match"))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 0) {
                Text(String(format: String(localized: "session_match_count"), session.matchCount))
                Text(verbatim: " · ")
                Text(String(format: String(localized: "session_wins"), session.wins))
                    .foregroundStyle(Color.brand)
                    .fontWeight(.semibold)
                if session.losses > 0 {
                    Text(verbatim: " ")
                    Text(String(format: String(localized: "session_losses"), session.losses))
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
    }

    private func metric(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(value == "–" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationText: String {
        session.elapsedSeconds.map(CumulativeDuration.format) ?? "–"
    }

    private var caloriesText: String {
        guard let calories = session.activeCalories else { return "–" }
        return calories.formatted(.number.precision(.fractionLength(0)))
    }

    private var heartRateText: String {
        guard let rate = session.averageHeartRate else { return "–" }
        return rate.formatted(.number.precision(.fractionLength(0)))
    }

    /// "8월 24일 (일)" / "Sat, Aug 24" — 로케일이 순서를 정한다.
    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 2: 문자열 6개를 카탈로그에 넣는다**

`iOSApp/Localizable.xcstrings` 에 아래 키를 추가한다. `"extractionState": "manual"` 을 반드시 붙인다 — 없으면 Xcode 가 다음 추출에서 지운다.

| 키 | ko | en |
|---|---|---|
| `session_metric_duration` | 운동 시간 | Workout Time |
| `session_metric_calories` | 활동 kcal | Active kcal |
| `session_metric_heart_rate` | 평균 심박 | Avg. Heart Rate |
| `session_no_match` | 경기 없음 | No matches |
| `session_match_count` | %d경기 | %d matches |
| `session_wins` | %d승 | %dW |
| `session_losses` | %d패 | %dL |

- [ ] **Step 3: 기록 목록을 세션 카드로 바꾼다**

`SessionList.swift`:

```swift
import SwiftUI

/// 기록 목록과 캘린더 하단이 함께 쓰는 세션 목록. 세션 하나가 카드 하나다.
struct SessionList: View {
    let sessions: [MatchSessionGroup]
    let isLoadingMore: Bool
    /// 캘린더 하단은 페이징하지 않으므로 nil.
    let onLoadMore: (() -> Void)?
    let onSelect: (MatchSessionGroup) -> Void
    let onDelete: (MatchSessionGroup) -> Void

    var body: some View {
        List {
            ForEach(sessions) { session in
                SessionCard(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(session) }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .swipeActions(edge: .trailing) {
                        Button(String(localized: "btn_delete"), role: .destructive) { onDelete(session) }
                    }
                    .onAppear { loadMoreIfNeeded(reaching: session) }
            }

            if isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// 무한 스크롤은 세션 기준으로 센다 — 목록의 단위가 세션이 됐다.
    private func loadMoreIfNeeded(reaching session: MatchSessionGroup) {
        guard let onLoadMore else { return }
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        if index == max(0, sessions.count - 3) { onLoadMore() }
    }
}
```

- [ ] **Step 4: 호출부를 고치고 죽은 파일을 지운다**

`HistoryView` 와 캘린더 하단이 `onSelect`/`onDelete` 를 **경기가 아니라 세션**으로 받도록 고친다. 삭제는 세션의 경기 전부와 레코드를 지운다.

```swift
    func delete(_ session: MatchSessionGroup) {
        for match in session.matches {
            try? MatchPersistenceService.shared.delete(match)
        }
        try? SessionPersistenceService.shared.delete(sessionId: session.id)
        reload()
    }
```

그다음 쓰이지 않게 된 파일을 지운다.

```bash
rm Apps/TennisCounter/iOSApp/Components/SessionHeader.swift
rm Apps/TennisCounter/iOSApp/Components/MatchRow.swift
grep -rn "SessionHeader\|MatchRow" Apps/TennisCounter --include="*.swift"
```

Expected: 출력 없음.

- [ ] **Step 5: 빌드 → 시뮬레이터 확인 → 커밋**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test 2>&1 | tail -5
make lint && make format
git add Apps/TennisCounter/iOSApp Apps/TennisCounter/iosTests
git commit -m "✨ 기록 목록을 세션 카드로 바꾼다"
```

---

### Task 6: 세션 상세와 공유 이동

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Features/History/SessionDetailView.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/History/Components/Scoreboard.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/Match/Result/MatchResultView.swift:52`
- Delete: `Apps/TennisCounter/iOSApp/Features/History/Components/MatchDetailSheet.swift`

**Interfaces:**
- Consumes: Task 4 의 `MatchSessionGroup`, 기존 `MatchShareButton(match:appearance:)`
- Produces: `SessionDetailView(session: MatchSessionGroup)`

- [ ] **Step 1: 스코어보드를 고친다**

`Scoreboard.swift` 의 `row(...)` 를 바꾼다. 굵기를 균일하게 두고 색으로 가른다 — 워치 `PlayerPointButton` 과 같은 색이다.

```swift
    private func row(name: String, games: [Int], color: Color) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            Spacer(minLength: 8)
            ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                Text(verbatim: "\(game)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
                    .frame(width: 24)
            }
        }
    }
```

`body` 의 호출부도 함께 바꾼다. `isWinner` 는 더 쓰지 않으므로 `didWin` 과 함께 지운다.

```swift
                row(name: String(localized: "match_detail_me"),
                    games: sets.map(\.myGames),
                    color: .green)
                row(name: match.opponentName ?? String(localized: "match_detail_opponent"),
                    games: sets.map(\.yourGames),
                    color: .orange)
```

- [ ] **Step 2: 세션 상세 화면**

`iOSApp/Features/History/SessionDetailView.swift`:

```swift
import SwiftUI

/// 세션 하나의 상세. 기록 목록에서 push 로 연다.
///
/// 경기마다 따로 화면을 두지 않는다 — 경기 카드를 이 화면에 쭉 늘어놓는다.
struct SessionDetailView: View {
    let session: MatchSessionGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                metrics
                if !session.matches.isEmpty { matchSection }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let last = session.matches.last {
                    MatchShareButton(match: last, appearance: .toolbar)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.dateText(session.date))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            if let range = timeRangeText {
                Text(range)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metrics: some View {
        SessionMetricsGrid(session: session)
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: String(localized: "session_match_count"), session.matchCount))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            ForEach(Array(session.matches.enumerated()), id: \.element.id) { index, match in
                SessionMatchCard(match: match, order: index + 1)
            }
        }
    }

    private var timeRangeText: String? {
        guard let record = session.record, let end = record.endedAt else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: record.startedAt)) – \(formatter.string(from: end))"
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: date)
    }
}
```

**공유 버튼은 세션의 마지막 경기를 넘긴다.** 카드가 워크아웃 누적값을 쓰므로 마지막 경기가 곧
세션 전체다. 경기가 없는 세션은 버튼이 그려지지 않는다 (`MatchShareButton` 이 누적값 없으면 숨긴다).

- [ ] **Step 3: 지표 그리드와 경기 카드**

같은 파일 아래에 private helper 로 둔다 (한 파일 = 한 타입의 예외).

```swift
private struct SessionMetricsGrid: View {
    let session: MatchSessionGroup

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                cell(String(localized: "session_metric_duration"), durationText, .brand)
                cell(String(localized: "share_metric_active"), caloriesText, Color(red: 1, green: 0.702, blue: 0.251))
            }
            Divider()
            HStack(spacing: 14) {
                cell(String(localized: "share_metric_total"), totalCaloriesText, Color(red: 1, green: 0.702, blue: 0.251))
                cell(String(localized: "session_metric_heart_rate"), heartRateText, Color(red: 1, green: 0.42, blue: 0.341))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func cell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(value == "–" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationText: String { session.elapsedSeconds.map(CumulativeDuration.format) ?? "–" }
    private var caloriesText: String { format(session.activeCalories) }
    private var totalCaloriesText: String { format(session.totalCalories) }
    private var heartRateText: String { format(session.averageHeartRate) }

    private func format(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(0))) ?? "–"
    }
}

private struct SessionMatchCard: View {
    let match: Match
    let order: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(format: String(localized: "session_match_order"), order))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let detail = detailText {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Scoreboard(match: match)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var detailText: String? {
        guard let seconds = match.durationSeconds else { return nil }
        return String(format: String(localized: "session_match_duration"), seconds / 60)
    }
}
```

문자열 3개를 더 넣는다 (`extractionState: manual`).

| 키 | ko | en |
|---|---|---|
| `session_match_order` | %d경기 | Match %d |
| `session_match_duration` | %d분 | %d min |
| `share_metric_active` | 활동 킬로칼로리 | Active Calories |
| `share_metric_total` | 총 킬로칼로리 | Total Calories |

- [ ] **Step 4: 목록에서 push 로 잇고, 경기 상세 시트를 지운다**

`HistoryView` 의 `SessionList` 를 `NavigationStack` 안에 두고 `navigationDestination(for: MatchSessionGroup.self)` 또는 `selectedSession` 바인딩으로 `SessionDetailView` 를 push 한다.

`MatchResultView.swift:52` 의 `MatchShareButton(match: savedMatch)` 줄을 지운다.

```bash
rm Apps/TennisCounter/iOSApp/Features/History/Components/MatchDetailSheet.swift
grep -rn "MatchDetailSheet" Apps/TennisCounter --include="*.swift"
```

Expected: 출력 없음.

- [ ] **Step 5: 빌드·테스트 → 커밋**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test 2>&1 | tail -5
make lint && make format
git add Apps/TennisCounter/iOSApp
git commit -m "✨ 세션 상세 화면과 공유 버튼 일원화"
```

---

### Task 7: 요약 — 기간별 통계와 차트

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/Summary/SummaryViewModel.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/Summary/SummaryView.swift`
- Modify: `Apps/TennisCounter/iOSApp/Features/Summary/Components/RecentTrendChart.swift`
- Delete: `Apps/TennisCounter/iOSApp/Features/Summary/Components/RecentSessionCard.swift`
- Test: `Apps/TennisCounter/iosTests/Summary/SummaryViewModelTests.swift` (기존 파일에 추가)

**Interfaces:**
- Consumes: Task 4 의 `MatchSessionGroup`, Task 5 의 `SessionCard`
- Produces: `SummaryStats.sessionCount: Int` · `SummaryStats.averageSessionSeconds: Int?`, `SummaryViewModel.monthlySessionCounts(from:records:) -> [(month: Date, count: Int)]`

- [ ] **Step 1: 실패하는 테스트** (기존 파일 끝에 추가)

```swift
    @Test func allPeriodCountsSessionsAndAverage() {
        let viewModel = SummaryViewModel()
        viewModel.selectedPeriod = .all

        let sessionA = UUID()
        let first = Match()
        first.workoutSessionId = sessionA
        first.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        first.workoutElapsedSeconds = 1000

        let sessionB = UUID()
        let second = Match()
        second.workoutSessionId = sessionB
        second.startedAt = Date(timeIntervalSince1970: 1_700_100_000)
        second.workoutElapsedSeconds = 2000

        let stats = viewModel.stats(from: [first, second], records: [])
        #expect(stats.sessionCount == 2)
        #expect(stats.averageSessionSeconds == 1500)
    }

    @Test func monthlySessionCountsGroupsByMonth() {
        let viewModel = SummaryViewModel()
        let calendar = Calendar.current

        let august = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let septemberOne = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let septemberTwo = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!

        let matches = [august, septemberOne, septemberTwo].map { date -> Match in
            let match = Match()
            match.workoutSessionId = UUID()
            match.startedAt = date
            return match
        }

        let counts = viewModel.monthlySessionCounts(from: matches, records: [])
        #expect(counts.count == 2)
        #expect(counts.last?.count == 2)
    }
```

- [ ] **Step 2: 실패 확인**

Run: `-only-testing:RalliTests/SummaryViewModelTests`
Expected: `value of type 'SummaryStats' has no member 'sessionCount'`

- [ ] **Step 3: 구현**

`SummaryStats` 에 두 값을 더한다.

```swift
struct SummaryStats {
    let totalMatches: Int
    let wins: Int
    let winRate: Double
    let totalCalories: Double
    let totalDuration: Int
    /// `전체` 기간에서 쓴다 — 누적값은 그 기간에서 의미를 잃는다.
    let sessionCount: Int
    let averageSessionSeconds: Int?
}
```

`stats(from:records:)` 끝에서 세션 그룹을 만들어 두 값을 채운다.

```swift
        let groups = MatchSessionGroup.group(filtered, records: records)
        let sessionCount = groups.count
        let durations = groups.compactMap(\.elapsedSeconds)
        let averageSessionSeconds = durations.isEmpty ? nil : durations.reduce(0, +) / durations.count
```

월별 세션 수:

```swift
    /// `전체` 기간 차트용. 월 오름차순.
    func monthlySessionCounts(from matches: [Match],
                              records: [WorkoutSessionRecord]) -> [(month: Date, count: Int)]
    {
        let calendar = Calendar.current
        let groups = MatchSessionGroup.group(matches, records: records)
        var counts: [Date: Int] = [:]
        for group in groups {
            let components = calendar.dateComponents([.year, .month], from: group.date)
            guard let month = calendar.date(from: components) else { continue }
            counts[month, default: 0] += 1
        }
        return counts.keys.sorted().map { (month: $0, count: counts[$0] ?? 0) }
    }
```

- [ ] **Step 4: 화면을 기간에 따라 가른다**

`SummaryView` 의 `statsSection` 은 `viewModel.selectedPeriod == .all` 일 때 시간·칼로리 대신
**세션 수 · 세션당 평균 시간**을 그린다. `trendSection` 도 `.all` 이면 `monthlySessionCounts` 를
막대로 그리고, 아니면 지금의 `RecentTrendChart` 를 쓴다.

차트는 단일 계열이므로 **범례를 두지 않고 축 라벨만** 둔다. 숫자는 모든 막대에 붙이지 않고
**최댓값 하나에만** 붙인다.

`recentSessionSection` 은 `SessionCard` 로 바꾸고, 탭하면 상세로 가지 않고 **기록 탭으로 전환**한다.
`MainTabView` 의 선택 탭 바인딩을 타고 올라가며, 기록 탭이 캘린더 모드면 목록 모드로 바꾼다.

```bash
rm Apps/TennisCounter/iOSApp/Features/Summary/Components/RecentSessionCard.swift
grep -rn "RecentSessionCard" Apps/TennisCounter --include="*.swift"
```

Expected: 출력 없음.

- [ ] **Step 5: 통과 확인 → 커밋**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test 2>&1 | tail -5
make lint && make format
git add Apps/TennisCounter/iOSApp Apps/TennisCounter/iosTests
git commit -m "✨ 요약 통계·차트를 기간에 따라 가른다"
```

---

### Task 8: 검증과 마무리

- [ ] **Step 1: 시뮬레이터에서 전체 흐름**

1. 기록 탭 — 세션 카드가 뜨고, 경기 행이 없다
2. 카드를 탭 → 세션 상세가 **밀려 들어온다**. 공유 버튼이 우상단에 있다
3. 공유 → 카드 미리보기가 세션 값이다
4. 카드를 스와이프 → 세션이 통째로 사라지고, **앱을 다시 켜도 돌아오지 않는다**
5. 요약 탭 — 기간을 `전체` 로 바꾸면 **세션 수 · 세션당 평균 시간**과 **월별 세션 수** 차트가 뜬다
6. 요약의 최근 세션을 탭 → **기록 탭으로 바뀌고** 그 세션이 맨 위에 있다
7. 경기 결과 화면에 **공유 버튼이 없다**

- [ ] **Step 2: 실기기에서 세션 레코드**

시뮬레이터로는 확인할 수 없다 — 워치가 있어야 한다.

1. 워치로 경기 2판을 치고 저장한 뒤, **경기를 더 하지 않고 5분쯤 지나서** 운동을 종료한다
2. 세션 카드의 운동 시간이 **마지막 경기 종료 시각이 아니라 운동 종료 시각까지** 인지 본다
3. **평균 심박이 `–` 가 아니라 값으로** 나오는지 본다
4. 경기를 한 판도 저장하지 않고 운동만 한 세션이 **`경기 없음` 카드로** 뜨는지 본다
5. 예전 기록(레코드 없는 세션)이 **여전히 시간·칼로리를 보여주고 심박만 `–`** 인지 본다

- [ ] **Step 3: `TODO.md` 갱신**

#9 행의 상태를 바꾸고 이 플랜과 스펙을 링크한다. "남은 논의 — #9" 절은 결정이 끝났으므로
스펙으로 옮겼다는 한 줄만 남기고 지운다.

- [ ] **Step 4: PR**

```bash
git add TODO.md
git commit -m "📝 TODO — #9 세션 중심 재편 진행 상태"
git push -u origin feat/session-centric-history
```

PR 본문에는 스펙의 "왜 이렇게 됐나" 절과 실기기 확인 항목을 옮겨 적는다.

---

## Self-Review

- **스펙 커버리지** — 세션 레코드(Task 1·2·3), 집계·폴백·빈 세션(Task 4), 세션 카드·목록·삭제(Task 5), 세션 상세·스코어보드 색·공유 일원화(Task 6), 기간별 통계·차트·최근 세션 탭 전환(Task 7), 실기기 확인(Task 8) ✅
- **타입 일관성** — `MatchSessionGroup(id:matches:record:)` 가 Task 4 정의·Task 5·6·7 사용에서 일치 ✅. `SessionPersistenceService` 의 `upsert`/`delete(sessionId:)` 가 Task 1 정의·Task 3·5 사용에서 일치 ✅. `WorkoutEndMessage` 생성자 인자 이름이 Task 2 정의·Task 3 테스트에서 일치 ✅
- **폴백 규칙** — 시간·활동칼로리·총칼로리는 폴백, **심박은 폴백하지 않는다**(경기 평균은 세션 평균이 아니다). Task 4 코드와 테스트, Task 8 실기기 항목이 같은 규칙 ✅
- **CloudKit** — `WorkoutSessionRecord` 의 모든 속성이 optional 또는 기본값 ✅
- 플레이스홀더 없음. Task 5 Step 4 · Task 6 Step 4 · Task 7 Step 4 는 기존 화면 구조에 맞춰
  호출부를 잇는 작업이라 `grep` 으로 대상을 찾는 절차를 함께 적었다.
