# WatchConnectivity 양방향 동기화 + iOS Live Activity 설계

**날짜:** 2026-05-19
**범위:** WatchConnectivity 양방향 동기화, Match 모델 통일, iOS Live Activity

---

## 목표

- Watch ↔ iPhone 경기 세션 자동 동기화 (Fitness 앱 모티브)
- 어느 기기에서 시작해도 상대 기기 자동 진입, 양방향 점수 입력
- iOS 잠금화면 / Dynamic Island에 실시간 점수 표시 (Live Activity)
- `Match` / `MatchRecord` 모델 불일치 해소 → `Match` 단일 모델로 통일

---

## 전체 흐름

### Flow 1 — iOS에서 경기 시작

```
iPhone                              Watch
  │                                   │
  ├─ ModeView: 포맷 선택              │
  ├─ startMatch(options) ─────────────►│  ← SessionStartMessage
  │                                   ├─ startWorkout() (HK 세션)
  │                                   ├─ ScoreView 자동 진입
  │                                   │
  ├─ Live Activity 시작               │
  │                                   │
  ├─ 점수 탭 → ScoreState 전송 ───────►│
  │                                   ├─ applyRemoteState()
  │◄──────────── ScoreState ──────────┤  (Watch에서 탭 시)
  ├─ applyRemoteState()               │
  ├─ Live Activity 업데이트            │
  │                                   │
  │◄──── WorkoutMetrics (실시간) ──────┤  ← 칼로리/BPM
  │                                   │
  ├─ 경기 종료 → MatchEndMessage ──────►│
  ├─ Match SwiftData 저장             ├─ ResultView 자동 전환
  └─ Live Activity 종료               │
```

### Flow 2 — Watch에서 경기 시작

```
iPhone                              Watch
  │                                   │
  │                                   ├─ WorkoutSessionView 진입
  │                                   ├─ startWorkout() (HK 세션)
  │◄──────── SessionStartMessage ─────┤
  ├─ WorkoutSessionView 자동 진입      │
  ├─ Live Activity 시작               │
  │◄──── WorkoutMetrics (실시간) ──────┤
  │  (이후 양방향 점수 입력 동일)        │
  │                                   │
  │◄────── MatchEndMessage ───────────┤  (Watch가 종료 시)
  ├─ Match SwiftData 저장             │
  └─ Live Activity 종료               │
```

### Flow 3 — Watch 미착용 (iOS 단독)

```
iPhone                              Watch
  │                                   │  (연결 없음)
  ├─ 단독 경기 진행                    │
  ├─ SessionStartMessage → 큐잉       │  (연결 시 전달)
  ├─ Live Activity 시작               │
  ├─ HealthKit 메트릭 없음 (타이머만)  │
  └─ Match 직접 저장                  │
```

### Flow 4 — 경기 중 Watch 재연결

```
iPhone (경기 진행 중)                Watch (새로 착용)
  │                                   │
  │  sessionReachabilityDidChange     │
  ├─ 현재 ScoreState 즉시 전송 ───────►│
  │                                   ├─ applyRemoteState()
  │                                   └─ ScoreView 합류
```

---

## 데이터 구조

### 메시지 타입 식별자

```swift
enum WCMessageType: String {
    case sessionStart  // 워크아웃 + 경기 시작
    case scoreState    // 전체 점수 상태 (기존 ScoreUpdate 대체)
    case matchEnd      // 경기 종료 + 저장용 세션 데이터
    case metrics       // 워크아웃 메트릭 (기존 유지)
}
```

### SessionStartMessage

```swift
struct SessionStartMessage {
    let sessionId: UUID
    let options: MatchOptions  // mode, noAdRule, noTieRule

    func toDictionary() -> [String: Any] {
        [
            "type": WCMessageType.sessionStart.rawValue,
            "sessionId": sessionId.uuidString,
            "mode": options.mode.rawValue,
            "noAdRule": options.noAdRule,
            "noTieRule": options.noTieRule
        ]
    }
}
```

### ScoreState (기존 ScoreUpdate 대체)

```swift
struct ScoreState {
    let myScore: Int            // 현재 포인트 인덱스
    let yourScore: Int
    let myGameScore: Int
    let yourGameScore: Int
    let mySetScore: Int         // 신규
    let yourSetScore: Int       // 신규
    let completedSets: [[Int]]  // 신규 [[my, your], ...]
    let isTieBreak: Bool        // 신규

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
}
```

### MatchEndMessage

```swift
struct MatchEndMessage {
    let sessionId: UUID
    let result: MatchResult
    let completedSets: [[Int]]  // [[my, your], ...]
    let startedAt: Date
    let endedAt: Date
    let calories: Double
    let averageHeartRate: Double?
    let mode: String
    let noAdRule: Bool
}
```

### WatchConnectivityService 변경

