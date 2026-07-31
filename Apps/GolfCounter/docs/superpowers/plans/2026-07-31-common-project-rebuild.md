# ① common: 프로젝트 재구성 + 아이콘 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** golf_counter 저장소의 Xcode 프로젝트를 tennis_counter 구조(Xcode 16 synchronized groups, 타깃 3개, ralli-kit 로컬 SPM)로 재구성하고, `Shared` 모델(`GolfRound`/`RoundSnapshot`)·App Group·준비된 아이콘까지 적용해 이후 모든 plan의 기반을 만든다.

**Architecture:** 기존 레거시 pbxproj와 중복 소스를 전부 버리고, tennis_counter의 `project.pbxproj`를 템플릿으로 복사·적응한다(LiveActivity 타깃 제거, 이름/번들ID/버전 치환). 소스는 `Shared/`(양 타깃 공유) + `iOSApp/` + `WatchApp/` + `ComplicationApp/`(스텁) 구조. 앱이 빌드·실행되는 최소 진입점만 두고 실제 화면은 이후 plan(②~⑧)에서 만든다.

**Tech Stack:** Swift 5(language mode) / SwiftUI / SwiftData / WidgetKit / ralli-kit(`WorkoutCore`·`ConnectivityCore`·`PersistenceCore`, 로컬 SPM `../ralli-kit`) / Swift Testing

**참조 spec:** `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` (§2 프로젝트 구조, §3 데이터 모델)

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0** (ralli-kit 최소 요구)
- 번들 ID 유지: iOS `com.yj.GolfCounter`, watch `com.yj.GolfCounter.watchkitapp`, 컴플리케이션 `com.yj.GolfCounter.watchkitapp.ComplicationApp`
- `DEVELOPMENT_TEAM = P2TU28W32L`, `MARKETING_VERSION`: iOS 2.0 / watch 2.0.1 (리빌드 전 실제 watch 타깃이 이미 2.0으로 App Store에 존재했으므로, 하향을 피하기 위해 1.0이 아닌 2.0.1로 상향) / 컴플리케이션 1.0 (신설 타깃, 이전 제출 이력 없음)
- App Group: `group.com.yj.GolfCounter` (watch 앱 + ComplicationApp만. iOS는 불필요)
- iCloud 컨테이너: `iCloud.com.yj.GolfCounter` (iOS만, CloudKit)
- 아이콘: Icon Composer 포맷, 원본 `/Users/yj/Downloads/golf-counter.icon/` → 저장소 루트 `GolfCounter.icon`으로 복사, `ASSETCATALOG_COMPILER_APPICON_NAME = GolfCounter`
- 커밋 메시지는 gitmoji prefix (`♻️ refactor:` / `✨ feat:` / `✅ test:` / `🔧 chore:` …), main 직접 커밋 금지
- 빌드 검증 시뮬레이터: iPhone은 `iPhone 17 Pro`, 워치는 `xcrun simctl list devices available | grep -i watch`로 확인한 첫 기기(tennis 기준 `Apple Watch Series 11 (46mm)`)
- 파일 네이밍·폴더 규칙: tennis_counter CLAUDE.md 컨벤션 (View suffix는 화면만, 한 파일=한 타입, 계층화 Components)

---

### Task 0: 작업 브랜치 생성

**Files:** 없음 (git만)

- [ ] **Step 1: main 최신화 후 브랜치 생성**

```bash
cd /Users/yj/Workspace/golf_counter
git checkout main && git pull
git checkout -b refactor/project-rebuild
```

(spec 브랜치 `docs/golfcounter-rebuild-spec`가 아직 머지 전이면 그 브랜치에서 분기해도 된다 — spec 문서만 다른 브랜치이므로 충돌 없음.)

---

### Task 1: 새 폴더 스켈레톤 + 진입점·엔타이틀먼트 파일 생성

기존 소스는 아직 지우지 않는다(Task 2에서 pbxproj 교체와 함께 삭제). 여기서는 새 구조의 파일만 만든다.

