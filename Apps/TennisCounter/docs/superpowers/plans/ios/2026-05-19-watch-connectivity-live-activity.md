# WatchConnectivity 양방향 동기화 + iOS Live Activity 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Watch ↔ iPhone 경기 세션 자동 동기화 + iOS Live Activity 구현. 어느 기기에서 시작해도 상대 기기가 자동 진입하고 양방향 점수 입력이 동기화되며, iOS 잠금화면/Dynamic Island에 실시간 점수가 표시된다.

**Architecture:** Full State Sync (last-write-wins). 점수 입력 시 전체 ScoreState를 상대 기기에 전송해 덮어씀. 경기 시작 시 SessionStartMessage로 상대 기기를 자동 진입시키고, 경기 종료 시 Watch가 MatchEndMessage로 iOS에 세션 데이터를 전달해 SwiftData에 저장한다.

**Tech Stack:** WatchConnectivity, ActivityKit (Live Activity), SwiftData, HealthKit, Combine

---

## 파일 구조

### 삭제
- `Shared/Models/MatchMode.swift` — MatchFormat과 중복, 제거
- `Shared/Persistence/MatchRecord.swift` — Match로 흡수, 제거

### 수정
- `Shared/Models/MatchOptions.swift` — `mode: MatchMode` → `mode: MatchFormat`
- `Shared/Persistence/Match.swift` — workoutSessionId, mode, noAdRule, resultRaw, averageHeartRate 필드 추가
- `Shared/Services/MatchPersistenceService.swift` — 저장 타입 `MatchRecord` → `Match`
- `Shared/Services/WatchConnectivityService.swift` — 새 메시지 타입 + publishers 교체
- `Shared/Models/Score.swift` — `applyRemote()` 메서드 추가
- `iOSApp/Features/Match/Mode/ModeViewModel.swift` — MatchMode → MatchFormat
- `WatchApp/Features/Match/Mode/ModeViewModel.swift` — MatchMode → MatchFormat
- `iOSApp/Features/Match/Score/ScoreViewModel.swift` — sendScoreState, applyRemoteState 추가
- `WatchApp/Features/Match/Score/ScoreViewModel.swift` — sendScoreState, applyRemoteState 추가
- `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` — SessionStartMessage 수신/전송, MatchEndMessage 전송
- `WatchApp/Features/Home/HomeView.swift` — receivedSessionStart 구독, 자동 진입
- `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` — receivedSessionStart/receivedMatchEnd 구독, saveFromWatch, Live Activity 연결
- `iOSApp/iOSApp.swift` (MainTabView) — receivedSessionStart 구독, 자동 진입
- `iOSApp/Components/MatchDetailSheet.swift` — 칼로리 + 평균 심박수 표시
- `iOSApp/Features/Summary/Components/StatCard.swift` — 아이콘 제거

### 신규
- `iOSApp/LiveActivity/TennisActivityAttributes.swift` — ActivityAttributes + ContentState 정의
- `iOSApp/LiveActivity/LiveActivityService.swift` — 시작/업데이트/종료 서비스
- `TennisLiveActivity/TennisLiveActivityBundle.swift` — Widget Extension @main (Xcode 수동 생성)
- `TennisLiveActivity/TennisLiveActivityView.swift` — 잠금화면 + Dynamic Island 뷰

---

## Task 1: MatchMode → MatchFormat 통일

**Files:**
- Delete: `Shared/Models/MatchMode.swift`
- Modify: `Shared/Models/MatchOptions.swift`
- Modify: `iOSApp/Features/Match/Mode/ModeViewModel.swift`
- Modify: `WatchApp/Features/Match/Mode/ModeViewModel.swift`

- [ ] **Step 1: MatchOptions.swift 수정**

```swift
// Shared/Models/MatchOptions.swift
import Foundation

struct MatchOptions {
    let mode: MatchFormat   // MatchMode → MatchFormat
    let noAdRule: Bool
    let noTieRule: Bool
}
```

- [ ] **Step 2: iOS ModeViewModel.swift 수정**

```swift
// iOSApp/Features/Match/Mode/ModeViewModel.swift
import Foundation

class ModeViewModel: ObservableObject {
    @Published var selectedMode: MatchFormat = .oneSet  // MatchMode → MatchFormat
    @Published var noAdRule: Bool = true
    @Published var noTieRule: Bool = false

    var options: MatchOptions {
        MatchOptions(mode: selectedMode, noAdRule: noAdRule, noTieRule: noTieRule)
    }
}
```

- [ ] **Step 3: Watch ModeViewModel.swift 수정**

```swift
// WatchApp/Features/Match/Mode/ModeViewModel.swift
import Foundation

class ModeViewModel: ObservableObject {
    @Published var selectedMode: MatchFormat = .oneSet  // MatchMode → MatchFormat
    @Published var noAdRule: Bool = true
    @Published var noTieRule: Bool = false

    var options: MatchOptions {
        MatchOptions(mode: selectedMode, noAdRule: noAdRule, noTieRule: noTieRule)
    }
}
```

- [ ] **Step 4: MatchMode.swift 삭제**

Finder 또는 터미널에서 삭제:
```bash
rm /Users/yj/Workspace/tennis_counter/Shared/Models/MatchMode.swift
```

- [ ] **Step 5: iOS + Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"

xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: 커밋**

```bash
git add Shared/Models/MatchOptions.swift iOSApp/Features/Match/Mode/ModeViewModel.swift WatchApp/Features/Match/Mode/ModeViewModel.swift
git rm Shared/Models/MatchMode.swift
git commit -m "refactor: MatchMode를 MatchFormat으로 통일"
```

---

## Task 1.5: CloudKit Capability 설정 (Xcode 수동)

**SwiftData `cloudKitDatabase: .automatic`이 실제로 동작하려면 아래 설정이 선행돼야 한다.**
코드 변경 없음. Xcode + Apple Developer 콘솔 작업.

- [ ] **Step 1: iOS 타겟에 iCloud Capability 추가**

```
Xcode → TennisCounter 타겟 → Signing & Capabilities 탭
→ "+ Capability" → "iCloud" 추가
→ "CloudKit" 체크박스 활성화
→ Containers "+" 버튼 → "iCloud.com.yj.TennisCounter" 자동 생성
```

- [ ] **Step 2: entitlements 자동 추가 확인**

`TennisCounter.entitlements`에 다음이 추가됐는지 확인:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.yj.TennisCounter</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

- [ ] **Step 3: 실기기 빌드 후 CloudKit Dashboard 스키마 확인**

처음 실기기 빌드하면 Development 환경에 스키마 자동 생성됨.
https://icloud.developer.apple.com → CloudKit Database → TennisCounter → Schema 탭에서
`CD_Match`, `CD_SetRecord` 레코드 타입이 생성됐는지 확인. (SwiftData는 `CD_` 접두사 자동 추가)

- [ ] **Step 4: App Store 배포 전 Production 배포 (나중에)**

```
CloudKit Dashboard → Schema → Deploy Schema Changes to Production
```

