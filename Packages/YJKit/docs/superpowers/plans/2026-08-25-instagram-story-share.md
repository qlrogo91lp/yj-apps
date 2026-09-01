# WorkoutShareUI 인스타그램 스토리 공유 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워크아웃 결과를 지표 카드로 렌더해 인스타그램 스토리에 스티커로 공유하는 신규 타깃 `WorkoutShareUI`를 만든다.

**Architecture:** `WorkoutResult`를 순수 모델(`WorkoutShareCardModel`)로 변환하고, SwiftUI 카드 뷰를 `ImageRenderer`로 PNG로 굽는다. 인스타그램이 설치되어 있으면 투명 배경 스티커 PNG를 페이스트보드에 올리고 `instagram-stories://` 딥링크를 열고, 아니면 배경이 합성된 1080×1920 이미지를 iOS 공유 시트로 넘긴다. 부수효과(페이스트보드 쓰기, 앱 열기)는 얇은 껍데기로 밀어내고 그 아래 순수 로직만 테스트한다.

**Tech Stack:** Swift 6 tools / Swift 5 language mode, SwiftUI, `ImageRenderer` (iOS 16+), `UIPasteboard`, `UIActivityViewController`, swift-testing.

**설계 문서:** [2026-08-24-instagram-story-share-design.md](../specs/2026-08-24-instagram-story-share-design.md)

## Global Constraints

- 모든 타깃은 `swiftSettings: [.swiftLanguageMode(.v5)]`를 갖는다. 신규 타깃도 동일하게 붙인다.
- 패키지 플랫폼은 `.iOS(.v17)`, `.watchOS(.v10)`. **`WorkoutShareUI`의 모든 소스와 테스트 파일은 `#if os(iOS)` ... `#endif`로 감싼다.**
- 테스트 프레임워크는 swift-testing이다. `import Testing`, `struct` 스위트, `@Test func`, `#expect(...)`. XCTest를 쓰지 않는다.
- 테스트 실행 명령은 항상 이것이다 (모노레포 루트에서 실행):
  ```bash
  make kit-test
  ```
  `swift test`는 이 저장소에서 실패한다(`PersistenceCore`의 macOS 가용성 문제, 이번 작업과 무관).
- 주석과 문서는 한국어로 쓴다. 기존 소스의 어조를 따른다.
- 사용자 노출 문자열은 전부 `String(localized: "키", bundle: .module)`로 읽고 `Resources/{en,ko}.lproj/Localizable.strings`에 정의한다.
- 커밋 메시지는 이모지 접두 + 한국어 한 줄. 예: `✨ WorkoutShareUI 타깃과 카드 모델 추가`
- `WorkoutShareUI`는 `WorkoutCore`에만 의존한다. `WorkoutUI`에 의존하지 않는다.

## 스펙에서 조정한 것

구현 과정에서 스펙보다 나은 선택이 드러난 지점이다. 동작은 스펙 그대로다.

1. **`Row.label: String` → `Row.metric: Metric` 열거형.** 라벨을 모델이 로컬라이즈해 담으면 테스트가 호스트 로케일에 묶인다. 모델은 어떤 지표인지만 담고, 문자열은 뷰가 해석한다.
2. **`averageHeartRate`가 0일 때도 행을 제외한다.** 칼로리 0을 제외하기로 한 것과 같은 이유다 — 0 bpm은 "심박이 0이었다"가 아니라 "수집되지 않았다"는 뜻이다.
3. **`StoryGradient`에 `colors(from:)`을 추가한다.** 딥링크로 넘기는 hex와 폴백 이미지에 그리는 배경이 같은 계산에서 나오게 하기 위함이다.
4. **`Render/ShareCanvas.swift`를 새로 둔다.** 스펙에 없던 파일이다. 캔버스 크기 계산이 스펙에서 가장 틀리기 쉬운 산수인데, 뷰 안에 묻어두면 테스트할 수 없다.
5. **스티커 카드는 라운드 사각형 배경을 갖는다.** 모서리 바깥이 투명해야 하므로 알파 채널과 PNG가 필요하다 — 스펙의 "배경 투명"이 실제로 의미하는 바다.

## 파일 구조

| 파일 | 책임 | 태스크 |
|---|---|---|
| `Package.swift` (수정) | product·target·testTarget 등록 | 1 |
| `Sources/WorkoutShareUI/Resources/{en,ko}.lproj/Localizable.strings` | 버튼·지표 라벨 문자열 | 1 |
| `Sources/WorkoutShareUI/Card/WorkoutShareCardModel.swift` | `WorkoutResult` → 표시 행 배열 | 1 |
| `Sources/WorkoutShareUI/Render/StoryGradient.swift` | 강조색 → 그라디언트 두 색 (hex·Color) | 2 |
| `Sources/WorkoutShareUI/Share/InstagramStoryLink.swift` | 딥링크 URL·페이스트보드 딕셔너리 구성 | 3 |
| `Sources/WorkoutShareUI/Render/ShareCanvas.swift` | 캔버스 크기 산수 | 4 |
| `Sources/WorkoutShareUI/WorkoutShareStyle.swift` | public — 강조색·로고 | 5 |
| `Sources/WorkoutShareUI/Card/WorkoutShareCard.swift` | 카드 SwiftUI 뷰 (스티커/전체) | 5 |
| `Sources/WorkoutShareUI/Render/WorkoutShareRenderer.swift` | 뷰 → `UIImage` | 6 |
| `Sources/WorkoutShareUI/Share/InstagramStoryShare.swift` | 페이스트보드 쓰기 + 앱 열기 | 7 |
| `Sources/WorkoutShareUI/Share/ShareSheet.swift` | `UIActivityViewController` 래퍼 | 7 |
| `Sources/WorkoutShareUI/WorkoutShareButton.swift` | public 진입점 | 8 |
| `README.md` (수정) | 사용법 + 소비자 책임 | 8 |

---

### Task 1: 타깃 스캐폴딩과 카드 모델

**Files:**
- Modify: `Package.swift`
- Create: `Sources/WorkoutShareUI/Resources/ko.lproj/Localizable.strings`
- Create: `Sources/WorkoutShareUI/Resources/en.lproj/Localizable.strings`
- Create: `Sources/WorkoutShareUI/Card/WorkoutShareCardModel.swift`
- Test: `Tests/WorkoutShareUITests/WorkoutShareCardModelTests.swift`

**Interfaces:**
- Consumes: `WorkoutCore.WorkoutResult`, `WorkoutCore.WorkoutMetrics.formatSeconds(_:)`
- Produces:
  - `struct WorkoutShareCardModel: Equatable`
  - `enum WorkoutShareCardModel.Metric: Equatable { case duration, calories, heartRate }`
  - `struct WorkoutShareCardModel.Row: Equatable { let metric: Metric; let value: String; let unit: String? }`
  - `let rows: [Row]`, `init(result: WorkoutResult)`

- [x] **Step 1: `Package.swift`에 product·target·testTarget 추가**

