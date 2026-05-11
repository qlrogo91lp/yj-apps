# Phase 1-B ② Live Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 경기 중 잠금화면 + Dynamic Island에 현재 게임 점수(ME vs OPP)와 세트 스코어를 실시간 표시하는 Live Activity 구현

**Architecture:** `TennisActivityAttributes`가 ActivityKit의 `ActivityAttributes` 프로토콜을 준수. `LiveActivityService` 싱글턴이 `Activity<TennisActivityAttributes>` 인스턴스 생명주기 관리. iOS `MatchViewModel`이 점수 변경 시 `LiveActivityService.update()` 호출. 잠금화면 Widget과 Dynamic Island(compact/expanded) 레이아웃을 별도 뷰로 구현.

**Tech Stack:** ActivityKit, WidgetKit, SwiftUI

**선행 조건:**
- `2026-04-29-phase1a-2-match-feature.md` 완료 (iOS MatchViewModel 존재)
- Xcode 14+, iOS 16.1+ 대상

---

## File Structure

| 파일 | 액션 | 역할 |
|------|------|------|
| `iOSApp/LiveActivity/TennisActivityAttributes.swift` | Create | ActivityAttributes 정의 |
| `iOSApp/LiveActivity/LiveActivityService.swift` | Create | Activity 생명주기 관리 |
| `iOSApp/LiveActivity/TennisLiveActivityView.swift` | Create | 잠금화면 + Dynamic Island 뷰 |
| `iOSApp/Features/Match/Score/MatchViewModel.swift` | Modify | 점수 변경 시 LiveActivityService 호출 |

> **주의**: Live Activity 위젯은 별도 Widget Extension 타겟이 필요하지 않다. WidgetKit 코드를 메인 앱 타겟 내 Widget Extension에 넣어야 하지만, ActivityAttributes와 Service는 메인 타겟에 위치해도 된다. 단, 실제 위젯 UI(`WidgetBundle`)는 App Extension 타겟에 있어야 한다. 이 plan에서는 기존 `ComplicationApp` 타겟을 확장하거나 새 `TennisWidgetExtension` 타겟을 추가하는 방식을 선택한다.

---

### Task 1: Live Activity Capability 추가 (Xcode 수동 작업)

- [ ] **Step 1: iOS 타겟 Push Notifications Capability 추가**

1. Xcode > TennisCounter 타겟
2. Signing & Capabilities > `+` > Push Notifications 추가
3. `+` > Background Modes 추가 → "Remote notifications" 체크

- [ ] **Step 2: Info.plist에 NSSupportsLiveActivities 추가**

`iOSApp/Info.plist`에 추가:
```
NSSupportsLiveActivities = YES (Boolean)
```

Xcode Custom iOS Target Properties에서 추가하거나, Info.plist XML 편집:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

---

### Task 2: TennisActivityAttributes 정의

**Files:**
- Create: `iOSApp/LiveActivity/TennisActivityAttributes.swift`

- [ ] **Step 1: 디렉터리 생성**

```bash
mkdir -p iOSApp/LiveActivity
```

- [ ] **Step 2: TennisActivityAttributes.swift 생성**

```swift
import ActivityKit
import Foundation

struct TennisActivityAttributes: ActivityAttributes {
    // 경기 내내 변하지 않는 정적 데이터
    let matchFormat: String

    // 실시간으로 바뀌는 동적 데이터
    struct ContentState: Codable, Hashable {
        var myScore: Int
        var yourScore: Int
        var myGameScore: Int
        var yourGameScore: Int
        var mySetScore: Int
        var yourSetScore: Int
        var currentSetNumber: Int
    }
}
```

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: TennisLiveActivityView (잠금화면 + Dynamic Island UI)

**Files:**
- Create: `iOSApp/LiveActivity/TennisLiveActivityView.swift`

> 이 뷰는 Widget Extension 타겟에서 사용된다. 메인 타겟에 파일을 만들고 Extension 타겟에도 추가한다.

- [ ] **Step 1: TennisLiveActivityView.swift 생성**