⚠️ Production 배포 후에는 기존 필드 삭제 불가. 이번 Task 2에서 추가하는 필드들은
모두 optional/default이므로 기존 사용자 데이터와 호환됨.

---

## Task 2: Match 모델 확장 + MatchRecord 제거

**Files:**
- Modify: `Shared/Persistence/Match.swift`
- Modify: `Shared/Services/MatchPersistenceService.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` (MatchRecord 참조 제거)
- Delete: `Shared/Persistence/MatchRecord.swift`

- [ ] **Step 1: Match.swift 확장**

```swift
// Shared/Persistence/Match.swift
import Foundation
import SwiftData

@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var caloriesBurned: Double?
    var durationSeconds: Int?
    var opponentName: String?
    var myTotalSets: Int = 0
    var yourTotalSets: Int = 0
    var isCompleted: Bool = false
    @Relationship(deleteRule: .cascade) var sets: [SetRecord] = []

    // MatchRecord에서 이전
    var workoutSessionId: UUID?
    var mode: String = MatchFormat.oneSet.rawValue
    var noAdRule: Bool = true
    var resultRaw: String = "win"
    var averageHeartRate: Double?

    var matchFormat: MatchFormat {
        get { MatchFormat(rawValue: mode) ?? .oneSet }
        set { mode = newValue.rawValue }
    }

    init() {}
}
```

- [ ] **Step 2: MatchPersistenceService.swift 수정 — 타입 Match로 변경**

```swift
// Shared/Services/MatchPersistenceService.swift
import Foundation
import SwiftData

@MainActor
final class MatchPersistenceService {
    static let shared = MatchPersistenceService()

    private var modelContext: ModelContext?

    private init() {}

    func configure(with context: ModelContext) {
        modelContext = context
    }

    func save(_ match: Match) throws {
        guard let context = modelContext else { return }
        context.insert(match)
        try context.save()
    }

    func fetchAll() throws -> [Match] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchByWorkoutSession(_ sessionId: UUID) throws -> [Match] {
        guard let context = modelContext else { return [] }
        let id = sessionId
        var descriptor = FetchDescriptor<Match>(
            predicate: #Predicate { $0.workoutSessionId == id }
        )
        descriptor.sortBy = [SortDescriptor(\.startedAt)]
        return try context.fetch(descriptor)
    }
}
```

- [ ] **Step 3: Watch WorkoutSessionViewModel에서 MatchRecord 참조 제거**

`saveCurrentMatch()`를 Match를 직접 생성하도록 수정:

```swift
// WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
func saveCurrentMatch() throws {
    guard let session = _currentSession else { return }
    let match = Match()
    match.workoutSessionId = session.workoutSessionId
    match.startedAt = session.startedAt
    match.endedAt = session.endedAt ?? Date()
    match.durationSeconds = Int((session.endedAt ?? Date()).timeIntervalSince(session.startedAt))
    match.mode = session.options.mode.rawValue
    match.noAdRule = session.options.noAdRule
    match.resultRaw = session.result?.rawValue ?? "win"
    match.myTotalSets = session.mySetScore
    match.yourTotalSets = session.yourSetScore
    match.averageHeartRate = session.averageHeartRate
    match.caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
    match.sets = session.completedSets.enumerated().map {
        SetRecord(myGames: $0.element.my, yourGames: $0.element.your, setNumber: $0.offset + 1)
    }
    try MatchPersistenceService.shared.save(match)
}
```

- [ ] **Step 4: MatchRecord.swift 삭제**

```bash
rm /Users/yj/Workspace/tennis_counter/Shared/Persistence/MatchRecord.swift
```

- [ ] **Step 5: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: 커밋**

```bash
git add Shared/Persistence/Match.swift Shared/Services/MatchPersistenceService.swift WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
git rm Shared/Persistence/MatchRecord.swift
git commit -m "refactor: MatchRecord 제거, Match 모델로 통일"
```

---

## Task 3: WatchConnectivityService 메시지 타입 추가

**Files:**
- Modify: `Shared/Services/WatchConnectivityService.swift`

- [ ] **Step 1: WatchConnectivityService.swift 전체 교체**

