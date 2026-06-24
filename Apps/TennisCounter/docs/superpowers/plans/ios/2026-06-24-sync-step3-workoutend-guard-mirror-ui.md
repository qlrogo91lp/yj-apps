# 동기화 재설계 3단계: workoutEnd 가드 + 미러 UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **선행 조건:** 1·2단계 머지 완료. `WorkoutSessionViewModel.isDriver`가 존재한다고 가정한다.

**Goal:** `workoutEnd` 메시지에 `sessionId`를 실어, 수신 측이 자기 현재 세션과 일치할 때만 종료/dismiss하게 한다(증상 2). 그리고 미러 기기의 점수 입력을 비활성화하고 "보기 전용" 배지를 표시한다.

**Architecture:** `WatchConnectivityService`의 `receivedWorkoutEnd`를 `Date?`에서 종료된 세션의 `UUID?`로 바꾼다. 수신 구독은 내 sessionId와 일치할 때만 처리하고 소비 즉시 nil로 비운다. `ScoreView`는 `isDriver`에 따라 입력을 막고 배지를 띄운다.

**Tech Stack:** Swift, SwiftUI, WatchConnectivity, Swift Testing.

**작업 브랜치:** `git switch -c sync-step3-workoutend-guard-mirror-ui`

**빌드/테스트 명령:** 1단계 plan 헤더 참조.

---

## File Structure

| 파일 | 변경 |
|------|------|
| `Shared/Services/WatchConnectivityService.swift` | `sendWorkoutEnd(sessionId:)`, `receivedWorkoutEnd: UUID?`, handle에서 sessionId 파싱 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | endSession이 sessionId 전송, 수신 가드 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 동일 |
| `iOSApp/Features/Match/Score/ScoreView.swift` | 미러 입력 비활성 + 배지 |
| `WatchApp/Features/Match/Score/ScoreView.swift` | 동일 |
| `iOSApp/Features/Match/Score/Components/MirrorBadge.swift` (신규) | "보기 전용" 배지 |
| `WatchApp/Features/Match/Score/Components/MirrorBadge.swift` (신규) | 동일 |

---

### Task 0: 브랜치 생성
- [ ] **Step 1:** `git switch -c sync-step3-workoutend-guard-mirror-ui`

---

### Task 1: WatchConnectivityService — workoutEnd에 sessionId

**Files:** Modify `Shared/Services/WatchConnectivityService.swift`

- [ ] **Step 1: 구현 (전송)**

`sendWorkoutEnd()`를 sessionId를 받도록 변경:
```swift
    func sendWorkoutEnd(sessionId: UUID) {
        sendRealtimeOnly([
            "type": WCMessageType.workoutEnd.rawValue,
            "sessionId": sessionId.uuidString
        ])
    }
```

- [ ] **Step 2: 구현 (수신 상태 타입)**

`@Published var receivedWorkoutEnd: Date?` → `@Published var receivedWorkoutEnd: UUID?`

`handle(_:)`의 workoutEnd 케이스 변경 (sessionId 없으면 무시 — 구버전 호환 안전 기본값):
```swift
            case WCMessageType.workoutEnd.rawValue:
                if let idStr = message["sessionId"] as? String, let id = UUID(uuidString: idStr) {
                    self.receivedWorkoutEnd = id
                }
```

- [ ] **Step 3: 빌드 — 호출부 컴파일 에러 확인**

Run: iOS 빌드. Expected: `sendWorkoutEnd()` 호출부와 `receivedWorkoutEnd` 비교부에서 에러 (Task 2·3에서 수정). 이 단계는 의도된 RED.

---

### Task 2: iOS endSession/수신 가드

**Files:** Modify `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`, Test `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

- [ ] **Step 1: 실패 테스트 — sessionId 불일치 시 종료 안 함**
```swift
@Test @MainActor func workoutEndIgnoredWhenSessionIdMismatch() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.handleIncomingWorkoutEndForTest(UUID()) // 다른 세션
    #expect(vm.remoteWorkoutEnded == false)
    if case .playing = vm.phase {} else { Issue.record("playing 유지 기대") }
}