**Files:**
- Create: `Shared/Models/.gitkeep` 대신 실제 파일은 Task 3·4에서 (폴더는 이 Task에서 mkdir)
- Create: `iOSApp/iOSApp.swift`, `iOSApp/Assets.xcassets/Contents.json`, `iOSApp/Preview Content/PreviewAssets.xcassets/Contents.json`
- Create: `WatchApp/WatchApp.swift`, `WatchApp/Assets.xcassets/Contents.json`, `WatchApp/Preview Content/PreviewAssets.xcassets/Contents.json`
- Create: `ComplicationApp/ComplicationAppBundle.swift`, `ComplicationApp/ComplicationApp.swift`, `ComplicationApp/Assets.xcassets/Contents.json`
- Create: `GolfCounter.entitlements`, `GolfCounter Watch App.entitlements`, `ComplicationAppExtension.entitlements`
- Create: `iosTests/`, `watchosTests/` 폴더 (테스트 파일은 Task 3·4)

**Interfaces:**
- Produces: 앱 진입점 타입 `GolfCounterApp`(iOS) / `GolfCounterWatchApp`(watch) / `ComplicationAppBundle`(widget). 이후 plan들이 이 진입점 안의 루트 뷰를 교체한다.

- [ ] **Step 1: 폴더 생성**

```bash
mkdir -p Shared/Models Shared/Persistence Shared/Services \
  iOSApp/Features iOSApp/Components "iOSApp/Preview Content/PreviewAssets.xcassets" iOSApp/Assets.xcassets \
  WatchApp/Features WatchApp/Components "WatchApp/Preview Content/PreviewAssets.xcassets" WatchApp/Assets.xcassets \
  ComplicationApp/Assets.xcassets \
  iosTests/Shared watchosTests/Shared
```

- [ ] **Step 2: iOS 진입점 작성** — `iOSApp/iOSApp.swift`

`GolfRound`는 Task 3에서 만들므로 이 시점에는 컨테이너 없이 컴파일되는 최소형으로 두고, Task 3에서 `PersistenceContainerFactory` 연결로 교체한다.

```swift
import SwiftUI

@main
struct GolfCounterApp: App {
    var body: some Scene {
        WindowGroup {
            Text("GolfCounter")
        }
    }
}
```

- [ ] **Step 3: watch 진입점 작성** — `WatchApp/WatchApp.swift`

```swift
import SwiftUI

@main
struct GolfCounterWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("GolfCounter")
        }
    }
}
```

- [ ] **Step 4: 컴플리케이션 스텁 작성** (실제 구현은 plan ②)

`ComplicationApp/ComplicationAppBundle.swift`:

```swift
import SwiftUI
import WidgetKit

@main
struct ComplicationAppBundle: WidgetBundle {
    var body: some Widget {
        ComplicationApp()
    }
}
```

`ComplicationApp/ComplicationApp.swift` (tennis처럼 Provider·Entry·View·Widget을 한 파일에 둔다):

```swift
import SwiftUI
import WidgetKit

struct ComplicationEntry: TimelineEntry {
    let date: Date
}

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date())
    }

    func getSnapshot(in _: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: Date()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(Timeline(entries: [ComplicationEntry(date: Date())], policy: .never))
    }
}

struct ComplicationAppEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Image(systemName: "figure.golf")
    }
}

struct ComplicationApp: Widget {
    let kind: String = "ComplicationApp"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationAppEntryView(entry: entry)
                .containerBackground(.green, for: .widget)
        }
        .configurationDisplayName("GolfCounter")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}
```

- [ ] **Step 5: Assets Contents.json 3벌 + PreviewAssets 2벌 작성**

다섯 개 `*.xcassets/Contents.json` 전부 동일 내용:

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 6: 엔타이틀먼트 3벌 작성**

`GolfCounter.entitlements` (iOS — CloudKit만):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.icloud-container-identifiers</key>
	<array>
		<string>iCloud.com.yj.GolfCounter</string>
	</array>
	<key>com.apple.developer.icloud-services</key>
	<array>
		<string>CloudKit</string>
	</array>