`products` 배열 마지막 항목 뒤에 추가:

```swift
        .library(name: "WorkoutShareUI", targets: ["WorkoutShareUI"]),
```

`targets` 배열에서 `WorkoutUI` 타깃 정의 바로 뒤에 추가:

```swift
        .target(
            name: "WorkoutShareUI",
            dependencies: ["WorkoutCore"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
```

`targets` 배열 마지막에 추가:

```swift
        .testTarget(
            name: "WorkoutShareUITests",
            dependencies: ["WorkoutShareUI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
```

- [x] **Step 2: 로컬라이징 파일 생성**

`resources: [.process("Resources")]`는 디렉터리가 없으면 SPM이 에러를 낸다. 지금 만들어 둔다.

`Sources/WorkoutShareUI/Resources/ko.lproj/Localizable.strings`:

```
"share_button" = "스토리에 공유";
"share_metric_duration" = "시간";
"share_metric_calories" = "활동";
"share_metric_heart_rate" = "심박";
```

`Sources/WorkoutShareUI/Resources/en.lproj/Localizable.strings`:

```
"share_button" = "Share to story";
"share_metric_duration" = "Time";
"share_metric_calories" = "Active";
"share_metric_heart_rate" = "Avg HR";
```

- [x] **Step 3: 타입 껍데기 작성 (테스트가 컴파일되도록)**

`Sources/WorkoutShareUI/Card/WorkoutShareCardModel.swift`:

```swift
#if os(iOS)
    import Foundation
    import WorkoutCore

    /// 공유 카드에 표시할 행 목록. 값이 없는 지표는 행 자체를 만들지 않는다.
    struct WorkoutShareCardModel: Equatable {
        enum Metric: Equatable {
            case duration
            case calories
            case heartRate
        }

        struct Row: Equatable {
            let metric: Metric
            let value: String
            /// 시간 행은 nil — 콜론 포맷이 이미 단위를 담고 있다.
            let unit: String?
        }

        let rows: [Row]

        init(result: WorkoutResult) {
            rows = []
        }
    }
#endif
```

- [x] **Step 4: 실패하는 테스트 작성**

`Tests/WorkoutShareUITests/WorkoutShareCardModelTests.swift`:

```swift
#if os(iOS)
    import Testing
    import WorkoutCore
    @testable import WorkoutShareUI

    struct WorkoutShareCardModelTests {
        private func result(duration: Int = 2538,
                            calories: Double = 312,
                            heartRate: Double? = 148) -> WorkoutResult
        {
            WorkoutResult(durationSeconds: duration,
                          caloriesBurned: calories,
                          averageHeartRate: heartRate)
        }

        @Test func includesAllThreeRowsInOrder() {
            let model = WorkoutShareCardModel(result: result())
            #expect(model.rows.map(\.metric) == [.duration, .calories, .heartRate])
        }

        @Test func omitsHeartRateRowWhenMissing() {
            #expect(WorkoutShareCardModel(result: result(heartRate: nil)).rows.map(\.metric)
                == [.duration, .calories])
            #expect(WorkoutShareCardModel(result: result(heartRate: 0)).rows.map(\.metric)
                == [.duration, .calories])
        }

        @Test func omitsCaloriesRowWhenZero() {
            #expect(WorkoutShareCardModel(result: result(calories: 0)).rows.map(\.metric)
                == [.duration, .heartRate])
        }

        @Test func keepsOnlyDurationWhenOthersMissing() {
            let model = WorkoutShareCardModel(result: result(calories: 0, heartRate: nil))
            #expect(model.rows.map(\.metric) == [.duration])
        }

        @Test func formatsDurationUnderOneHour() {
            let model = WorkoutShareCardModel(result: result(duration: 2538))
            #expect(model.rows[0].value == "42:18")
            #expect(model.rows[0].unit == nil)
        }

        @Test func formatsDurationOverOneHourWithHours() {
            let model = WorkoutShareCardModel(result: result(duration: 5400))
            #expect(model.rows[0].value == "1:30:00")
        }

        @Test func roundsCaloriesAndHeartRateToWholeNumbers() {
            let model = WorkoutShareCardModel(result: result(calories: 312.7, heartRate: 147.6))
            #expect(model.rows[1].value == "313")
            #expect(model.rows[1].unit == "kcal")
            #expect(model.rows[2].value == "148")
            #expect(model.rows[2].unit == "bpm")
        }
    }
#endif
```

- [x] **Step 5: 테스트가 실패하는지 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "WorkoutShareCardModelTests|Test run"
```
Expected: `WorkoutShareCardModelTests`의 7개 테스트가 모두 FAIL. `rows`가 빈 배열이라 `map(\.metric)`이 `[]`이고 인덱스 접근은 범위를 벗어난다.

- [x] **Step 6: 최소 구현**

`WorkoutShareCardModel.swift`의 `init`을 교체:

```swift
        init(result: WorkoutResult) {
            var rows: [Row] = [
                Row(metric: .duration,
                    value: WorkoutMetrics.formatSeconds(result.durationSeconds),
                    unit: nil),
            ]
            if result.caloriesBurned > 0 {
                rows.append(Row(metric: .calories,
                                value: String(format: "%.0f", result.caloriesBurned),
                                unit: "kcal"))
            }
            if let heartRate = result.averageHeartRate, heartRate > 0 {
                rows.append(Row(metric: .heartRate,
                                value: String(format: "%.0f", heartRate),
                                unit: "bpm"))
            }
            self.rows = rows
        }
```

- [x] **Step 7: 테스트 통과 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "WorkoutShareCardModelTests|Test run"
```
Expected: `WorkoutShareCardModelTests` 7개 PASS, 기존 51개 포함 전체 PASS.

- [x] **Step 8: 커밋**

```bash
git add Package.swift Sources/WorkoutShareUI Tests/WorkoutShareUITests
git commit -m "✨ WorkoutShareUI 타깃과 공유 카드 모델 추가"
```

---

### Task 2: StoryGradient

**Files:**
- Create: `Sources/WorkoutShareUI/Render/StoryGradient.swift`
- Test: `Tests/WorkoutShareUITests/StoryGradientTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `enum StoryGradient`
  - `static let darkenFactor: CGFloat` (= 0.6)
  - `static func hexPair(from accent: Color) -> (top: String, bottom: String)`
  - `static func colors(from accent: Color) -> (top: Color, bottom: Color)`

- [x] **Step 1: 껍데기 작성**

`Sources/WorkoutShareUI/Render/StoryGradient.swift`:

```swift
#if os(iOS)
    import SwiftUI
    import UIKit

    /// 강조색에서 스토리 배경 그라디언트의 두 색을 뽑는다.
    /// 딥링크로 넘기는 hex와 폴백 이미지에 그리는 배경이 같은 계산에서 나오게 하는 것이 목적이다.
    enum StoryGradient {
        /// 아래쪽 색은 각 RGB 채널에 이 비율을 곱한 값이다.
        static let darkenFactor: CGFloat = 0.6

        static func hexPair(from accent: Color) -> (top: String, bottom: String) {
            ("", "")
        }

        static func colors(from accent: Color) -> (top: Color, bottom: Color) {
            (accent, accent)
        }
    }
