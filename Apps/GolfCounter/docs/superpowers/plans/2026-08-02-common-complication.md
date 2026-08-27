# ② common: 컴플리케이션 / Smart Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ComplicationAppExtension` 타깃에 워치 컴플리케이션 3종(`accessoryCircular`/`accessoryCorner`/`accessoryRectangular`)을 구현해, App Group의 `RoundSnapshot` 유무에 따라 "평상시"와 "라운드 중"을 구분해 표시한다.

**Architecture:** 표시에 필요한 값 계산은 UI에서 분리해 `Shared/Models/ComplicationState.swift`의 순수 struct로 두고(테스트 대상), 위젯 쪽은 `TimelineProvider`가 `RoundSnapshotStore.load()` 결과를 `ComplicationState`로 감싸 뷰에 넘기기만 한다. 타임라인은 시간 기반 갱신 없이 `.never` 정책을 쓰고, 갱신은 워치 앱이 스냅샷을 저장/삭제할 때 호출하는 `WidgetCenter.reloadAllTimelines()`로만 일어난다(**호출부는 plan ③ 범위** — 이 plan에서는 넣지 않는다).

**Tech Stack:** SwiftUI / WidgetKit (watchOS 10+) / Swift Testing

**참조 spec:** `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` (§3 RoundSnapshot, §7 컴플리케이션 / Smart Stack)

**선행 상태(plan ① 완료분, 이미 저장소에 있음):**
- `Shared/Models/RoundSnapshot.swift` — `startedAt`, `courseName`, `currentHoleIndex`(0-based), `holeScores`, `holePars`, `puttCounts` / 계산 프로퍼티 `currentHoleNumber`, `totalStrokes`, `relativeToPar`
- `Shared/Services/RoundSnapshotStore.swift` — `save(_:to:) -> Bool`, `load(from:) -> RoundSnapshot?`, `clear(from:)` (기본 인자는 App Group suite)
- `ComplicationApp/`는 `PBXFileSystemSynchronizedRootGroup`이고 `Shared/`도 `ComplicationAppExtension` 타깃 멤버다 → **이 plan에서 pbxproj를 손댈 일이 없다.** 파일·에셋 추가는 파일시스템 조작만으로 빌드에 반영된다.
- `ComplicationAppExtension.entitlements`에 App Group `group.com.yj.GolfCounter`가 이미 설정되어 있다.

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0** — `containerBackground(_:for:)`는 watchOS 10부터이므로 `#available` 분기 없이 그대로 쓴다
- App Group: `group.com.yj.GolfCounter` (watch 앱 + ComplicationApp)
- 지원 패밀리: `.accessoryCircular`, `.accessoryCorner`, `.accessoryRectangular` — 이 3종만
- 사용자 노출 문자열은 이 단계에서 **한국어 하드코딩**한다. `.xcstrings` 로컬라이즈는 plan ⑦ 범위
- 딥링크 URL 라우팅을 만들지 않는다 — 컴플리케이션 탭은 위젯 기본 동작(앱 실행)에 맡기고, 라운드 복귀 분기는 워치 앱이 스냅샷 존재 여부로 처리한다(plan ③)
- `WidgetCenter.reloadAllTimelines()` 호출은 이 plan에 넣지 않는다 (plan ③ 워치 앱 쪽 책임)
- ViewModel/Model은 UI 프레임워크 import 금지 — `ComplicationState`는 `Foundation`만 import한다
- 한 파일 = 한 타입 (단, 위젯의 Entry/Provider/View/Widget은 tennis_counter와 동일하게 `ComplicationApp.swift` 한 파일에 둔다 — 기존 예외)
- 커밋 메시지는 gitmoji prefix, `main` 직접 커밋 금지
- 빌드/테스트 시뮬레이터: 워치는 `Apple Watch Series 11 (46mm)`, iPhone은 `iPhone 17 Pro`

---

### Task 0: 작업 브랜치 생성

**Files:** 없음 (git만)

- [ ] **Step 1: main 최신화 후 브랜치 생성**

```bash
cd /Users/yj/Workspace/golf_counter
git checkout main && git pull
git checkout -b feat/complication
```

---

### Task 1: ComplicationState (TDD)

컴플리케이션이 화면에 그릴 값을 `RoundSnapshot?` 하나로부터 계산하는 순수 struct. 위젯 타깃에는 테스트 타깃이 없으므로, 테스트 가능한 로직을 전부 `Shared/`로 내려서 `watchosTests`에서 검증한다. (`Shared/`는 워치 앱·컴플리케이션 양 타깃의 멤버이므로 `@testable import GolfCounter_Watch_App`으로 접근된다.)

**Files:**
- Create: `Shared/Models/ComplicationState.swift`
- Test: `watchosTests/Shared/ComplicationStateTests.swift`

