# iOS 온보딩 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 첫 실행(및 온보딩 버전이 오른 업데이트 직후)에 4페이지 온보딩을 띄운다 — 스크린샷 3장(크라운·건강 앱·인스타 공유) + 애플식 기능 목록 1장.

**Architecture:** `TennisCounterApp` 이 `LaunchScreenView` 다음, `MainTabView` 앞에 `OnboardingView` 를 끼운다. 노출 판단은 순수 함수 `OnboardingGate.shouldShow(seenVersion:)` 가 하고 플래그는 `@AppStorage("onboardingSeenVersion")`. 페이지는 `TabView(.page)`, 스크린샷 페이지와 목록 페이지는 각각 컴포넌트 하나. 이미지는 에셋 카탈로그 로컬라이즈(ko/en)로 두 벌, 크라운 화살표는 이미지에 안 그리고 SwiftUI 오버레이.

**Tech Stack:** SwiftUI / `@AppStorage` / Asset Catalog 이미지 로컬라이즈 / Swift Testing

**Spec:** [docs/specs/ios/2026/2026-09-07-onboarding-design.md](../../../specs/ios/2026/2026-09-07-onboarding-design.md)

**선행:** 작업 #1(공유 버튼)·#4(크라운)이 구현돼 있어야 3페이지 스크린샷을 찍고 1페이지 안내가 거짓이 아니다. Task 1~3(뼈대)은 먼저 해도 되고, Task 4(스크린샷)만 뒤로 미룬다.

## Global Constraints