#endif
```

- [x] **Step 2: 실패하는 테스트 작성**

`Tests/WorkoutShareUITests/StoryGradientTests.swift`:

```swift
#if os(iOS)
    import SwiftUI
    import Testing
    @testable import WorkoutShareUI

    struct StoryGradientTests {
        @Test func topKeepsAccentAndBottomIsDarkened() {
            let pair = StoryGradient.hexPair(from: Color(red: 1, green: 0, blue: 0))
            #expect(pair.top == "#FF0000")
            #expect(pair.bottom == "#990000")
        }

        @Test func whiteDarkensToMidGray() {
            let pair = StoryGradient.hexPair(from: .white)
            #expect(pair.top == "#FFFFFF")
            #expect(pair.bottom == "#999999")
        }

        @Test func blackStaysBlackInBothStops() {
            let pair = StoryGradient.hexPair(from: .black)
            #expect(pair.top == "#000000")
            #expect(pair.bottom == "#000000")
        }

        @Test func hexIsHashPlusSixUppercaseDigits() {
            let pair = StoryGradient.hexPair(from: Color(red: 0.2, green: 0.4, blue: 0.6))
            for value in [pair.top, pair.bottom] {
                #expect(value.count == 7)
                #expect(value.hasPrefix("#"))
                #expect(value.dropFirst().allSatisfy { $0.isHexDigit && !$0.isLowercase })
            }
        }

        /// 두 진입점이 어긋나면 딥링크 배경색과 폴백 이미지 배경색이 갈린다.
        @Test func colorsAgreeWithHexPair() {
            let accent = Color(red: 0.2, green: 0.4, blue: 0.6)
            let expected = StoryGradient.hexPair(from: accent)
            let derived = StoryGradient.colors(from: accent)
            #expect(StoryGradient.hexPair(from: derived.top).top == expected.top)
            #expect(StoryGradient.hexPair(from: derived.bottom).top == expected.bottom)
        }
    }
#endif
```

- [x] **Step 3: 테스트가 실패하는지 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "StoryGradientTests|Test run"
```
Expected: 5개 FAIL. `hexPair`가 빈 문자열을 돌려준다.

- [x] **Step 4: 구현**

`StoryGradient`의 두 함수를 교체하고 헬퍼를 추가:

```swift
        static func hexPair(from accent: Color) -> (top: String, bottom: String) {
            let (red, green, blue) = components(of: accent)
            return (hex(red, green, blue),
                    hex(red * darkenFactor, green * darkenFactor, blue * darkenFactor))
        }

        static func colors(from accent: Color) -> (top: Color, bottom: Color) {
            let (red, green, blue) = components(of: accent)
            return (accent,
                    Color(red: red * darkenFactor,
                          green: green * darkenFactor,
                          blue: blue * darkenFactor))
        }

        /// 알파는 무시하고 불투명으로 취급한다.
        private static func components(of color: Color) -> (CGFloat, CGFloat, CGFloat) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return (red, green, blue)
        }

        private static func hex(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> String {
            String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
        }

        private static func channel(_ value: CGFloat) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
```

- [x] **Step 5: 테스트 통과 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "StoryGradientTests|Test run"
```
Expected: 5개 PASS, 전체 PASS.

- [x] **Step 6: 커밋**

```bash
git add Sources/WorkoutShareUI/Render/StoryGradient.swift Tests/WorkoutShareUITests/StoryGradientTests.swift
git commit -m "✨ 강조색에서 스토리 배경 그라디언트를 뽑는 StoryGradient 추가"
```

---

### Task 3: InstagramStoryLink

**Files:**
- Create: `Sources/WorkoutShareUI/Share/InstagramStoryLink.swift`
- Test: `Tests/WorkoutShareUITests/InstagramStoryLinkTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `enum InstagramStoryLink`
  - `static let stickerImageKey/backgroundTopColorKey/backgroundBottomColorKey: String`
  - `static var probeURL: URL?`
  - `static func storyURL(appID: String) -> URL?`
  - `static func pasteboardItems(stickerPNG: Data, topColor: String, bottomColor: String) -> [[String: Any]]`

- [x] **Step 1: 껍데기 작성**

`Sources/WorkoutShareUI/Share/InstagramStoryLink.swift`:

```swift
#if os(iOS)
    import Foundation

    /// 인스타그램 스토리 딥링크에 넘길 URL과 페이스트보드 아이템을 만든다. 부수효과가 없어 그대로 검증할 수 있다.
    enum InstagramStoryLink {
        static let scheme = "instagram-stories"
        static let stickerImageKey = "com.instagram.sharedSticker.stickerImage"
        static let backgroundTopColorKey = "com.instagram.sharedSticker.backgroundTopColor"
        static let backgroundBottomColorKey = "com.instagram.sharedSticker.backgroundBottomColor"

        /// 스킴 등록 여부를 `canOpenURL`로 물을 때 쓴다. appID가 필요 없다.
        static var probeURL: URL? { nil }

        static func storyURL(appID: String) -> URL? { nil }

        static func pasteboardItems(stickerPNG: Data,
                                    topColor: String,
                                    bottomColor: String) -> [[String: Any]]
        {
            []
        }
    }
#endif
```

- [x] **Step 2: 실패하는 테스트 작성**

`Tests/WorkoutShareUITests/InstagramStoryLinkTests.swift`:

```swift
#if os(iOS)
    import Foundation
    import Testing
    @testable import WorkoutShareUI

    struct InstagramStoryLinkTests {
        @Test func storyURLCarriesAppIDAsSourceApplication() {
            #expect(InstagramStoryLink.storyURL(appID: "1234567890")?.absoluteString
                == "instagram-stories://share?source_application=1234567890")
        }

        /// 앱이 App ID를 안 넣은 실수가 조용히 통과하지 않도록 한다.
        @Test func storyURLIsNilWhenAppIDIsBlank() {
            #expect(InstagramStoryLink.storyURL(appID: "") == nil)
            #expect(InstagramStoryLink.storyURL(appID: "   ") == nil)
        }

        @Test func probeURLNeedsNoAppID() {
            #expect(InstagramStoryLink.probeURL?.absoluteString == "instagram-stories://share")
        }

        @Test func pasteboardItemsHoldExactlyThreeKeysInOneItem() {
            let items = InstagramStoryLink.pasteboardItems(stickerPNG: Data([0x01]),
                                                           topColor: "#FF0000",
                                                           bottomColor: "#990000")
            #expect(items.count == 1)
            #expect(Set(items[0].keys) == [
                "com.instagram.sharedSticker.stickerImage",
                "com.instagram.sharedSticker.backgroundTopColor",
                "com.instagram.sharedSticker.backgroundBottomColor",
            ])
        }

        @Test func pasteboardItemsPassValuesThrough() {
            let png = Data([0xDE, 0xAD, 0xBE, 0xEF])
            let items = InstagramStoryLink.pasteboardItems(stickerPNG: png,
                                                           topColor: "#112233",
                                                           bottomColor: "#0A141F")
            #expect(items[0][InstagramStoryLink.stickerImageKey] as? Data == png)
            #expect(items[0][InstagramStoryLink.backgroundTopColorKey] as? String == "#112233")
            #expect(items[0][InstagramStoryLink.backgroundBottomColorKey] as? String == "#0A141F")
        }
    }
#endif
```