**Interfaces:**
- Consumes: `RoundSnapshot` (`currentHoleNumber: Int`, `totalStrokes: Int`, `relativeToPar: Int`)
- Produces: `ComplicationState` (`Equatable` struct)
  - `init(snapshot: RoundSnapshot?)`
  - 저장 프로퍼티: `isRoundActive: Bool`, `holeNumber: Int`, `totalStrokes: Int`, `relativeToPar: Int`
  - 계산 프로퍼티: `holeText: String`("H7"), `relativeToParText: String`("+3"/"E"/"-2"), `strokesText: String`("41타")
  - Task 2의 `ComplicationEntry`·`ComplicationAppEntryView`가 이 시그니처에 의존

- [ ] **Step 1: 실패하는 테스트 작성** — `watchosTests/Shared/ComplicationStateTests.swift`

```swift
import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct ComplicationStateTests {
    private func makeSnapshot(holeScores: [Int], holePars: [Int], currentHoleIndex: Int) -> RoundSnapshot {
        RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1000),
                      courseName: "테스트CC",
                      currentHoleIndex: currentHoleIndex,
                      holeScores: holeScores,
                      holePars: holePars,
                      puttCounts: [])
    }

    @Test func 스냅샷없으면_비활성이고_값은_0이다() {
        let state = ComplicationState(snapshot: nil)

        #expect(state.isRoundActive == false)
        #expect(state.holeNumber == 0)
        #expect(state.totalStrokes == 0)
        #expect(state.relativeToPar == 0)
    }

    @Test func 스냅샷있으면_활성이고_파생값을_노출한다() {
        let snapshot = makeSnapshot(holeScores: [4, 3, 6], holePars: [4, 3, 5], currentHoleIndex: 2)

        let state = ComplicationState(snapshot: snapshot)

        #expect(state.isRoundActive == true)
        #expect(state.holeNumber == 3)
        #expect(state.totalStrokes == 13)
        #expect(state.relativeToPar == 1)
    }

    @Test func 표시문자열_오버파는_부호를_붙인다() {
        let snapshot = makeSnapshot(holeScores: [4, 3, 6], holePars: [4, 3, 5], currentHoleIndex: 2)

        let state = ComplicationState(snapshot: snapshot)

        #expect(state.holeText == "H3")
        #expect(state.relativeToParText == "+1")
        #expect(state.strokesText == "13타")
    }

    @Test func 표시문자열_이븐파는_E로_표시한다() {
        let snapshot = makeSnapshot(holeScores: [4, 3], holePars: [4, 3], currentHoleIndex: 1)

        let state = ComplicationState(snapshot: snapshot)

        #expect(state.relativeToParText == "E")
    }

    @Test func 표시문자열_언더파는_음수부호를_유지한다() {
        let snapshot = makeSnapshot(holeScores: [3, 3], holePars: [4, 3], currentHoleIndex: 1)

        let state = ComplicationState(snapshot: snapshot)

        #expect(state.relativeToParText == "-1")
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:watchosTests/ComplicationStateTests
```

Expected: FAIL — `cannot find 'ComplicationState' in scope` 컴파일 에러.

- [ ] **Step 3: 구현** — `Shared/Models/ComplicationState.swift`

```swift
import Foundation

/// 컴플리케이션이 그릴 표시값. 진행 중 스냅샷(`RoundSnapshot`) 유무로 평상시/라운드 중을 가른다 (spec §7).
/// 위젯 타깃에는 테스트 타깃이 없으므로, 표시 로직을 Shared로 내려 watchosTests에서 검증한다.
struct ComplicationState: Equatable {
    let isRoundActive: Bool
    let holeNumber: Int
    let totalStrokes: Int
    let relativeToPar: Int

    init(snapshot: RoundSnapshot?) {
        isRoundActive = snapshot != nil
        holeNumber = snapshot?.currentHoleNumber ?? 0
        totalStrokes = snapshot?.totalStrokes ?? 0
        relativeToPar = snapshot?.relativeToPar ?? 0
    }

    var holeText: String {
        "H\(holeNumber)"
    }

    /// 골프 표기 관례: 이븐파는 0이 아니라 E, 오버파는 명시적으로 + 부호를 붙인다.
    var relativeToParText: String {
        if relativeToPar == 0 {
            return "E"
        }
        if relativeToPar > 0 {
            return "+\(relativeToPar)"
        }
        return "\(relativeToPar)"
    }

    var strokesText: String {
        "\(totalStrokes)타"
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Step 2와 같은 명령. Expected: PASS 5건.

- [ ] **Step 5: 커밋**

```bash
git add Shared/Models/ComplicationState.swift watchosTests/Shared/ComplicationStateTests.swift
git commit -m "✨ feat: 컴플리케이션 표시값 ComplicationState 추가"
```

---

### Task 2: 컴플리케이션 에셋 + 3종 패밀리 뷰 구현

앱 아이콘 SVG를 위젯 타깃 에셋으로 복사하고, 브랜드 색상과 Provider/Entry/View/Widget을 구현한다. `ComplicationApp/`이 synchronized group이므로 파일을 만들면 곧바로 타깃에 포함된다.

**Files:**
- Create: `ComplicationApp/Assets.xcassets/GolfIcon.imageset/Contents.json`
- Create: `ComplicationApp/Assets.xcassets/GolfIcon.imageset/golf-counter.svg` (복사)
- Create: `ComplicationApp/BrandColor.swift`
- Modify: `ComplicationApp/ComplicationApp.swift` (스텁 전체 교체)

**Interfaces:**
- Consumes: `ComplicationState(snapshot:)` (Task 1), `RoundSnapshotStore.load()` (plan ①)
- Produces: `ComplicationEntry`(`date: Date`, `state: ComplicationState`), `Provider: TimelineProvider`, `ComplicationAppEntryView`, `ComplicationApp: Widget`. `ComplicationAppBundle`(기존 파일)이 `ComplicationApp()`을 그대로 사용하므로 번들 쪽 수정은 없다.

- [ ] **Step 1: 아이콘 에셋 복사**

앱 아이콘(Icon Composer)의 글리프 SVG를 위젯 에셋으로 재사용한다. 글리프는 크림색(`#F7F3E7`) 단색이라 브랜드 배경 위에 그대로 얹으면 앱 아이콘과 같은 인상이 된다.