```swift
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - 잠금화면 뷰 (Lock Screen)

struct TennisLockScreenView: View {
    let state: TennisActivityAttributes.ContentState
    let attributes: TennisActivityAttributes

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("🎾 Ralli")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("Set \(state.currentSetNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("ME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                    Text(scoreText(state.myScore))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                    Text("\(state.myGameScore)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green.opacity(0.7))
                }

                Text(":")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(spacing: 2) {
                    Text("OPP")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(scoreText(state.yourScore))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)
                    Text("\(state.yourGameScore)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func scoreText(_ score: Int) -> String {
        score == 50 ? "W" : "\(score)"
    }
}

// MARK: - Dynamic Island Compact 뷰

struct TennisCompactLeadingView: View {
    let state: TennisActivityAttributes.ContentState

    var body: some View {
        Text("\(state.myGameScore)-\(state.yourGameScore)")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.green)
    }
}

struct TennisCompactTrailingView: View {
    let state: TennisActivityAttributes.ContentState

    var body: some View {
        Text(scoreText(state.myScore))
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(state.myScore >= state.yourScore ? .green : .orange)
    }

    private func scoreText(_ score: Int) -> String {
        score == 50 ? "W" : "\(score)"
    }
}

// MARK: - Dynamic Island Expanded 뷰

struct TennisExpandedView: View {
    let state: TennisActivityAttributes.ContentState

    var body: some View {
        HStack {
            VStack(spacing: 2) {
                Text("ME").font(.caption2).foregroundColor(.green)
                Text(scoreText(state.myScore))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                Text("G: \(state.myGameScore)")
                    .font(.caption2).foregroundColor(.green.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("Set \(state.currentSetNumber)")
                    .font(.caption2).foregroundColor(.secondary)
                Text("\(state.mySetScore) - \(state.yourSetScore)")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("OPP").font(.caption2).foregroundColor(.orange)
                Text(scoreText(state.yourScore))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.orange)
                Text("G: \(state.yourGameScore)")
                    .font(.caption2).foregroundColor(.orange.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
    }

    private func scoreText(_ score: Int) -> String {
        score == 50 ? "W" : "\(score)"
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

### Task 4: Widget Extension에 Live Activity 위젯 등록

> Xcode에서 수동으로 Widget Extension 타겟 추가가 필요하다. 기존 `ComplicationAppExtension`을 활용하거나 새 Extension을 만든다.

- [ ] **Step 1: Xcode에서 Widget Extension 추가**

1. File > New > Target > Widget Extension
2. Product Name: `TennisWidgetExtension`
3. "Include Live Activity" 체크
4. Activate scheme: Yes

- [ ] **Step 2: Extension 타겟에 TennisActivityAttributes 파일 추가**

Xcode에서:
- `TennisActivityAttributes.swift` 선택 → Target Membership에 `TennisWidgetExtension` 추가
- `TennisLiveActivityView.swift` 선택 → Target Membership에 `TennisWidgetExtension` 추가

- [ ] **Step 3: Widget Extension 진입점에 LiveActivity 등록**

Xcode가 생성한 `TennisWidgetExtensionBundle.swift` 수정:

```swift
import WidgetKit
import SwiftUI

@main
struct TennisWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        TennisLiveActivityWidget()
    }
}

struct TennisLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TennisActivityAttributes.self) { context in
            TennisLockScreenView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color.black.opacity(0.9))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    TennisExpandedView(state: context.state)
                }
            } compactLeading: {
                TennisCompactLeadingView(state: context.state)
            } compactTrailing: {
                TennisCompactTrailingView(state: context.state)
            } minimal: {
                Text("🎾")
            }
        }
    }
}
```

- [ ] **Step 4: Extension 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisWidgetExtension" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 5: LiveActivityService 생성

**Files:**
- Create: `iOSApp/LiveActivity/LiveActivityService.swift`

- [ ] **Step 1: LiveActivityService.swift 생성**

```swift
import ActivityKit
import Foundation

final class LiveActivityService {
    static let shared = LiveActivityService()

    private var currentActivity: Activity<TennisActivityAttributes>?

    private init() {}