- [x] **Step 3: 테스트가 실패하는지 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "InstagramStoryLinkTests|Test run"
```
Expected: 5개 FAIL. URL이 nil이고 아이템 배열이 비어 있다.

- [x] **Step 4: 구현**

세 멤버를 교체:

```swift
        static var probeURL: URL? { URL(string: "\(scheme)://share") }

        static func storyURL(appID: String) -> URL? {
            let trimmed = appID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var components = URLComponents()
            components.scheme = scheme
            components.host = "share"
            components.queryItems = [URLQueryItem(name: "source_application", value: trimmed)]
            return components.url
        }

        static func pasteboardItems(stickerPNG: Data,
                                    topColor: String,
                                    bottomColor: String) -> [[String: Any]]
        {
            [[
                stickerImageKey: stickerPNG,
                backgroundTopColorKey: topColor,
                backgroundBottomColorKey: bottomColor,
            ]]
        }
```

- [x] **Step 5: 테스트 통과 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "InstagramStoryLinkTests|Test run"
```
Expected: 5개 PASS, 전체 PASS.

- [x] **Step 6: 커밋**

```bash
git add Sources/WorkoutShareUI/Share/InstagramStoryLink.swift Tests/WorkoutShareUITests/InstagramStoryLinkTests.swift
git commit -m "✨ 인스타그램 스토리 딥링크 URL·페이스트보드 구성 추가"
```

---

### Task 4: ShareCanvas

**Files:**
- Create: `Sources/WorkoutShareUI/Render/ShareCanvas.swift`
- Test: `Tests/WorkoutShareUITests/ShareCanvasTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `enum ShareCanvas`
  - `static let scale: CGFloat` (= 4), `width: CGFloat` (= 270), `verticalPadding: CGFloat` (= 16), `rowHeight: CGFloat` (= 42), `logoStripHeight: CGFloat` (= 32), `standaloneHeight: CGFloat` (= 480)
  - `static func stickerSize(rowCount: Int, hasLogo: Bool) -> CGSize`
  - `static let standaloneSize: CGSize`

- [x] **Step 1: 껍데기 작성**

`Sources/WorkoutShareUI/Render/ShareCanvas.swift`:

```swift
#if os(iOS)
    import CoreGraphics

    /// 카드 캔버스 크기. 값은 pt이고, 픽셀 크기는 `scale`을 곱한 값이다.
    /// 270 × 4 = 1080이라 폰트 크기를 pt로 잡아도 반올림 오차가 생기지 않는다.
    enum ShareCanvas {
        static let scale: CGFloat = 4
        static let width: CGFloat = 270
        static let verticalPadding: CGFloat = 16
        static let rowHeight: CGFloat = 42
        static let logoStripHeight: CGFloat = 32
        static let standaloneHeight: CGFloat = 480

        /// 스티커 캔버스 — 행 수와 로고 유무에 따라 높이가 변한다.
        static func stickerSize(rowCount: Int, hasLogo: Bool) -> CGSize {
            .zero
        }

        /// 폴백 이미지 캔버스 — 항상 1080×1920 px에 대응한다.
        static let standaloneSize = CGSize(width: width, height: standaloneHeight)
    }
#endif
```

- [x] **Step 2: 실패하는 테스트 작성**

`Tests/WorkoutShareUITests/ShareCanvasTests.swift`:

```swift
#if os(iOS)
    import CoreGraphics
    import Testing
    @testable import WorkoutShareUI

    struct ShareCanvasTests {
        @Test func stickerHeightMatchesTheSpecTable() {
            #expect(ShareCanvas.stickerSize(rowCount: 3, hasLogo: true)
                == CGSize(width: 270, height: 190))
            #expect(ShareCanvas.stickerSize(rowCount: 2, hasLogo: true)
                == CGSize(width: 270, height: 148))
            #expect(ShareCanvas.stickerSize(rowCount: 1, hasLogo: true)
                == CGSize(width: 270, height: 106))
        }

        @Test func droppingLogoRemovesTheStripHeight() {
            #expect(ShareCanvas.stickerSize(rowCount: 3, hasLogo: false).height == 158)
            #expect(ShareCanvas.stickerSize(rowCount: 1, hasLogo: false).height == 74)
        }

        @Test func scaledStickerPixelsAreWholeNumbers() {
            let size = ShareCanvas.stickerSize(rowCount: 3, hasLogo: true)
            #expect(size.width * ShareCanvas.scale == 1080)
            #expect(size.height * ShareCanvas.scale == 760)
        }

        @Test func standaloneCanvasIsStorySize() {
            #expect(ShareCanvas.standaloneSize.width * ShareCanvas.scale == 1080)
            #expect(ShareCanvas.standaloneSize.height * ShareCanvas.scale == 1920)
        }

        /// 스토리 안전 영역은 1080×1330 px = 270×332.5 pt다. 가장 큰 카드가 그 안에 들어가야
        /// 인스타그램 UI에 가리지 않는다.
        @Test func tallestStickerFitsInsideTheStorySafeArea() {
            #expect(ShareCanvas.stickerSize(rowCount: 3, hasLogo: true).height <= 332.5)
        }
    }
#endif
```

- [x] **Step 3: 테스트가 실패하는지 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "ShareCanvasTests|Test run"
```
Expected: `stickerSize`를 쓰는 4개 FAIL(`.zero`를 돌려준다). `standaloneCanvasIsStorySize`는 PASS.

- [x] **Step 4: 구현**

`stickerSize`를 교체:

```swift
        static func stickerSize(rowCount: Int, hasLogo: Bool) -> CGSize {
            let height = verticalPadding * 2
                + rowHeight * CGFloat(rowCount)
                + (hasLogo ? logoStripHeight : 0)
            return CGSize(width: width, height: height)
        }
```