</dict>
</plist>
```

`GolfCounter Watch App.entitlements` (watch — HealthKit + App Group):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.yj.GolfCounter</string>
	</array>
</dict>
</plist>
```

`ComplicationAppExtension.entitlements` (App Group만):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.yj.GolfCounter</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 7: 커밋**

```bash
git add iOSApp WatchApp ComplicationApp Shared *.entitlements iosTests watchosTests
git commit -m "✨ feat: 새 폴더 구조 스켈레톤과 타깃 진입점 추가"
```

(빈 폴더는 git이 추적하지 않으므로 `Shared/`·`iosTests/`·`watchosTests/`가 스테이징에서 빠져도 정상 — Task 3·4에서 파일과 함께 들어간다.)

---

### Task 2: pbxproj 재구성 (tennis 템플릿 적응) + 아이콘 + 기존 소스 삭제

가장 큰 Task. tennis의 `project.pbxproj`(objectVersion 70, synchronized groups)를 복사한 뒤 golf에 맞게 고친다. 완료 기준은 세 스킴이 전부 빌드되는 것.

**Files:**
- Modify: `GolfCounter.xcodeproj/project.pbxproj` (전체 교체)
- Create: `GolfCounter.xcodeproj/xcshareddata/xcschemes/*.xcscheme` (tennis에서 복사·개명)
- Create: `GolfCounter.icon/` (아이콘 복사)
- Delete: `GolfCounter/`, `GolfCounter Watch App/`, `GolfCounterTests/`, `GolfCounterUITests/`, `GolfCounter Watch AppTests/`, `GolfCounter Watch AppUITests/`

**Interfaces:**
- Produces: 스킴 `GolfCounter` / `GolfCounter Watch App` / `ComplicationAppExtension`, 모듈명 `GolfCounter`(iOS)·`GolfCounter_Watch_App`(watch), 테스트 타깃 `iosTests`·`watchosTests`. 이후 모든 plan의 빌드/테스트 명령이 이를 사용.

- [ ] **Step 1: 아이콘 복사**

```bash
cp -R "/Users/yj/Downloads/golf-counter.icon" "/Users/yj/Workspace/golf_counter/GolfCounter.icon"
```

- [ ] **Step 2: 기존 소스·구프로젝트 파일 삭제**

```bash
git rm -r "GolfCounter" "GolfCounter Watch App" "GolfCounterTests" "GolfCounterUITests" \
  "GolfCounter Watch AppTests" "GolfCounter Watch AppUITests"
rm -rf GolfCounter.xcodeproj/xcuserdata GolfCounter.xcodeproj/project.xcworkspace/xcuserdata
```

- [ ] **Step 3: tennis pbxproj·스킴 복사**

```bash
cp ~/Workspace/tennis_counter/TennisCounter.xcodeproj/project.pbxproj GolfCounter.xcodeproj/project.pbxproj
mkdir -p GolfCounter.xcodeproj/xcshareddata/xcschemes
cp ~/Workspace/tennis_counter/TennisCounter.xcodeproj/xcshareddata/xcschemes/*.xcscheme \
  GolfCounter.xcodeproj/xcshareddata/xcschemes/ 2>/dev/null || echo "공유 스킴 없음 — Step 7에서 자동 생성 확인"
```

- [ ] **Step 4: LiveActivity 타깃 제거**

golf에는 Live Activity가 없다. `GolfCounter.xcodeproj/project.pbxproj`에서 `TennisLiveActivity` 관련 요소를 전부 제거한다. 절차:

1. `grep -n "TennisLiveActivity\|LiveActivity" GolfCounter.xcodeproj/project.pbxproj`로 등장 지점을 모두 나열한다.
2. 다음 섹션에서 해당 항목(및 그 항목만)을 삭제한다:
   - `PBXBuildFile` — LiveActivity 임베드 항목
   - `PBXFileReference` / `PBXFileSystemSynchronizedRootGroup` — `TennisLiveActivity` 폴더 참조와 그 exception set들
   - `PBXNativeTarget` — `TennisLiveActivityExtension` 타깃 블록 전체와, iOS 앱 타깃의 `dependencies`·"Embed Foundation Extensions" copy phase 안의 참조
   - `PBXTargetDependency` / `PBXContainerItemProxy` — LiveActivity용 항목
   - `XCConfigurationList` + `XCBuildConfiguration` — LiveActivity 타깃의 Debug/Release 설정 블록 (iOS 26.4 deployment target을 가진 익스텐션 설정이 그것인지 `PRODUCT_BUNDLE_IDENTIFIER`로 확인하고 지울 것)
   - 메인 그룹 `children`과 `Products`의 참조