```swift
// 제거
@Published var receivedScoreUpdate: ScoreUpdate?  // ← 삭제

// 추가
@Published var receivedSessionStart: SessionStartMessage?
@Published var receivedScoreState: ScoreState?
@Published var receivedMatchEnd: MatchEndMessage?
// @Published var receivedMetrics: WorkoutMetrics? ← 기존 유지

// 메시지 수신 분기
func session(_: WCSession, didReceiveMessage message: [String: Any]) {
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
        default: break
        }
    }
}

// MatchEndMessage 보장 전달 (Watch → iOS)
func sendMatchEnd(_ msg: MatchEndMessage) {
    let dict = msg.toDictionary()
    if WCSession.default.isReachable {
        WCSession.default.sendMessage(dict, replyHandler: nil)
    } else {
        WCSession.default.transferUserInfo(dict)  // 큐잉, 연결 시 자동 전달
    }
}

// iOS에서 transferUserInfo 수신 처리 추가
func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    DispatchQueue.main.async {
        if let msg = MatchEndMessage(from: userInfo) {
            self.receivedMatchEnd = msg
        }
    }
}
```

---

## 컴포넌트 변경사항

### Match 모델 통일 (`MatchRecord` 제거)

```swift
// Shared/Persistence/Match.swift
@Model
class Match {
    // 기존 유지
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var caloriesBurned: Double?
    var durationSeconds: Int?
    var opponentName: String?
    var myTotalSets: Int = 0
    var yourTotalSets: Int = 0
    @Relationship(deleteRule: .cascade) var sets: [SetRecord] = []

    // MatchRecord에서 이전 (신규)
    var workoutSessionId: UUID?
    var mode: String = MatchMode.oneSet.rawValue
    var noAdRule: Bool = true
    var resultRaw: String = MatchResult.win.rawValue
    var averageHeartRate: Double?
}
```

- `MatchRecord.swift` 삭제
- `MatchPersistenceService` 저장 타입을 `Match`로 변경
- `iOSApp.swift` 스키마: `Schema([Match.self, SetRecord.self])` 그대로 유지

### ScoreViewModel (iOS + Watch 공통)

```swift
private var isApplyingRemote = false

// init()에 구독 추가
connectivity.$receivedScoreState
    .compactMap(\.self)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state in self?.applyRemoteState(state) }
    .store(in: &cancellables)

// addPoint() 이후 전송 (기존 sendScoreUpdate 대체)
private func sendScoreState() {
    guard !isApplyingRemote else { return }  // 에코 방지
    connectivity.sendScoreState(ScoreState(
        myScore: score.myScore,
        yourScore: score.yourScore,
        myGameScore: myGameScore,
        yourGameScore: yourGameScore,
        mySetScore: mySetScore,
        yourSetScore: yourSetScore,
        completedSets: completedSets.map { [$0.my, $0.your] },
        isTieBreak: isTieBreak
    ))
}

// 상대 기기 상태 수신 → 로컬에 덮어씀
func applyRemoteState(_ state: ScoreState) {
    isApplyingRemote = true
    myGameScore = state.myGameScore
    yourGameScore = state.yourGameScore
    mySetScore = state.mySetScore
    yourSetScore = state.yourSetScore
    completedSets = state.completedSets.map { SetScore(my: $0[0], your: $0[1]) }
    score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
    isApplyingRemote = false

    #if os(iOS)
    // ScoreState → TennisActivityAttributes.ContentState 변환 (score.displayString 활용)
    LiveActivityService.shared.update(TennisActivityAttributes.ContentState(
        myPoint: state.myPointDisplay,   // Score.scoreArr 기반 표시 문자열
        yourPoint: state.yourPointDisplay,
        myGame: state.myGameScore,
        yourGame: state.yourGameScore,
        mySet: state.mySetScore,
        yourSet: state.yourSetScore,
        isTieBreak: state.isTieBreak
    ))
    #endif
}
```

`Score` 모델에 `applyRemote(myScore:yourScore:isTieBreak:)` 메서드 추가 필요.

### WorkoutSessionViewModel — Watch

```swift
// init()에 추가
connectivity.$receivedSessionStart
    .compactMap(\.self)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] msg in
        guard let self else { return }
        if !healthKit.isWorkoutActive { startWorkout() }
        startMatch(options: msg.options, sessionId: msg.sessionId, isRemote: true)
    }
    .store(in: &cancellables)

// isRemote 파라미터 추가
func startMatch(options: MatchOptions, sessionId: UUID = UUID(), isRemote: Bool = false) {
    // 기존 로직
    if !isRemote {
        connectivity.sendSessionStart(SessionStartMessage(sessionId: sessionId, options: options))
    }
}

// 경기 종료 시 iOS로 세션 전달
func finishMatch(result: MatchResult, completedSets: [SetScore]) {
    guard let session = _currentSession else { return }
    // 기존 로직
    connectivity.sendMatchEnd(MatchEndMessage(
        sessionId: session.id,
        result: result,
        completedSets: completedSets.map { [$0.my, $0.your] },
        startedAt: session.startedAt,
        endedAt: session.endedAt ?? Date(),
        calories: healthKit.currentCalories - session.kcalAtStart,
        averageHeartRate: nil,  // stopWorkout() 후 비동기 수집
        mode: session.options.mode.rawValue,
        noAdRule: session.options.noAdRule
    ))
}
```