@Test @MainActor func workoutEndAppliedWhenSessionIdMatches() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.handleIncomingWorkoutEndForTest(vm.currentSessionIdForTest)
    #expect(vm.remoteWorkoutEnded == true)
}
```

- [ ] **Step 2: 실패 확인** — `handleIncomingWorkoutEndForTest`/`currentSessionIdForTest` 없음.

- [ ] **Step 3: 구현**

`endSession(notifyRemote:)`의 전송부 변경:
```swift
        if notifyRemote { connectivity.sendWorkoutEnd(sessionId: sessionId) }
```

`$receivedWorkoutEnd` 구독을 가드+소비로 변경:
```swift
        connectivity.$receivedWorkoutEnd
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in self?.handleIncomingWorkoutEnd(id) }
            .store(in: &cancellables)
```
수신 본체:
```swift
    private func handleIncomingWorkoutEnd(_ id: UUID) {
        guard id == sessionId else { return }
        connectivity.receivedWorkoutEnd = nil   // 소비
        endSession(notifyRemote: false)
        remoteWorkoutEnded = true
    }

    #if DEBUG
    func handleIncomingWorkoutEndForTest(_ id: UUID) { handleIncomingWorkoutEnd(id) }
    var currentSessionIdForTest: UUID { sessionId }
    #endif
```

- [ ] **Step 4: 통과 확인.**

- [ ] **Step 5: 커밋 (Task 1 포함)**
```bash
git add Shared/Services/WatchConnectivityService.swift iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "🐛 workoutEnd에 sessionId 가드 (iOS) — 무관 종료 신호 무시"
```

---

### Task 3: Watch endWorkout/수신 가드

**Files:** Modify `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`, Test `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

Watch는 `startMatch`에서 `sessionId ?? workoutSessionId`를 쓰므로, "현재 활성 세션 id"를 추적하는 프로퍼티가 필요하다.

- [ ] **Step 1: 실패 테스트**
```swift
@Test @MainActor func workoutEndIgnoredWhenSessionIdMismatch() {
    let vm = WorkoutSessionViewModel()
    vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    vm.handleIncomingWorkoutEndForTest(UUID())
    #expect(vm.remoteWorkoutEnded == false)
}
```

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: 구현**

활성 세션 id 추적 — 프로퍼티 추가:
```swift
    private(set) var activeSessionId: UUID = .init()
```
`startMatch(options:sessionId:isRemote:)`에서 `let id = sessionId ?? workoutSessionId` 직후:
```swift
        activeSessionId = id
```
`endWorkout(notifyRemote:)`의 전송부:
```swift
        if notifyRemote { connectivity.sendWorkoutEnd(sessionId: activeSessionId) }
```
`$receivedWorkoutEnd` 구독을 가드+소비로:
```swift
        connectivity.$receivedWorkoutEnd
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in self?.handleIncomingWorkoutEnd(id) }
            .store(in: &cancellables)
```
```swift
    private func handleIncomingWorkoutEnd(_ id: UUID) {
        guard id == activeSessionId else { return }
        connectivity.receivedWorkoutEnd = nil
        endWorkout(notifyRemote: false)
        remoteWorkoutEnded = true
    }

    #if DEBUG
    func handleIncomingWorkoutEndForTest(_ id: UUID) { handleIncomingWorkoutEnd(id) }
    #endif
```

- [ ] **Step 4: 통과 확인.**

- [ ] **Step 5: 커밋**
```bash
git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "🐛 workoutEnd에 sessionId 가드 (Watch)"
```

---

### Task 4: receivedWorkoutEnd 타입 변경 호환 빌드 확인

`receivedWorkoutEnd` 타입이 `Date?` → `UUID?`로 바뀌었다. `iOSApp/iOSApp.swift`, `WatchApp/Features/Home/HomeView.swift`의 `connectivity.receivedWorkoutEnd = nil`은 nil 대입이라 무영향.

- [ ] **Step 1:** iOS·Watch 빌드 → BUILD SUCCEEDED

---

### Task 5: 미러 입력 비활성 + 배지 (iOS)