- **iOS 타깃만.** `WatchApp/`·`Shared/` 는 건드리지 않는다.
- 문자열은 전부 `String(localized:)`. #5 가 끝나 `iOSApp/Localizable.xcstrings` 에 넣는다.
  **`xcodebuild` 는 카탈로그를 갱신하지 않는다** — 추출 반영은 Xcode.app 빌드에서만 일어나므로
  키는 직접 넣는다 (#5 플랜 §카탈로그를 손으로 고칠 때).
- 이미지 에셋은 **로컬라이즈된 이미지셋** (ko/en). 코드는 이미지 이름 하나만 안다.
- 온보딩은 시트가 아니라 **루트 교체**로 띄운다 — 시트는 당겨서 닫히고 플래그가 안 남는다.
- SwiftLint: line length 경고 150 / 오류 200. SwiftFormat: 4-space, imports 알파벳순, trailing comma. 한 파일 = 한 타입 (private helper 예외).
- 브랜치 **`feat/onboarding`**, 메인 체크아웃. gitmoji 커밋.
  (`feat/ralli` 은 PR #11 로 머지되어 더 쓰지 않는다 — 루트 `TODO.md`.)

**빌드·테스트 명령** (루트에서)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" \
  -only-testing:RalliTests/OnboardingGateTests test   # 폴더는 iosTests, 타깃은 RalliTests
make lint && make format
```

## 문자열 표

| 키 | ko | en |
|---|---|---|
| `onboarding_skip` | 건너뛰기 | Skip |
| `onboarding_next` | 다음 | Next |
| `onboarding_start` | 시작하기 | Get Started |
| `onboarding_crown_title` | 크라운으로 점수 입력 | Score with the Crown |
| `onboarding_crown_body` | 워치에서 크라운을 위로 돌리면 내 점수, 아래로 돌리면 상대 점수. 탭해도 됩니다. | On your watch, turn the crown up for your point, down for your opponent's. Tapping works too. |
| `onboarding_crown_up` | 내 점수 | My point |
| `onboarding_crown_down` | 상대 점수 | Their point |
| `onboarding_health_title` | 건강 앱에 기록됩니다 | Saved to Health |
| `onboarding_health_body` | 경기마다 테니스 워크아웃으로 저장됩니다. 칼로리·심박·시간이 건강 앱에 쌓입니다. | Every match is saved as a tennis workout. Calories, heart rate and time build up in Health. |
| `onboarding_share_title` | 인스타 스토리로 공유 | Share to Instagram Stories |
| `onboarding_share_body` | 기록 상세에서 한 번에. 카드는 스티커라 사진 위에 자유롭게 놓을 수 있습니다. | One tap from match details. The card is a sticker — place it anywhere over your photo. |
| `onboarding_more_title` | 그리고 이런 것도 | And a few more |
| `onboarding_more_mirror_title` | 어느 쪽에서 시작해도 | Start from either device |
| `onboarding_more_mirror_body` | 폰과 워치 중 먼저 시작한 쪽이 심판, 다른 쪽은 따라옵니다 | Whichever starts first keeps score; the other follows along |
| `onboarding_more_undo_title` | 되돌리기는 끝까지 | Undo goes all the way |
| `onboarding_more_undo_body` | 게임·세트 경계를 넘어 경기 시작까지 되돌립니다 | Steps back across games and sets, to the first point |
| `onboarding_more_lock_title` | 잠금화면에서 점수 확인 | Score on the Lock Screen |
| `onboarding_more_lock_body` | Live Activity 와 워치 컴플리케이션 | Live Activity and a watch complication |
| `onboarding_more_pause_title` | 폰에서 일시정지 | Pause from your phone |
| `onboarding_more_pause_body` | 워크아웃 탭에서. 워치가 함께 멈춥니다 | In the Workout tab — the watch pauses too |

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `iOSApp/Features/Onboarding/OnboardingGate.swift` | 생성 | `version` 상수 + `shouldShow(seenVersion:)` 순수 함수 |
| `iosTests/Onboarding/OnboardingGateTests.swift` | 생성 | 노출 규칙 4케이스 |
| `iOSApp/Features/Onboarding/OnboardingView.swift` | 생성 | `TabView` 4장, 건너뛰기/다음/시작하기, `onFinished` |
| `iOSApp/Features/Onboarding/Components/OnboardingScreenshotPage.swift` | 생성 | 이미지 + 제목 + 본문. 오버레이 슬롯 |
| `iOSApp/Features/Onboarding/Components/CrownArrowsOverlay.swift` | 생성 | 1페이지 전용 화살표 + 라벨 |
| `iOSApp/Features/Onboarding/Components/OnboardingFeatureListPage.swift` | 생성 | 4페이지 목록 (행은 private helper) |
| `iOSApp/iOSApp.swift` | 수정 | `@AppStorage` 플래그, 런치 → 온보딩 → 메인 분기 |
| `iOSApp/Assets.xcassets/OnboardingCrown.imageset` 등 3개 | 생성 (Xcode) | ko/en 로컬라이즈 이미지 |
| `Localizable` (카탈로그 또는 `.strings`) | 수정 | 위 문자열 표 |

---

### Task 1: `OnboardingGate` — 노출 규칙

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Features/Onboarding/OnboardingGate.swift`
- Create: `Apps/TennisCounter/iosTests/Onboarding/OnboardingGateTests.swift`

**Interfaces:**
- Produces: `enum OnboardingGate { static let version: Int; static func shouldShow(seenVersion: Int) -> Bool }`

- [ ] **Step 1: 실패하는 테스트**

```swift
@testable import TennisCounter
import Testing

struct OnboardingGateTests {
    @Test func freshInstallShows() {
        #expect(OnboardingGate.shouldShow(seenVersion: 0))
    }

    @Test func seenCurrentVersionHides() {
        #expect(!OnboardingGate.shouldShow(seenVersion: OnboardingGate.version))
    }

    @Test func seenOlderVersionShowsAgain() {
        #expect(OnboardingGate.shouldShow(seenVersion: OnboardingGate.version - 1))
    }

    @Test func seenNewerVersionHides() {
        // 다운그레이드 등 — 미래 버전을 본 기록이면 띄우지 않는다
        #expect(!OnboardingGate.shouldShow(seenVersion: OnboardingGate.version + 1))
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `xcodebuild ... -only-testing:RalliTests/OnboardingGateTests test 2>&1 | grep error: | head -2`
Expected: `cannot find 'OnboardingGate' in scope`.

- [ ] **Step 3: 구현**

```swift
/// 온보딩 노출 규칙. "봤나" 가 아니라 "몇 번째까지 봤나" 로 판단한다 —
/// 내용을 고치고 `version` 을 올리면 기존 사용자에게 다시 뜬다 (What's New 역할).
enum OnboardingGate {
    /// 온보딩 내용이 바뀌면 올린다. 1 = 2026-09 크라운·공유·햅틱 출시.
    static let version = 1

    static func shouldShow(seenVersion: Int) -> Bool {
        seenVersion < version
    }
}
```

- [ ] **Step 4: 통과 확인 → 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Features/Onboarding/OnboardingGate.swift Apps/TennisCounter/iosTests/Onboarding/OnboardingGateTests.swift
git commit -m "✨ OnboardingGate — 온보딩 노출 버전 규칙"
```

---

### Task 2: 페이지 컴포넌트 3개

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Features/Onboarding/Components/OnboardingScreenshotPage.swift`
- Create: `Apps/TennisCounter/iOSApp/Features/Onboarding/Components/CrownArrowsOverlay.swift`
- Create: `Apps/TennisCounter/iOSApp/Features/Onboarding/Components/OnboardingFeatureListPage.swift`

**Interfaces:**
- Produces:
  - `OnboardingScreenshotPage<Overlay: View>(imageName: String, title: String, body: String, @ViewBuilder overlay: () -> Overlay)` — `overlay` 기본 `EmptyView`
  - `CrownArrowsOverlay()` — 1페이지에서 `overlay` 로 넣는다
  - `OnboardingFeatureListPage(title: String, items: [OnboardingFeatureListPage.Item])`, `Item(symbol: String, title: String, body: String)`

- [ ] **Step 1: 스크린샷 페이지**

```swift
import SwiftUI

/// 스크린샷 한 장 + 제목 + 본문. 이미지 위에 얹을 게 있으면 `overlay` 로 넘긴다 (크라운 화살표).
struct OnboardingScreenshotPage<Overlay: View>: View {
    let imageName: String
    let title: String
    let body: String
    @ViewBuilder let overlay: () -> Overlay

    init(imageName: String, title: String, body: String,
         @ViewBuilder overlay: @escaping () -> Overlay = { EmptyView() })
    {
        self.imageName = imageName
        self.title = title
        self.body = body
        self.overlay = overlay
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay { overlay() }
                .frame(maxHeight: 420)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreenshotPage(imageName: "OnboardingHealth",
                                 title: "건강 앱에 기록됩니다",
                                 body: "경기마다 테니스 워크아웃으로 저장됩니다.")
    }
}
```

- [ ] **Step 2: 크라운 화살표 오버레이**

워치 스크린샷의 **오른쪽 가장자리 중간**(크라운 위치)에 위·아래 화살표와 라벨을 얹는다. 이미지에 그리지 않으므로 라벨이 로컬라이즈되고 위치 조정이 코드로 끝난다.

```swift
import SwiftUI

/// 워치 스크린샷 위에 얹는 크라운 안내. 오른쪽 가장자리 중간이 크라운 자리다.
struct CrownArrowsOverlay: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 6) {
                arrow("arrow.up", label: String(localized: "onboarding_crown_up"), color: .green)
                arrow("arrow.down", label: String(localized: "onboarding_crown_down"), color: .orange)
            }
            .position(x: geo.size.width + 4, y: geo.size.height * 0.42)
        }
    }

    private func arrow(_ symbol: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.caption.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.7), in: Capsule())
    }
}
```

`y: 0.42` 는 Series 11 46mm 스크린샷 기준 크라운 높이. 다른 기기 스크린샷을 쓰면 프리뷰에서 맞춘다.

- [ ] **Step 3: 목록 페이지**

```swift
import SwiftUI