3. 삭제 후 `grep -c "LiveActivity" GolfCounter.xcodeproj/project.pbxproj` 결과가 0이어야 한다.

- [ ] **Step 5: 이름·식별자 전역 치환**

```bash
cd /Users/yj/Workspace/golf_counter
sed -i '' \
  -e 's/TennisCounter Watch App/GolfCounter Watch App/g' \
  -e 's/TennisCounter/GolfCounter/g' \
  -e 's/Ralli\.icon/GolfCounter.icon/g' \
  -e 's/ASSETCATALOG_COMPILER_APPICON_NAME = Ralli/ASSETCATALOG_COMPILER_APPICON_NAME = GolfCounter/g' \
  GolfCounter.xcodeproj/project.pbxproj
```

치환 결과 자동으로 맞는 것: 번들 ID(`com.yj.GolfCounter*`), 엔타이틀먼트 파일명, App Group·iCloud 문자열, 타깃/스킴/모듈명. 이어서 수동 확인·수정:

1. `PRODUCT_BUNDLE_IDENTIFIER` 전수 확인 — iOS `com.yj.GolfCounter`, watch `com.yj.GolfCounter.watchkitapp`, ComplicationApp `com.yj.GolfCounter.watchkitapp.ComplicationApp`. tennis의 watch 번들 ID 체계가 다르면(`.watchkitapp`이 아니면) 기존 golf 값으로 맞춘다 (App Store 연속성).
2. `MARKETING_VERSION` — iOS 타깃 2.0, watch 2.0.1 (리빌드 전 실제 watch 타깃이 App Store에 이미 2.0으로 존재 — 1.0으로 내리면 업로드 거부 위험), ComplicationApp 1.0 (신설 타깃, 이전 제출 이력 없음).
3. `DEVELOPMENT_TEAM = P2TU28W32L` 전수 확인.
4. `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `WATCHOS_DEPLOYMENT_TARGET = 10.0` (앱 타깃 기준. 테스트 타깃이 26.x면 그대로 둬도 무방).
5. 표시명(`INFOPLIST_KEY_CFBundleDisplayName`)이 "Ralli"로 남아 있으면 "GolfCounter"로.
6. `GolfCounter-Info.plist`를 참조하는 `INFOPLIST_FILE`이 있으면 tennis의 `TennisCounter-Info.plist`를 복사·개명해 오고 내용에서 tennis 고유 키(aps 등)를 제거한다.
7. watch 타깃에 HealthKit 사용 문구가 있는지 확인: `INFOPLIST_KEY_NSHealthShareUsageDescription`·`INFOPLIST_KEY_NSHealthUpdateUsageDescription`이 없으면 추가 (값: "라운드 중 심박수·칼로리를 기록하기 위해 사용합니다." — 로컬라이즈는 plan ⑦).
8. 엔타이틀먼트에서 tennis 잔재 제거 확인 — 우리 파일(Task 1)에는 `aps-environment`가 없으므로 `CODE_SIGN_ENTITLEMENTS` 경로가 Task 1에서 만든 3개 파일을 가리키는지만 확인.
9. `PBXFileSystemSynchronizedBuildFileExceptionSet` 전수 확인 — tennis의 ComplicationApp exception set이 우리 폴더에 없는 파일(`BrandColor.swift` 등)을 참조하면 해당 `membershipExceptions` 항목을 제거하고, exception set이 비게 되면 set 자체와 그룹의 `exceptions` 참조를 삭제한다.
10. 스킴 파일도 동일 sed 적용:

```bash
cd GolfCounter.xcodeproj/xcshareddata/xcschemes
for f in TennisCounter*.xcscheme; do [ -e "$f" ] && mv "$f" "${f/TennisCounter/GolfCounter}"; done
sed -i '' -e 's/TennisCounter Watch App/GolfCounter Watch App/g' -e 's/TennisCounter/GolfCounter/g' *.xcscheme
cd /Users/yj/Workspace/golf_counter
```

LiveActivity 스킴 파일이 복사돼 왔으면 삭제한다.

- [ ] **Step 6: 프로젝트 파싱 확인**

```bash
xcodebuild -list -project GolfCounter.xcodeproj
```

Expected: Targets에 `GolfCounter`, `GolfCounter Watch App`, `ComplicationAppExtension`, `iosTests`, `watchosTests`가 보이고 에러 없음. 파싱 에러가 나면 Step 4·5의 삭제/치환 누락 — 에러 메시지의 오브젝트 ID를 grep해서 고친다.

- [ ] **Step 7: 세 스킴 빌드 검증**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

```bash
WATCH_DEST=$(xcrun simctl list devices available | grep -i "apple watch" | head -1 | sed 's/ (\([0-9A-F-]*\)).*//' | sed 's/^ *//')
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination "platform=watchOS Simulator,name=$WATCH_DEST" build
```

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "ComplicationAppExtension" \
  -destination "platform=watchOS Simulator,name=$WATCH_DEST" build
```