```swift
// Shared/Services/WatchConnectivityService.swift
import Combine
import Foundation
import WatchConnectivity

// MARK: - Message Types

private enum WCMessageType: String {
    case sessionStart
    case scoreState
    case matchEnd
    case metrics
}

struct SessionStartMessage {
    let sessionId: UUID
    let options: MatchOptions

    func toDictionary() -> [String: Any] {
        [
            "type": WCMessageType.sessionStart.rawValue,
            "sessionId": sessionId.uuidString,
            "mode": options.mode.rawValue,
            "noAdRule": options.noAdRule,
            "noTieRule": options.noTieRule
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.sessionStart.rawValue,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let modeRaw = dict["mode"] as? String,
              let mode = MatchFormat(rawValue: modeRaw) else { return nil }
        sessionId = id
        options = MatchOptions(
            mode: mode,
            noAdRule: dict["noAdRule"] as? Bool ?? true,
            noTieRule: dict["noTieRule"] as? Bool ?? false
        )
    }

    init(sessionId: UUID, options: MatchOptions) {
        self.sessionId = sessionId
        self.options = options
    }
}

struct ScoreState {
    let myScore: Int            // normal: 0/15/30/40/50, tieBreak: raw int
    let yourScore: Int
    let myGameScore: Int
    let yourGameScore: Int
    let mySetScore: Int
    let yourSetScore: Int
    let completedSets: [[Int]]  // [[my, your], ...]
    let isTieBreak: Bool

    func toDictionary() -> [String: Any] {
        [
            "type": WCMessageType.scoreState.rawValue,
            "myScore": myScore,
            "yourScore": yourScore,
            "myGame": myGameScore,
            "yourGame": yourGameScore,
            "mySet": mySetScore,
            "yourSet": yourSetScore,
            "sets": completedSets,
            "tieBreak": isTieBreak
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.scoreState.rawValue,
              let myScore = dict["myScore"] as? Int,
              let yourScore = dict["yourScore"] as? Int,
              let myGame = dict["myGame"] as? Int,
              let yourGame = dict["yourGame"] as? Int,
              let mySet = dict["mySet"] as? Int,
              let yourSet = dict["yourSet"] as? Int else { return nil }
        self.myScore = myScore
        self.yourScore = yourScore
        myGameScore = myGame
        yourGameScore = yourGame
        mySetScore = mySet
        yourSetScore = yourSet
        completedSets = dict["sets"] as? [[Int]] ?? []
        isTieBreak = dict["tieBreak"] as? Bool ?? false
    }

    init(myScore: Int, yourScore: Int, myGameScore: Int, yourGameScore: Int,
         mySetScore: Int, yourSetScore: Int, completedSets: [[Int]], isTieBreak: Bool) {
        self.myScore = myScore
        self.yourScore = yourScore
        self.myGameScore = myGameScore
        self.yourGameScore = yourGameScore
        self.mySetScore = mySetScore
        self.yourSetScore = yourSetScore
        self.completedSets = completedSets
        self.isTieBreak = isTieBreak
    }
}

struct MatchEndMessage {
    let sessionId: UUID
    let result: String          // "win" / "loss"
    let completedSets: [[Int]]
    let startedAt: Date
    let endedAt: Date
    let calories: Double
    let averageHeartRate: Double?
    let mode: String
    let noAdRule: Bool

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": WCMessageType.matchEnd.rawValue,
            "sessionId": sessionId.uuidString,
            "result": result,
            "sets": completedSets,
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "calories": calories,
            "mode": mode,
            "noAdRule": noAdRule
        ]
        if let hr = averageHeartRate { dict["heartRate"] = hr }
        return dict
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.matchEnd.rawValue,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let result = dict["result"] as? String,
              let startTs = dict["startedAt"] as? Double,
              let endTs = dict["endedAt"] as? Double,
              let mode = dict["mode"] as? String else { return nil }
        sessionId = id
        self.result = result
        completedSets = dict["sets"] as? [[Int]] ?? []
        startedAt = Date(timeIntervalSince1970: startTs)
        endedAt = Date(timeIntervalSince1970: endTs)
        calories = dict["calories"] as? Double ?? 0
        averageHeartRate = dict["heartRate"] as? Double
        self.mode = mode
        noAdRule = dict["noAdRule"] as? Bool ?? true
    }

    init(sessionId: UUID, result: String, completedSets: [[Int]], startedAt: Date,
         endedAt: Date, calories: Double, averageHeartRate: Double?, mode: String, noAdRule: Bool) {
        self.sessionId = sessionId
        self.result = result
        self.completedSets = completedSets
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.mode = mode
        self.noAdRule = noAdRule
    }
}

// MARK: - Service

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isWatchReachable: Bool = false
    @Published var receivedSessionStart: SessionStartMessage?
    @Published var receivedScoreState: ScoreState?
    @Published var receivedMatchEnd: MatchEndMessage?
    @Published var receivedMetrics: WorkoutMetrics?

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSessionStart(_ msg: SessionStartMessage) {
        send(msg.toDictionary())
    }

    func sendScoreState(_ state: ScoreState) {
        send(state.toDictionary())
    }

    func sendMatchEnd(_ msg: MatchEndMessage) {
        let dict = msg.toDictionary()
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(dict)
        }
    }

    func sendMetrics(_ metrics: WorkoutMetrics) {
        send(metrics.toDictionary())
    }

    private func send(_ dict: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        #if os(iOS)
        guard WCSession.default.isWatchAppInstalled else { return }
        #endif
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(dict)
        }
    }

    private func handle(_ message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case WCMessageType.sessionStart.rawValue:
                self.receivedSessionStart = SessionStartMessage(from: message)
            case WCMessageType.scoreState.rawValue:
                self.receivedScoreState = ScoreState(from: message)
            case WCMessageType.matchEnd.rawValue:
                self.receivedMatchEnd = MatchEndMessage(from: message)
            case WCMessageType.metrics.rawValue:
                self.receivedMetrics = WorkoutMetrics(from: message)
            default:
                break
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_: WCSession) {}
    func sessionDidDeactivate(_: WCSession) {
        WCSession.default.activate()
    }
    #endif
}
```

- [ ] **Step 2: WorkoutMetrics에 toDictionary() 추가 확인**

`WorkoutMetrics(from:)`과 `toDictionary()`가 이미 구현돼 있는지 확인. 없다면 `Shared/Models/WorkoutMetrics.swift`에 추가:

```swift
// 기존 WorkoutMetrics에 추가 (없는 경우)
func toDictionary() -> [String: Any] {
    [
        "type": "metrics",
        WorkoutMetrics.messageKey: [
            "calories": calories,
            "heartRate": heartRate,
            "steps": steps
        ] as [String: Any]
    ]
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: 커밋**

```bash
git add Shared/Services/WatchConnectivityService.swift
git commit -m "feat: WatchConnectivity 메시지 타입 추가 (SessionStart/ScoreState/MatchEnd)"
```

---

## Task 4: Score.applyRemote() 추가

**Files:**
- Modify: `Shared/Models/Score.swift`

- [ ] **Step 1: Score.swift에 applyRemote 추가**

`Score` 클래스 끝에 다음 메서드 추가:

```swift
// Shared/Models/Score.swift — 클래스 내부에 추가