/// 애플식 "새로운 기능" 목록 — 아이콘 + 제목 + 한 줄, 세로로 쌓는다.
struct OnboardingFeatureListPage: View {
    struct Item: Identifiable {
        let symbol: String
        let title: String
        let body: String
        var id: String { symbol }
    }

    let title: String
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

            ForEach(items) { item in
                Row(item: item)
            }
        }
        .padding(.horizontal, 32)
    }

    private struct Row: View {
        let item: Item

        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: item.symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.brand)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingFeatureListPage(title: "그리고 이런 것도", items: [
            .init(symbol: "applewatch.radiowaves.left.and.right", title: "어느 쪽에서 시작해도",
                  body: "폰과 워치 중 먼저 시작한 쪽이 심판, 다른 쪽은 따라옵니다"),
            .init(symbol: "arrow.uturn.backward", title: "되돌리기는 끝까지",
                  body: "게임·세트 경계를 넘어 경기 시작까지 되돌립니다"),
        ])
    }
}
```

- [ ] **Step 4: 빌드 + 프리뷰 확인 → 커밋**

이미지 에셋이 아직 없어 스크린샷 프리뷰는 빈 자리가 보인다 — 정상. 목록 페이지 프리뷰가 제대로 그려지는지 본다.

```bash
git add Apps/TennisCounter/iOSApp/Features/Onboarding/Components
git commit -m "✨ 온보딩 페이지 컴포넌트 — 스크린샷·크라운 오버레이·기능 목록"
```

---

### Task 3: `OnboardingView` + 앱 진입 분기 + 문자열

**Files:**
- Create: `Apps/TennisCounter/iOSApp/Features/Onboarding/OnboardingView.swift`
- Modify: `Apps/TennisCounter/iOSApp/iOSApp.swift`
- Modify: `Localizable` (카탈로그 또는 `ko.lproj`/`en.lproj/Localizable.strings`)

**Interfaces:**
- Consumes: Task 1·2 전부
- Produces: `OnboardingView(onFinished: () -> Void)`

- [ ] **Step 1: `OnboardingView`**

```swift
import SwiftUI

