# Complication SVG 교체 + 워크아웃 회전 애니메이션 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ComplicationApp의 아이콘을 `Ralli_icon.svg`로 교체하고, 워크아웃 세션이 활성 상태일 때 컴플리케이션 아이콘이 회전하는 애니메이션을 추가한다.

**Architecture:** WatchApp과 ComplicationApp이 App Group UserDefaults(`group.com.yj.TennisCounter`)를 통해 워크아웃 활성 상태(`isWorkoutActive`)를 공유한다. WatchApp은 workout 시작/종료 시 UserDefaults에 상태를 기록하고 `WidgetCenter.shared.reloadTimelines(ofKind:)`를 호출해 컴플리케이션을 강제 갱신한다. 컴플리케이션 Provider는 타임라인 생성 시 UserDefaults를 읽어 `SimpleEntry`에 포함하고, View는 `onAppear`에서 조건부로 회전 애니메이션을 시작한다.

**Tech Stack:** SwiftUI, WidgetKit, App Groups (UserDefaults), watchOS 10+

---

## 수정 파일 목록

| 구분 | 경로 | 내용 |
|------|------|------|
| 생성 | `ComplicationApp/Assets.xcassets/RalliIcon.imageset/Contents.json` | SVG imageset 메타데이터 |
| 복사 | `ComplicationApp/Assets.xcassets/RalliIcon.imageset/Ralli_icon.svg` | iOS에서 복사 |
| 수정 | `ComplicationApp/ComplicationApp.swift` | SVG 사용 + 회전 애니메이션 |
| 수정 | `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | App Group 쓰기 + WidgetCenter 호출 |
| 자동 수정 (Xcode) | `TennisCounter Watch App.entitlements` | App Group entitlement 추가 |
| 자동 수정 (Xcode) | `ComplicationAppExtension.entitlements` | App Group entitlement 추가 |

---

## Task 1: [Xcode 수동 작업] App Group Capability 추가

> ⚠️ 이 Task는 코드 에디터가 아닌 **Xcode에서 직접** 수행해야 합니다.  
> App Group은 Apple Developer 계정과 연동된 Provisioning Profile을 통해 등록되므로 Xcode UI를 통해서만 설정할 수 있습니다.

**파일:** `TennisCounter Watch App.entitlements`, `ComplicationAppExtension.entitlements` (Xcode가 자동 수정)

- [ ] **Step 1: WatchApp 타겟에 App Group 추가**

  1. Xcode에서 `TennisCounter.xcodeproj` 열기
  2. 좌측 Project Navigator에서 최상단 `TennisCounter` 프로젝트 클릭
  3. TARGETS 목록에서 **`TennisCounter Watch App`** 선택
  4. 상단 탭에서 **`Signing & Capabilities`** 클릭
  5. 좌상단 **`+ Capability`** 버튼 클릭
  6. 검색창에 `App Groups` 입력 후 더블클릭으로 추가
  7. App Groups 섹션에서 **`+`** 버튼 클릭
  8. `group.com.yj.TennisCounter` 입력 후 OK

- [ ] **Step 2: ComplicationApp 타겟에 App Group 추가**

  1. TARGETS 목록에서 **`ComplicationAppExtension`** 선택
  2. **`Signing & Capabilities`** 탭 클릭
  3. **`+ Capability`** → `App Groups` 더블클릭
  4. **`+`** 버튼 → `group.com.yj.TennisCounter` 선택 (위에서 만든 것, 새로 생성 X)
  5. OK

- [ ] **Step 3: entitlements 파일 검증**

  두 파일 모두 아래 키가 추가됐는지 확인:

  `TennisCounter Watch App.entitlements`:
  ```xml
  <key>com.apple.security.application-groups</key>
  <array>
      <string>group.com.yj.TennisCounter</string>
  </array>
  ```

  `ComplicationAppExtension.entitlements`:
  ```xml
  <key>com.apple.security.application-groups</key>
  <array>
      <string>group.com.yj.TennisCounter</string>
  </array>
  ```

---

## Task 2: SVG 에셋을 ComplicationApp Assets에 추가

**파일:**
- 생성: `ComplicationApp/Assets.xcassets/RalliIcon.imageset/Contents.json`
- 복사: `ComplicationApp/Assets.xcassets/RalliIcon.imageset/Ralli_icon.svg`

- [ ] **Step 1: imageset 디렉토리 생성 및 SVG 복사**

  ```bash
  mkdir -p ComplicationApp/Assets.xcassets/RalliIcon.imageset
  cp iOSApp/Assets.xcassets/RalliIcon.imageset/Ralli_icon.svg \
     ComplicationApp/Assets.xcassets/RalliIcon.imageset/Ralli_icon.svg
  ```

- [ ] **Step 2: Contents.json 생성**

  `ComplicationApp/Assets.xcassets/RalliIcon.imageset/Contents.json`:
  ```json
  {
    "images" : [
      {
        "filename" : "Ralli_icon.svg",
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

- [ ] **Step 3: 빌드로 에셋 인식 확인**

  ```bash
  xcodebuild -project TennisCounter.xcodeproj \
    -scheme "ComplicationAppExtension" \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
    build 2>&1 | tail -5
  ```

  예상 출력: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

  ```bash
  git add ComplicationApp/Assets.xcassets/RalliIcon.imageset/
  git commit -m "feat: SVG 아이콘 에셋을 ComplicationApp에 추가"
  ```

---

## Task 3: ComplicationApp 뷰 업데이트 (SVG + 조건부 회전 애니메이션)

**파일:**
- 수정: `ComplicationApp/ComplicationApp.swift`

현재 `ComplicationApp.swift`는 `SimpleEntry`에 날짜만 있고, `Provider`는 App Group을 읽지 않으며, View는 PNG 이미지를 사용한다.

- [ ] **Step 1: `ComplicationApp.swift` 전체를 아래 코드로 교체**

  ```swift
  import SwiftUI
  import WidgetKit

  private let appGroupID = "group.com.yj.TennisCounter"
  private let workoutActiveKey = "isWorkoutActive"

  struct Provider: TimelineProvider {
      func placeholder(in _: Context) -> SimpleEntry {
          SimpleEntry(date: Date(), isWorkoutActive: false)
      }

      func getSnapshot(in _: Context, completion: @escaping (SimpleEntry) -> Void) {
          let isActive = UserDefaults(suiteName: appGroupID)?.bool(forKey: workoutActiveKey) ?? false
          completion(SimpleEntry(date: Date(), isWorkoutActive: isActive))
      }

      func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
          let isActive = UserDefaults(suiteName: appGroupID)?.bool(forKey: workoutActiveKey) ?? false
          let entry = SimpleEntry(date: Date(), isWorkoutActive: isActive)
          let timeline = Timeline(entries: [entry], policy: .never)
          completion(timeline)
      }
  }

  struct SimpleEntry: TimelineEntry {
      let date: Date
      let isWorkoutActive: Bool
  }

  struct ComplicationAppEntryView: View {
      @Environment(\.widgetFamily) var widgetFamily
      @State private var rotation: Double = 0
      var entry: Provider.Entry

      var body: some View {
          switch widgetFamily {
          case .accessoryCorner:
              iconImage
                  .renderingMode(.original)
                  .resizable()
                  .scaledToFit()
                  .rotationEffect(.degrees(rotation))
                  .onAppear { startRotationIfNeeded() }
          case .accessoryRectangular:
              HStack(spacing: 6) {
                  iconImage
                      .renderingMode(.original)
                      .resizable()
                      .scaledToFit()
                      .frame(width: 24, height: 24)
                      .clipShape(Circle())
                      .rotationEffect(.degrees(rotation))
                      .onAppear { startRotationIfNeeded() }
                  Text("Tennis Counter")
                      .font(.headline)
                      .widgetAccentable()
              }
          default:
              iconImage
                  .renderingMode(.original)
                  .resizable()
                  .scaledToFill()
                  .rotationEffect(.degrees(rotation))
                  .clipShape(Circle())
                  .onAppear { startRotationIfNeeded() }
          }
      }

      private var iconImage: Image {
          Image("RalliIcon")
      }

      private func startRotationIfNeeded() {
          guard entry.isWorkoutActive else { return }
          withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
              rotation = 360
          }
      }
  }

  struct ComplicationApp: Widget {
      let kind: String = "ComplicationApp"

      var body: some WidgetConfiguration {
          StaticConfiguration(kind: kind, provider: Provider()) { entry in
              if #available(watchOS 10.0, *) {
                  ComplicationAppEntryView(entry: entry)
                      .containerBackground(.fill.tertiary, for: .widget)
              } else {
                  ComplicationAppEntryView(entry: entry)
                      .padding()
                      .background()
              }
          }
          .configurationDisplayName("Tennis Counter")
          .description("Tennis score counter complication.")
          .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
      }
  }

  #Preview(as: .accessoryCircular) {
      ComplicationApp()
  } timeline: {
      SimpleEntry(date: .now, isWorkoutActive: false)
      SimpleEntry(date: .now, isWorkoutActive: true)
  }

  #Preview(as: .accessoryRectangular) {
      ComplicationApp()
  } timeline: {
      SimpleEntry(date: .now, isWorkoutActive: false)
  }

  #Preview(as: .accessoryCorner) {
      ComplicationApp()
  } timeline: {
      SimpleEntry(date: .now, isWorkoutActive: false)
  }
  ```

- [ ] **Step 2: 빌드 확인**

  ```bash
  xcodebuild -project TennisCounter.xcodeproj \
    -scheme "ComplicationAppExtension" \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
    build 2>&1 | tail -5
  ```

  예상 출력: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Xcode Canvas에서 Preview 확인**

  - Xcode에서 `ComplicationApp.swift` 열기
  - Preview Canvas에서 `isWorkoutActive: false` → 정적 아이콘
  - `isWorkoutActive: true` → 회전하는 아이콘 (Preview에서는 애니메이션이 안 보일 수 있음)

- [ ] **Step 4: 커밋**

  ```bash
  git add ComplicationApp/ComplicationApp.swift
  git commit -m "feat: 컴플리케이션 아이콘 SVG 교체 및 워크아웃 회전 애니메이션 추가"
  ```

---

## Task 4: WorkoutSessionViewModel — App Group 상태 기록 + WidgetCenter 호출

**파일:**
- 수정: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`

워크아웃 시작(`startWorkout`) 및 종료(`endWorkout`) 시점에 App Group UserDefaults에 상태를 기록하고 컴플리케이션을 갱신해야 한다.

- [ ] **Step 1: import WidgetKit 추가 및 상수 정의**

  파일 상단 import 블록에 추가:
  ```swift
  import WidgetKit
  ```

  클래스 내부 상단(프로퍼티 선언 위)에 추가:
  ```swift
  private let appGroupDefaults = UserDefaults(suiteName: "group.com.yj.TennisCounter")
  ```

- [ ] **Step 2: `startWorkout()` 수정**

  기존:
  ```swift
  func startWorkout() {
      Task {
          await healthKit.requestAuthorization()
          healthKit.startWorkout()
      }
  }
  ```

  변경:
  ```swift
  func startWorkout() {
      Task {
          await healthKit.requestAuthorization()
          healthKit.startWorkout()
          appGroupDefaults?.set(true, forKey: "isWorkoutActive")
          WidgetCenter.shared.reloadTimelines(ofKind: "ComplicationApp")
      }
  }
  ```

- [ ] **Step 3: `endWorkout()` 수정**

  기존:
  ```swift
  func endWorkout() {
      _currentSession = nil
      Task { _ = await healthKit.stopWorkout() }
  }
  ```

  변경:
  ```swift
  func endWorkout() {
      _currentSession = nil
      appGroupDefaults?.set(false, forKey: "isWorkoutActive")
      WidgetCenter.shared.reloadTimelines(ofKind: "ComplicationApp")
      Task { _ = await healthKit.stopWorkout() }
  }
  ```

- [ ] **Step 4: WatchApp 빌드 확인**

  ```bash
  xcodebuild -project TennisCounter.xcodeproj \
    -scheme "TennisCounter Watch App" \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
    build 2>&1 | tail -5
  ```

  예상 출력: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

  ```bash
  git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
  git commit -m "feat: 워크아웃 시작/종료 시 컴플리케이션 상태 동기화 추가"
  ```

---

## Task 5: 통합 검증 (시뮬레이터 또는 실기기)

> 시뮬레이터에서는 WidgetKit 컴플리케이션 애니메이션이 제한적으로 동작합니다.  
> 정확한 검증은 실제 Apple Watch에서 수행하는 것을 권장합니다.

- [ ] **Step 1: 전체 빌드 확인**

  ```bash
  xcodebuild -project TennisCounter.xcodeproj \
    -scheme "TennisCounter" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    build 2>&1 | tail -5
  ```

  예상 출력: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 실기기 동작 체크리스트**

  Apple Watch에 앱 설치 후:
  - [ ] 시계 화면에 컴플리케이션 추가 → **Ralli SVG 아이콘**이 표시되는지 확인
  - [ ] Watch 앱 실행 → 워크아웃 시작 → 컴플리케이션 아이콘이 **회전**하는지 확인
  - [ ] 워크아웃 종료 → 컴플리케이션 아이콘이 **정지**하는지 확인
  - [ ] Watch Face Gallery에서 컴플리케이션 선택 화면에서 **앱 아이콘** (Icon Composer 결과물) 표시 확인

- [ ] **Step 3: lint 통과 확인**

  ```bash
  make lint
  ```

  예상 출력: 경고 없음 또는 기존 경고만 존재

---

## 참고: 기술적 제약 사항

- **watchOS 10 미만**: `onAppear` 기반 애니메이션은 watchOS 10+에서 가장 안정적으로 동작합니다. watchOS 9 이하에서는 회전이 보이지 않을 수 있으나, 정적 SVG 아이콘은 정상 표시됩니다.
- **시뮬레이터**: 컴플리케이션 애니메이션은 시뮬레이터에서 재현이 어렵습니다. 회전 여부는 실기기에서 확인하세요.
- **App Group**: Xcode에서 Capability를 추가하면 Apple Developer 포털에 자동으로 App Group identifier가 등록됩니다. 처음 추가 시 인터넷 연결 필요.

---

## 실기기 테스트 후 발견된 사항 및 구현 변경

### 문제: `withAnimation(.repeatForever)`은 WidgetKit에서 동작하지 않음

최초 플랜의 애니메이션 구현(`@State` + `withAnimation(.repeatForever)`)은 실기기에서 동작하지 않았다.

**근본 원인:** WidgetKit 컴플리케이션 뷰는 라이브 SwiftUI 뷰가 아니라 **정적 스냅샷**으로 렌더링된다. Extension 프로세스가 잠깐 깨어나 뷰를 이미지로 찍은 뒤 종료되기 때문에, `@State` 변경과 `withAnimation`이 일으키는 프레임별 렌더링이 존재하지 않는다.

```
// 동작하지 않는 방식 (원래 플랜)
@State private var rotation: Double = 0
withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
    rotation = 360  // 실행은 되지만 display loop가 없어 화면에 반영 안 됨
}
```

### 해결: 타임라인 프레임 방식으로 전환

`SimpleEntry`에 `rotationDegrees`와 `scaleFactor`를 추가하고, 워크아웃 활성 시 `getTimeline`에서 여러 entry를 미리 생성해 시스템에 예약한다. 시스템이 각 entry의 예약 시각에 해당 스냅샷으로 교체하여 애니메이션처럼 보이게 한다.

```swift
// 현재 구현
private let rotationFrameCount = 8      // 45° 간격
private let rotationFrameInterval = 2.0 // 초 단위, 한 프레임 지속 시간
private let rotationBatchSize = 80      // 한 번에 생성할 entries 수 (~160초)

struct SimpleEntry: TimelineEntry {
    let date: Date
    let isWorkoutActive: Bool
    let rotationDegrees: Double  // 0, 45, 90 ... 315
    let scaleFactor: Double      // 1.0 ↔ 0.85 교번 (맥박 효과)
}
```

- 워크아웃 활성 시: 80개 entry 생성 (160초치), 소진 후 `.after` 정책으로 재호출 → 루프
- 워크아웃 종료 시: `WidgetCenter.reloadTimelines()` → entry 1개, `.never` 정책으로 정지

### 배터리 고려 사항

- 타임라인 프레임 방식은 2초마다 스냅샷을 교체하므로 이론상 1시간에 1,800회 렌더링
- 그러나 **워크아웃 중 사용자는 대부분 앱(WorkoutSessionView)을 띄워놓고, 컴플리케이션은 watch face에서만 보인다**
- 실제로 컴플리케이션이 표시되는 시간은 짧으므로 실질적인 배터리 부담은 낮다
- watchOS는 AOD(항상켜기 화면) 모드에서 컴플리케이션 갱신을 자동으로 줄인다

### SF Symbols / 커스텀 심볼 가능성 검토

피트니스 앱의 달리는 사람 애니메이션은 SF Symbols의 `.symbolEffect()` 수식어를 사용한다. 이 방식은 Extension 프로세스 없이 시스템 컴포지터(GPU)가 직접 렌더링하므로 배터리 효율이 높다.

**커스텀 SF Symbol 제작은 가능하다** (SF Symbols 앱 → SVG 편집 → Xcode Assets 추가). 그러나 `.symbolEffect()`에는 **연속 회전(`.rotate`) 효과가 없다** — `.pulse`, `.bounce`, `.scale`, `.variableColor` 등 강조 계열만 존재한다. 따라서 커스텀 SF Symbol을 만들어도 아이콘 회전 애니메이션은 타임라인 프레임 방식을 사용해야 한다.