/// 원격 기기에서 받은 상태를 직접 적용. ScoreViewModel에서만 호출.
func applyRemote(myScore: Int, yourScore: Int, isTieBreak: Bool) {
    snapshot = nil
    lastAction = .none
    if isTieBreak {
        gameMode = .tieBreak
        myTieBreak = myScore    // tieBreak 모드에서는 raw int 전달
        yourTieBreak = yourScore
    } else {
        gameMode = .normal
        let myIdx = Self.scoreValues.firstIndex(of: myScore) ?? 0
        let yourIdx = Self.scoreValues.firstIndex(of: yourScore) ?? 0
        myNormal = Self.normalStates[myIdx]
        yourNormal = Self.normalStates[yourIdx]
    }
    objectWillChange.send()
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 3: 커밋**

```bash
git add Shared/Models/Score.swift
git commit -m "feat: Score.applyRemote() 추가 — 원격 상태 직접 주입"
```

---

## Task 5: ScoreViewModel 양방향 동기화 (iOS + Watch 공통)

두 플랫폼의 ScoreViewModel은 구조가 달라 각각 수정한다.

**Files:**
- Modify: `iOSApp/Features/Match/Score/ScoreViewModel.swift`
- Modify: `WatchApp/Features/Match/Score/ScoreViewModel.swift`

- [ ] **Step 1: iOS ScoreViewModel 수정**

```swift
// iOSApp/Features/Match/Score/ScoreViewModel.swift
import Combine
import Foundation

@MainActor
final class ScoreViewModel: ObservableObject {
    let options: MatchOptions

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    var isTieBreak: Bool { score.gameMode == .tieBreak }

    var hasProgress: Bool {
        myGameScore > 0 || yourGameScore > 0 ||
        mySetScore > 0 || yourSetScore > 0 ||
        !completedSets.isEmpty ||
        score.lastAction != .none
    }

    private var isApplyingRemote = false
    private var cancellable: AnyCancellable?
    private var connectivityCancellable: AnyCancellable?
    private let connectivity = WatchConnectivityService.shared

    init(options: MatchOptions = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) {
        self.options = options
        self.score.noAdRule = options.noAdRule
        cancellable = score.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        connectivityCancellable = connectivity.$receivedScoreState
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyRemoteState(state) }

        // Watch 재연결 시 현재 상태 즉시 전송 (Flow 4)
        connectivity.$isWatchReachable
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sendScoreState() }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        guard !isMatchOver else { return }
        guard score.addPoint(side) != nil else { return }
        if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
        score.resetData()
        sendScoreState()
        checkSetUpdate()
        if myGameScore == 6 && yourGameScore == 6 && !options.noTieRule {
            score.setTieBreakMode()
        }
    }

    func undo() {
        score.undo()
    }

    func resetAll() {
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        currentSetNumber = 1
        completedSets = []
        isMatchOver = false
        didWin = false
        score.noAdRule = options.noAdRule
        score.resetData()
    }

    func applyRemoteState(_ state: ScoreState) {
        isApplyingRemote = true
        myGameScore = state.myGameScore
        yourGameScore = state.yourGameScore
        mySetScore = state.mySetScore
        yourSetScore = state.yourSetScore
        completedSets = state.completedSets.map { (my: $0[0], your: $0[1]) }
        score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
        isApplyingRemote = false
    }

    private func sendScoreState() {
        guard !isApplyingRemote else { return }
        let myScore = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
        let yourScore = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
        connectivity.sendScoreState(ScoreState(
            myScore: myScore,
            yourScore: yourScore,
            myGameScore: myGameScore,
            yourGameScore: yourGameScore,
            mySetScore: mySetScore,
            yourSetScore: yourSetScore,
            completedSets: completedSets.map { [$0.my, $0.your] },
            isTieBreak: score.gameMode == .tieBreak
        ))
    }

    private func checkSetUpdate() {
        guard isSetComplete() else { return }
        let myWonSet = myGameScore > yourGameScore
        completedSets.append((my: myGameScore, your: yourGameScore))
        if myWonSet { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0
        currentSetNumber += 1
        if mySetScore >= options.mode.setsToWin {
            didWin = true
            isMatchOver = true
        } else if yourSetScore >= options.mode.setsToWin {
            didWin = false
            isMatchOver = true
        }
    }

    private func isSetComplete() -> Bool {
        let maxGames = max(myGameScore, yourGameScore)
        let minGames = min(myGameScore, yourGameScore)
        if maxGames == 7 && minGames == 6 { return true }
        return maxGames >= 6 && (maxGames - minGames) >= 2
    }
}
```

- [ ] **Step 2: Watch ScoreViewModel 수정**

```swift
// WatchApp/Features/Match/Score/ScoreViewModel.swift
import Combine
import SwiftUI

class ScoreViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var completedSets: [SetScore] = []

    let options: MatchOptions
    var onMatchFinished: ((MatchResult, [SetScore]) -> Void)?

    private var isApplyingRemote = false
    private var tieBreakInProgress: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init(options: MatchOptions) {
        self.options = options
        score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreState
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyRemoteState(state) }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        guard score.addPoint(side) != nil else { return }
        withAnimation(.bouncy) {
            if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
        }
        score.reset()
        sendScoreState()
        checkSetUpdate()
    }

    func undo() {
        score.undo()
    }

    func applyRemoteState(_ state: ScoreState) {
        isApplyingRemote = true
        myGameScore = state.myGameScore
        yourGameScore = state.yourGameScore
        mySetScore = state.mySetScore
        yourSetScore = state.yourSetScore
        completedSets = state.completedSets.map { SetScore(my: $0[0], your: $0[1]) }
        score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
        tieBreakInProgress = state.isTieBreak
        isApplyingRemote = false
    }

    private func sendScoreState() {
        guard !isApplyingRemote else { return }
        let myScore = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
        let yourScore = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
        connectivity.sendScoreState(ScoreState(
            myScore: myScore,
            yourScore: yourScore,
            myGameScore: myGameScore,
            yourGameScore: yourGameScore,
            mySetScore: mySetScore,
            yourSetScore: yourSetScore,
            completedSets: completedSets.map { [$0.my, $0.your] },
            isTieBreak: score.gameMode == .tieBreak
        ))
    }

    private func checkSetUpdate() {
        let my = myGameScore, your = yourGameScore

        if tieBreakInProgress {
            if (my == 7 && your == 6) || (your == 7 && my == 6) {
                tieBreakInProgress = false
                let winner: PlayerSide = my == 7 ? .me : .opponent
                finalizeSet(winner: winner)
            }
            return
        }

        if !options.noTieRule, my == 6, your == 6 {
            score.setTieBreakMode()
            tieBreakInProgress = true
            return
        }

        let maxG = max(my, your), minG = min(my, your)
        let setWinner: PlayerSide? = if options.noTieRule {
            if my >= 6, my > your { .me } else if your >= 6, your > my { .opponent } else { nil }
        } else {
            if maxG >= 6, (maxG - minG) >= 2 { my > your ? .me : .opponent } else { nil }
        }

        if let winner = setWinner { finalizeSet(winner: winner) }
    }

    private func finalizeSet(winner: PlayerSide) {
        completedSets.append(SetScore(my: myGameScore, your: yourGameScore))
        if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0

        let setsToWin = options.mode.setsToWin
        if mySetScore >= setsToWin {
            onMatchFinished?(.win, completedSets)
        } else if yourSetScore >= setsToWin {
            onMatchFinished?(.loss, completedSets)
        }
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"

xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Score/ScoreViewModel.swift WatchApp/Features/Match/Score/ScoreViewModel.swift
git commit -m "feat: ScoreViewModel 양방향 동기화 — applyRemoteState, sendScoreState"
```

---

## Task 6: Watch WorkoutSessionViewModel 세션 동기화

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`

- [ ] **Step 1: WorkoutSessionViewModel 전체 교체**

```swift
// WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
import Combine
import Foundation
import WidgetKit

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var isPaused: Bool = false

    let healthKit = HealthKitService.shared
    let workoutSessionId: UUID = .init()

    private let connectivity = WatchConnectivityService.shared
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.yj.TennisCounter")
    private var cancellables = Set<AnyCancellable>()
    private var _currentSession: MatchSession?

    init() {
        healthKit.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)

        // iOS가 경기를 시작했을 때 Watch 자동 진입 (이미 경기 중이면 무시)
        connectivity.$receivedSessionStart
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self, case .modeSelection = self.phase else { return }
                if !self.healthKit.isWorkoutActive { self.startWorkout() }
                self.startMatch(options: msg.options, sessionId: msg.sessionId, isRemote: true)
            }
            .store(in: &cancellables)
    }

    func startWorkout() {
        Task {
            await healthKit.requestAuthorization()
            healthKit.startWorkout()
            appGroupDefaults?.set(true, forKey: "isWorkoutActive")
            WidgetCenter.shared.reloadTimelines(ofKind: "ComplicationApp")
        }
    }

    func startMatch(options: MatchOptions, sessionId: UUID? = nil, isRemote: Bool = false) {
        let id = sessionId ?? workoutSessionId
        let session = MatchSession(
            workoutSessionId: id,
            options: options,
            kcalAtStart: healthKit.currentCalories
        )
        _currentSession = session
        phase = .playing(options)

        if !isRemote {
            connectivity.sendSessionStart(SessionStartMessage(sessionId: id, options: options))
        }
    }

    func currentSession() -> MatchSession? { _currentSession }

    func finishMatch(result: MatchResult, completedSets: [SetScore]) {
        guard let session = _currentSession else { return }
        session.endedAt = Date()
        session.result = result
        session.completedSets = completedSets
        session.kcalAtEnd = healthKit.currentCalories
        session.mySetScore = completedSets.count(where: { $0.my > $0.your })
        session.yourSetScore = completedSets.count(where: { $0.your > $0.my })

        phase = .finished(session)

        Task {
            session.averageHeartRate = await healthKit.averageHeartRate(
                from: session.startedAt,
                to: session.endedAt ?? Date()
            )
            // averageHeartRate 수집 후 iOS로 세션 전달
            sendMatchEndToiOS(session: session)
        }
    }

    func saveCurrentMatch() throws {
        // Watch에서는 iOS로 전달하므로 직접 저장하지 않음.
        // iOS 없이 단독 사용 시를 대비한 fallback — ModelContext 없으면 무시됨.
        guard let session = _currentSession else { return }
        let match = Match()
        match.workoutSessionId = session.workoutSessionId
        match.startedAt = session.startedAt
        match.endedAt = session.endedAt ?? Date()
        match.durationSeconds = Int((session.endedAt ?? Date()).timeIntervalSince(session.startedAt))
        match.mode = session.options.mode.rawValue
        match.noAdRule = session.options.noAdRule
        match.resultRaw = session.result?.rawValue ?? "win"
        match.myTotalSets = session.mySetScore
        match.yourTotalSets = session.yourSetScore
        match.averageHeartRate = session.averageHeartRate
        match.caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
        match.sets = session.completedSets.enumerated().map {
            SetRecord(myGames: $0.element.my, yourGames: $0.element.your, setNumber: $0.offset + 1)
        }
        try MatchPersistenceService.shared.save(match)
    }

    func startNewMatch() {
        _currentSession = nil
        phase = .modeSelection
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options)
    }

    func pauseWorkout() { healthKit.pauseWorkout() }
    func resumeWorkout() { healthKit.resumeWorkout() }

    func endWorkout() {
        _currentSession = nil
        appGroupDefaults?.set(false, forKey: "isWorkoutActive")
        WidgetCenter.shared.reloadTimelines(ofKind: "ComplicationApp")
        Task { _ = await healthKit.stopWorkout() }
    }

    private func sendMatchEndToiOS(session: MatchSession) {
        let msg = MatchEndMessage(
            sessionId: session.workoutSessionId,
            result: session.result?.rawValue ?? "win",
            completedSets: session.completedSets.map { [$0.my, $0.your] },
            startedAt: session.startedAt,
            endedAt: session.endedAt ?? Date(),
            calories: (session.kcalAtEnd ?? 0) - session.kcalAtStart,
            averageHeartRate: session.averageHeartRate,
            mode: session.options.mode.rawValue,
            noAdRule: session.options.noAdRule
        )
        connectivity.sendMatchEnd(msg)
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 3: 커밋**

```bash
git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
git commit -m "feat: Watch WorkoutSessionViewModel — SessionStart 수신/전송, MatchEnd 전송"
```

---

## Task 7: Watch HomeView 자동 진입

iOS가 경기를 시작하면 Watch가 자동으로 WorkoutSessionView로 이동해야 한다.

**Files:**
- Modify: `WatchApp/Features/Home/HomeView.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionView.swift`

- [ ] **Step 1: WorkoutSessionView에 remoteSession 파라미터 추가**

```swift
// WatchApp/Features/WorkoutSession/WorkoutSessionView.swift
import SwiftUI

struct WorkoutSessionView: View {
    let remoteSession: SessionStartMessage?

    @StateObject private var viewModel: WorkoutSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1

    init(remoteSession: SessionStartMessage? = nil) {
        self.remoteSession = remoteSession
        _viewModel = StateObject(wrappedValue: WorkoutSessionViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutControlsView(viewModel: viewModel, dismiss: dismiss)
                .tag(0)
            centerView
                .tag(1)
            WorkoutMetricsView(healthKit: viewModel.healthKit, isPaused: viewModel.isPaused)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear {
            viewModel.startWorkout()
            if let remote = remoteSession {
                viewModel.startMatch(options: remote.options, sessionId: remote.sessionId, isRemote: true)
            }
        }
    }

    @ViewBuilder
    private var centerView: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView(viewModel: viewModel)
        case let .playing(options):
            ScoreView(options: options, flowViewModel: viewModel)
        case let .finished(session):
            MatchResultView(session: session, flowViewModel: viewModel)
        }
    }
}
```

- [ ] **Step 2: HomeView에 자동 진입 로직 추가**

```swift
// WatchApp/Features/Home/HomeView.swift
import SwiftUI

struct HomeView: View {
    @State private var autoNavigate = false
    @State private var remoteSession: SessionStartMessage?
    private let connectivity = WatchConnectivityService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Ralli")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.green)
                        .italic()
                    Text("Tennis Counter")
                        .font(.system(size: 14, weight: .semibold))
                }
                NavigationLink(destination: WorkoutSessionView()) {
                    Text(String(localized: "watch_start_workout"))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                // 자동 진입용 숨겨진 NavigationLink
                NavigationLink(
                    destination: WorkoutSessionView(remoteSession: remoteSession),
                    isActive: $autoNavigate
                ) { EmptyView() }
                .hidden()
            }
            .padding()
        }
        .onReceive(connectivity.$receivedSessionStart.compactMap { $0 }) { msg in
            remoteSession = msg
            autoNavigate = true
        }
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: 커밋**

```bash
git add WatchApp/Features/Home/HomeView.swift WatchApp/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "feat: Watch HomeView — iOS 시작 시 자동 진입"
```

---

## Task 8: iOS WorkoutSessionViewModel 세션 동기화

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`

- [ ] **Step 1: WorkoutSessionViewModel 전체 교체**

```swift
// iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
import Combine
import Foundation

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var elapsedSeconds: Int = 0
    @Published var metrics: WorkoutMetrics = .init()
    @Published var watchConnected: Bool = false
    @Published var isPaused: Bool = false
    @Published var completedMatchCount: Int = 0

    private var startedAt: Date?
    private var sessionId: UUID = .init()
    private var _currentSession: MatchSession?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init() {
        connectivity.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$watchConnected)

        connectivity.$receivedMetrics
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] received in
                guard let self else { return }
                self.metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(self.elapsedSeconds),
                    calories: received.calories,
                    heartRate: received.heartRate,
                    steps: received.steps
                )
            }
            .store(in: &cancellables)

        // Watch가 경기를 시작했을 때 iOS 자동 진입
        connectivity.$receivedSessionStart
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.sessionId = msg.sessionId
                self.startSession()
                self.startMatch(options: msg.options, isRemote: true)
            }
            .store(in: &cancellables)

        // Watch에서 경기 종료 — iOS가 저장 담당
        connectivity.$receivedMatchEnd
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.saveFromWatch(msg)
                // ResultView 진입용 세션 구성
                let session = self.buildSession(from: msg)
                self.completedMatchCount += 1
                self.phase = .finished(session)
            }
            .store(in: &cancellables)
    }

    deinit { timer?.invalidate() }

    func startSession() {
        startedAt = Date()
        startTimer()
    }

    func pauseSession() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resumeSession() {
        isPaused = false
        startTimer()
    }

    func startMatch(options: MatchOptions, isRemote: Bool = false) {
        _currentSession = MatchSession(
            workoutSessionId: sessionId,
            options: options,
            startedAt: startedAt ?? Date(),
            kcalAtStart: 0
        )
        phase = .playing(options)

        if !isRemote {
            connectivity.sendSessionStart(SessionStartMessage(sessionId: sessionId, options: options))
        }
    }

    func finishMatch(didWin: Bool, completedSets: [(my: Int, your: Int)]) {
        guard let session = _currentSession else { return }
        session.endedAt = Date()
        session.result = didWin ? .win : .loss
        let setScores = completedSets.map { SetScore(my: $0.my, your: $0.your) }
        session.completedSets = setScores
        session.mySetScore = setScores.filter { $0.my > $0.your }.count
        session.yourSetScore = setScores.filter { $0.your > $0.my }.count
        session.kcalAtEnd = metrics.calories
        completedMatchCount += 1
        phase = .finished(session)
        saveCurrentMatch()
    }

    func saveCurrentMatch() {
        guard let session = _currentSession else { return }
        let match = buildMatchFromSession(session)
        try? MatchPersistenceService.shared.save(match)
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options)
    }

    func startNewMatch() {
        _currentSession = nil
        phase = .modeSelection
    }

    func endSession() {
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
        metrics = .init()
        _currentSession = nil
        phase = .modeSelection
    }

    // MARK: - Private

    private func saveFromWatch(_ msg: MatchEndMessage) {
        let match = buildMatchFromMessage(msg)
        try? MatchPersistenceService.shared.save(match)
    }

    private func buildMatchFromMessage(_ msg: MatchEndMessage) -> Match {
        let match = Match()
        match.workoutSessionId = msg.sessionId
        match.startedAt = msg.startedAt
        match.endedAt = msg.endedAt
        match.durationSeconds = Int(msg.endedAt.timeIntervalSince(msg.startedAt))
        match.caloriesBurned = msg.calories
        match.averageHeartRate = msg.averageHeartRate
        match.mode = msg.mode
        match.noAdRule = msg.noAdRule
        match.resultRaw = msg.result
        match.myTotalSets = msg.completedSets.filter { $0[0] > $0[1] }.count
        match.yourTotalSets = msg.completedSets.filter { $0[1] > $0[0] }.count
        match.sets = msg.completedSets.enumerated().map {
            SetRecord(myGames: $0.element[0], yourGames: $0.element[1], setNumber: $0.offset + 1)
        }
        return match
    }

    private func buildMatchFromSession(_ session: MatchSession) -> Match {
        let match = Match()
        match.workoutSessionId = session.workoutSessionId
        match.startedAt = session.startedAt
        match.endedAt = session.endedAt ?? Date()
        match.durationSeconds = Int((session.endedAt ?? Date()).timeIntervalSince(session.startedAt))
        match.caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
        match.mode = session.options.mode.rawValue
        match.noAdRule = session.options.noAdRule
        match.resultRaw = session.result?.rawValue ?? "win"
        match.myTotalSets = session.mySetScore
        match.yourTotalSets = session.yourSetScore
        match.sets = session.completedSets.enumerated().map {
            SetRecord(myGames: $0.element.my, yourGames: $0.element.your, setNumber: $0.offset + 1)
        }
        return match
    }

    private func buildSession(from msg: MatchEndMessage) -> MatchSession {
        let options = MatchOptions(
            mode: MatchFormat(rawValue: msg.mode) ?? .oneSet,
            noAdRule: msg.noAdRule,
            noTieRule: false
        )
        let session = MatchSession(
            workoutSessionId: msg.sessionId,
            options: options,
            startedAt: msg.startedAt,
            kcalAtStart: 0
        )
        session.endedAt = msg.endedAt
        session.result = msg.result == "win" ? .win : .loss
        session.completedSets = msg.completedSets.map { SetScore(my: $0[0], your: $0[1]) }
        session.mySetScore = msg.completedSets.filter { $0[0] > $0[1] }.count
        session.yourSetScore = msg.completedSets.filter { $0[1] > $0[0] }.count
        session.kcalAtEnd = msg.calories
        session.averageHeartRate = msg.averageHeartRate
        return session
    }

    private func startTimer() {
        timer?.invalidate()
        guard let startedAt else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPaused else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
                self.metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(self.elapsedSeconds),
                    calories: self.metrics.calories,
                    heartRate: self.metrics.heartRate,
                    steps: self.metrics.steps
                )
            }
        }
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
git commit -m "feat: iOS WorkoutSessionViewModel — SessionStart/MatchEnd 동기화, saveFromWatch"
```

---

## Task 9: iOS MainTabView 자동 진입

Watch가 경기를 시작하면 iPhone도 WorkoutSessionView로 자동 진입해야 한다.

**Files:**
- Modify: `iOSApp/iOSApp.swift`

- [ ] **Step 1: MainTabView에 자동 진입 로직 추가**

```swift
// iOSApp/iOSApp.swift
import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer
    private let watchConnectivity = WatchConnectivityService.shared
    @State private var isLaunching = true

    init() {
        do {
            let schema = Schema([Match.self, SetRecord.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)
            MatchPersistenceService.shared.configure(with: context)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if isLaunching {
                LaunchScreenView(onFinished: { isLaunching = false })
            } else {
                MainTabView()
            }
        }
        .modelContainer(container)
    }
}

struct MainTabView: View {
    @State private var isMatchActive = false
    @State private var selectedTab: Int = 0
    @State private var remoteSession: SessionStartMessage?
    private let connectivity = WatchConnectivityService.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                SummaryView()
                    .tabItem { Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill") }
                    .tag(0)

                HomeView(onMatchStart: { withAnimation { isMatchActive = true } })
                    .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                    .tag(1)

                HistoryView()
                    .tabItem { Label(String(localized: "tab_history"), systemImage: "clock.fill") }
                    .tag(2)
            }

            if isMatchActive {
                NavigationStack {
                    WorkoutSessionView(
                        remoteSession: remoteSession,
                        onExit: {
                            selectedTab = 1
                            remoteSession = nil
                            withAnimation { isMatchActive = false }
                        }
                    )
                }
                .transition(.opacity)
            }
        }
        .onReceive(connectivity.$receivedSessionStart.compactMap { $0 }) { msg in
            guard !isMatchActive else { return }
            remoteSession = msg
            withAnimation { isMatchActive = true }
        }
    }
}
```

- [ ] **Step 2: iOS WorkoutSessionView에 remoteSession 파라미터 추가**

```swift
// iOSApp/Features/WorkoutSession/WorkoutSessionView.swift
import SwiftUI

struct WorkoutSessionView: View {
    let onExit: () -> Void
    let remoteSession: SessionStartMessage?

    @StateObject private var viewModel = WorkoutSessionViewModel()
    @State private var selectedTab: Int = 1
    @State private var showEndMatchConfirm = false
    @State private var showEndWorkoutConfirm = false
    @State private var hasMatchProgress = false

    init(remoteSession: SessionStartMessage? = nil, onExit: @escaping () -> Void) {
        self.remoteSession = remoteSession
        self.onExit = onExit
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutTabView(
                metrics: viewModel.metrics,
                completedMatchCount: viewModel.completedMatchCount,
                isPaused: viewModel.isPaused,
                onPauseResume: { viewModel.isPaused ? viewModel.resumeSession() : viewModel.pauseSession() },
                onEnd: { showEndWorkoutConfirm = true }
            )
            .tabItem { Label(String(localized: "tab_workout"), systemImage: "figure.run") }
            .tag(0)

            scoreTabContent
                .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                switch viewModel.phase {
                case .modeSelection:
                    BackButton { selectedTab = 0 }
                case .playing:
                    BackButton {
                        if hasMatchProgress { showEndMatchConfirm = true }
                        else { viewModel.startNewMatch() }
                    }
                case .finished:
                    BackButton { viewModel.startNewMatch() }
                }
            }
            ToolbarItem(placement: .principal) {
                if case .modeSelection = viewModel.phase {
                    Text(String(localized: "new_match"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .alert(String(localized: "early_end_confirm_title"), isPresented: $showEndMatchConfirm) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                hasMatchProgress = false
                viewModel.startNewMatch()
            }
            Button(String(localized: "btn_cancel"), role: .cancel) {}
        } message: { Text(String(localized: "early_end_confirm_message")) }
        .alert(String(localized: "end_workout_confirm_title"), isPresented: $showEndWorkoutConfirm) {
            Button(String(localized: "workout_end"), role: .destructive) {
                viewModel.endSession()
                onExit()
            }
            Button(String(localized: "btn_cancel"), role: .cancel) {}
        } message: {
            if case .playing = viewModel.phase {
                Text(String(localized: "end_workout_with_match_message"))
            } else {
                Text(String(localized: "end_workout_confirm_message"))
            }
        }
        .onAppear {
            viewModel.startSession()
            if let remote = remoteSession {
                viewModel.startMatch(options: remote.options, isRemote: true)
            }
        }
    }

    @ViewBuilder
    private var scoreTabContent: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView(viewModel: viewModel)
        case .playing(let options):
            ScoreView(
                options: options,
                onMatchFinished: { didWin, sets in viewModel.finishMatch(didWin: didWin, completedSets: sets) },
                onProgressChanged: { hasMatchProgress = $0 }
            )
        case .finished(let session):
            MatchResultView(session: session, viewModel: viewModel)
        }
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/iOSApp.swift iOSApp/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "feat: iOS MainTabView — Watch 시작 시 자동 진입"
```

---

## Task 10: iOS Live Activity — ActivityAttributes + Service

**사전 작업 (Xcode 수동):**
1. Xcode → File → New → Target → Widget Extension 선택
2. Product Name: `TennisLiveActivity`
3. "Include Live Activity" 체크, "Include Configuration App Intent" 해제
4. Finish → 생성된 기본 파일은 모두 삭제하고 아래 파일만 유지

**Files:**
- Create: `iOSApp/LiveActivity/TennisActivityAttributes.swift`
- Create: `iOSApp/LiveActivity/LiveActivityService.swift`

- [ ] **Step 1: TennisActivityAttributes.swift 생성**

이 파일은 **iOS 앱 타겟과 TennisLiveActivity 타겟 양쪽에 추가**해야 한다.
Xcode에서 파일 선택 → File Inspector → Target Membership에서 두 타겟 모두 체크.

```swift
// iOSApp/LiveActivity/TennisActivityAttributes.swift
import ActivityKit
import Foundation

struct TennisActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var myPoint: String      // "0", "15", "30", "40", "AD"
        var yourPoint: String
        var myGame: Int
        var yourGame: Int
        var mySet: Int
        var yourSet: Int
        var isTieBreak: Bool

        static let empty = ContentState(
            myPoint: "0", yourPoint: "0",
            myGame: 0, yourGame: 0,
            mySet: 0, yourSet: 0,
            isTieBreak: false
        )
    }

    let matchMode: String
}
```

- [ ] **Step 2: LiveActivityService.swift 생성 (iOS 앱 타겟 전용)**

```swift
// iOSApp/LiveActivity/LiveActivityService.swift
import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var activity: Activity<TennisActivityAttributes>?

    private init() {}

    func start(mode: MatchFormat) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TennisActivityAttributes(matchMode: mode.rawValue)
        activity = try? Activity.request(
            attributes: attributes,
            contentState: .empty,
            pushType: nil
        )
    }

    func update(from state: ScoreState, score: Score) {
        let contentState = TennisActivityAttributes.ContentState(
            myPoint: state.isTieBreak ? "\(state.myScore)" : score.myDisplayScore,
            yourPoint: state.isTieBreak ? "\(state.yourScore)" : score.yourDisplayScore,
            myGame: state.myGameScore,
            yourGame: state.yourGameScore,
            mySet: state.mySetScore,
            yourSet: state.yourSetScore,
            isTieBreak: state.isTieBreak
        )
        Task { await activity?.update(using: contentState) }
    }

    func end() {
        Task { await activity?.end(dismissalPolicy: .immediate) }
        activity = nil
    }
}
```

- [ ] **Step 3: iOS 앱 Info.plist에 키 추가**

Xcode → TennisCounter 타겟 → Info 탭에서 다음 키 추가:
- Key: `NSSupportsLiveActivities`, Type: Boolean, Value: YES
- Key: `NSSupportsLiveActivitiesFrequentUpdates`, Type: Boolean, Value: YES

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/LiveActivity/TennisActivityAttributes.swift iOSApp/LiveActivity/LiveActivityService.swift
git commit -m "feat: TennisActivityAttributes + LiveActivityService 추가"
```

---

## Task 11: Live Activity Widget Extension 뷰

**Files:**
- Create: `TennisLiveActivity/TennisLiveActivityBundle.swift`
- Create: `TennisLiveActivity/TennisLiveActivityView.swift`

- [ ] **Step 1: TennisLiveActivityBundle.swift 생성 (Widget Extension 타겟)**

```swift
// TennisLiveActivity/TennisLiveActivityBundle.swift
import SwiftUI
import WidgetKit

@main
struct TennisLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TennisLiveActivityWidget()
    }
}
```

- [ ] **Step 2: TennisLiveActivityView.swift 생성 (Widget Extension 타겟)**

```swift
// TennisLiveActivity/TennisLiveActivityView.swift
import ActivityKit
import SwiftUI
import WidgetKit