Expected: 3개 모두 `BUILD SUCCEEDED`. ralli-kit 해석 실패 시 `XCLocalSwiftPackageReference "../ralli-kit"`의 relativePath 확인. 서명 에러 시 시뮬레이터 빌드이므로 `CODE_SIGNING_ALLOWED=NO`를 붙여 재시도하고 원인을 기록한다.

- [ ] **Step 8: 커밋**

```bash
git add -A
git commit -m "♻️ refactor: pbxproj를 Xcode 16 synchronized groups로 재구성, ralli-kit 연동·아이콘 적용"
```

---

### Task 3: GolfRound 모델 (TDD)

**Files:**
- Create: `Shared/Persistence/GolfRound.swift`
- Test: `iosTests/Shared/GolfRoundTests.swift`
- Modify: `iOSApp/iOSApp.swift` (ModelContainer 연결)

**Interfaces:**
- Consumes: `PersistenceCore.PersistenceContainerFactory.make(for:cloudKit:inMemory:) -> ModelContainer`
- Produces: `GolfRound` (`@Model final class`) — 저장 프로퍼티 `id: UUID`, `startedAt: Date`, `endedAt: Date?`, `courseName: String?`, `holeScores: [Int]`, `holePars: [Int]`, `puttCounts: [Int]`, `calories: Double`, `avgHeartRate: Double`, `distanceMeters: Double`, `steps: Int` / 계산 프로퍼티 `totalStrokes`, `totalPutts`, `totalPar`, `relativeToPar: Int`. plan ④(수신·저장)·⑤(기록)·⑥(통계)이 이 시그니처에 의존.

- [ ] **Step 1: 실패하는 테스트 작성** — `iosTests/Shared/GolfRoundTests.swift`

```swift
import Foundation
import Testing
@testable import GolfCounter

struct GolfRoundTests {
    @Test func 파생합계_홀배열로부터_계산된다() {
        let round = GolfRound()
        round.holeScores = [4, 3, 6]
        round.holePars = [4, 3, 5]
        round.puttCounts = [2, 1, 2]

        #expect(round.totalStrokes == 13)
        #expect(round.totalPutts == 5)
        #expect(round.totalPar == 12)
        #expect(round.relativeToPar == 1)
    }

    @Test func 빈라운드_합계는_전부0이다() {
        let round = GolfRound()

        #expect(round.totalStrokes == 0)
        #expect(round.totalPutts == 0)
        #expect(round.totalPar == 0)
        #expect(round.relativeToPar == 0)
        #expect(round.endedAt == nil)
        #expect(round.courseName == nil)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/GolfRoundTests
```