struct OnboardingView: View {
    let onFinished: () -> Void
    @State private var page = 0
    private let lastPage = 3

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < lastPage {
                        Button(String(localized: "onboarding_skip"), action: onFinished)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                .frame(height: 44)

                TabView(selection: $page) {
                    OnboardingScreenshotPage(
                        imageName: "OnboardingCrown",
                        title: String(localized: "onboarding_crown_title"),
                        body: String(localized: "onboarding_crown_body")
                    ) { CrownArrowsOverlay() }
                        .tag(0)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingHealth",
                        title: String(localized: "onboarding_health_title"),
                        body: String(localized: "onboarding_health_body")
                    )
                    .tag(1)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingShare",
                        title: String(localized: "onboarding_share_title"),
                        body: String(localized: "onboarding_share_body")
                    )
                    .tag(2)

                    OnboardingFeatureListPage(
                        title: String(localized: "onboarding_more_title"),
                        items: [
                            .init(symbol: "applewatch.radiowaves.left.and.right",
                                  title: String(localized: "onboarding_more_mirror_title"),
                                  body: String(localized: "onboarding_more_mirror_body")),
                            .init(symbol: "arrow.uturn.backward",
                                  title: String(localized: "onboarding_more_undo_title"),
                                  body: String(localized: "onboarding_more_undo_body")),
                            .init(symbol: "lock.iphone",
                                  title: String(localized: "onboarding_more_lock_title"),
                                  body: String(localized: "onboarding_more_lock_body")),
                            .init(symbol: "pause.circle",
                                  title: String(localized: "onboarding_more_pause_title"),
                                  body: String(localized: "onboarding_more_pause_body")),
                        ]
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page < lastPage {
                        withAnimation { page += 1 }
                    } else {
                        onFinished()
                    }
                } label: {
                    Text(page < lastPage
                        ? String(localized: "onboarding_next")
                        : String(localized: "onboarding_start"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .colorScheme(.dark)
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
```

- [ ] **Step 2: 앱 진입 분기**

`iOSApp.swift` 의 `TennisCounterApp`:

```swift
    @State private var isLaunching = true
    /// 마지막으로 본 온보딩 버전. 0 = 본 적 없음. 규칙은 OnboardingGate.
    @AppStorage("onboardingSeenVersion") private var onboardingSeenVersion = 0
```

```swift
        WindowGroup {
            if isLaunching {
                LaunchScreenView(onFinished: { isLaunching = false })
            } else if OnboardingGate.shouldShow(seenVersion: onboardingSeenVersion) {
                OnboardingView(onFinished: {
                    withAnimation { onboardingSeenVersion = OnboardingGate.version }
                })
            } else {
                MainTabView()
            }
        }
```

- [ ] **Step 3: 문자열 추가**

위 §문자열 표의 **20개** 키를 ko/en 에 넣는다.
- 카탈로그(#5 이후): 한 번 빌드하면 `iOSApp/Localizable.xcstrings` 에 키가 자동 추출된다. Xcode 에디터에서 ko/en 값을 채운다.
- `.strings`(#5 이전): `iOSApp/ko.lproj/Localizable.strings` 와 `en.lproj` 에 `"키" = "값";` 형식으로 추가.

- [ ] **Step 4: 빌드 + 시뮬레이터 확인**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" build 2>&1 | tail -2
make lint && make format
```

시뮬레이터에서:
1. 앱 삭제 후 설치 → 런치 화면 → **온보딩 뜸** → 4장 넘김 → 시작하기 → 메인 탭
2. 앱 종료 후 재실행 → **온보딩 안 뜸**
3. `xcrun simctl spawn "$IOS" defaults delete com.yj.TennisCounter onboardingSeenVersion` → 재실행 → 다시 뜸 → **건너뛰기** → 메인 탭 → 재실행 → 안 뜸
4. 스킴 App Language 를 English 로 → 삭제 후 설치 → 영문 문자열 확인

이미지 3장은 아직 없어 빈 자리로 보인다 — Task 4 에서 채운다.

- [ ] **Step 5: 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Features/Onboarding/OnboardingView.swift \
        Apps/TennisCounter/iOSApp/iOSApp.swift \
        Apps/TennisCounter/iOSApp/Localizable.xcstrings   # 또는 iOSApp/*.lproj/Localizable.strings
git commit -m "✨ 온보딩 4페이지 — 첫 실행과 온보딩 버전 갱신 시 노출"
```

---

## 구현하며 고친 것 (2026-09-09)

| 플랜 | 실제 | 이유 |
|---|---|---|
| `OnboardingScreenshotPage` 의 본문 파라미터 `body` | **`message`** | `View.body` 와 이름이 겹쳐 컴파일이 안 된다 |
| `CrownArrowsOverlay` 가 `.position(x: geo.size.width + 4, ...)` | **컨테이너 오른쪽 안쪽에 붙인다** (`.frame(alignment: .trailing)` + `.padding(.trailing, 12)` + `.offset(y: -24)`) | `scaledToFit` 은 뷰가 가용 폭을 다 차지하므로 바깥 좌표를 주면 **화면 밖으로 잘린다.** 시뮬레이터에서 확인했다 |
| `OnboardingView` 끝의 `.colorScheme(.dark)` | **뺀다** | #2 가 `TennisCounter-Info.plist` 의 `UIUserInterfaceStyle = Dark` 로 앱 전체를 고정했다. 게다가 `.colorScheme` 은 SwiftUI 하위 트리만 바꾼다 |

**시뮬레이터로 확인한 것** — 첫 실행에 온보딩이 뜨고, `onboardingSeenVersion = 1` 을 심어 재실행하면
메인 탭으로 바로 간다. 4페이지에서 "건너뛰기" 가 사라지고 버튼이 "시작하기" 로 바뀐다.
이미지 3장이 없어 1~3페이지는 빈 자리다 — Task 4 에서 채운다.

---

### Task 4: 스크린샷 3장 × ko/en (사람이 한다)

**선행:** #1 공유 버튼 · #4 크라운 구현 완료.

**Files:**
- Create (Xcode): `iOSApp/Assets.xcassets/OnboardingCrown.imageset`, `OnboardingHealth.imageset`, `OnboardingShare.imageset`

- [ ] **Step 1: 이미지셋 3개 만들고 로컬라이즈 켜기**

Xcode 에셋 카탈로그에서 New Image Set 3개 → 각각 선택 → Attributes inspector → **Localization** 에서 Korean·English 체크. 이미지셋 안에 언어별 슬롯이 생긴다. Scales 는 **Single Scale** (스크린샷은 래스터 한 장이면 된다).

- [ ] **Step 2: 크라운 — 워치 시뮬레이터**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
# 워치 앱 실행 → 모드 선택 → 점수 화면(15-0 정도) 에서
xcrun simctl io "$WATCH" screenshot ~/Desktop/OnboardingCrown-ko.png
# 시뮬레이터 언어를 English 로 (Settings → General → Language) 후 한 번 더
xcrun simctl io "$WATCH" screenshot ~/Desktop/OnboardingCrown-en.png
```

점수는 **15-0** 처럼 내 쪽이 앞선 상태로. 화살표는 오버레이가 그리니 이미지엔 아무것도 안 그린다.

- [ ] **Step 3: 건강 앱 — 실기기**

실제 경기 하나 저장 → 건강 앱 → 훑어보기 → 활동 → 운동 → Ralli 항목 상세. 칼로리·심박·시간이 보이는 상단을 캡처. 기기 언어를 English 로 바꿔 한 번 더.

- [ ] **Step 4: 인스타 공유 — 실기기**

기록 상세 → 공유 → 스토리 편집기가 열린 상태에서 카드 스티커가 가운데쯤 보이게. **배경은 단색**(개인 사진 금지). 캡처 후 언어 바꿔 한 번 더. (인스타그램이 앱 언어를 따라가게 기기 언어를 바꾼다.)

- [ ] **Step 5: 에셋에 넣고 프리뷰·시뮬레이터 확인**

각 이미지셋의 ko/en 슬롯에 드롭. `OnboardingView` 프리뷰에서 1페이지 화살표가 크라운 위치에 맞는지 — 안 맞으면 `CrownArrowsOverlay` 의 `y: 0.42` 조정. 시뮬레이터에서 ko/en 각각 4장 넘겨 본다.

- [ ] **Step 6: 커밋**

```bash
git add Apps/TennisCounter/iOSApp/Assets.xcassets
git commit -m "✨ 온보딩 스크린샷 3장 (ko/en)"
```

---

## 후속 (이번 커밋에 넣지 않는다)

- **설정 페이지 "사용법 다시 보기" (#8)** — `OnboardingView(onFinished: { dismiss() })` 를 시트로. 플래그는 건드리지 않는다.
- **모드 옵션 설명** — No-Ad·타이브레이크 ⓘ 는 모드 선택 화면 소관.
- **크라운 애니메이션** — 정적 화살표가 약하면 1페이지만 회전 애니메이션으로 교체. `CrownArrowsOverlay` 만 바뀐다.

## Self-Review

- 스펙 커버리지 — 4페이지 구성(Task 3 Step 1), 노출 규칙·버전(Task 1 + `@AppStorage`), 루트 교체 진입(Task 3 Step 2), 건너뛰기도 플래그 저장(`onFinished` 공용), 다크 톤(`.colorScheme(.dark)` + 검정 배경), ko/en 이미지(Task 4 Step 1), 런타임 화살표(Task 2 Step 2), iOS 만(제약), 의존 관계(선행 절) ✅
- 타입 일관성 — `OnboardingGate.version`/`shouldShow(seenVersion:)` Task 1 정의·Task 3 사용 ✅. `OnboardingScreenshotPage(imageName:title:body:overlay:)` Task 2 정의·Task 3 호출(트레일링 클로저·기본값 둘 다) ✅. `OnboardingFeatureListPage.Item(symbol:title:body:)` ✅
- 문자열 22개 키가 표와 코드에서 일치 ✅
- 플레이스홀더 없음.