**Files:** Modify `iOSApp/Features/Match/Score/ScoreView.swift`, `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`, Create `iOSApp/Features/Match/Score/Components/MirrorBadge.swift`

- [ ] **Step 1: 배지 컴포넌트 생성**

Create `iOSApp/Features/Match/Score/Components/MirrorBadge.swift`:
```swift
import SwiftUI

struct MirrorBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "applewatch")
            Text(String(localized: "mirror_view_only"))
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundColor(.white.opacity(0.9))
    }
}
```
> 문자열 키 `mirror_view_only`("워치에서 입력 중 · 보기 전용")를 Localizable에 추가한다.

- [ ] **Step 2: ScoreView에 isDriver 주입 + 입력 가드 + 배지**

`ScoreView`에 `let isDriver: Bool` 추가(init 파라미터). `PlayerPointZone`의 `onTap`을 가드:
```swift
                    onTap: { guard isDriver else { return }; withAnimation { viewModel.addPoint(.me) } },
```
(반대편 zone도 `.opponent`로 동일.) body 상단 overlay로 배지:
```swift
            if !isDriver {
                VStack { MirrorBadge().padding(.top, 8); Spacer() }
            }
```
`WorkoutSessionView`의 `ScoreView(...)` 호출에 `isDriver: viewModel.isDriver` 추가. `#Preview`에는 `isDriver: true` 추가.

- [ ] **Step 3:** iOS 빌드 → BUILD SUCCEEDED, iOS 테스트 GREEN

- [ ] **Step 4: 커밋**
```bash
git add iOSApp/Features/Match/Score/ iOSApp/Features/WorkoutSession/WorkoutSessionView.swift
git commit -m "✨ iOS 미러 입력 비활성 + 보기전용 배지"
```

---

### Task 6: 미러 입력 비활성 + 배지 (Watch)

**Files:** Modify `WatchApp/Features/Match/Score/ScoreView.swift`, Create `WatchApp/Features/Match/Score/Components/MirrorBadge.swift`

- [ ] **Step 1: 배지 컴포넌트**

Create `WatchApp/Features/Match/Score/Components/MirrorBadge.swift`:
```swift
import SwiftUI

struct MirrorBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "iphone")
            Text(String(localized: "mirror_view_only_short"))
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundColor(.white.opacity(0.9))
    }
}
```
> `mirror_view_only_short`("보기 전용") 키 추가.

- [ ] **Step 2: ScoreView 입력 가드 + 배지**

`PlayerPointButton`의 `action`을 `flowViewModel.isDriver`로 가드:
```swift
                    action: { guard flowViewModel.isDriver else { return }; viewModel.addPoint(.me) }
```
(반대편 버튼도 `.opponent`로 동일.) `ZStack` 상단에 배지:
```swift
            if !flowViewModel.isDriver {
                VStack { MirrorBadge().padding(.top, 4); Spacer() }
            }
```

- [ ] **Step 3:** Watch 빌드 → BUILD SUCCEEDED, Watch 테스트 GREEN

- [ ] **Step 4: 커밋**
```bash
git add WatchApp/Features/Match/Score/
git commit -m "✨ Watch 미러 입력 비활성 + 보기전용 배지"
```

---

### Task 7: 전체 검증 + code-review

- [ ] **Step 1:** iOS·Watch 빌드/테스트 GREEN
- [ ] **Step 2:** `make fix && make lint`
- [ ] **Step 3:** `/code-review` → `superpowers:receiving-code-review`로 반영
- [ ] **Step 4: 실기기 2대 확인**
  - 폰에서 운동 종료 → 워치가 **같은 세션일 때만** 종료되는지 / 무관한 잔여 신호로 안 튕기는지 (증상 2)
  - 미러 기기에서 점수 영역 탭 → 반응 없고 배지 보이는지

---

## 이 단계가 검증하는 것 (증상 2)

- `workoutEnd`는 sessionId 일치 시에만 종료를 일으키고, 소비 즉시 비워져 stale/오신호로 인한 홈 복귀가 사라진다.
- 미러 기기는 입력이 막히고 보기 전용임이 화면에 표시된다.