Expected: FAIL — `cannot find 'GolfRound' in scope` 컴파일 에러.

- [ ] **Step 3: 모델 구현** — `Shared/Persistence/GolfRound.swift` (spec §3 그대로)

```swift
import Foundation
import SwiftData

/// 한 라운드의 전체 기록. CloudKit 규칙: 전 프로퍼티 기본값/optional, .unique 금지.
/// 홀 데이터는 관계 대신 병렬 배열 — 인덱스 = 홀 번호 - 1.
@Model
final class GolfRound {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var courseName: String?
    var holeScores: [Int] = []
    var holePars: [Int] = []
    var puttCounts: [Int] = []
    var calories: Double = 0
    var avgHeartRate: Double = 0
    var distanceMeters: Double = 0
    var steps: Int = 0

    init() {}

    var totalStrokes: Int { holeScores.reduce(0, +) }
    var totalPutts: Int { puttCounts.reduce(0, +) }
    var totalPar: Int { holePars.reduce(0, +) }
    var relativeToPar: Int { totalStrokes - totalPar }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Step 2와 같은 명령. Expected: PASS 2건.

- [ ] **Step 5: iOS 진입점에 컨테이너 연결** — `iOSApp/iOSApp.swift` 교체

```swift
import PersistenceCore
import SwiftData
import SwiftUI

@main
struct GolfCounterApp: App {
    private let container = PersistenceContainerFactory.make(for: [GolfRound.self])