### WorkoutSessionViewModel — iOS

```swift
// init()에 추가
connectivity.$receivedSessionStart
    .compactMap(\.self)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] msg in
        guard let self else { return }
        startSession()
        startMatch(options: msg.options, sessionId: msg.sessionId, isRemote: true)
        LiveActivityService.shared.start(options: msg.options)
    }
    .store(in: &cancellables)

connectivity.$receivedMatchEnd
    .compactMap(\.self)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] msg in
        self?.saveFromWatch(msg)
        self?.phase = .finished(...)
        LiveActivityService.shared.end()
    }
    .store(in: &cancellables)

// Watch에서 받은 세션 → Match 저장
private func saveFromWatch(_ msg: MatchEndMessage) {
    let match = Match()
    match.workoutSessionId = msg.sessionId
    match.startedAt = msg.startedAt
    match.endedAt = msg.endedAt
    match.durationSeconds = Int(msg.endedAt.timeIntervalSince(msg.startedAt))
    match.caloriesBurned = msg.calories
    match.averageHeartRate = msg.averageHeartRate
    match.mode = msg.mode
    match.noAdRule = msg.noAdRule
    match.myTotalSets = msg.completedSets.filter { $0[0] > $0[1] }.count
    match.yourTotalSets = msg.completedSets.filter { $0[1] > $0[0] }.count
    match.resultRaw = msg.result.rawValue
    match.sets = msg.completedSets.enumerated().map { SetRecord(my: $0.element[0], your: $0.element[1]) }
    try? MatchPersistenceService.shared.save(match)
}

// iOS primary 종료 시
func finishMatch(didWin: Bool, completedSets: [(my: Int, your: Int)]) {
    // 기존 로직
    saveCurrentMatch()
    LiveActivityService.shared.end()
}
```

### iOS Live Activity (신규)

**파일 구조:**
```
iOSApp/
└── LiveActivity/
    ├── TennisActivityAttributes.swift   # ActivityAttributes 정의
    ├── LiveActivityService.swift        # 시작/업데이트/종료 서비스
    └── TennisLiveActivityView.swift     # 잠금화면 + Dynamic Island View
```

**TennisActivityAttributes:**
```swift
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

**LiveActivityService:**
```swift
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var activity: Activity<TennisActivityAttributes>?

    func start(options: MatchOptions) {
        let attributes = TennisActivityAttributes(matchMode: options.mode.rawValue)
        activity = try? Activity.request(
            attributes: attributes,
            contentState: .empty
        )
    }

    func update(_ state: TennisActivityAttributes.ContentState) {
        Task { await activity?.update(using: state) }
    }

    func end() {
        Task { await activity?.end(dismissalPolicy: .immediate) }
        activity = nil
    }
}
```

**Dynamic Island / 잠금화면 레이아웃:**

```
Dynamic Island 컴팩트 (leading / trailing)
┌─────────[●]─────────┐
│  40          30      │   ← myPoint / yourPoint
└─────────────────────┘

잠금화면 배너
┌──────────────────────────────┐
│  🎾  Best of 3               │
│   ME  40 : 30  OPP           │   ← 포인트
│    3   -   2   (게임)         │   ← 게임 스코어
│    1   -   0   (세트)         │   ← 세트 스코어
└──────────────────────────────┘
```

---

## 엣지 케이스

| 케이스 | 처리 방식 |
|--------|-----------|
| 동시 점수 입력 | last-write-wins. 다음 입력에서 재동기화. |
| 경기 중 Watch 착용 | `sessionReachabilityDidChange` → 현재 ScoreState 즉시 전송 |
| 경기 중 연결 끊김 | 각 기기 독립 동작 → 재연결 시 동기화 |
| Watch-primary, iOS 없이 종료 | `transferUserInfo` 큐잉 → iOS 연결 시 자동 저장 |
| Live Activity 권한 없음 | `try?` 처리, 점수 추적 기능 영향 없음 |

---

## 구현 시 주의사항

- `Score.applyRemote()` 메서드 추가 필요 — 내부 점수 상태를 외부에서 주입 가능하게
- `MatchRecord` 제거 시 SwiftData 마이그레이션 필요 — `Match`에 추가되는 필드는 optional/default이므로 자동 마이그레이션 가능
- Live Activity는 `NSSupportsLiveActivities` Info.plist 키 추가 필요
- Watch `WorkoutSessionViewModel.finishMatch` 에서 `averageHeartRate`는 `stopWorkout()` 완료 후 비동기로 수집 — 별도 `transferUserInfo`로 후속 전송하거나 생략 가능