    func startActivity(matchFormat: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TennisActivityAttributes(matchFormat: matchFormat)
        let state = TennisActivityAttributes.ContentState(
            myScore: 0, yourScore: 0,
            myGameScore: 0, yourGameScore: 0,
            mySetScore: 0, yourSetScore: 0,
            currentSetNumber: 1
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {}
    }

    func update(
        myScore: Int, yourScore: Int,
        myGameScore: Int, yourGameScore: Int,
        mySetScore: Int, yourSetScore: Int,
        currentSetNumber: Int
    ) {
        let state = TennisActivityAttributes.ContentState(
            myScore: myScore, yourScore: yourScore,
            myGameScore: myGameScore, yourGameScore: yourGameScore,
            mySetScore: mySetScore, yourSetScore: yourSetScore,
            currentSetNumber: currentSetNumber
        )
        Task {
            await currentActivity?.update(.init(state: state, staleDate: nil))
        }
    }

    func endActivity() {
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
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
git add iOSApp/LiveActivity/
git commit -m "feat: add LiveActivityService and TennisActivityAttributes"
```

---

### Task 6: iOS MatchViewModel에 LiveActivity 연동

**Files:**
- Modify: `iOSApp/Features/Match/Score/MatchViewModel.swift`

- [ ] **Step 1: MatchViewModel에 LiveActivity 호출 추가**

`MatchViewModel`에 다음 추가:

```swift
private let liveActivity = LiveActivityService.shared
```

`init()` 완료 후 경기 시작 시 `startActivity` 호출을 위해 `startMatch()` 메서드 추가:

```swift
func startMatch() {
    liveActivity.startActivity(matchFormat: format.rawValue)
}
```

`sendScoreUpdate()` 메서드 내부에 liveActivity 업데이트 추가:

```swift
private func sendScoreUpdate() {
    let update = ScoreUpdate(
        myScore: score.myScore,
        yourScore: score.yourScore,
        myGameScore: myGameScore,
        yourGameScore: yourGameScore
    )
    connectivity.sendScoreUpdate(update)

    liveActivity.update(
        myScore: score.myScore,
        yourScore: score.yourScore,
        myGameScore: myGameScore,
        yourGameScore: yourGameScore,
        mySetScore: mySetScore,
        yourSetScore: yourSetScore,
        currentSetNumber: currentSetNumber
    )
}
```

`saveMatch()` 끝부분에 `liveActivity.endActivity()` 호출 추가:

```swift
private func saveMatch() {
    // ... 기존 저장 코드 ...
    liveActivity.endActivity()
}
```

- [ ] **Step 2: MatchView.swift의 .onAppear에 startMatch() 호출 추가**

`MatchView.swift`:

```swift
.onAppear {
    viewModel.injectContext(modelContext)
    viewModel.startMatch()
    UIApplication.shared.isIdleTimerDisabled = true
}
```

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Score/MatchViewModel.swift \
        iOSApp/Features/Match/Score/MatchView.swift
git commit -m "feat: integrate LiveActivity with iOS MatchViewModel"
```

---

### Task 7: Live Activity 통합 검증

- [ ] **Step 1: 실기기에서 검증 (시뮬레이터 미지원)**

> Live Activity는 iOS 시뮬레이터에서 동작하지 않는다. 실기기(iOS 16.1+)에서만 테스트 가능.

실기기 빌드:
1. Xcode에서 실기기 선택
2. Product > Run
3. Match 탭 → One Set 선택 → Score 화면 진입
4. 홈 버튼으로 앱 백그라운드 전환
5. 잠금화면에서 현재 점수 표시 확인
6. Dynamic Island(iPhone 14 Pro+)에서 compact 점수 표시 확인

- [ ] **Step 2: 점수 변경 실시간 반영 확인**

1. 잠금화면 상태에서 Watch로 점수 입력
2. 잠금화면의 Live Activity가 업데이트되는지 확인

- [ ] **Step 3: 경기 종료 후 Live Activity 해제 확인**

1. 경기 완료(세트 승리) 후
2. Live Activity가 잠금화면에서 사라지는지 확인

- [ ] **Step 4: 최종 커밋**

```bash
git add .
git commit -m "feat: Phase 1-B Live Activity implementation complete"
```

---

## 완료 기준

- [x] 경기 시작 시 잠금화면에 Live Activity 표시
- [x] 잠금화면에 현재 게임 점수(ME/OPP), 세트 스코어 표시
- [x] Dynamic Island(iPhone 14 Pro+) compact/expanded 레이아웃 표시
- [x] 점수 변경 시 Live Activity 실시간 업데이트
- [x] 경기 종료 시 Live Activity 자동 해제
- [x] iOS 빌드 성공