    var body: some Scene {
        WindowGroup {
            Text("GolfCounter")
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 6: iOS 스킴 빌드 재확인**

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: 커밋**

```bash
git add Shared/Persistence/GolfRound.swift iosTests/Shared/GolfRoundTests.swift iOSApp/iOSApp.swift
git commit -m "✨ feat: GolfRound SwiftData 모델과 파생 프로퍼티 추가"
```

---

### Task 4: RoundSnapshot + RoundSnapshotStore (TDD)

**Files:**
- Create: `Shared/Models/RoundSnapshot.swift`
- Create: `Shared/Services/RoundSnapshotStore.swift`
- Test: `watchosTests/Shared/RoundSnapshotTests.swift`

**Interfaces:**
- Produces:
  - `RoundSnapshot` (`Codable, Equatable` struct) — `startedAt: Date`, `courseName: String?`, `currentHoleIndex: Int`(0-based), `holeScores: [Int]`, `holePars: [Int]`, `puttCounts: [Int]` / 계산 프로퍼티 `totalStrokes: Int`, `relativeToPar: Int`, `currentHoleNumber: Int`
  - `RoundSnapshotStore` — `appGroupID = "group.com.yj.GolfCounter"`, `save(_:to:)`, `load(from:) -> RoundSnapshot?`, `clear(from:)` (전부 `UserDefaults` 주입 가능, 기본값은 App Group suite)
  - plan ②(컴플리케이션 표시)·③(워치 기록/복구)이 이 시그니처에 의존. WidgetKit reload 호출은 여기 넣지 않는다(순수 저장 로직만 — 호출부는 plan ③).

- [ ] **Step 1: 실패하는 테스트 작성** — `watchosTests/Shared/RoundSnapshotTests.swift`

```swift
import Foundation
import Testing
@testable import GolfCounter_Watch_App

struct RoundSnapshotTests {
    private func makeSnapshot() -> RoundSnapshot {
        RoundSnapshot(startedAt: Date(timeIntervalSince1970: 1_000),
                      courseName: "테스트CC",
                      currentHoleIndex: 6,
                      holeScores: [4, 3, 6, 5, 4, 3, 2],
                      holePars: [4, 3, 5, 4, 4, 3, 4],
                      puttCounts: [2, 1, 2, 2, 1, 1, 1])
    }

    @Test func 파생값_현재홀번호와_누적오버파() {
        let snapshot = makeSnapshot()

        #expect(snapshot.currentHoleNumber == 7)
        #expect(snapshot.totalStrokes == 27)
        #expect(snapshot.relativeToPar == 0)
    }

    @Test func 코더블_왕복시_동일하다() throws {
        let snapshot = makeSnapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RoundSnapshot.self, from: data)

        #expect(decoded == snapshot)
    }

    @Test func 스토어_저장후_로드하면_동일하다() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let snapshot = makeSnapshot()

        RoundSnapshotStore.save(snapshot, to: defaults)

        #expect(RoundSnapshotStore.load(from: defaults) == snapshot)
    }

    @Test func 스토어_클리어후_로드는_nil이다() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        RoundSnapshotStore.save(makeSnapshot(), to: defaults)

        RoundSnapshotStore.clear(from: defaults)

        #expect(RoundSnapshotStore.load(from: defaults) == nil)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
WATCH_DEST=$(xcrun simctl list devices available | grep -i "apple watch" | head -1 | sed 's/ (\([0-9A-F-]*\)).*//' | sed 's/^ *//')
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination "platform=watchOS Simulator,name=$WATCH_DEST" -only-testing:watchosTests/RoundSnapshotTests
```

Expected: FAIL — `cannot find 'RoundSnapshot' in scope`.

- [ ] **Step 3: 모델·스토어 구현**

`Shared/Models/RoundSnapshot.swift`:

```swift
import Foundation

/// 라운드 진행 중 상태 스냅샷.
/// 워치 크래시/강제종료 복구와 컴플리케이션 표시 데이터원을 겸한다 (spec §3).
struct RoundSnapshot: Codable, Equatable {
    var startedAt: Date
    var courseName: String?
    var currentHoleIndex: Int // 0-based, 인덱스 = 홀 번호 - 1
    var holeScores: [Int]
    var holePars: [Int]
    var puttCounts: [Int]

    var currentHoleNumber: Int { currentHoleIndex + 1 }
    var totalStrokes: Int { holeScores.reduce(0, +) }
    var relativeToPar: Int { totalStrokes - holePars.reduce(0, +) }
}
```

`Shared/Services/RoundSnapshotStore.swift`:

```swift
import Foundation

/// App Group UserDefaults에 진행 중 라운드 스냅샷을 저장/로드한다.
/// WidgetKit reload 호출은 호출부 책임 (이 타입은 순수 저장만).
enum RoundSnapshotStore {
    static let appGroupID = "group.com.yj.GolfCounter"
    private static let key = "roundSnapshot"

    static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ snapshot: RoundSnapshot, to defaults: UserDefaults? = RoundSnapshotStore.appGroupDefaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load(from defaults: UserDefaults? = RoundSnapshotStore.appGroupDefaults) -> RoundSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RoundSnapshot.self, from: data)
    }

    static func clear(from defaults: UserDefaults? = RoundSnapshotStore.appGroupDefaults) {
        defaults?.removeObject(forKey: key)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Step 2와 같은 명령. Expected: PASS 4건.

- [ ] **Step 5: 커밋**

```bash
git add Shared/Models/RoundSnapshot.swift Shared/Services/RoundSnapshotStore.swift watchosTests/Shared/RoundSnapshotTests.swift
git commit -m "✨ feat: RoundSnapshot 모델과 App Group 스토어 추가"
```

---

### Task 5: 린트 설정 갱신 + 전체 검증 + CLAUDE.md 갱신

**Files:**
- Modify: `.swiftlint.yml` (included 경로, type_name excluded)
- Modify: `CLAUDE.md` (전면 교체)

**Interfaces:**
- Produces: `make lint`/`make format` 통과 상태, 새 구조를 설명하는 CLAUDE.md. 이후 모든 plan이 이 문서 기준으로 작업.

- [ ] **Step 1: .swiftlint.yml 경로 갱신**

`included:`를 새 폴더로 교체:

```yaml
included:
  - Shared
  - iOSApp
  - WatchApp
  - ComplicationApp
```

`type_name`의 `excluded: [GolfCounter_Watch_AppApp]` 항목은 새 진입점명(`GolfCounterWatchApp`)으로 불필요해졌으므로 제거.

- [ ] **Step 2: 포맷·린트 자동 수정 후 통과 확인**

```bash
make fix && make lint && make format
```

Expected: 위반 0 (기존 8건의 `force_unwrapping` 경고는 해당 코드가 삭제되었으므로 사라짐). 위반이 나오면 수정하고 다시 실행.

- [ ] **Step 3: 전체 테스트 재실행**

```bash
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
WATCH_DEST=$(xcrun simctl list devices available | grep -i "apple watch" | head -1 | sed 's/ (\([0-9A-F-]*\)).*//' | sed 's/^ *//')
xcodebuild test -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination "platform=watchOS Simulator,name=$WATCH_DEST"
```

Expected: 전부 PASS (iOS 2건 + watch 4건).

- [ ] **Step 4: CLAUDE.md 전면 교체**

기존 내용은 구 구조 설명이므로 전부 대체한다. 새 내용:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

GolfCounter — 워치 메인 입력, iOS는 기록·통계 전용인 골프 스트로크 카운터.
설계는 `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` 참조 (v1 리빌드 진행 중).
타깃: `GolfCounter`(iOS 17+) / `GolfCounter Watch App`(watchOS 10+) / `ComplicationAppExtension`(watch 위젯).
의존성: `../ralli-kit` 로컬 SPM (WorkoutCore / ConnectivityCore / PersistenceCore). 그 외 없음.

## Commands

```bash
make lint      # swiftlint
make format    # swiftformat --lint (검사만)
make fix       # 자동 수정

# iOS 빌드/테스트
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build   # 또는 test

# watch 빌드/테스트 (기기명은 xcrun simctl list devices available로 확인)
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build   # 또는 test
```

## Architecture & Conventions

폴더 구조·계층화 컴포넌트·MVVM·테스트 규칙은 tennis_counter(`../tennis_counter/CLAUDE.md`) 컨벤션을 그대로 따른다. 요약:

- `Shared/`(Models·Persistence·Services, 양 타깃 공유) / `iOSApp/`·`WatchApp/`(Features + Components) / `ComplicationApp/`
- pbxproj는 Xcode 16 `PBXFileSystemSynchronizedRootGroup` — 파일 생성/삭제는 파일시스템 조작만으로 빌드에 반영된다
- 테스트: Swift Testing, `iosTests/`·`watchosTests/`에서 소스 구조 미러링, ViewModel 우선, View는 테스트 안 함
- 데이터: `GolfRound`(SwiftData, CloudKit 규칙: 기본값/optional, 병렬 배열) / `RoundSnapshot`(진행 중 상태, App Group `group.com.yj.GolfCounter`)
- 워치→iOS 단방향 전송(`.reliable`), iOS만 SwiftData 저장

## Git Workflow

- `main` 직접 push 금지 — 브랜치 + PR, 머지는 항상 일반 merge commit (`gh pr merge <n> --merge --delete-branch`)
- 커밋 메시지는 gitmoji prefix: ✨ feat / 🐛 fix / ♻️ refactor / 🎨 style / 📝 docs / ✅ test / 🔧 chore / 🔥 remove / ⏪ revert

## Docs

`docs/superpowers/specs/`(설계)·`plans/`(구현 계획, 파일명에 common-/watch-/ios- prefix). 사용자 검토 전에는 커밋하지 않는다.
```

- [ ] **Step 5: 커밋**

```bash
git add .swiftlint.yml CLAUDE.md
git commit -m "🔧 chore: 린트 경로·CLAUDE.md를 새 프로젝트 구조로 갱신"
```

---

## 완료 기준

- [ ] 세 스킴(`GolfCounter`, `GolfCounter Watch App`, `ComplicationAppExtension`) 모두 BUILD SUCCEEDED
- [ ] `iosTests`(2건)·`watchosTests`(4건) 전부 PASS
- [ ] `make lint`·`make format` 위반 0
- [ ] 시뮬레이터 홈 화면에 새 아이콘 표시 (iOS·watch 앱 설치 후 육안 확인)
- [ ] 구 소스(`GolfCounter/`, `GolfCounter Watch App/` 등) 삭제 완료
