# Phase 1-A ⑤ WatchConnectivity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iPhone에서 점수가 변경될 때 Apple Watch로 실시간 전송. Watch에서도 점수 입력 시 iPhone으로 전송. 오프라인(Wi-Fi 없이 코트)에서도 동작.

**Architecture:** `WatchConnectivityService` 싱글턴이 `WCSession`을 관리. iOS MatchViewModel이 `score.objectWillChange`를 구독해 변경 시 sendMessage. Watch MatchViewModel이 동일한 방식으로 역방향 전송. Message payload: `{ "my": Int, "your": Int, "myGame": Int, "yourGame": Int }`.

**Tech Stack:** WatchConnectivity framework, Combine

**선행 조건:** `2026-04-29-phase1a-2-match-feature.md` 완료 (MatchViewModel 존재)

---

## File Structure

| 파일 | 액션 | 역할 |
|------|------|------|
| `Shared/Services/WatchConnectivityService.swift` | Create | WCSession 래퍼 |
| `iOSApp/Features/Match/Score/MatchViewModel.swift` | Modify | 점수 변경 시 Watch로 전송 |
| `WatchApp/Features/Match/MatchViewModel.swift` | Modify | 점수 변경 시 iPhone으로 전송 + 수신 반영 |
| `iOSApp/iOSApp.swift` | Modify | WatchConnectivityService 초기화 |
| `WatchApp/WatchApp.swift` | Modify | WatchConnectivityService 초기화 |

---

### Task 1: WatchConnectivityService 생성

**Files:**
- Create: `Shared/Services/WatchConnectivityService.swift`

> Services 디렉터리를 만든다. 이 파일은 iOS와 Watch 양쪽 타겟에 추가해야 한다.

- [ ] **Step 1: 디렉터리 생성**

```bash
mkdir -p Shared/Services
```

- [ ] **Step 2: WatchConnectivityService.swift 생성**

```swift
import Combine
import Foundation
import WatchConnectivity

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var receivedScoreUpdate: ScoreUpdate?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendScoreUpdate(_ update: ScoreUpdate) {
        guard WCSession.default.activationState == .activated else { return }
        #if os(iOS)
        guard WCSession.default.isWatchAppInstalled else { return }
        #endif

        let message = update.toDictionary()

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedScoreUpdate = ScoreUpdate(from: message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedScoreUpdate = ScoreUpdate(from: applicationContext)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}

struct ScoreUpdate {
    let myScore: Int
    let yourScore: Int
    let myGameScore: Int
    let yourGameScore: Int

    func toDictionary() -> [String: Any] {
        ["my": myScore, "your": yourScore, "myGame": myGameScore, "yourGame": yourGameScore]
    }

    init(myScore: Int, yourScore: Int, myGameScore: Int, yourGameScore: Int) {
        self.myScore = myScore
        self.yourScore = yourScore
        self.myGameScore = myGameScore
        self.yourGameScore = yourGameScore
    }

    init?(from dict: [String: Any]) {
        guard let my = dict["my"] as? Int,
              let your = dict["your"] as? Int,
              let myGame = dict["myGame"] as? Int,
              let yourGame = dict["yourGame"] as? Int else { return nil }
        myScore = my
        yourScore = your
        myGameScore = myGame
        yourGameScore = yourGame
    }
}
```

- [ ] **Step 3: Xcode에서 두 타겟에 파일 추가**

Xcode에서 수동으로:
1. `Shared/Services/WatchConnectivityService.swift` 선택
2. Target Membership: `TennisCounter` + `TennisCounter Watch App` 모두 체크

- [ ] **Step 4: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 커밋**

```bash
git add Shared/Services/WatchConnectivityService.swift
git commit -m "feat: add WatchConnectivityService for phone-watch sync"
```

---

### Task 2: iOSApp.swift에 WatchConnectivityService 초기화 추가

**Files:**
- Modify: `iOSApp/iOSApp.swift`

- [ ] **Step 1: iOSApp.swift 수정**

`TennisCounterApp` 구조체에 WatchConnectivityService 초기화 추가:

```swift
@main
struct TennisCounterApp: App {
    // WCSession은 앱 시작 시 한 번만 활성화되어야 한다
    private let watchConnectivity = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Match.self, SetRecord.self])
    }
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: WatchApp.swift에 WatchConnectivityService 초기화 추가

**Files:**
- Modify: `WatchApp/WatchApp.swift`

- [ ] **Step 1: WatchApp.swift 수정**

```swift
import SwiftUI