- [x] **Step 5: 테스트 통과 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "ShareCanvasTests|Test run"
```
Expected: 5개 PASS, 전체 PASS.

- [x] **Step 6: 커밋**

```bash
git add Sources/WorkoutShareUI/Render/ShareCanvas.swift Tests/WorkoutShareUITests/ShareCanvasTests.swift
git commit -m "✨ 공유 카드 캔버스 크기 계산 추가"
```

---

### Task 5: 스타일과 카드 뷰

유닛테스트가 붙지 않는 태스크다. 게이트는 **빌드 통과 + Xcode Preview 육안 확인**이다.

**Files:**
- Create: `Sources/WorkoutShareUI/WorkoutShareStyle.swift`
- Create: `Sources/WorkoutShareUI/Card/WorkoutShareCard.swift`

**Interfaces:**
- Consumes: `WorkoutShareCardModel`, `WorkoutShareCardModel.Metric`, `ShareCanvas`, `StoryGradient.colors(from:)`
- Produces:
  - `public struct WorkoutShareStyle { public let accentColor: Color; public let logo: Image?; public init(accentColor: Color, logo: Image? = nil) }`
  - `struct WorkoutShareCard: View`
  - `enum WorkoutShareCard.Mode { case sticker, standalone }`
  - `WorkoutShareCard(model:style:mode:)`
  - `extension WorkoutShareCardModel.Metric { var localizedLabel: String }`

- [x] **Step 1: `WorkoutShareStyle` 작성**

`Sources/WorkoutShareUI/WorkoutShareStyle.swift`:

```swift
#if os(iOS)
    import SwiftUI

    /// 공유 카드에서 앱마다 달라지는 부분. 나머지 레이아웃과 문자열은 패키지가 소유한다.
    public struct WorkoutShareStyle {
        /// 카드 배경 그라디언트가 이 색에서 파생된다. 너무 밝은 색은 흰 텍스트와 대비가 떨어진다.
        public let accentColor: Color
        /// nil이면 카드 하단 로고 줄을 통째로 뺀다.
        public let logo: Image?

        public init(accentColor: Color, logo: Image? = nil) {
            self.accentColor = accentColor
            self.logo = logo
        }
    }
#endif
```

- [x] **Step 2: 카드 뷰 작성**

`Sources/WorkoutShareUI/Card/WorkoutShareCard.swift`:

```swift
#if os(iOS)
    import SwiftUI
    import WorkoutCore

    extension WorkoutShareCardModel.Metric {
        var localizedLabel: String {
            switch self {
            case .duration: String(localized: "share_metric_duration", bundle: .module)
            case .calories: String(localized: "share_metric_calories", bundle: .module)
            case .heartRate: String(localized: "share_metric_heart_rate", bundle: .module)
            }
        }
    }

    /// 스토리에 올릴 지표 카드. 값과 스타일만 받는다 — 서비스나 ViewModel을 모른다.
    struct WorkoutShareCard: View {
        enum Mode {
            /// 카드 모서리 바깥이 투명하다. 인스타그램 스티커로 넘긴다.
            case sticker
            /// 그라디언트가 캔버스 전체를 채우고 카드가 세로 중앙에 놓인다. 공유 시트 폴백용.
            case standalone
        }

        let model: WorkoutShareCardModel
        let style: WorkoutShareStyle
        let mode: Mode

        var body: some View {
            switch mode {
            case .sticker:
                card
                    .frame(width: ShareCanvas.width, height: stickerHeight)
            case .standalone:
                card
                    .frame(width: ShareCanvas.width, height: ShareCanvas.standaloneHeight)
                    .background(gradient)
            }
        }

        private var stickerHeight: CGFloat {
            ShareCanvas.stickerSize(rowCount: model.rows.count,
                                    hasLogo: style.logo != nil).height
        }

        private var card: some View {
            content
                .frame(width: ShareCanvas.width, height: stickerHeight)
                .background(cardBackground)
        }

        /// 스티커 모드에서 이 라운드 사각형의 모서리 바깥이 투명해진다 — PNG와 알파 채널이 필요한 이유다.
        @ViewBuilder private var cardBackground: some View {
            switch mode {
            case .sticker:
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(gradient)
            case .standalone:
                Color.clear
            }
        }

        private var gradient: LinearGradient {
            let pair = StoryGradient.colors(from: style.accentColor)
            return LinearGradient(colors: [pair.top, pair.bottom],
                                  startPoint: .top,
                                  endPoint: .bottom)
        }

        private var content: some View {
            VStack(spacing: 0) {
                ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                    metricRow(row)
                        .frame(height: ShareCanvas.rowHeight)
                }
                if let logo = style.logo {
                    VStack(spacing: 6) {
                        Rectangle()
                            .fill(.white.opacity(0.25))
                            .frame(height: 1)
                        logo
                            .resizable()
                            .scaledToFit()
                            .frame(height: 16)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(height: ShareCanvas.logoStripHeight)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, ShareCanvas.verticalPadding)
        }

        private func metricRow(_ row: WorkoutShareCardModel.Row) -> some View {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(row.metric.localizedLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 8)
                Text(row.value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let unit = row.unit {
                    Text(unit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private let previewResult = WorkoutResult(durationSeconds: 2538,
                                              caloriesBurned: 312,
                                              averageHeartRate: 148)

    #Preview("스티커 · 3행 + 로고") {
        WorkoutShareCard(model: WorkoutShareCardModel(result: previewResult),
                         style: WorkoutShareStyle(accentColor: .green,
                                                  logo: Image(systemName: "figure.tennis")),
                         mode: .sticker)
    }

    #Preview("스티커 · 로고 없음") {
        WorkoutShareCard(model: WorkoutShareCardModel(result: previewResult),
                         style: WorkoutShareStyle(accentColor: .green),
                         mode: .sticker)
    }

    #Preview("스티커 · 1행") {
        WorkoutShareCard(
            model: WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 5400,
                                                               caloriesBurned: 0,
                                                               averageHeartRate: nil)),
            style: WorkoutShareStyle(accentColor: .indigo,
                                     logo: Image(systemName: "figure.golf")),
            mode: .sticker
        )
    }

    #Preview("전체 이미지") {
        WorkoutShareCard(model: WorkoutShareCardModel(result: previewResult),
                         style: WorkoutShareStyle(accentColor: .green,
                                                  logo: Image(systemName: "figure.tennis")),
                         mode: .standalone)
    }