```bash
cd /Users/yj/Workspace/golf_counter
mkdir -p ComplicationApp/Assets.xcassets/GolfIcon.imageset
cp GolfCounter.icon/Assets/golf-counter.svg ComplicationApp/Assets.xcassets/GolfIcon.imageset/golf-counter.svg
```

- [ ] **Step 2: imageset Contents.json 작성** — `ComplicationApp/Assets.xcassets/GolfIcon.imageset/Contents.json`

`preserves-vector-representation`을 켜야 작은 컴플리케이션 크기에서도 벡터로 또렷하게 렌더된다.

```json
{
  "images" : [
    {
      "filename" : "golf-counter.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
```

- [ ] **Step 3: 브랜드 색상 작성** — `ComplicationApp/BrandColor.swift`

평상시는 앱 아이콘 그라디언트의 기준색(파랑), 라운드 중은 초록으로 전환해 진행 중임을 알린다(spec §7). 최종 색은 아이콘 디자인 확정 후 조정 가능한 잠정값이다.

```swift
import SwiftUI

extension Color {
    /// 앱 아이콘 그라디언트 기준색 (GolfCounter.icon의 automatic-gradient 값)
    static let brand = Color(red: 0, green: 0.5333, blue: 1.0)
    /// 라운드 진행 중 배경색
    static let brandActive = Color(red: 0.2980, green: 0.6863, blue: 0.3137)
}
```

- [ ] **Step 4: 위젯 본체 교체** — `ComplicationApp/ComplicationApp.swift` 전체를 아래로 교체

```swift
import SwiftUI
import WidgetKit

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let state: ComplicationState
}

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), state: ComplicationState(snapshot: nil))
    }

    func getSnapshot(in _: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(currentEntry())
    }

    /// 시간 기반 갱신이 필요 없다 — 라운드 상태가 바뀔 때 워치 앱이 reloadAllTimelines()를 호출한다 (plan ③).
    func getTimeline(in _: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> ComplicationEntry {
        ComplicationEntry(date: Date(), state: ComplicationState(snapshot: RoundSnapshotStore.load()))
    }
}

struct ComplicationAppEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    var entry: ComplicationEntry

    @ViewBuilder
    var body: some View {
        switch widgetFamily {
        case .accessoryRectangular:
            rectangularBody
                .containerBackground(.clear, for: .widget)
        default:
            iconBody
                .containerBackground(entry.state.isRoundActive ? Color.brandActive : Color.brand, for: .widget)
        }
    }

    private var iconBody: some View {
        golfIcon
            .padding(4)
    }

    private var rectangularBody: some View {
        HStack(spacing: 8) {
            golfIcon
                .frame(width: 24, height: 24)
            if entry.state.isRoundActive {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(entry.state.holeText) · \(entry.state.relativeToParText)")
                        .font(.headline)
                    Text(entry.state.strokesText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("라운드 시작")
                    .font(.headline)
            }
            Spacer(minLength: 0)
        }
    }

    private var golfIcon: some View {
        Image("GolfIcon")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
    }
}

struct ComplicationApp: Widget {
    let kind: String = "ComplicationApp"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationAppEntryView(entry: entry)
        }
        .configurationDisplayName("GolfCounter")
        .description("라운드 진행 상황")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

private func previewSnapshot() -> RoundSnapshot {
    RoundSnapshot(startedAt: Date(),
                  courseName: "테스트CC",
                  currentHoleIndex: 6,
                  holeScores: [4, 3, 6, 5, 4, 3, 2],
                  holePars: [4, 3, 5, 4, 4, 3, 4],
                  puttCounts: [2, 1, 2, 2, 1, 1, 1])
}

#Preview(as: .accessoryCircular) {
    ComplicationApp()
} timeline: {
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()))
}

#Preview(as: .accessoryRectangular) {
    ComplicationApp()
} timeline: {
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()))
}
```