struct TennisLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TennisActivityAttributes.self) { context in
            // 잠금화면 배너
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 확장 뷰 (길게 누를 때)
                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(state: context.state)
                }
            } compactLeading: {
                Text(context.state.myPoint)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
            } compactTrailing: {
                Text(context.state.yourPoint)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
            } minimal: {
                Text(context.state.myPoint)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - 잠금화면 배너

private struct LockScreenView: View {
    let state: TennisActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("ME")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(state.myPoint)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
            }
            VStack(spacing: 4) {
                Text("\(state.myGame) - \(state.yourGame)")
                    .font(.system(size: 18, weight: .semibold))
                Text("\(state.mySet) - \(state.yourSet)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if state.isTieBreak {
                    Text("TIEBREAK")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            VStack(spacing: 2) {
                Text("OPP")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(state.yourPoint)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Dynamic Island 확장 뷰

private struct ExpandedView: View {
    let state: TennisActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 20) {
            Text(state.myPoint)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.green)
            VStack(spacing: 2) {
                Text("\(state.myGame) : \(state.yourGame)")
                    .font(.system(size: 16, weight: .semibold))
                Text("Set \(state.mySet) - \(state.yourSet)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(state.yourPoint)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.orange)
        }
    }
}
```

- [ ] **Step 3: 빌드 확인 (Widget Extension 포함)**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisLiveActivity" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: 커밋**

```bash
git add TennisLiveActivity/
git commit -m "feat: Live Activity Widget Extension — 잠금화면 + Dynamic Island 뷰"
```

---

## Task 12: Live Activity 연결 (ScoreViewModel + WorkoutSessionViewModel)

**Files:**
- Modify: `iOSApp/Features/Match/Score/ScoreViewModel.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`

- [ ] **Step 1: iOS ScoreViewModel에 Live Activity 업데이트 추가**

`applyRemoteState` 메서드 끝에 추가:

```swift
// iOSApp/Features/Match/Score/ScoreViewModel.swift
// applyRemoteState 내부 isApplyingRemote = false 바로 위에 추가
LiveActivityService.shared.update(from: state, score: score)
```

`addPoint` 메서드에서 `sendScoreState()` 호출 이후에 추가:

```swift
// addPoint 내부 sendScoreState() 호출 다음 줄에 추가
let myScore = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
let yourScore = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
LiveActivityService.shared.update(from: ScoreState(
    myScore: myScore, yourScore: yourScore,
    myGameScore: myGameScore, yourGameScore: yourGameScore,
    mySetScore: mySetScore, yourSetScore: yourSetScore,
    completedSets: completedSets.map { [$0.my, $0.your] },
    isTieBreak: score.gameMode == .tieBreak
), score: score)
```

- [ ] **Step 2: iOS WorkoutSessionViewModel에 Live Activity 시작/종료 추가**

`startMatch` 메서드에 Live Activity 시작 추가:

```swift
// startMatch 내부, phase = .playing(options) 다음 줄에 추가
LiveActivityService.shared.start(mode: options.mode)
```

`finishMatch` 메서드에 Live Activity 종료 추가:

```swift
// finishMatch 내부, phase = .finished(session) 다음 줄에 추가
LiveActivityService.shared.end()
```

`endSession` 메서드에 추가:

```swift
// endSession 내부 마지막 줄에 추가
LiveActivityService.shared.end()
```

`receivedSessionStart` 구독 핸들러에 추가:

```swift
// receivedSessionStart 구독 내부 startMatch 호출 다음 줄에 추가
LiveActivityService.shared.start(mode: msg.options.mode)
```

`saveFromWatch` 호출 다음 줄에 추가:

```swift
// receivedMatchEnd 구독 내부 saveFromWatch 다음 줄에 추가
LiveActivityService.shared.end()
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Score/ScoreViewModel.swift iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
git commit -m "feat: Live Activity 연결 — 경기 시작/점수 입력/종료 시 업데이트"
```

---

## Task 13: MatchDetailSheet 칼로리 + 평균 심박수

**Files:**
- Modify: `iOSApp/Components/MatchDetailSheet.swift`

- [ ] **Step 1: MatchDetailSheet Info 섹션에 칼로리/심박수 추가**

```swift
// iOSApp/Components/MatchDetailSheet.swift
import SwiftUI

struct MatchDetailSheet: View {
    let match: Match

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text(match.myTotalSets > match.yourTotalSets
                                ? String(localized: "match_over_win")
                                : String(localized: "match_over_lose"))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(match.myTotalSets > match.yourTotalSets ? .green : .orange)
                            Text("\(match.myTotalSets) – \(match.yourTotalSets)")
                                .font(.system(size: 22, weight: .semibold))
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("Sets")) {
                    let sets = (match.sets ?? []).sorted { $0.setNumber < $1.setNumber }
                    if sets.isEmpty {
                        Text("No set data").foregroundColor(.secondary)
                    } else {
                        ForEach(sets, id: \.setNumber) { set in
                            HStack {
                                Text("Set \(set.setNumber)").foregroundColor(.secondary)
                                Spacer()
                                Text("\(set.myGames)")
                                    .font(.system(size: 18, weight: .bold)).foregroundColor(.green)
                                Text(" – ").foregroundColor(.secondary)
                                Text("\(set.yourGames)")
                                    .font(.system(size: 18, weight: .bold)).foregroundColor(.orange)
                            }
                        }
                    }
                }

                Section(header: Text("Info")) {
                    LabeledContent("Format") {
                        Text(match.matchFormat == .oneSet
                            ? String(localized: "match_format_one_set")
                            : String(localized: "match_format_best_of_3"))
                    }
                    if let endedAt = match.endedAt {
                        LabeledContent("Duration") {
                            let minutes = Int(endedAt.timeIntervalSince(match.startedAt) / 60)
                            Text("\(minutes) min")
                        }
                    }
                    LabeledContent("Date") {
                        Text(match.startedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let calories = match.caloriesBurned, calories > 0 {
                        LabeledContent("Calories") {
                            Text(String(format: "%.0f kcal", calories))
                        }
                    }
                    if let hr = match.averageHeartRate {
                        LabeledContent("Avg. Heart Rate") {
                            Text(String(format: "%.0f BPM", hr))
                        }
                    }
                }
            }
            .navigationTitle("Match Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "btn_cancel")) { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Components/MatchDetailSheet.swift
git commit -m "feat: MatchDetailSheet에 칼로리/평균 심박수 표시"
```

---

## Task 14: Summary StatCard 아이콘 제거

**Files:**
- Modify: `iOSApp/Features/Summary/Components/StatCard.swift`
- Modify: `iOSApp/Features/Summary/SummaryView.swift`

- [ ] **Step 1: StatCard에서 아이콘 제거**

```swift
// iOSApp/Features/Summary/Components/StatCard.swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: SummaryView에서 systemImage 파라미터 제거**

```swift
// iOSApp/Features/Summary/SummaryView.swift — statsGrid 부분만 교체
private var statsGrid: some View {
    let stats = viewModel.stats(from: matches)
    return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StatCard(title: String(localized: "summary_total_matches"), value: "\(stats.totalMatches)", color: .blue)
        StatCard(title: String(localized: "summary_win_rate"), value: String(format: "%.0f%%", stats.winRate * 100), color: stats.winRate >= 0.5 ? .green : .orange)
        StatCard(title: String(localized: "summary_streak"), value: "\(stats.streak)", color: .red)
        StatCard(title: "Wins", value: "\(stats.wins)", color: .green)
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Summary/Components/StatCard.swift iOSApp/Features/Summary/SummaryView.swift
git commit -m "design: Summary StatCard 아이콘 제거"
```

---

## 최종 빌드 검증

- [ ] iOS + Watch 동시 빌드

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|warning:|BUILD"

xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|warning:|BUILD"
```

- [ ] Complication Extension 빌드

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "ComplicationAppExtension" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```