#endif
```

- [x] **Step 3: 빌드 확인**

Run:
```bash
make kit-test 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [x] **Step 4: 기존 테스트가 깨지지 않았는지 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "Test run"
```
Expected: 전체 PASS.

- [ ] **Step 5: Preview 육안 확인**

> **미완료.** 코드는 PR #4로 머지 대기 중이고 빌드·테스트는 통과했지만, Preview를 눈으로 본 사람이 아직 없다.

Xcode에서 `WorkoutShareCard.swift`를 열고 네 개 Preview를 확인한다. 볼 것:

- 3행 카드에서 라벨은 왼쪽, 값과 단위는 오른쪽에 붙어 있는가
- 로고 없는 Preview에서 하단 구분선까지 함께 사라졌는가
- 1행 Preview에서 카드가 그만큼 짧아졌는가 (시간만 표시)
- 전체 이미지 Preview에서 카드가 세로 중앙에 있고 위아래로 그라디언트 여백이 넉넉한가
- 스티커 Preview의 모서리가 둥글고 그 바깥이 비어 있는가

- [x] **Step 6: 커밋**

```bash
git add Sources/WorkoutShareUI/WorkoutShareStyle.swift Sources/WorkoutShareUI/Card/WorkoutShareCard.swift
git commit -m "✨ 공유 카드 뷰와 스타일 추가"
```

---

### Task 6: WorkoutShareRenderer

**Files:**
- Create: `Sources/WorkoutShareUI/Render/WorkoutShareRenderer.swift`
- Test: `Tests/WorkoutShareUITests/WorkoutShareRendererTests.swift`

**Interfaces:**
- Consumes: `WorkoutShareCard`, `WorkoutShareCardModel`, `WorkoutShareStyle`, `ShareCanvas.scale`
- Produces:
  - `@MainActor enum WorkoutShareRenderer`
  - `static func stickerImage(model: WorkoutShareCardModel, style: WorkoutShareStyle) -> UIImage?`
  - `static func standaloneImage(model: WorkoutShareCardModel, style: WorkoutShareStyle) -> UIImage?`

- [x] **Step 1: 껍데기 작성**

`Sources/WorkoutShareUI/Render/WorkoutShareRenderer.swift`:

```swift
#if os(iOS)
    import os
    import SwiftUI
    import UIKit

    /// 카드 뷰를 이미지로 굽는다. 탭 시점에 한 장만 만든다.
    @MainActor
    enum WorkoutShareRenderer {
        private static let logger = Logger(subsystem: "com.yj.YJKit", category: "WorkoutShareUI")

        static func stickerImage(model: WorkoutShareCardModel,
                                 style: WorkoutShareStyle) -> UIImage?
        {
            nil
        }

        static func standaloneImage(model: WorkoutShareCardModel,
                                    style: WorkoutShareStyle) -> UIImage?
        {
            nil
        }
    }
#endif
```

- [x] **Step 2: 실패하는 테스트 작성**

`Tests/WorkoutShareUITests/WorkoutShareRendererTests.swift`:

```swift
#if os(iOS)
    import CoreGraphics
    import SwiftUI
    import Testing
    import UIKit
    import WorkoutCore
    @testable import WorkoutShareUI

    @MainActor
    struct WorkoutShareRendererTests {
        private let style = WorkoutShareStyle(accentColor: .green)

        private var threeRowModel: WorkoutShareCardModel {
            WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 2538,
                                                        caloriesBurned: 312,
                                                        averageHeartRate: 148))
        }

        /// 로고가 없으므로 3행 캔버스는 158pt = 632px다.
        @Test func stickerRendersAtFourTimesTheCanvas() {
            let image = WorkoutShareRenderer.stickerImage(model: threeRowModel, style: style)
            #expect(image?.cgImage?.width == 1080)
            #expect(image?.cgImage?.height == 632)
        }

        @Test func fewerRowsProduceAShorterSticker() {
            let oneRow = WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 600,
                                                                     caloriesBurned: 0,
                                                                     averageHeartRate: nil))
            let image = WorkoutShareRenderer.stickerImage(model: oneRow, style: style)
            #expect(image?.cgImage?.height == 296)
        }

        @Test func standaloneRendersAtStorySize() {
            let image = WorkoutShareRenderer.standaloneImage(model: threeRowModel, style: style)
            #expect(image?.cgImage?.width == 1080)
            #expect(image?.cgImage?.height == 1920)
        }

        /// 카드 모서리 바깥이 비어 있어야 사용자 사진 위에 얹힌다.
        @Test func stickerCornerIsTransparent() throws {
            let image = try #require(WorkoutShareRenderer.stickerImage(model: threeRowModel,
                                                                       style: style))
            #expect(cornerAlpha(of: try #require(image.cgImage)) == 0)
        }

        /// 이미지를 1×1 컨텍스트에 원본 크기로 그리면 좌하단 모서리 픽셀 하나만 남는다.
        private func cornerAlpha(of image: CGImage) -> UInt8 {
            var pixel: [UInt8] = [0, 0, 0, 0]
            pixel.withUnsafeMutableBytes { buffer in
                let context = CGContext(data: buffer.baseAddress,
                                        width: 1,
                                        height: 1,
                                        bitsPerComponent: 8,
                                        bytesPerRow: 4,
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                context?.draw(image, in: CGRect(x: 0,
                                                y: 0,
                                                width: image.width,
                                                height: image.height))
            }
            return pixel[3]
        }
    }
#endif
```

1행 캔버스는 로고 없이 74pt이므로 74 × 4 = 296px이다.

- [x] **Step 3: 테스트가 실패하는지 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "WorkoutShareRendererTests|Test run"
```
Expected: 4개 FAIL. 렌더러가 nil을 돌려준다.

- [x] **Step 4: 구현**

두 함수를 교체하고 헬퍼를 추가:

```swift
        static func stickerImage(model: WorkoutShareCardModel,
                                 style: WorkoutShareStyle) -> UIImage?
        {
            render(WorkoutShareCard(model: model, style: style, mode: .sticker), isOpaque: false)
        }

        static func standaloneImage(model: WorkoutShareCardModel,
                                    style: WorkoutShareStyle) -> UIImage?
        {
            render(WorkoutShareCard(model: model, style: style, mode: .standalone), isOpaque: true)
        }

        private static func render(_ view: some View, isOpaque: Bool) -> UIImage? {
            let renderer = ImageRenderer(content: view)
            renderer.scale = ShareCanvas.scale
            renderer.isOpaque = isOpaque
            guard let image = renderer.uiImage else {
                // 조용히 실패하면 사용자는 버튼이 고장난 줄 안다.
                logger.error("공유 카드 렌더에 실패했다")
                assertionFailure("공유 카드 렌더에 실패했다")
                return nil
            }
            return image
        }
```