@main
struct TennisCounter_Watch_AppApp: App {
    private let watchConnectivity = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

- [ ] **Step 2: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/iOSApp.swift WatchApp/WatchApp.swift
git commit -m "feat: initialize WatchConnectivityService on app start"
```

---

### Task 4: iOS MatchViewModel에 점수 전송 추가

**Files:**
- Modify: `iOSApp/Features/Match/Score/MatchViewModel.swift`

- [ ] **Step 1: MatchViewModel.swift에 WatchConnectivity 전송 추가**

`MatchViewModel` 클래스에 다음을 추가:

```swift
// init 상단에 추가
private let connectivity = WatchConnectivityService.shared

// confirmScore() 내부에서 score.resetData() 직후 또는 게임 업데이트 후 호출
private func sendScoreUpdate() {
    let update = ScoreUpdate(
        myScore: score.myScore,
        yourScore: score.yourScore,
        myGameScore: myGameScore,
        yourGameScore: yourGameScore
    )
    connectivity.sendScoreUpdate(update)
}
```

`confirmScore()` 메서드에서 점수 변경 후 `sendScoreUpdate()` 호출:

```swift
func confirmScore() {
    guard score.myScore != score.yourScore else { return }

    if score.myScore == 50 {
        myGameScore += 1
        score.resetData()
        sendScoreUpdate()
        checkSetUpdate()
    } else if score.yourScore == 50 {
        yourGameScore += 1
        score.resetData()
        sendScoreUpdate()
        checkSetUpdate()
    }
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/Match/Score/MatchViewModel.swift
git commit -m "feat: iOS MatchViewModel sends score updates to Watch"
```

---

### Task 5: Watch MatchViewModel에 점수 전송 + 수신 추가

**Files:**
- Modify: `WatchApp/Features/Match/MatchViewModel.swift`

- [ ] **Step 1: MatchViewModel.swift 수정**

기존 Watch MatchViewModel에 WatchConnectivity 통합:

```swift
import Combine
import SwiftUI

class MatchViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init() {
        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreUpdate
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.applyScoreUpdate(update)
            }
            .store(in: &cancellables)
    }

    func addMyPoint() {
        score.addMyPoint()
        checkGameUpdate()
        sendScoreUpdate()
    }

    func addYourPoint() {
        score.addYourPoint()
        checkGameUpdate()
        sendScoreUpdate()
    }

    func undo() {
        score.undo()
        sendScoreUpdate()
    }

    func startNewMatch() {
        myGameScore = 0
        yourGameScore = 0
        score.resetData()
        isMatchOver = false
        didWin = false
    }

    private func sendScoreUpdate() {
        let update = ScoreUpdate(
            myScore: score.myScore,
            yourScore: score.yourScore,
            myGameScore: myGameScore,
            yourGameScore: yourGameScore
        )
        connectivity.sendScoreUpdate(update)
    }

    private func applyScoreUpdate(_ update: ScoreUpdate) {
        score.myScore = update.myScore
        score.yourScore = update.yourScore
        score.myIndex = score.scoreArr.firstIndex(of: update.myScore) ?? 0
        score.yourIndex = score.scoreArr.firstIndex(of: update.yourScore) ?? 0
        myGameScore = update.myGameScore
        yourGameScore = update.yourGameScore
    }

    private func checkGameUpdate() {
        if score.myScore == 50 {
            withAnimation(.bouncy) { myGameScore += 1 }
            score.resetData()
            if myGameScore >= 6 { didWin = true; isMatchOver = true }
        } else if score.yourScore == 50 {
            withAnimation(.bouncy) { yourGameScore += 1 }
            score.resetData()
            if yourGameScore >= 6 { didWin = false; isMatchOver = true }
        }
    }
}
```

> **주의**: `Score` 클래스의 `myScore`/`yourScore`가 `@Published var`이므로 직접 설정 가능. `myIndex`/`yourIndex`도 직접 설정해야 undo가 올바르게 동작한다.

- [ ] **Step 2: Watch 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add WatchApp/Features/Match/MatchViewModel.swift
git commit -m "feat: Watch MatchViewModel syncs score with iPhone via WatchConnectivity"
```

---

### Task 6: WatchConnectivity 기능 통합 검증

> 실제 기기 없이 시뮬레이터 쌍(iPhone + Watch)으로 테스트 가능.

- [ ] **Step 1: 시뮬레이터 쌍 구성**

Xcode > Window > Devices and Simulators에서 iPhone 17 Pro와 Apple Watch Series 11을 pair 상태로 확인.

- [ ] **Step 2: 양쪽 앱 동시 실행**

1. iPhone 시뮬레이터에서 TennisCounter 실행
2. Watch 시뮬레이터에서 TennisCounter Watch App 실행

- [ ] **Step 3: iPhone → Watch 동기화 확인**

1. iPhone에서 Match 탭 → One Set 선택
2. 점수 입력 후 Confirm
3. Watch 화면에서 점수가 업데이트되는지 확인

- [ ] **Step 4: Watch → iPhone 동기화 확인**

1. Watch에서 Quick Match 진입
2. ME 영역 탭으로 점수 입력
3. iPhone MatchView에서 점수가 반영되는지 확인

- [ ] **Step 5: 커밋**

```bash
git add .
git commit -m "feat: WatchConnectivity bidirectional score sync complete"
```

---

## 완료 기준

- [x] iPhone 점수 변경 시 Watch에 실시간 반영
- [x] Watch 점수 탭 시 iPhone에 실시간 반영
- [x] 기기 미연결 시(applicationContext 폴백) 다음 연결 시 최신 점수 수신
- [x] iOS/Watch 빌드 모두 성공