- [ ] **Step 5: 컴플리케이션 타깃 빌드**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

Expected: `BUILD SUCCEEDED`. `cannot find 'ComplicationState'`가 나오면 `Shared/`가 `ComplicationAppExtension` 타깃 멤버인지 pbxproj의 `fileSystemSynchronizedGroups`에서 확인한다(plan ① 시점에 이미 포함되어 있어야 정상).

- [ ] **Step 6: 워치 앱 타깃도 빌드 확인**

컴플리케이션은 워치 앱에 임베드되므로 워치 스킴도 함께 확인한다.

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 7: 커밋**

```bash
git add ComplicationApp
git commit -m "✨ feat: 컴플리케이션 3종 패밀리와 라운드 중 표시 구현"
```

---

### Task 3: 전체 검증 + 육안 확인

**Files:** 없음 (검증만)

- [ ] **Step 1: 포맷·린트**

```bash
make fix && make lint && make format
```

Expected: 위반 0. `make fix`로 변경된 파일이 생기면 `git add -A && git commit -m "🎨 style: make fix 결과 반영"`로 별도 커밋한다.

- [ ] **Step 2: 세 스킴 전체 빌드**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

Expected: 3개 모두 `BUILD SUCCEEDED`.

- [ ] **Step 3: 전체 테스트**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Expected: iOS 2건 + watch 9건(기존 `RoundSnapshotTests` 4건 + 신규 `ComplicationStateTests` 5건) 전부 PASS.

- [ ] **Step 4: 워치 시뮬레이터 육안 확인 (수동)**

Xcode에서 `ComplicationAppExtension` 스킴을 워치 시뮬레이터로 Run하면 위젯 프리뷰 모드로 뜬다. 확인 항목:

1. `accessoryCircular`·`accessoryCorner` — 파란 배경 위에 골프 아이콘 (평상시)
2. `accessoryRectangular` — 아이콘 + "라운드 시작" (평상시)
3. 라운드 중 상태는 워치 앱이 스냅샷을 쓰기 전까지 시뮬레이터에서 재현되지 않으므로, `#Preview`의 두 번째 타임라인 엔트리(초록 배경 / "H7 · E" + "27타")로 Xcode 캔버스에서 확인한다.

실제 기기에서의 라운드 중 전환은 plan ③(워치 카운터 코어)에서 스냅샷 저장 + `reloadAllTimelines()` 호출이 붙은 뒤에 검증한다.

- [ ] **Step 5: PR 생성**

```bash
git push -u origin feat/complication
gh pr create --title "✨ feat: 컴플리케이션 / Smart Stack 구현 (plan ②)" --body "$(cat <<'EOF'
## 요약
- `ComplicationState`(Shared/Models) — `RoundSnapshot?` → 컴플리케이션 표시값 파생, 순수 struct라 watchosTests에서 검증
- `ComplicationAppExtension` 3종 패밀리 구현 (circular / corner / rectangular)
- 평상시: 브랜드 파랑 + 아이콘 / 라운드 중: 초록 배경 + 현재 홀·오버파·총타수

## 테스트
- iosTests 2건, watchosTests 9건 전부 PASS
- 세 스킴 BUILD SUCCEEDED, `make lint`/`make format` 위반 0

## 범위 밖
- `WidgetCenter.reloadAllTimelines()` 호출부는 plan ③(워치 카운터 코어)
- 문자열 로컬라이즈는 plan ⑦

참조: `docs/superpowers/plans/2026-08-02-common-complication.md`
EOF
)"
```

---

## 완료 기준

- [ ] `ComplicationStateTests` 5건 PASS, `watchosTests` 전체 9건 PASS, `iosTests` 2건 PASS
- [ ] 세 스킴(`GolfCounter`, `GolfCounter Watch App`, `ComplicationAppExtension`) BUILD SUCCEEDED
- [ ] `make lint`·`make format` 위반 0
- [ ] 컴플리케이션 3종 패밀리가 평상시/라운드 중 두 상태로 렌더되는 것을 Xcode 프리뷰에서 확인
- [ ] pbxproj 변경 없음 (synchronized group 덕분에 파일 추가만으로 반영)