- [x] **Step 5: 테스트 통과 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "WorkoutShareRendererTests|Test run"
```
Expected: 4개 PASS, 전체 PASS.

높이가 어긋나면 `WorkoutShareCard`의 `.frame` 계산이 `ShareCanvas`와 다르다는 뜻이다. 테스트의 기대값을 고치지 말고 뷰를 고칠 것 — `ShareCanvas`가 크기의 단일 소스다.

- [x] **Step 6: 커밋**

```bash
git add Sources/WorkoutShareUI/Render/WorkoutShareRenderer.swift Tests/WorkoutShareUITests/WorkoutShareRendererTests.swift
git commit -m "✨ 공유 카드를 이미지로 굽는 렌더러 추가"
```

---

### Task 7: 공유 경로

부수효과 계층이라 유닛테스트가 붙지 않는다. 게이트는 **빌드 통과**이며, 실제 동작은 Task 8에서 시뮬레이터로 확인한다.

**Files:**
- Create: `Sources/WorkoutShareUI/Share/InstagramStoryShare.swift`
- Create: `Sources/WorkoutShareUI/Share/ShareSheet.swift`

**Interfaces:**
- Consumes: `InstagramStoryLink.probeURL`, `InstagramStoryLink.storyURL(appID:)`, `InstagramStoryLink.pasteboardItems(stickerPNG:topColor:bottomColor:)`
- Produces:
  - `@MainActor enum InstagramStoryShare`
  - `static var isAvailable: Bool`
  - `static func share(stickerPNG: Data, topColor: String, bottomColor: String, appID: String, completion: @escaping (Bool) -> Void)`
  - `struct ShareSheet: UIViewControllerRepresentable`, `init(image: UIImage)` (멤버와이즈)

- [x] **Step 1: `InstagramStoryShare` 작성**

`Sources/WorkoutShareUI/Share/InstagramStoryShare.swift`:

```swift
#if os(iOS)
    import Foundation
    import UIKit

    /// 페이스트보드에 스티커를 올리고 인스타그램 스토리 편집기를 연다.
    @MainActor
    enum InstagramStoryShare {
        /// 페이스트보드에 남겨두는 시간. Meta 권장값이다.
        private static let pasteboardLifetime: TimeInterval = 300

        /// 스킴이 등록되어 있고 인스타그램이 설치되어 있는가.
        /// 앱 Info.plist에 LSApplicationQueriesSchemes가 없으면 항상 false다 —
        /// 설정 누락과 미설치가 같은 경로(공유 시트 폴백)를 타는 것은 의도된 동작이다.
        static var isAvailable: Bool {
            guard let url = InstagramStoryLink.probeURL else { return false }
            return UIApplication.shared.canOpenURL(url)
        }

        /// 스토리 편집기를 열었으면 true. false면 호출자가 공유 시트로 폴백한다.
        static func share(stickerPNG: Data,
                          topColor: String,
                          bottomColor: String,
                          appID: String,
                          completion: @escaping (Bool) -> Void)
        {
            guard isAvailable, let url = InstagramStoryLink.storyURL(appID: appID) else {
                completion(false)
                return
            }
            UIPasteboard.general.setItems(
                InstagramStoryLink.pasteboardItems(stickerPNG: stickerPNG,
                                                   topColor: topColor,
                                                   bottomColor: bottomColor),
                options: [.expirationDate: Date().addingTimeInterval(pasteboardLifetime)]
            )
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
        }
    }
#endif
```

- [x] **Step 2: `ShareSheet` 작성**

`Sources/WorkoutShareUI/Share/ShareSheet.swift`:

```swift
#if os(iOS)
    import SwiftUI
    import UIKit

    /// UIActivityViewController를 SwiftUI에서 띄우기 위한 래퍼.
    /// 렌더가 탭 이후에 일어나므로 구성 시점에 아이템이 필요한 ShareLink를 쓸 수 없다.
    struct ShareSheet: UIViewControllerRepresentable {
        let image: UIImage

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: [image], applicationActivities: nil)
        }

        func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
    }
#endif
```

- [x] **Step 3: 빌드 확인**

Run:
```bash
make kit-test 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [x] **Step 4: 기존 테스트가 깨지지 않았는지 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "Test run"
```
Expected: 전체 PASS.

- [x] **Step 5: 커밋**

```bash
git add Sources/WorkoutShareUI/Share/InstagramStoryShare.swift Sources/WorkoutShareUI/Share/ShareSheet.swift
git commit -m "✨ 인스타그램 딥링크 공유와 공유 시트 폴백 추가"
```

---

### Task 8: WorkoutShareButton과 문서

**Files:**
- Create: `Sources/WorkoutShareUI/WorkoutShareButton.swift`
- Modify: `README.md` (`## ConnectivityCore 사용법` 바로 앞에 새 절 삽입)

**Interfaces:**
- Consumes: `WorkoutShareCardModel(result:)`, `WorkoutShareStyle`, `WorkoutShareRenderer.stickerImage(model:style:)`, `WorkoutShareRenderer.standaloneImage(model:style:)`, `StoryGradient.hexPair(from:)`, `InstagramStoryShare.isAvailable`, `InstagramStoryShare.share(stickerPNG:topColor:bottomColor:appID:completion:)`, `ShareSheet(image:)`
- Produces:
  - `public struct WorkoutShareButton: View`
  - `public init(result: WorkoutResult, style: WorkoutShareStyle, instagramAppID: String)`

- [x] **Step 1: 버튼 작성**

`Sources/WorkoutShareUI/WorkoutShareButton.swift`:

```swift
#if os(iOS)
    import SwiftUI
    import UIKit
    import WorkoutCore

    /// 워크아웃 결과를 인스타그램 스토리로 공유하는 버튼.
    /// 인스타그램이 있으면 스토리 편집기를 열고, 없으면 공유 시트로 폴백한다.
    public struct WorkoutShareButton: View {
        private let result: WorkoutResult
        private let style: WorkoutShareStyle
        private let instagramAppID: String

        @State private var fallback: FallbackImage?
        @State private var isPreparing = false

        public init(result: WorkoutResult, style: WorkoutShareStyle, instagramAppID: String) {
            self.result = result
            self.style = style
            self.instagramAppID = instagramAppID
        }

        public var body: some View {
            Button {
                share()
            } label: {
                Label(String(localized: "share_button", bundle: .module),
                      systemImage: "square.and.arrow.up")
            }
            .disabled(isPreparing)
            .sheet(item: $fallback) { ShareSheet(image: $0.image) }
        }

        @MainActor
        private func share() {
            isPreparing = true
            let model = WorkoutShareCardModel(result: result)

            guard InstagramStoryShare.isAvailable,
                  let sticker = WorkoutShareRenderer.stickerImage(model: model, style: style)?
                      .pngData()
            else {
                presentFallback(model: model)
                isPreparing = false
                return
            }

            let colors = StoryGradient.hexPair(from: style.accentColor)
            InstagramStoryShare.share(stickerPNG: sticker,
                                      topColor: colors.top,
                                      bottomColor: colors.bottom,
                                      appID: instagramAppID)
            { opened in
                isPreparing = false
                if !opened { presentFallback(model: model) }
            }
        }

        @MainActor
        private func presentFallback(model: WorkoutShareCardModel) {
            guard let image = WorkoutShareRenderer.standaloneImage(model: model, style: style)
            else { return }
            fallback = FallbackImage(image: image)
        }
    }

    private struct FallbackImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    #Preview {
        WorkoutShareButton(
            result: WorkoutResult(durationSeconds: 2538,
                                  caloriesBurned: 312,
                                  averageHeartRate: 148),
            style: WorkoutShareStyle(accentColor: .green,
                                     logo: Image(systemName: "figure.tennis")),
            instagramAppID: "1234567890"
        )
    }
#endif
```

- [x] **Step 2: 빌드와 테스트 확인**

Run:
```bash
make kit-test 2>&1 | grep -E "Test run|BUILD"
```
Expected: 빌드 성공, 전체 PASS.

- [ ] **Step 3: 시뮬레이터에서 폴백 경로 확인**

