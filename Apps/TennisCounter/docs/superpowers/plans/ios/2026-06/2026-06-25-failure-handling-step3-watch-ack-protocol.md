# 저장 실패 처리 3단계: Watch ack 프로토콜 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **선행 조건:** 1단계(컨텍스트 rollback)와 2단계(iOS 로컬 저장 UI)가 머지된 상태여야 한다.
> 이 단계는 1단계의 `upsert`가 `throw`하는 것에 의존한다.

**Goal:** Watch가 저장 요청을 보내면(`sendMatchSave`) iOS가 실제 persist 성공/실패를 ack
메시지로 Watch에 회신한다. 지금은 Watch가 메시지를 "보냈다"는 사실만으로 저장됐다고 가정하고,
iOS가 실제로 저장에 성공했는지는 전혀 알려주지 않는다.

**Architecture:** `Shared/Services/WatchConnectivityService.swift`에 `matchSaveResult` 메시지
타입과 `MatchSaveResultMessage` 모델을 추가하고, 기존 `sendReliably` 패턴(reachable이면 즉시,
아니면 `transferUserInfo`로 큐잉)으로 회신을 보낸다. iOS의 `saveFromWatch`가 `upsert` 결과를
이 메시지로 Watch에 보낸다. (Watch가 ack를 수신해 UI에 반영하는 것은 4단계.)

**Tech Stack:** Swift, WatchConnectivity, Swift Testing.

**작업 브랜치:** `git switch -c failure-handling-step3-watch-ack-protocol`

**빌드/테스트 명령:**
```bash
# iOS 빌드/테스트
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/MatchSaveResultMessageTests
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests

# Watch 빌드 (Shared 파일 변경이므로 컴파일 확인 필요. ack 수신/UI는 4단계)
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Lint/Format
make fix && make lint
```

---

## File Structure

| 파일 | 변경 |
|------|------|
| `Shared/Services/WatchConnectivityService.swift` | `matchSaveResult` 타입/모델/송신/수신 추가 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `saveFromWatch`가 ack 회신 |
| `iosTests/Shared/MatchSaveResultMessageTests.swift` (신규) | 직렬화 round-trip 테스트 |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | `saveFromWatch` persist 효과 테스트 |

---

### Task 0: 브랜치 생성
- [x] **Step 1:** `git switch -c failure-handling-step3-watch-ack-protocol`

---

### Task 1: `MatchSaveResultMessage` 모델 + WatchConnectivityService 송수신

**Files:**
- Modify: `Shared/Services/WatchConnectivityService.swift`
- Create: `iosTests/Shared/MatchSaveResultMessageTests.swift`

- [x] **Step 1: 실패 테스트 작성**

`iosTests/Shared/MatchSaveResultMessageTests.swift` 생성:
```swift
import Foundation
@testable import TennisCounter
import Testing

struct MatchSaveResultMessageTests {
    @Test func dictionaryUsesMatchSaveResultType() {
        let msg = MatchSaveResultMessage(sessionId: UUID(), success: true)
        #expect(msg.toDictionary()["type"] as? String == "matchSaveResult")
    }

    @Test func dictionaryRoundTripsOnSuccess() {
        let original = MatchSaveResultMessage(sessionId: UUID(), success: true)
        guard let decoded = MatchSaveResultMessage(from: original.toDictionary()) else {
            Issue.record("matchSaveResult 페이로드가 파싱되지 않음")
            return
        }
        #expect(decoded.sessionId == original.sessionId)
        #expect(decoded.success == true)
    }

    @Test func dictionaryRoundTripsOnFailure() {
        let original = MatchSaveResultMessage(sessionId: UUID(), success: false)
        let decoded = MatchSaveResultMessage(from: original.toDictionary())
        #expect(decoded?.success == false)
    }

    @Test func parsingFailsForWrongType() {
        #expect(MatchSaveResultMessage(from: ["type": "matchSave"]) == nil)
    }
}
```