> **미완료.** 위와 같다. 시뮬레이터로 확인되는 것은 폴백 경로뿐이며 딥링크는 실기기 몫이다.

시뮬레이터에는 인스타그램이 없고 테스트 호스트에 `LSApplicationQueriesSchemes`도 없으므로 `isAvailable`이 false다. 즉 **폴백 경로가 그대로 확인된다.**

Xcode에서 `WorkoutShareButton.swift`의 Preview를 시뮬레이터로 실행하고 버튼을 누른다. 볼 것:

- 공유 시트가 뜬다
- 시트 상단 썸네일에 그라디언트 배경 위 카드가 세로 중앙으로 보인다
- 이미지를 사진에 저장한 뒤 크기가 1080×1920인지 확인한다

- [x] **Step 4: README에 사용법 절 추가**

`README.md`에서 `## ConnectivityCore 사용법` 바로 앞에 아래를 삽입한다.

````markdown
## WorkoutShareUI 사용법

워크아웃 결과를 인스타그램 스토리에 공유하는 버튼. 앱은 한 줄만 쓰면 된다.

```swift
import WorkoutShareUI

WorkoutShareButton(
    result: workoutResult,
    style: WorkoutShareStyle(accentColor: .tennisGreen, logo: Image("AppLogo")),
    instagramAppID: "1234567890"
)
```

탭하면 인스타그램이 설치된 경우 스토리 편집기가 열린다. 배경은 `accentColor`에서 파생한 그라디언트,
그 위에 지표 카드가 **스티커**로 올라가므로 사용자가 자기 사진·영상으로 배경을 바꾸고 카드를 끌어
배치할 수 있다. 인스타그램이 없으면 배경이 합성된 1080×1920 이미지를 iOS 공유 시트로 넘긴다.

카드에 들어가는 지표는 **시간·활동 kcal·평균 심박 최대 3개**다. 스티커는 사용자가 축소할 수 있어
적게 넣고 크게 보여주는 쪽이 유리하다. 값이 없는 지표(`averageHeartRate`가 nil, 칼로리가 0)는
`--`를 표시하지 않고 **행 자체를 뺀다** — 카드 높이도 그만큼 줄어든다.

버튼 라벨·지표 라벨·레이아웃은 패키지가 소유한다. 앱이 문자열을 관리하지 않는다.

### 소비자 책임 (패키지가 대신 못 해주는 것)

- [ ] **`Info.plist`에 `LSApplicationQueriesSchemes` → `instagram-stories`를 추가한다.** 빠지면 크래시가 아니라 **항상 공유 시트로 폴백된다** — 조용히 동작이 달라지므로 실기기에서 딥링크가 실제로 열리는지 확인할 것.
- [ ] **Meta 개발자 대시보드에서 Facebook App ID를 발급해 `instagramAppID`로 주입한다.** Meta 문서상 2022년 10월부터 필수다. 빈 문자열을 넘기면 딥링크를 만들지 않고 폴백으로 넘어간다.
- [ ] **`WorkoutResult`는 워크아웃 누적값으로 넘긴다.** 구간 델타를 넘기면 두 앱의 숫자 의미가 갈린다 — `WorkoutUI`와 같은 규칙이다.
- [ ] **`accentColor`에서 배경 그라디언트가 파생된다.** 아래쪽 색은 각 RGB 채널에 0.6을 곱한 값이다. 너무 밝은 색을 주면 흰 텍스트와 대비가 떨어진다.
- [ ] **iOS 전용이다.** 워치 타깃에서 임포트해도 심볼이 없다.
````

- [x] **Step 5: 커밋**

```bash
git add Sources/WorkoutShareUI/WorkoutShareButton.swift README.md
git commit -m "✨ WorkoutShareButton 추가와 사용법 문서화"
```

---

## 구현 결과

2026-09-01, Task 1~8 구현 완료. PR [#4](https://github.com/qlrogo91lp/yj-apps/pull/4).

| Task | 커밋 | 게이트 |
|---|---|---|
| 1 타깃·카드 모델 | `d5f24f4` | 테스트 7 |
| 2 StoryGradient | `2ff51f4` | 테스트 5 |
| 3 InstagramStoryLink | `47ec262` | 테스트 5 |
| 4 ShareCanvas | `ab54987` | 테스트 5 |
| 5 카드 뷰·스타일 | `7bcb7d4` | 빌드 |
| 6 WorkoutShareRenderer | `ec3a858` | 테스트 4 |
| 7 공유 경로 | `415e1c2` | 빌드 |
| 8 WorkoutShareButton·문서 | `dd73b2c` | 빌드 |

테스트 26개가 늘었고 기존 69개(51/9/9)와 함께 전부 통과한다. 모든 태스크에서 RED를 먼저 확인한 뒤 구현했다.
CI는 `Packages/YJKit/` 변경을 코어 변경으로 잡아 두 앱까지 전부 빌드했고, 새 타깃이 기존 앱을 깨지 않는 것이 확인됐다.

### 플랜과 달랐던 것

1. **README 상단 Product 표에 `WorkoutShareUI` 행을 추가했다.** 플랜은 사용법 절만 지시했으나 그 표가 프로덕트 목록이라 누락이 된다.
2. **RED 단계 실패 개수가 두 곳에서 플랜 기대보다 1개 적었다.** Task 2의 `colorsAgreeWithHexPair`와 Task 4의 `tallestStickerFitsInsideTheStorySafeArea`가 껍데기 상태(`""`, `.zero`)에서 우연히 통과한다. 구현 후에야 검증력을 갖는 테스트이므로 문제는 아니다.

### 남은 육안 확인

Task 5 Step 5(카드 Preview 4개)와 Task 8 Step 3(시뮬레이터 폴백 경로)은 미체크로 남겼다. 자동 검증이 닿지 않는 부분이라 사람이 봐야 한다.

## 구현 후 실기기 확인

시뮬레이터에는 인스타그램이 없어 딥링크 경로를 확인할 수 없다. 아래 셋은 실기기에서만 검증된다.
`Info.plist`에 `LSApplicationQueriesSchemes` → `instagram-stories`를 넣은 소비자 앱에 붙여서 확인한다.

1. **딥링크가 스토리 편집기를 여는가.** 안 열리면 App ID가 유효한지, `Info.plist` 항목이 들어갔는지 먼저 본다.
2. **인스타그램이 스티커를 어느 크기로 배치하는가.** Meta 권장은 640×480인데 우리는 1080×760으로 넘긴다. 너무 크거나 작게 들어가면 `ShareCanvas.width`를 조정하고 `ShareCanvasTests`의 기대값을 함께 고친다.
3. **"다른 앱에서 붙여넣기" 프롬프트가 뜨는가.** 뜬다면 없앨 방법은 없다(사용자 설정 영역). 그 경우 공유 시트를 기본 경로로 바꾸는 것을 재검토한다 — 스펙 작성 시점에 미해결로 남겨둔 항목이다.