- [x] **Step 2: 실패 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/MatchSaveResultMessageTests`
Expected: BUILD FAILED — `MatchSaveResultMessage` 타입이 없음

- [x] **Step 3: 구현**

`Shared/Services/WatchConnectivityService.swift`의 `WCMessageType` enum:
```swift
private enum WCMessageType: String {
    case sessionStart
    case scoreState
    case matchEnd
    case matchSave
    case metrics
    case workoutEnd
}
```
을 다음으로 교체 (`matchSaveResult` 케이스 추가):
```swift
private enum WCMessageType: String {
    case sessionStart
    case scoreState
    case matchEnd
    case matchSave
    case matchSaveResult
    case metrics
    case workoutEnd
}
```

`struct MatchEndMessage { ... }` 정의 바로 다음(line 186, `// MARK: - Service` 앞)에 새 구조체
추가:
```swift
struct MatchSaveResultMessage {
    let sessionId: UUID
    let success: Bool

    func toDictionary() -> [String: Any] {
        [
            "type": WCMessageType.matchSaveResult.rawValue,
            "sessionId": sessionId.uuidString,
            "success": success,
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.matchSaveResult.rawValue,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let success = dict["success"] as? Bool else { return nil }
        sessionId = id
        self.success = success
    }

    init(sessionId: UUID, success: Bool) {
        self.sessionId = sessionId
        self.success = success
    }
}
```

`final class WatchConnectivityService`의 `@Published` 선언 블록:
```swift
    @Published var isWatchReachable: Bool = false
    @Published var receivedSessionStart: SessionStartMessage?
    @Published var receivedScoreState: ScoreState?
    @Published var receivedMatchEnd: MatchEndMessage?
    @Published var receivedMatchSave: MatchEndMessage?
    @Published var receivedMetrics: WorkoutMetrics?
    @Published var receivedWorkoutEnd: UUID?
```
에 한 줄 추가:
```swift
    @Published var isWatchReachable: Bool = false
    @Published var receivedSessionStart: SessionStartMessage?
    @Published var receivedScoreState: ScoreState?
    @Published var receivedMatchEnd: MatchEndMessage?
    @Published var receivedMatchSave: MatchEndMessage?
    @Published var receivedMatchSaveResult: MatchSaveResultMessage?
    @Published var receivedMetrics: WorkoutMetrics?
    @Published var receivedWorkoutEnd: UUID?
```

`sendMatchSave(_:)` 바로 다음에 송신 메서드 추가:
```swift
    /// 저장 버튼 전용. iOS가 이 메시지를 받을 때만 히스토리에 persist 한다.
    func sendMatchSave(_ msg: MatchEndMessage) {
        sendReliably(msg.toSaveDictionary())
    }

    /// iOS가 저장 요청을 처리한 뒤 실제 persist 성공/실패를 Watch에 회신한다.
    func sendMatchSaveResult(_ msg: MatchSaveResultMessage) {
        sendReliably(msg.toDictionary())
    }
```

`handle(_:)`의 switch에 케이스 추가:
```swift
            case WCMessageType.matchSave.rawValue:
                self.receivedMatchSave = MatchEndMessage(from: message)
            case WCMessageType.matchSaveResult.rawValue:
                self.receivedMatchSaveResult = MatchSaveResultMessage(from: message)
            case WCMessageType.metrics.rawValue:
```

- [x] **Step 4: 통과 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/MatchSaveResultMessageTests`
Expected: PASS

- [x] **Step 5: Watch 빌드 확인**

Run: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`
Expected: BUILD SUCCEEDED

- [x] **Step 6: 커밋**

```bash
git add Shared/Services/WatchConnectivityService.swift iosTests/Shared/MatchSaveResultMessageTests.swift
git commit -m "✨ matchSaveResult 메시지 추가 (Watch ack 프로토콜)"
```

---

### Task 2: iOS `saveFromWatch`가 ack 회신

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

- [x] **Step 1: 실패 테스트 작성**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에서 `private func saveFromWatch`를
테스트에서 호출할 수 있도록, `WorkoutSessionViewModel.swift`의 `#if DEBUG` 블록
(`applyIncomingScoreStateForTest`/`applyIncomingSessionStartForTest`가 있는 곳)에 테스트 훅을
하나 추가해야 한다 — 이건 Step 3의 구현에서 함께 추가한다. 먼저 테스트만 작성:

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 새 테스트 추가:
```swift
    @Test @MainActor func saveFromWatchPersistsMatch() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        MatchPersistenceService.shared.configure(with: ModelContext(container))

        let sid = UUID()
        let msg = MatchEndMessage(
            sessionId: sid,
            result: "win",
            completedSets: [[6, 4]],
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            endedAt: Date(timeIntervalSince1970: 1_001_800),
            durationSeconds: 1800,
            calories: 200,
            averageHeartRate: 130,
            mode: "oneSet",
            noAdRule: true
        )

        let vm = WorkoutSessionViewModel()
        vm.saveFromWatchForTest(msg)

        let saved = try MatchPersistenceService.shared.fetchByWorkoutSession(sid)
        #expect(saved.count == 1)
    }
```

- [x] **Step 2: 실패 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests`
Expected: BUILD FAILED — `saveFromWatchForTest`가 없음

- [x] **Step 3: 구현**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 `#if DEBUG` 블록:
```swift
    #if DEBUG
        func applyIncomingScoreStateForTest(_ state: ScoreState) {
            handleIncomingScoreState(state)
        }

        func applyIncomingSessionStartForTest(_ msg: SessionStartMessage) {
            handleIncomingSessionStart(msg)
        }
    #endif
```
을 다음으로 교체 (테스트 훅 추가):
```swift
    #if DEBUG
        func applyIncomingScoreStateForTest(_ state: ScoreState) {
            handleIncomingScoreState(state)
        }

        func applyIncomingSessionStartForTest(_ msg: SessionStartMessage) {
            handleIncomingSessionStart(msg)
        }

        func saveFromWatchForTest(_ msg: MatchEndMessage) {
            saveFromWatch(msg)
        }
    #endif
```

`private func saveFromWatch(_ msg: MatchEndMessage)`:
```swift
    private func saveFromWatch(_ msg: MatchEndMessage) {
        let match = buildMatchFromMessage(msg)
        try? MatchPersistenceService.shared.upsert(match)
    }
```
를 다음으로 교체:
```swift
    private func saveFromWatch(_ msg: MatchEndMessage) {
        let match = buildMatchFromMessage(msg)
        let success: Bool
        do {
            try MatchPersistenceService.shared.upsert(match)
            success = true
        } catch {
            success = false
        }
        connectivity.sendMatchSaveResult(MatchSaveResultMessage(sessionId: msg.sessionId, success: success))
    }
```

- [x] **Step 4: 통과 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests`
Expected: PASS

> 이 테스트는 ack가 실제로 전송됐는지는 검증하지 않는다 — `sendMatchSaveResult`는 실제
> `WCSession`을 거치므로(테스트 환경에는 활성 세션이 없어 `sendReliably`가 조용히 no-op),
> CLAUDE.md Testing 컨벤션("외부 의존성은 테스트에서 직접 호출하지 않음 — ViewModel의 순수
> 상태 변화만 검증")대로 `upsert`의 부수효과(영속화 성공)만 검증한다. ack 전송 자체는 4단계의
> Watch 수신 테스트와 실기기 검증으로 보완한다.

- [x] **Step 5: 커밋**

```bash
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "✨ Watch 저장 요청 처리 후 결과를 ack로 회신"
```

---

### Task 3: 전체 검증 + code-review

- [x] **Step 1:** iOS 빌드/테스트 전체 GREEN

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

- [x] **Step 2:** Watch 빌드 GREEN (Shared 파일 변경 영향 확인)

Run: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`

- [x] **Step 3:** `make fix && make lint` — 모두 클린

- [ ] **Step 4:** `/code-review` 실행 → 지적 사항은 `superpowers:receiving-code-review`로 검증 후 반영

- [ ] **Step 5:** 위 검증·반영이 끝나면 `superpowers:finishing-a-development-branch`로 브랜치 정리

---

## 이 단계가 검증하는 것

- `MatchSaveResultMessage`가 직렬화/역직렬화를 정확히 round-trip한다.
- iOS가 Watch의 저장 요청을 처리한 뒤 실제 `upsert` 성공/실패에 따라 ack 메시지를 보낸다
  (전송 자체는 미검증 — 위 Step 4 주석 참조).

> Watch는 아직 이 ack를 수신하지 않는다(연결만 했고 구독은 안 함) — 4단계에서 Watch가
> `receivedMatchSaveResult`를 구독하고 UI에 반영한다.
